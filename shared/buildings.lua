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

local function verify_base_atom_bond(reaction)
	local molecule = reaction.reactants[BASE_NAME]
	local atom_bond = reaction.selectors[BASE_NAME]
	if not molecule or not atom_bond then return nil end

	local shape, height, width = parse_molecule(molecule)
	local y_scale, x_scale, center_y, center_x, direction = parse_atom_bond(atom_bond)
	if y_scale ~= height or x_scale ~= width then return nil end

	local source = shape[center_y][center_x]
	if not source then return nil end

	return source, shape, height, width, center_y, center_x, direction
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

local function get_bonds(atom, direction)
	if direction == "E" then
		return atom.right
	elseif direction == "S" then
		return atom.down
	elseif direction == "W" then
		return atom.left
	else
		return atom.up
	end
end

local function set_bonds(source, target, direction, bonds)
	if bonds == 0 then bonds = nil end
	if direction == "E" then
		source.right, target.left = bonds, bonds
	elseif direction == "S" then
		source.down, target.up = bonds, bonds
	elseif direction == "W" then
		source.left, target.right = bonds, bonds
	else
		source.up, target.down = bonds, bonds
	end
end

local function extract_connected_atoms(shape, start_x, start_y)
	-- make sure we actually have an atom at the starting position
	local start_row = shape[start_y]
	if not start_row then return nil end
	local atom = start_row[start_x]
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

local function has_any_atoms(shape)
	for _, shape_row in pairs(shape) do
		for _, _ in pairs(shape_row) do return true end
	end
	return false
end

local function perform_fission(atom, byproduct)
	local atom_number = ALL_ATOMS[atom.symbol].number
	local byproduct_atom
	if byproduct then
		-- we can assume that the byproduct is an atom because fission is always performed off of selectors
		byproduct_atom = parse_molecule(byproduct)[1][1]
	else
		byproduct_atom = {symbol = ALL_ATOMS[math.ceil(atom_number / 2)].symbol}
	end
	local new_atom = ALL_ATOMS[atom_number - ALL_ATOMS[byproduct_atom.symbol].number]
	if not new_atom then return false end
	atom.symbol = new_atom.symbol
	return true, byproduct_atom
end

local function perform_fusion(atom, catalyst, catalyst_atom)
	if catalyst then
		local catalyst_shape, catalyst_height, catalyst_width = parse_molecule(catalyst)
		if catalyst_height ~= 1 or catalyst_width ~= 1 then return false end
		catalyst_atom = catalyst_shape[1][1]
	end
	local new_atom = ALL_ATOMS[ALL_ATOMS[atom.symbol].number + ALL_ATOMS[catalyst_atom.symbol].number]
	if not new_atom then return false end
	atom.symbol = new_atom.symbol
	return true
end

local function maybe_perform_mutation(atom, mutation, catalyst)
	if catalyst ~= nil then
		return mutation == PERFORM_FUSION_SELECTOR_SUBGROUP and perform_fusion(atom, catalyst)
	-- mutation is optional, so it's valid if there is no catalyst and no mutation
	elseif not mutation then
		return true
	else
		return mutation ~= PERFORM_FUSION_SELECTOR_SUBGROUP and perform_fission(atom, mutation)
	end
end

local function merge_with_modifier(shape, target_x, target_y, modifier, modifier_target)
	local modifier_shape, modifier_height, modifier_width = parse_molecule(modifier)
	local modifier_y_scale, modifier_x_scale, modifier_y, modifier_x = parse_target(modifier_target)
	if modifier_height ~= modifier_y_scale or modifier_width ~= modifier_x_scale then return false end

	local target = modifier_shape[modifier_y][modifier_x]
	if not target then return false end

	-- merge it into the base shape
	local move_x, move_y = target_x - modifier_x, target_y - modifier_y
	for y, modifier_shape_row in pairs(modifier_shape) do
		for x, atom in pairs(modifier_shape_row) do
			local dest_x, dest_y = x + move_x, y + move_y
			local shape_row = shape[dest_y]
			if not shape_row then
				shape_row = {}
				shape[dest_y] = shape_row
			end
			if shape_row[dest_x] then return false end
			shape_row[dest_x] = atom
		end
	end
	return true
end

