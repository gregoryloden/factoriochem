-- Constants
local MOLECULE_ITEM_PREFIX_MATCH = "^"..MOLECULE_ITEM_PREFIX
local ATOM_ITEM_PREFIX_MATCH = "^"..ATOM_ITEM_PREFIX
local PARSE_MOLECULE_ROW_MATCH = "([^"..ATOM_ROW_SEPARATOR.."]+)"..ATOM_ROW_SEPARATOR
local PARSE_MOLECULE_ATOM_MATCH = "([^"..ATOM_COL_SEPARATOR.."]*)"..ATOM_COL_SEPARATOR


-- Reaction utilities
local function parse_molecule(molecule)
	if string.find(molecule, MOLECULE_ITEM_PREFIX_MATCH) then
		molecule = string.sub(molecule, #MOLECULE_ITEM_PREFIX + 1)
		local shape = {}

		-- extract the initial data from the molecule
		for molecule_row in string.gmatch(molecule..ATOM_ROW_SEPARATOR, PARSE_MOLECULE_ROW_MATCH) do
			local shape_row = {}
			for atom_data in string.gmatch(molecule_row..ATOM_COL_SEPARATOR, PARSE_MOLECULE_ATOM_MATCH) do
				local atom = {symbol = string.match(atom_data, "%a+")}
				local up = string.match(atom_data, "^%d")
				if up then atom.up = tonumber(up) end
				local right = string.match(atom_data, "%d$")
				if right then atom.right = tonumber(right) end
				table.insert(shape_row, atom)
			end
			table.insert(shape, shape_row)
		end

		-- add corresponding down and left bonds, and also compute the grid width
		local grid_width = 0
		for y, shape_row in ipairs(shape) do
			for x, atom in ipairs(shape_row) do
				if atom.up then shape[y - 1][x].down = atom.up end
				if atom.right then shape_row[x + 1].left = atom.right end
			end
			local shape_row_width = #shape_row
			if shape_row_width > grid_width then grid_width = shape_row_width end
		end

		return shape, #shape, grid_width
	elseif string.find(molecule, ATOM_ITEM_PREFIX_MATCH) then
		return {{{symbol = string.sub(molecule, #ATOM_ITEM_PREFIX + 1)}}}, 1, 1
	else
		error("Unexpected molecule ID \""..molecule.."\"")
	end
end

local function gen_grid(height, width)
	local shape = {}
	for _ = 1, height do
		local shape_row = {}
		for _ = 1, width do table.insert(shape_row, {}) end
		table.insert(shape, shape_row)
	end
	return shape
end

local function assemble_molecule(shape)
	local builder = {MOLECULE_ITEM_PREFIX}
	for y, shape_row in ipairs(shape) do
		if y > 1 then table.insert(builder, ATOM_ROW_SEPARATOR) end
		local next_col = 1
		for x, atom in ipairs(shape_row) do
			if atom.symbol then
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
	if #builder == 2 then builder[1] = ATOM_ITEM_PREFIX end
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

			-- build the shape of the new grid
			local shape, height, width = parse_molecule(molecule)
			local rotation = tonumber(string.sub(reaction.selectors[BASE_NAME], -1))
			local new_shape
			if rotation == 2 then
				new_shape = gen_grid(height, width)
			else
				new_shape = gen_grid(width, height)
			end

			-- setup the function to move atoms into the new shape
			local write_atom
			if rotation == 1 then
				write_atom = function(base_atom, y, x)
					atom = new_shape[width + 1 - x][y]
					atom.symbol, atom.up, atom.right = base_atom.symbol, base_atom.right, base_atom.down
				end
			elseif rotation == 3 then
				write_atom = function(base_atom, y, x)
					atom = new_shape[x][height + 1 - y]
					atom.symbol, atom.up, atom.right = base_atom.symbol, base_atom.left, base_atom.up
				end
			else
				write_atom = function(base_atom, y, x)
					atom = new_shape[height + 1 - y][width + 1 - x]
					atom.symbol, atom.up, atom.right = base_atom.symbol, base_atom.down, base_atom.left
				end
			end

			-- write all the corresponding atoms
			for y, shape_row in ipairs(shape) do
				for x, atom in ipairs(shape_row) do write_atom(atom, y, x) end
			end

			-- turn the shape into a molecule and write it to the output
			reaction.products[RESULT_NAME] = assemble_molecule(new_shape)
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
