-- Constants
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
local function gen_grid(height)
	local shape = {}
	for y = 1, height do shape[y] = {} end
	return shape
end

local function get_target(center_x, center_y, direction)
	if direction == "E" then
		return center_x + 1, center_y
	elseif direction == "S" then
		return center_x, center_y + 1
	elseif direction == "W" then
		return center_x - 1, center_y
	else
		return center_x, center_y - 1
	end
end

local function extract_connected_atoms(shape, start_x, start_y)
	-- make sure we actually have an atom at the starting position
	local atom = shape[start_y][start_x]
	if not atom then return nil end

	-- BFS through the shape, removing any atom connected through bonds to the starting atom
	shape[start_y][start_x] = nil
	local atoms = {atom}
	local atom_i = 1
	function check_connected_atom(check_atom)
		if not check_atom then return end
		table.insert(atoms, check_atom)
		shape[check_atom.y][check_atom.x] = nil
	end
	repeat
		if atom.left then check_connected_atom(shape[atom.y][atom.x - 1]) end
		if atom.up then check_connected_atom(shape[atom.y - 1][atom.x]) end
		if atom.right then check_connected_atom(shape[atom.y][atom.x + 1]) end
		if atom.down then check_connected_atom(shape[atom.y + 1][atom.x]) end
		atom_i = atom_i + 1
		atom = atoms[atom_i]
	until not atom
	return atoms
end

local function normalize_shape(shape)
	local min_x, max_x, min_y, max_y
	for y, shape_row in pairs(shape) do
		for x, atom in pairs(shape_row) do
			if not min_x or x < min_x then min_x = x end
			if not max_x or x > max_x then max_x = x end
			if not min_y or y < min_y then min_y = y end
			if not max_y or y > max_y then max_y = y end
		end
	end
	local width = max_x - min_x + 1
	local height = max_y - min_y + 1
	if width > MAX_GRID_WIDTH or height > MAX_GRID_HEIGHT then return nil end
	if min_x == 1 and min_y == 1 then return shape end
	local new_shape = {}
	for y = 1, height do
		local new_shape_row = {}
		local shape_row = shape[min_y + y - 1]
		for x = 1, width do new_shape_row[x] = shape_row[min_x + x - 1] end
		new_shape[y] = new_shape_row
	end
	return shape
end


-- Building definitions
BUILDING_DEFINITIONS = {
	["molecule-sorter"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-1"},
		item_order = "b",
		-- data and control fields
		reactants = {BASE_NAME},
		products = {RESULT_NAME, REMAINDER_NAME},
		-- control fields
		selectors = {[BASE_NAME] = TARGET_SELECTOR_NAME, [MODIFIER_NAME] = ATOM_SELECTOR_NAME},
		reaction = function(reaction)
			local molecule = reaction.reactants[BASE_NAME]
			local target = reaction.selectors[BASE_NAME]
			local target_atom = reaction.selectors[MODIFIER_NAME]
			if not molecule or not target or not target_atom then return false end

			local y_scale, x_scale, y, x = parse_target(target)
			local shape, height, width = parse_molecule(molecule)
			if height == y_scale and width == x_scale then
				local atom = shape[y][x]
				if atom and atom.symbol == string.sub(target_atom, #ATOM_ITEM_PREFIX + 1) then
					reaction.products[RESULT_NAME] = molecule
					return true
				end
			end

			reaction.products[REMAINDER_NAME] = molecule
			return true
		end,
	},
	["molecule-rotator"] = {
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
			local rotation = reaction.selectors[MODIFIER_NAME]
			if not molecule or not rotation then return false end

			local shape, height, width = parse_molecule(molecule)
			rotation = tonumber(string.sub(rotation, -1))
			local rotate = ROTATE[rotation]
			local rotate_atom = ROTATE_ATOM[rotation]

			-- if a bond is not specified, rotate the entire molecule
			local atom_bond = reaction.selectors[BASE_NAME]
			if not atom_bond then
				-- no need to rotate a single atom, it's already its own result
				if height == 1 and width == 1 then
					reaction.products[RESULT_NAME] = molecule
					return true
				end

				-- build the shape of the new grid
				local center_x = (width + 1) / 2
				local center_y = (height + 1) / 2
				if rotation == 1 then
					width, height, center_y = height, width, center_x
				elseif rotation == 3 then
					width, height, center_x = height, width, center_y
				end
				local new_shape = gen_grid(height)

				-- move all the atoms into the new shape
				for y, shape_row in pairs(shape) do
					for x, atom in pairs(shape_row) do
						new_x, new_y = rotate(center_x, center_y, x, y)
						rotate_atom(atom)
						new_shape[new_y][new_x] = atom
					end
				end
				shape = new_shape
			else
				local y_scale, x_scale, center_y, center_x, direction = parse_atom_bond(atom_bond)
				-- any reaction on an atom produces that same atom
				if y_scale == 1 and x_scale == 1 then
					-- but it has to actually be an atom
					if not string.find(molecule, ATOM_ITEM_PREFIX_MATCH) then return false end
					reaction.products[RESULT_NAME] = molecule
					return true
				end

				-- verify that we have a molecule matching the selector shape, an atom at the center, and an
				--	atom at the target
				if height ~= y_scale or width ~= x_scale then return false end

				local center_row = shape[center_y]
				local center_atom = center_row[center_x]
				center_row[center_x] = nil
				if not center_atom then return false end

				-- all the requirements are met, now remove all the connected atoms from the shape so that we
				--	can re-insert them at their rotated positions
				local target_x, target_y = get_target(center_x, center_y, direction)
				local atoms_to_rotate = extract_connected_atoms(shape, target_x, target_y)
				if not atoms_to_rotate then return false end

				-- then, rotate them all, and make sure that there are no collisions
				for _, atom in ipairs(atoms_to_rotate) do
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
				shape = normalize_shape(shape)
				if not shape then return false end
			end

			-- and now, finally, we can reassemble the molecule and produce it
			reaction.products[RESULT_NAME] = assemble_molecule(shape, height, width)
			return true
		end,
	},
	["molecule-debonder"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-2"},
		item_order = "d",
		-- data and control fields
		reactants = {BASE_NAME, CATALYST_NAME, MODIFIER_NAME},
		products = {RESULT_NAME, BYPRODUCT_NAME, REMAINDER_NAME},
		-- control fields
		selectors = {
			[BASE_NAME] = ATOM_BOND_INNER_SELECTOR_NAME,
			[CATALYST_NAME] = ATOM_SELECTOR_NAME,
			[MODIFIER_NAME] = ATOM_SELECTOR_NAME,
		},
		reaction = function(reaction)
			return false
		end,
	},
	["molecule-voider"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-3"},
		item_order = "e",
		-- data and control fields
		reactants = {BASE_NAME},
		products = {},
		-- control fields
		selectors = {},
		reaction = function(reaction)
			return reaction.reactants[BASE_NAME] ~= nil
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