local function place_atom_and_assign_bonds(center_atom, shape, center_x, center_y)
	center_atom.x, center_atom.y = center_x, center_y
	shape[center_y][center_x] = center_atom
	local center_up_atom = shape[center_y - 1] and shape[center_y - 1][center_x]
	local center_left_atom = shape[center_y][center_x - 1]
	local center_right_atom = shape[center_y][center_x + 1]
	local center_down_atom = shape[center_y + 1] and shape[center_y + 1][center_x]
	if center_up_atom then center_atom.up = center_up_atom.down end
	if center_left_atom then center_atom.left = center_left_atom.right end
	if center_right_atom then center_atom.right = center_right_atom.left end
	if center_down_atom then center_atom.down = center_down_atom.up end
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
	if min_x == 1 and min_y == 1 then return shape, height, width end
	local new_shape = {}
	for y = 1, height do
		local new_shape_row = {}
		local shape_row = shape[min_y + y - 1]
		for x = 1, width do
			local atom = shape_row[min_x + x - 1]
			if atom then atom.x, atom.y = x, y end
			new_shape_row[x] = atom
		end
		new_shape[y] = new_shape_row
	end
	return new_shape, height, width
end

local function verify_bond_count(atom)
	return (atom.left or 0) + (atom.up or 0) + (atom.right or 0) + (atom.down or 0) <= ALL_ATOMS[atom.symbol].bonds
end

