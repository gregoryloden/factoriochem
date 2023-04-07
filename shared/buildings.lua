-- Constants
local MOLECULE_ITEM_PREFIX_MATCH = "^"..MOLECULE_ITEM_PREFIX
local ATOM_ITEM_PREFIX_MATCH = "^"..ATOM_ITEM_PREFIX
local PARSE_MOLECULE_ROW_MATCH = "([^"..ATOM_ROW_SEPARATOR.."]+)"..ATOM_ROW_SEPARATOR
local PARSE_MOLECULE_ATOM_MATCH = "([^"..ATOM_COL_SEPARATOR.."]*)"..ATOM_COL_SEPARATOR
local ROTATE = {
	-- left
	function(center_x, center_y, x, y) return center_x - center_y + y, center_y + center_x - x end,
	-- flip
	function(center_x, center_y, x, y) return center_x + center_x - x, center_y + center_y - y end,
	-- right
	function(center_x, center_y, x, y) return center_x + center_y - y, center_y - center_x + x end,
}
local ROTATE_ATOM = {
	-- left
	function(atom) atom.left, atom.up, atom.right, atom.down = atom.up, atom.right, atom.down, atom.left end,
	-- flip
	function(atom) atom.left, atom.up, atom.right, atom.down = atom.right, atom.down, atom.left, atom.up end,
	-- right
	function(atom) atom.left, atom.up, atom.right, atom.down = atom.down, atom.left, atom.up, atom.right end,
}


-- Reaction utilities
local function parse_molecule(molecule)
	if string.find(molecule, MOLECULE_ITEM_PREFIX_MATCH) then
		molecule = string.sub(molecule, #MOLECULE_ITEM_PREFIX + 1)
		local shape = {}

		-- extract the initial data from the molecule
		local grid_height = 0
		local grid_width = 0
		for molecule_row in string.gmatch(molecule..ATOM_ROW_SEPARATOR, PARSE_MOLECULE_ROW_MATCH) do
			grid_height = grid_height + 1
			local shape_row = {}
			local x = 0
			for atom_data in string.gmatch(molecule_row..ATOM_COL_SEPARATOR, PARSE_MOLECULE_ATOM_MATCH) do
				x = x + 1
				local symbol = string.match(atom_data, "%a+")
				if symbol then
					local atom = {symbol = symbol}
					local up = string.match(atom_data, "^%d")
					if up then atom.up = tonumber(up) end
					local right = string.match(atom_data, "%d$")
					if right then atom.right = tonumber(right) end
					shape_row[x] = atom
				end
			end
			if x > grid_width then grid_width = x end
			shape[grid_height] = shape_row
		end

		-- add corresponding down and left bonds
		for y, shape_row in pairs(shape) do
			for x, atom in pairs(shape_row) do
				if atom.up then shape[y - 1][x].down = atom.up end
				if atom.right then shape_row[x + 1].left = atom.right end
			end
		end
		return shape, grid_height, grid_width
	else
		error("Unexpected molecule ID \""..molecule.."\"")
	end
end

local function gen_grid(height)
	local shape = {}
	for y = 1, height do shape[y] = {} end
	return shape
end

local function assemble_molecule(shape, height, width)
	local builder = {MOLECULE_ITEM_PREFIX}
	for y = 1, height do
		shape_row = shape[y]
		if y > 1 then table.insert(builder, ATOM_ROW_SEPARATOR) end
		local next_col = 1
		for x = 1, width do
			atom = shape_row[x]
			if atom then
				while next_col < x do
					table.insert(builder, ATOM_COL_SEPARATOR)
					next_col = next_col + 1
				end
				if atom.up then table.insert(builder, atom.up) end
				table.insert(builder, atom.symbol)
				if atom.right then table.insert(builder, atom.right) end
			end
		end
	end
	return table.concat(builder)
end


-- Building definitions
BUILDING_DEFINITIONS = {
	["molecule-rotater"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-1"},
		item_order = "b",
		-- data and control fields
		reactants = {BASE_NAME},
		products = {RESULT_NAME},
		-- control fields
		selectors = {[BASE_NAME] = ROTATION_SELECTOR_NAME},
		reaction = function(reaction)
			local molecule = reaction.reactants[BASE_NAME]
			if not molecule then return false end
			if string.find(molecule, ATOM_ITEM_PREFIX_MATCH) then
				-- don't bother doing calculations to rotate an atom, it's already its own result
				reaction.products[RESULT_NAME] = molecule
				return true
			end

			-- capture stats about the old grid shape and build the shape of the new grid
			local shape, height, width = parse_molecule(molecule)
			local center_x = (width + 1) / 2
			local center_y = (height + 1) / 2
			local rotation = tonumber(string.sub(reaction.selectors[BASE_NAME], -1))
			if rotation == 2 then width, height = height, width end
			local new_shape = gen_grid(height)

			-- move all the atoms into the new shape
			local rotate = ROTATE[rotation]
			local rotate_atom = ROTATE_ATOM[rotation]
			for y, shape_row in pairs(shape) do
				for x, atom in pairs(shape_row) do
					new_x, new_y = rotate(center_x, center_y, x, y)
					rotate_atom(atom)
					new_shape[new_y][new_x] = atom
				end
			end

			-- turn the shape into a molecule and write it to the output
			reaction.products[RESULT_NAME] = assemble_molecule(new_shape, height, width)
			return true
		end,
	},
}
for _, building_definition in pairs(BUILDING_DEFINITIONS) do
	building_definition.has_component = {}
	for _, reactant_name in ipairs(building_definition.reactants) do
		building_definition.has_component[reactant_name] = true
	end
	for _, product_name in ipairs(building_definition.products) do
		building_definition.has_component[product_name] = true
	end
end
