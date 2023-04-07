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

		-- add corresponding down and left bonds and add coordinates
		for y, shape_row in pairs(shape) do
			for x, atom in pairs(shape_row) do
				if atom.up then shape[y - 1][x].down = atom.up end
				if atom.right then shape_row[x + 1].left = atom.right end
				atom.x = x
				atom.y = y
			end
		end
		return shape, grid_height, grid_width
	elseif string.find(molecule, ATOM_ITEM_PREFIX_MATCH) then
		return {{{symbol = string.sub(molecule, #ATOM_ITEM_PREFIX + 1), x = 1, y = 1}}}, 1, 1
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

local function extract_atom_bond(atom_bond)
	return tonumber(string.sub(atom_bond, -5, -5)), -- y_scale
		tonumber(string.sub(atom_bond, -4, -4)), -- x_scale
		tonumber(string.sub(atom_bond, -3, -3)) + 1, -- y
		tonumber(string.sub(atom_bond, -2, -2)) + 1, -- x
		string.sub(atom_bond, -1, -1) -- direction
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
	["molecule-bender"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-1"},
		item_order = "c",
		-- data and control fields
		reactants = {BASE_NAME},
		products = {RESULT_NAME},
		-- control fields
		selectors = {[BASE_NAME] = ATOM_BOND_INNER_SELECTOR_NAME, [MODIFIER_NAME] = ROTATION_SELECTOR_NAME},
		reaction = function(reaction)
			local molecule = reaction.reactants[BASE_NAME]
			if not molecule then return false end
			local y_scale, x_scale, center_y, center_x, direction = extract_atom_bond(reaction.selectors[BASE_NAME])
			-- any reaction on an atom produces that same atom
			if y_scale == 1 and x_scale == 1 then
				-- but it has to actually be an atom
				if not string.find(molecule, ATOM_ITEM_PREFIX_MATCH) then return false end
				reaction.products[RESULT_NAME] = molecule
				return true
			end

			-- verify that we have a molecule matching the selector shape, an atom at the center, and an atom at the
			--	target
			local shape, height, width = parse_molecule(molecule)
			if height ~= y_scale or width ~= x_scale then return false end

			local center_row = shape[center_y]
			local center_atom = center_row[center_x]
			if not center_atom then return false end

			local target_x, target_y = center_x, center_y
			if direction == "E" then
				target_x = center_x + 1
			elseif direction == "S" then
				target_y = center_y + 1
			elseif direction == "W" then
				target_x = center_x - 1
			else
				target_y = center_y - 1
			end
			local rotate_atom = shape[target_y][target_x]
			if not rotate_atom then return false end

			-- all the requirements are met, now BFS to find all atoms connected by the bond
			-- remove atoms from the shape as we find them so that we can re-insert them at their rotated positions
			center_row[center_x] = nil
			shape[target_y][target_x] = nil
			local rotate_atoms = {rotate_atom}
			local rotate_atoms_i = 1
			function check_rotate_atom(check_atom)
				if not check_atom then return end
				table.insert(rotate_atoms, check_atom)
				shape[check_atom.y][check_atom.x] = nil
			end
			repeat
				if rotate_atom.left then check_rotate_atom(shape[rotate_atom.y][rotate_atom.x - 1]) end
				if rotate_atom.up then check_rotate_atom(shape[rotate_atom.y - 1][rotate_atom.x]) end
				if rotate_atom.right then check_rotate_atom(shape[rotate_atom.y][rotate_atom.x + 1]) end
				if rotate_atom.down then check_rotate_atom(shape[rotate_atom.y + 1][rotate_atom.x]) end
				rotate_atoms_i = rotate_atoms_i + 1
				rotate_atom = rotate_atoms[rotate_atoms_i]
			until not rotate_atom

			-- then, rotate them all, and make sure that there are no collisions
			local rotation = tonumber(string.sub(reaction.selectors[MODIFIER_NAME], -1))
			local rotate = ROTATE[rotation]
			local rotate_atom = ROTATE_ATOM[rotation]
			for _, atom in ipairs(rotate_atoms) do
				local dest_x, dest_y = rotate(center_x, center_y, atom.x, atom.y)
				atom.x, atom.y = dest_x, dest_y
				rotate_atom(atom)
				local shape_row = shape[dest_y]
				if not shape_row then
					shape_row = {}
					shape[dest_y] = shape_row
				end
				if shape_row[dest_x] then return false end
				shape_row[dest_x] = atom
			end

			-- restore the center atom and reassign bonds to it now that other atoms have been rotated
			center_atom = {symbol = center_atom.symbol}
			center_row[center_x] = center_atom
			local center_up_atom = shape[center_y - 1] and shape[center_y - 1][center_x]
			local center_left_atom = center_row[center_x - 1]
			local center_right_atom = center_row[center_x + 1]
			local center_down_atom = shape[center_y + 1] and shape[center_y + 1][center_x]
			if center_up_atom then center_atom.up = center_up_atom.down end
			if center_left_atom then center_atom.left = center_left_atom.right end
			if center_right_atom then center_atom.right = center_right_atom.left end
			if center_down_atom then center_atom.down = center_down_atom.up end

			-- normalize the positions of all the atoms, if needed
			local min_x, max_x, min_y, max_y = center_x, center_x, center_y, center_y
			for y, shape_row in pairs(shape) do
				for x, atom in pairs(shape_row) do
					if x < min_x then min_x = x end
					if x > max_x then max_x = x end
					if y < min_y then min_y = y end
					if y > max_y then max_y = y end
				end
			end
			width = max_x - min_x + 1
			height = max_y - min_y + 1
			if width > MAX_GRID_WIDTH or height > MAX_GRID_HEIGHT then return false end
			if min_x ~= 1 or min_y ~= 1 then
				local new_shape = {}
				for y = 1, height do
					local new_shape_row = {}
					local shape_row = shape[min_y + y - 1]
					for x = 1, width do new_shape_row[x] = shape_row[min_x + x - 1] end
					new_shape[y] = new_shape_row
				end
				shape = new_shape
			end

			-- and now, finally, we can reassemble the molecule and produce it
			reaction.products[RESULT_NAME] = assemble_molecule(shape, height, width)
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