local function maybe_set_byproduct(products, product_name, byproduct)
	if byproduct and byproduct ~= PERFORM_FUSION_SELECTOR_SUBGROUP then products[product_name] = byproduct end
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
		selectors = {
			[BASE_NAME] = TARGET_SELECTOR_NAME,
			[CATALYST_NAME] = DROPDOWN_SELECTOR_NAME,
			[MODIFIER_NAME] = ATOM_SELECTOR_NAME,
		},
		dropdowns = {[CATALYST_NAME] = COMPARISON_SELECTOR_VALUES},
		reaction = function(reaction)
			local molecule = reaction.reactants[BASE_NAME]
			local target = reaction.selectors[BASE_NAME]
			local target_atom = reaction.selectors[MODIFIER_NAME]
			if not molecule or not target or not target_atom then return false end

			local y_scale, x_scale, y, x = parse_target(target)
			local shape, height, width = parse_molecule(molecule)
			local matches_comparison = false
			if height == y_scale and width == x_scale then
				local atom = shape[y][x]
				if atom then
					local comparator = ALL_ATOMS[atom.symbol].number
					local comparand = ALL_ATOMS[string.sub(target_atom, #ATOM_ITEM_PREFIX + 1)].number
					local comparison = COMPARISON_SELECTOR_VALUES[reaction.selectors[CATALYST_NAME]]
					if comparison == "=" then
						matches_comparison = comparator == comparand
					elseif comparison == "<" then
						matches_comparison = comparator < comparand
					elseif comparison == ">" then
						matches_comparison = comparator > comparand
					elseif comparison == "≤" then
						matches_comparison = comparator <= comparand
					elseif comparison == "≥" then
						matches_comparison = comparator >= comparand
					elseif comparison == "≠" then
						matches_comparison = comparator ~= comparand
					end
				end
			end

			if matches_comparison then
				reaction.products[RESULT_NAME] = molecule
			else
				reaction.products[REMAINDER_NAME] = molecule
			end
			return true
		end,
		examples = {{
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O1-H|1H"},
			selectors = {
				[BASE_NAME] = TARGET_SELECTOR_SUBGROUP.."-2200",
				[CATALYST_NAME] = 1,
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."O",
			},
		}, {
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O1-H|1H"},
			selectors = {
				[BASE_NAME] = TARGET_SELECTOR_SUBGROUP.."-2200",
				[CATALYST_NAME] = 4,
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."N",
			},
		}, {
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O1-H|1H"},
			selectors = {
				[BASE_NAME] = TARGET_SELECTOR_SUBGROUP.."-2211",
				[CATALYST_NAME] = 1,
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."O",
			},
		}, {
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O1-H|1H"},
			selectors = {
				[BASE_NAME] = TARGET_SELECTOR_SUBGROUP.."-2300",
				[CATALYST_NAME] = 1,
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."O",
			},
		}},
	},
	["molecule-rotator"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-1"},
		item_order = "c",
		-- data and control fields
		reactants = {BASE_NAME},
		products = {RESULT_NAME},
		-- control fields
		selectors = {[BASE_NAME] = ATOM_BOND_INNER_SELECTOR_NAME, [CATALYST_NAME] = ROTATION_SELECTOR_NAME},
		reaction = function(reaction)
			local molecule = reaction.reactants[BASE_NAME]
			local rotation = reaction.selectors[CATALYST_NAME]
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

				local center_atom = shape[center_y][center_x]
				if not center_atom then return false end
				shape[center_y][center_x] = nil

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
				place_atom_and_assign_bonds({symbol = center_atom.symbol}, shape, center_x, center_y)

				-- normalize the positions of all the atoms, if needed
				shape, height, width = normalize_shape(shape)
				if not shape then return false end
			end

			-- and now, finally, we can reassemble the molecule and produce it
			reaction.products[RESULT_NAME] = assemble_molecule(shape, height, width)
			return true
		end,
		examples = {{
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O1-H|1H"},
			selectors = {[CATALYST_NAME] = ROTATION_SELECTOR_SUBGROUP.."-3"},
		}, {
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."H|1N1-H|1O1-H"},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-3220E",
				[CATALYST_NAME] = ROTATION_SELECTOR_SUBGROUP.."-2",
			},
		}},
	},
	["molecule-debonder"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-2"},
		item_order = "d",
		unlocking_technology = "molecule-reaction-buildings-2",
		-- data and control fields
		reactants = {BASE_NAME, CATALYST_NAME},
		products = {RESULT_NAME, BYPRODUCT_NAME, REMAINDER_NAME},
		-- control fields
		selectors = {[BASE_NAME] = ATOM_BOND_INNER_SELECTOR_NAME, [CATALYST_NAME] = MUTATION_SELECTOR_NAME},
		reaction = function(reaction)
			local source, shape, height, width, center_y, center_x, direction = verify_base_atom_bond(reaction)
			if not source then return false end

			local bonds = get_bonds(source, direction)
			if not bonds then return false end

			-- at this point, the reaction is valid to start looking at, but might end up not being valid depending
			--	on bonds or atomic numbers
			local target_x, target_y = get_target(center_x, center_y, direction)
			local target = shape[target_y][target_x]
			if not target then return false end
			set_bonds(source, target, direction, bonds - 1)

			-- if we removed the last bond, check to see if it disconnected the molecule
			local remainder_shape, remainder_width, remainder_height
			if bonds == 1 then
				local extracted_atoms = extract_connected_atoms(shape, target_x, target_y)
				if has_any_atoms(shape) then
					-- generate a new molecule with the extracted atoms, then normalize both shapes
					remainder_shape = gen_grid(height)
					for _, atom in ipairs(extracted_atoms) do remainder_shape[atom.y][atom.x] = atom end
					shape, height, width = normalize_shape(shape)
					remainder_shape, remainder_height, remainder_width = normalize_shape(remainder_shape)
				else
					-- no split, restore all the atoms to the original shape
					for _, atom in ipairs(extracted_atoms) do shape[atom.y][atom.x] = atom end
				end
			end

			-- modify source with fission or fusion if specified
			local mutation = reaction.selectors[CATALYST_NAME]
			local catalyst = reaction.reactants[CATALYST_NAME]
			if not maybe_perform_mutation(source, mutation, catalyst) or not verify_bond_count(source) then
				return false
			end

			-- we've finally done everything, reassemble the molecule(s) and deliver any fission results
			reaction.products[RESULT_NAME] = assemble_molecule(shape, height, width)
			if remainder_shape then
				reaction.products[REMAINDER_NAME] =
					assemble_molecule(remainder_shape, remainder_height, remainder_width)
			end
			maybe_set_byproduct(reaction.products, BYPRODUCT_NAME, mutation)
			return true
		end,
		examples = {{
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O1-H|1H"},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-2200E",
				[CATALYST_NAME] = ATOM_ITEM_PREFIX.."B",
			},
		}, {
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."Li|1H"},
			selectors = {[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-2100S"},
		}, {
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O1-H|1H", [CATALYST_NAME] = ATOM_ITEM_PREFIX.."H"},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-2200S",
				[CATALYST_NAME] = PERFORM_FUSION_SELECTOR_SUBGROUP,
			},
		}},
	},
	["molecule-bonder"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-2"},
		item_order = "e",
		unlocking_technology = "molecule-reaction-buildings-2",
		-- data and control fields
		reactants = {BASE_NAME, CATALYST_NAME, MODIFIER_NAME},
		products = {RESULT_NAME, BYPRODUCT_NAME},
		-- control fields
		selectors = {
			[BASE_NAME] = ATOM_BOND_SELECTOR_NAME,
			[CATALYST_NAME] = MUTATION_SELECTOR_NAME,
			[MODIFIER_NAME] = TARGET_SELECTOR_NAME,
		},
		reaction = function(reaction)
			local source, shape, height, width, center_y, center_x, direction = verify_base_atom_bond(reaction)
			if not source then return false end

			-- modify source with fission or fusion if specified
			local mutation = reaction.selectors[CATALYST_NAME]
			local catalyst = reaction.reactants[CATALYST_NAME]
			if not maybe_perform_mutation(source, mutation, catalyst) then return false end

			local target_x, target_y = get_target(center_x, center_y, direction)
			local target
			if target_y >= 1 and target_y <= height then target = shape[target_y][target_x] end

			-- if there is a modifier molecule, join it with the base molecule
			local modifier = reaction.reactants[MODIFIER_NAME]
			local modifier_target = reaction.selectors[MODIFIER_NAME]
			if modifier then
				-- make sure there is not already a target atom at the position and that there is a target atom
				--	specified on the modifier molecule
				if target or not modifier_target then return false end

				-- merge it into the base molecule
				if not merge_with_modifier(shape, target_x, target_y, modifier, modifier_target) then
					return false
				end
				target = shape[target_y][target_x]

				-- normalize the shape, and make sure that it fits within the grid
				shape, height, width = normalize_shape(shape)
				if not shape then return false end
			-- if there is no modifier molecule, we just have to add a bond to the molecule
			else
				-- make sure there is a target atom at the position and that there is no modifier molecule
				--	target specified
				if not target or modifier_target then return false end
			end

			-- add bonds between the source and the target
			local bonds = get_bonds(source, direction) or 0
			set_bonds(source, target, direction, bonds + 1)
			if not verify_bond_count(source) or not verify_bond_count(target) then return false end

			-- we've finally done everything, reassemble the molecule
			reaction.products[RESULT_NAME] = assemble_molecule(shape, height, width)
			maybe_set_byproduct(reaction.products, BYPRODUCT_NAME, mutation)
			return true
		end,
		examples = {{
			reactants = {
				[BASE_NAME] = MOLECULE_ITEM_PREFIX.."Li|1H",
				[CATALYST_NAME] = ATOM_ITEM_PREFIX.."B",
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."H",
			},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-2100E",
				[CATALYST_NAME] = PERFORM_FUSION_SELECTOR_SUBGROUP,
				[MODIFIER_NAME] = TARGET_SELECTOR_SUBGROUP.."-1100",
			},
		}, {
			reactants = {[BASE_NAME] = ATOM_ITEM_PREFIX.."Li", [MODIFIER_NAME] = ATOM_ITEM_PREFIX.."H"},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-1100S",
				[MODIFIER_NAME] = TARGET_SELECTOR_SUBGROUP.."-1100",
			},
		}, {
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."F1-H", [MODIFIER_NAME] = ATOM_ITEM_PREFIX.."H"},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-1200S",
				[CATALYST_NAME] = ATOM_ITEM_PREFIX.."H",
				[MODIFIER_NAME] = TARGET_SELECTOR_SUBGROUP.."-1100",
			},
		}},
	},
	["molecule-fissioner"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-2"},
		item_order = "f",
		unlocking_technology = "molecule-reaction-buildings-2",
		-- data and control fields
		reactants = {BASE_NAME},
		products = {RESULT_NAME, REMAINDER_NAME},
		-- control fields
		selectors = {[BASE_NAME] = ATOM_SELECTOR_NAME},
		reaction = function(reaction)
			local molecule = reaction.reactants[BASE_NAME]
			if not molecule then return false end

			local shape, height, width = parse_molecule(molecule)
			if height ~= 1 or width ~= 1 then return false end

			local remainder_atom = shape[1][1]
			local valid_fission, result_atom = perform_fission(remainder_atom, reaction.selectors[BASE_NAME])
			if not valid_fission then return false end

			reaction.products[RESULT_NAME] = ATOM_ITEM_PREFIX..result_atom.symbol
			reaction.products[REMAINDER_NAME] = ATOM_ITEM_PREFIX..remainder_atom.symbol
			return true
		end,
		examples = {{
			reactants = {[BASE_NAME] = ATOM_ITEM_PREFIX.."Ne"},
			selectors = {[BASE_NAME] = ATOM_ITEM_PREFIX.."H"},
		}, {
			reactants = {[BASE_NAME] = ATOM_ITEM_PREFIX.."He"},
			selectors = {},
		}, {
			reactants = {[BASE_NAME] = ATOM_ITEM_PREFIX.."F"},
			selectors = {},
		}},
	},
	["molecule-fusioner"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-2"},
		item_order = "g",
		unlocking_technology = "molecule-reaction-buildings-2",
		-- data and control fields
		reactants = {BASE_NAME, MODIFIER_NAME},
		products = {RESULT_NAME},
		-- control fields
		selectors = {},
		reaction = function(reaction)
			local first = reaction.reactants[BASE_NAME]
			local second = reaction.reactants[MODIFIER_NAME]
			if not first or not second then return false end

			local first_shape, first_height, first_width = parse_molecule(first)
			if first_height ~= 1 or first_width ~= 1 then return false end

			local atom = first_shape[1][1]
			if not perform_fusion(atom, second) then return false end

			reaction.products[RESULT_NAME] = ATOM_ITEM_PREFIX..atom.symbol
			return true
		end,
		examples = {{
			reactants = {[BASE_NAME] = ATOM_ITEM_PREFIX.."Li", [MODIFIER_NAME] = ATOM_ITEM_PREFIX.."H"},
			selectors = {},
		}, {
			reactants = {[BASE_NAME] = ATOM_ITEM_PREFIX.."Be", [MODIFIER_NAME] = ATOM_ITEM_PREFIX.."C"},
			selectors = {},
		}},
	},
	["molecule-severer"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-2"},
		item_order = "h",
		unlocking_technology = "molecule-reaction-buildings-3",
		-- data and control fields
		reactants = {BASE_NAME},
		products = {RESULT_NAME, BYPRODUCT_NAME, REMAINDER_NAME},
		-- control fields
		selectors = {
			[BASE_NAME] = ATOM_BOND_INNER_SELECTOR_NAME,
			[CATALYST_NAME] = ATOM_SELECTOR_NAME,
			[MODIFIER_NAME] = ATOM_SELECTOR_NAME,
		},
		reaction = function(reaction)
			-- check that the base reaction is valid
			local source, shape, height, _, center_y, center_x, direction = verify_base_atom_bond(reaction)
			if not source then return false end

			local remainder_atom = reaction.selectors[MODIFIER_NAME]
			if not remainder_atom then return false end

			-- remove the atom and all atoms connected to it
			shape[center_y][center_x] = nil
			local target_x, target_y = get_target(center_x, center_y, direction)
			local remainder_atoms = extract_connected_atoms(shape, target_x, target_y)
			if not remainder_atoms then return false end

			-- restore the source atom and perform fission on it
			source = {symbol = source.symbol}
			place_atom_and_assign_bonds(source, shape, center_x, center_y)
			local valid_fission, source_fission_remainder = perform_fission(source, remainder_atom)
			local byproduct = reaction.selectors[CATALYST_NAME]
			if byproduct then valid_fission = valid_fission and perform_fission(source, byproduct) end
			if not valid_fission or not verify_bond_count(source) then return false end

			-- assemble the remainder molecule
			local remainder_shape = gen_grid(height)
			for _, atom in ipairs(remainder_atoms) do remainder_shape[atom.y][atom.x] = atom end
			place_atom_and_assign_bonds(source_fission_remainder, remainder_shape, center_x, center_y)
			if not verify_bond_count(source_fission_remainder) then return false end

			-- and finally, normalize molecules and write everything to the output
			reaction.products[RESULT_NAME] = assemble_molecule(normalize_shape(shape))
			reaction.products[REMAINDER_NAME] = assemble_molecule(normalize_shape(remainder_shape))
			if byproduct then reaction.products[BYPRODUCT_NAME] = byproduct end
			return true
		end,
		examples = {{
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O1-H|1H"},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-2200E",
				[CATALYST_NAME] = ATOM_ITEM_PREFIX.."He",
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."Li",
			},
		}, {
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."H|1Be|1H"},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-3110S",
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."H",
			},
		}},
	},
	["molecule-splicer"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-2"},
		item_order = "i",
		unlocking_technology = "molecule-reaction-buildings-3",
		-- data and control fields
		reactants = {BASE_NAME, CATALYST_NAME, MODIFIER_NAME},
		products = {RESULT_NAME},
		-- control fields
		selectors = {
			[BASE_NAME] = TARGET_SELECTOR_NAME,
			[CATALYST_NAME] = CHECKBOX_SELECTOR_NAME,
			[MODIFIER_NAME] = TARGET_SELECTOR_NAME,
		},
		reaction = function(reaction)
			-- check that the base reaction is valid
			local molecule = reaction.reactants[BASE_NAME]
			local molecule_target = reaction.selectors[BASE_NAME]
			if not molecule or not molecule_target then return false end

			local shape, height, width = parse_molecule(molecule)
			local y_scale, x_scale, center_y, center_x = parse_target(molecule_target)
			if y_scale ~= height or x_scale ~= width then return false end

			local source = shape[center_y][center_x]
			if not source then return false end

			-- remove the target atom and move in the modifier
			shape[center_y][center_x] = nil
			local modifier = reaction.reactants[MODIFIER_NAME]
			local modifier_target = reaction.selectors[MODIFIER_NAME]
			if not modifier or not modifier_target then return false end
			if not merge_with_modifier(shape, center_x, center_y, modifier, modifier_target) then return false end

			-- place an atom with the combined atomic number
			local splice_atom = {symbol = source.symbol}
			if not perform_fusion(splice_atom, nil, shape[center_y][center_x]) then return false end
			place_atom_and_assign_bonds(splice_atom, shape, center_x, center_y)

			-- add the catalyst if it is present and specified by the selector
			local catalyst = reaction.reactants[CATALYST_NAME]
			local use_catalyst = reaction.selectors[CATALYST_NAME]
			if (catalyst ~= nil) ~= use_catalyst then return false end
			if catalyst and not perform_fusion(splice_atom, catalyst) then return false end

			-- make sure everything is valid
			if not verify_bond_count(splice_atom) then return false end
			shape, height, width = normalize_shape(shape)
			if not shape then return false end

			-- we've finally done everything, reassemble the molecule
			reaction.products[RESULT_NAME] = assemble_molecule(shape, height, width)
			return true
		end,
		examples = {{
			reactants = {
				[BASE_NAME] = MOLECULE_ITEM_PREFIX.."Li|1H",
				[CATALYST_NAME] = ATOM_ITEM_PREFIX.."He",
				[MODIFIER_NAME] = MOLECULE_ITEM_PREFIX.."Li1-H",
			},
			selectors = {
				[BASE_NAME] = TARGET_SELECTOR_SUBGROUP.."-2100",
				[CATALYST_NAME] = true,
				[MODIFIER_NAME] = TARGET_SELECTOR_SUBGROUP.."-1200",
			},
		}, {
			reactants = {
				[BASE_NAME] = MOLECULE_ITEM_PREFIX.."Li|1H",
				[MODIFIER_NAME] = MOLECULE_ITEM_PREFIX.."H|1H",
			},
			selectors = {
				[BASE_NAME] = TARGET_SELECTOR_SUBGROUP.."-2100",
				[CATALYST_NAME] = false,
				[MODIFIER_NAME] = TARGET_SELECTOR_SUBGROUP.."-2110",
			},
		}},
	},
	["molecule-debonder-2"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-3"},
		item_order = "j",
		unlocking_technology = "molecule-reaction-buildings-4a",
		-- data and control fields
		reactants = {BASE_NAME, CATALYST_NAME, MODIFIER_NAME},
		products = {RESULT_NAME, BYPRODUCT_NAME, REMAINDER_NAME},
		-- control fields
		selectors = {
			[BASE_NAME] = ATOM_BOND_INNER_SELECTOR_NAME,
			[CATALYST_NAME] = MUTATION_SELECTOR_NAME,
			[MODIFIER_NAME] = MUTATION_SELECTOR_NAME,
		},
		reaction = function(reaction)
			local source, shape, height, width, center_y, center_x, direction = verify_base_atom_bond(reaction)
			if not source then return false end

			local bonds = get_bonds(source, direction)
			if not bonds then return false end

			-- remove a bond and make sure that the molecule is still connected
			local target_x, target_y = get_target(center_x, center_y, direction)
			local target = shape[target_y][target_x]
			set_bonds(source, target, direction, bonds - 1)
			local all_atoms = extract_connected_atoms(shape, target_x, target_y)
			if has_any_atoms(shape) then return false end
			for _, atom in ipairs(all_atoms) do shape[atom.y][atom.x] = atom end

			-- fission/fusion both the source and the target
			local source_mutation = reaction.selectors[CATALYST_NAME]
			local target_mutation = reaction.selectors[MODIFIER_NAME]
			if not source_mutation or not target_mutation then return false end

			local source_catalyst = reaction.reactants[CATALYST_NAME]
			local target_catalyst = reaction.reactants[MODIFIER_NAME]
			if not maybe_perform_mutation(source, source_mutation, source_catalyst) then return false end
			if not maybe_perform_mutation(target, target_mutation, target_catalyst) then return false end
			if not verify_bond_count(source) or not verify_bond_count(target) then return false end

			-- everything is valid, write the output
			reaction.products[RESULT_NAME] = assemble_molecule(shape, height, width)
			maybe_set_byproduct(reaction.products, BYPRODUCT_NAME, source_mutation)
			maybe_set_byproduct(reaction.products, REMAINDER_NAME, target_mutation)
			return true
		end,
		examples = {{
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."N3-B"},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-1200E",
				[CATALYST_NAME] = ATOM_ITEM_PREFIX.."Li",
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."H",
			},
		}, {
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."N3-B", [CATALYST_NAME] = ATOM_ITEM_PREFIX.."H"},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-1200E",
				[CATALYST_NAME] = PERFORM_FUSION_SELECTOR_SUBGROUP,
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."H",
			},
		}, {
			reactants = {
				[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O1-O|1O1-1O",
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."H",
			},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-2211N",
				[CATALYST_NAME] = ATOM_ITEM_PREFIX.."B",
				[MODIFIER_NAME] = PERFORM_FUSION_SELECTOR_SUBGROUP,
			},
		}, {
			reactants = {
				[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O1-O|1O1-1O",
				[CATALYST_NAME] = ATOM_ITEM_PREFIX.."H",
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."H",
			},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-2211N",
				[CATALYST_NAME] = PERFORM_FUSION_SELECTOR_SUBGROUP,
				[MODIFIER_NAME] = PERFORM_FUSION_SELECTOR_SUBGROUP,
			},
		}},
	},
	["molecule-bonder-2"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-3"},
		item_order = "k",
		unlocking_technology = "molecule-reaction-buildings-4a",
		-- data and control fields
		reactants = {BASE_NAME, CATALYST_NAME, MODIFIER_NAME},
		products = {RESULT_NAME, BYPRODUCT_NAME, REMAINDER_NAME},
		-- control fields
		selectors = {
			[BASE_NAME] = ATOM_BOND_INNER_SELECTOR_NAME,
			[CATALYST_NAME] = MUTATION_SELECTOR_NAME,
			[MODIFIER_NAME] = MUTATION_SELECTOR_NAME,
		},
		reaction = function(reaction)
			local source, shape, height, width, center_y, center_x, direction = verify_base_atom_bond(reaction)
			if not source then return false end

			local target_x, target_y = get_target(center_x, center_y, direction)
			local target = shape[target_y][target_x]
			if not target then return false end

			-- set the bonds
			local bonds = get_bonds(source, direction) or 0
			set_bonds(source, target, direction, bonds + 1)

			-- fission/fusion both the source and the target
			local source_mutation = reaction.selectors[CATALYST_NAME]
			local target_mutation = reaction.selectors[MODIFIER_NAME]
			if not source_mutation or not target_mutation then return false end

			local source_catalyst = reaction.reactants[CATALYST_NAME]
			local target_catalyst = reaction.reactants[MODIFIER_NAME]
			if not maybe_perform_mutation(source, source_mutation, source_catalyst) then return false end
			if not maybe_perform_mutation(target, target_mutation, target_catalyst) then return false end
			if not verify_bond_count(source) or not verify_bond_count(target) then return false end

			-- everything is valid, write the output
			reaction.products[RESULT_NAME] = assemble_molecule(shape, height, width)
			maybe_set_byproduct(reaction.products, BYPRODUCT_NAME, source_mutation)
			maybe_set_byproduct(reaction.products, REMAINDER_NAME, target_mutation)
			return true
		end,
		examples = {{
			reactants = {
				[BASE_NAME] = MOLECULE_ITEM_PREFIX.."Be2-Be",
				[CATALYST_NAME] = ATOM_ITEM_PREFIX.."Li",
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."H",
			},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-1200E",
				[CATALYST_NAME] = PERFORM_FUSION_SELECTOR_SUBGROUP,
				[MODIFIER_NAME] = PERFORM_FUSION_SELECTOR_SUBGROUP,
			},
		}, {
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O2-Be", [MODIFIER_NAME] = ATOM_ITEM_PREFIX.."H"},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-1200E",
				[CATALYST_NAME] = ATOM_ITEM_PREFIX.."H",
				[MODIFIER_NAME] = PERFORM_FUSION_SELECTOR_SUBGROUP,
			},
		}, {
			reactants = {
				[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O1-F|1O1-Li",
				[CATALYST_NAME] = ATOM_ITEM_PREFIX.."B",
			},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-2211N",
				[CATALYST_NAME] = PERFORM_FUSION_SELECTOR_SUBGROUP,
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."H",
			},
		}, {
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O1-F|1O1-F"},
			selectors = {
				[BASE_NAME] = ATOM_BOND_SELECTOR_SUBGROUP.."-2211N",
				[CATALYST_NAME] = ATOM_ITEM_PREFIX.."H",
				[MODIFIER_NAME] = ATOM_ITEM_PREFIX.."H",
			},
		}},
	},
	["molecule-fissioner-2"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-3"},
		item_order = "l",
		unlocking_technology = "molecule-reaction-buildings-4b",
		-- data and control fields
		reactants = {BASE_NAME},
		products = {RESULT_NAME, BYPRODUCT_NAME, REMAINDER_NAME},
		-- control fields
		selectors = {
			[BASE_NAME] = ATOM_BOND_INNER_SELECTOR_NAME,
			[CATALYST_NAME] = ATOM_SELECTOR_NAME,
			[MODIFIER_NAME] = ATOM_SELECTOR_NAME,
		},
		reaction = function(reaction)
			local source, shape, height, width, center_y, center_x, direction = verify_base_atom_bond(reaction)
			if not source then return false end

			local source_byproduct = reaction.selectors[CATALYST_NAME]
			if not source_byproduct then return false end
			if not perform_fission(source, source_byproduct) or not verify_bond_count(source) then return false end

			local target_byproduct = reaction.selectors[MODIFIER_NAME]
			if target_byproduct then
				local target_x, target_y = get_target(center_x, center_y, direction)
				local target = shape[target_y][target_x]
				if not target then return false end
				if not perform_fission(target, target_byproduct) or not verify_bond_count(target) then
					return false
				end
			end

			-- everything is valid, write the output
			reaction.products[RESULT_NAME] = assemble_molecule(shape, height, width)
			reaction.products[BYPRODUCT_NAME] = source_byproduct
			reaction.products[REMAINDER_NAME] = target_byproduct
			return true
		end,
	},
	["molecule-fusioner-2"] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-3"},
		item_order = "m",
		unlocking_technology = "molecule-reaction-buildings-4b",
		-- data and control fields
		reactants = {BASE_NAME, CATALYST_NAME, MODIFIER_NAME},
		products = {RESULT_NAME},
		-- control fields
		selectors = {[BASE_NAME] = ATOM_BOND_INNER_SELECTOR_NAME, [MODIFIER_NAME] = CHECKBOX_SELECTOR_NAME},
		reaction = function(reaction)
			local source, shape, height, width, center_y, center_x, direction = verify_base_atom_bond(reaction)
			if not source then return false end

			local source_catalyst = reaction.reactants[CATALYST_NAME]
			if not source_catalyst then return false end
			if not perform_fusion(source, source_catalyst) or not verify_bond_count(source) then return false end

			local target_catalyst = reaction.reactants[MODIFIER_NAME]
			if target_catalyst then
				-- make sure it was specified
				if not reaction.selectors[MODIFIER_NAME] then return false end

				local target_x, target_y = get_target(center_x, center_y, direction)
				local target = shape[target_y][target_x]
				if not target then return false end
				if not perform_fusion(target, target_catalyst) or not verify_bond_count(target) then
					return false
				end
			else
				-- make sure it wasn't specified
				if reaction.selectors[MODIFIER_NAME] then return false end
			end

			-- everything is valid, write the output
			reaction.products[RESULT_NAME] = assemble_molecule(shape, height, width)
			return true
		end,
	},
	[MOLECULE_VOIDER_NAME] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-3"},
		item_order = "n",
		-- data and control fields
		reactants = {BASE_NAME},
		products = {},
		-- control fields
		selectors = {},
		reaction = function(reaction)
			return reaction.reactants[BASE_NAME] ~= nil
		end,
		examples = {{
			reactants = {[BASE_NAME] = MOLECULE_ITEM_PREFIX.."O1-H|1H"},
			selectors = {},
		}, {
			reactants = {[BASE_NAME] = ATOM_ITEM_PREFIX.."O"},
			selectors = {},
		}, {
			reactants = {[BASE_NAME] = MOLECULE_REACTION_REACTANTS_NAME},
			selectors = {},
		}, {
			reactants = {[BASE_NAME] = MOLECULE_ABSORBER_NAME},
			selectors = {},
		}},
	},
	[MOLECULE_PRINTER_NAME] = {
		-- data fields
		building_design = {"assembling-machine", "assembling-machine-3"},
		item_order = "o",
		unlocking_technology = "molecule-printer",
		-- data and control fields
		reactants = {},
		products = {RESULT_NAME},
		-- control fields
		selectors = {[BASE_NAME] = TEXT_SELECTOR_NAME},
		reaction = function(reaction)
			-- check that we can even parse the molecule ID
			local molecule_id = reaction.selectors[BASE_NAME]
			local shape, height, width
			if not pcall(function() shape, height, width = parse_molecule_id(molecule_id) end) then return false end

			-- make sure that the size and positioning is valid
			if height == 0 or height > MAX_GRID_HEIGHT or width == 0 or width > MAX_GRID_WIDTH then return false end
			local top_x
			for x = 1, width do
				if shape[1][x] then
					top_x = x
					break
				end
			end
			if not top_x then return false end
			local has_left = false
			for y = 1, height do
				if shape[y][1] then
					has_left = true
					break
				end
			end
			if not has_left then return false end

			-- make sure all atoms are connected
			local all_atoms = extract_connected_atoms(shape, top_x, 1)
			if has_any_atoms(shape) then return false end

			-- make sure all bond counts are valid
			for _, atom in ipairs(all_atoms) do
				if not ALL_ATOMS[atom.symbol] or not verify_bond_count(atom) then return false end
			end

			-- we finished validating the molecule ID, reassemble it and write it to the output
			-- while this will probably be identical to the input, molecule parsing is lenient and may approve of an
			--	ID that doesn't directly convert to a molecule
			for _, atom in ipairs(all_atoms) do shape[atom.y][atom.x] = atom end
			reaction.products[RESULT_NAME] = assemble_molecule(shape, height, width)
			return true
		end,
		examples = {{
			reactants = {},
			selectors = {[BASE_NAME] = "Ne                 "},
		}, {
			reactants = {},
			selectors = {[BASE_NAME] = "O1-H|1H     "},
		}, {
			reactants = {},
			selectors = {[BASE_NAME] = "--H|H1-N1-1O|H1-1N1-H"},
		}},
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
