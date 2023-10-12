-- Array-like operators using a length value
local function empty_array()
	return {n = 0}
end

local function array_with_contents(contents)
	contents.n = #contents
	return contents
end

local function array_push(array, v)
	local n = array.n + 1
	array.n = n
	array[n] = v
end

local function array_pop(array)
	local n = array.n
	local v = array[n]
	array[n] = nil
	array.n = n - 1
	return v
end

local function array_clear(array)
	for i = 1, array.n do array[i] = nil end
	array.n = 0
end


-- Constants
local GRID_AREA = MAX_GRID_WIDTH * MAX_GRID_HEIGHT
local MAX_TOTAL_BONDS = 0
local MOLECULE_ATOMS_ACCEPT_BONDS = {}
local HCNO = {H = true, C = true, N = true, O = true}
local MAX_ATOMS = 8
local MAX_ATOMS_HCNO = MAX_ATOMS
local MAX_ATOMS_Ne = 4
local MAX_ATOMS_Ar = 3
local MAX_ATOMS_OTHER = 2
local GRID = empty_array()
local MAX_GRID_WIDTH_M1 = MAX_GRID_WIDTH - 1
local MAX_GRID_HEIGHT_M1 = MAX_GRID_HEIGHT - 1
local MAX_SINGLE_BONDS = 3
local MAX_SINGLE_BONDS_HCNO = 2
local MAX_SINGLE_BONDS_Ne = MAX_SINGLE_BONDS
local MOLECULE_BUILDER = empty_array()
local MOLECULE_DISPLAY_COUNTER = {}
local MOLECULE_DISPLAY_BUILDER = empty_array()
local ATOM_ICON_ROOT = GRAPHICS_ROOT.."atoms/"
local BOND_ICON_ROOT = GRAPHICS_ROOT.."bonds/"
local SHAPE_ICON_ROOT = GRAPHICS_ROOT.."shapes/"
local MOLECULE_DESCRIPTION_CACHE = {}
local ITEM_GROUP_ICON_SIZE = 128
local ITEM_GROUP_ICON_MIPMAPS = 2
local COMPLEX_MOLECULE_PARTS_NAME = "complex-molecule-parts"
local EQUIPMENT_GRID_SIZE = 32


-- Item groups and subgroups
data:extend({
	{
		type = "item-group",
		name = MOLECULES_GROUP_NAME,
		icon = GRAPHICS_ROOT.."item-group.png",
		icon_size = ITEM_GROUP_ICON_SIZE,
		icon_mipmaps = ITEM_GROUP_ICON_MIPMAPS,
		order = "e-a",
	},
	{
		type = "item-subgroup",
		name = COMPLEX_MOLECULES_SUBGROUP_NAME,
		group = MOLECULES_GROUP_NAME,
		order = "b",
	},
	{
		type = "item-subgroup",
		name = MOLECULES_SUBGROUP_NAME,
		group = MOLECULES_GROUP_NAME,
		order = "c",
	},
	-- d and e are moleculify/demoleculify
	{
		type = "item-subgroup",
		name = MOLECULE_ITEMS_SUBGROUP_NAME,
		group = MOLECULES_GROUP_NAME,
		order = "f",
	},
})
for row_n, _ in ipairs(ATOM_ROWS) do
	data:extend({{
		type = "item-subgroup",
		name = ATOMS_SUBGROUP_PREFIX..row_n,
		group = MOLECULES_GROUP_NAME,
		order = "a"
	}})
end


-- Atom stats
local function add_atom_accepts_bonds_for_molecule(atom, bonds, atom_count)
	local atoms_accept_bonds = MOLECULE_ATOMS_ACCEPT_BONDS[atom_count]
	if not atoms_accept_bonds then
		atoms_accept_bonds = {}
		MOLECULE_ATOMS_ACCEPT_BONDS[atom_count] = atoms_accept_bonds
	end
	local atoms = atoms_accept_bonds[bonds]
	if not atoms then
		atoms = empty_array()
		atoms_accept_bonds[bonds] = atoms
	end
	array_push(atoms, atom)
end

for row_n, atoms_row in ipairs(ATOM_ROWS) do
	for _, symbol in ipairs(atoms_row) do
		local molecule_max_atoms = MAX_ATOMS_Ne
		if row_n > 3 then
			molecule_max_atoms = MAX_ATOMS_OTHER
		elseif row_n == 3 then
			molecule_max_atoms = MAX_ATOMS_Ar
		elseif HCNO[symbol] then
			molecule_max_atoms = MAX_ATOMS_HCNO
		end
		local atom = ALL_ATOMS[symbol]
		for atom_count = 1, molecule_max_atoms do
			add_atom_accepts_bonds_for_molecule(atom, 0, atom_count)
			if atom.bonds > 0 then add_atom_accepts_bonds_for_molecule(atom, atom.bonds, atom_count) end
		end
		if atom.bonds > MAX_TOTAL_BONDS then MAX_TOTAL_BONDS = atom.bonds end
	end
end


-- Molecule generation
local current_atom_count = 0
local current_max_single_bonds = 0
local current_shape_icon = nil
local current_shape_height = 0
local current_shape_width = 0
local total_molecules = 0

local function assign_valid_atoms(grid_is)
	local atoms_accept_bonds = MOLECULE_ATOMS_ACCEPT_BONDS[current_atom_count]
	for _, grid_i in ipairs(grid_is) do
		local slot = GRID[grid_i]
		slot.valid_atoms = atoms_accept_bonds[slot.left_bonds + slot.up_bonds + slot.right_bonds + slot.down_bonds]
	end
end

local function gen_atom(atom)
	local name = ATOM_ITEM_PREFIX..atom.symbol
	local localised_name = {"item-name.atom-AA", atom.localised_name, atom.symbol}
	local localised_description = {"item-description.atom-AA", atom.number, atom.bonds}
	local icon_name = ATOM_ICON_ROOT..atom.symbol.."/1100.png"
	data:extend({
		{
			type = "item",
			name = name,
			subgroup = ATOMS_SUBGROUP_PREFIX..atom.row,
			order = string.format("%02X", atom.number),
			localised_name = localised_name,
			localised_description = localised_description,
			icon = icon_name,
			icon_size = ITEM_ICON_SIZE,
			icon_mipmaps = MOLECULE_ICON_MIPMAPS,
			stack_size = 1,
		},
		{
			type = "battery-equipment",
			name = name,
			categories = {COMPLEX_MOLECULE_PARTS_NAME},
			localised_name = localised_name,
			localised_description = localised_description,
			sprite = {
				filename = icon_name,
				size = ITEM_ICON_SIZE,
				mipmap_count = MOLECULE_ICON_MIPMAPS,
				flags = {"icon"},
			},
			shape = {width = 1, height = 1, type = "full"},
			energy_source = {type = "void", usage_priority = "tertiary"},
			-- never used, but we have to specify something valid
			take_result = MOLECULE_ABSORBER_NAME,
		},
	})
end

local function gen_molecules(grid_i_i, grid_is)
	if grid_i_i <= grid_is.n then
		local slot = GRID[grid_is[grid_i_i]]
		for _, atom in ipairs(slot.valid_atoms) do
			slot.atom = atom
			gen_molecules(grid_i_i + 1, grid_is)
		end
		return
	end

	array_clear(MOLECULE_BUILDER)
	local icons = {current_shape_icon}
	local last_row = 0
	local last_col = 0
	for grid_i = 1, GRID_AREA do
		local slot = GRID[grid_i]
		if slot then
			local grid_0_i = grid_i - 1
			local row = math.floor(grid_0_i / MAX_GRID_WIDTH)
			local col = grid_0_i % MAX_GRID_WIDTH
			if row > last_row then
				last_row = row
				array_push(MOLECULE_BUILDER, ATOM_ROW_SEPARATOR)
				last_col = 0
			end
			while last_col < col do
				array_push(MOLECULE_BUILDER, ATOM_COL_SEPARATOR)
				last_col = last_col + 1
			end
			local atom = slot.atom
			local symbol = atom.symbol
			local name_spec = current_shape_height..current_shape_width..row..col
			table.insert(
				icons,
				{
					icon = ATOM_ICON_ROOT..symbol.."/"..name_spec..".png",
					icon_size = ITEM_ICON_SIZE,
					icon_mipmaps = MOLECULE_ICON_MIPMAPS,
				})
			local up_bonds = slot.up_bonds
			if slot.up_bonds > 0 then
				array_push(MOLECULE_BUILDER, up_bonds)
				table.insert(
					icons,
					{
						icon = BOND_ICON_ROOT.."U"..name_spec..up_bonds..".png",
						icon_size = ITEM_ICON_SIZE,
						icon_mipmaps = MOLECULE_ICON_MIPMAPS,
					})
			end
			array_push(MOLECULE_BUILDER, symbol)
			if slot.right_bonds > 0 then array_push(MOLECULE_BUILDER, slot.right_bonds) end
			local left_bonds = slot.left_bonds
			if left_bonds > 0 then
				table.insert(
					icons,
					{
						icon = BOND_ICON_ROOT.."L"..name_spec..left_bonds..".png",
						icon_size = ITEM_ICON_SIZE,
						icon_mipmaps = MOLECULE_ICON_MIPMAPS,
					})
			end
			local number = atom.number
			MOLECULE_DISPLAY_COUNTER[number] = (MOLECULE_DISPLAY_COUNTER[number] or 0) + 1
		end
	end
	-- selection sort to assemble a chemical name in ascending atomic number order
	array_clear(MOLECULE_DISPLAY_BUILDER)
	local description_cache = MOLECULE_DESCRIPTION_CACHE
	while true do
		local atomic_number = 1000
		for check_atomic_number, _ in pairs(MOLECULE_DISPLAY_COUNTER) do
			if check_atomic_number < atomic_number then atomic_number = check_atomic_number end
		end
		if atomic_number == 1000 then break end
		local atom = ALL_ATOMS[atomic_number]
		array_push(MOLECULE_DISPLAY_BUILDER, atom.symbol)
		local count = MOLECULE_DISPLAY_COUNTER[atomic_number]
		if count > 1 then array_push(MOLECULE_DISPLAY_BUILDER, count) end
		MOLECULE_DISPLAY_COUNTER[atomic_number] = nil
		local next_description_cache = description_cache[atomic_number]
		if not next_description_cache then
			local description = description_cache[0]
			if description then
				next_description_cache = {
					[0] = {
						"item-description.molecule-AA2",
						description,
						atom.rich_text,
						atom.symbol,
						atom.number,
						atom.localised_name,
					},
				}
			else
				next_description_cache = {
					[0] = {
						"item-description.molecule-AA",
						atom.rich_text,
						atom.symbol,
						atom.number,
						atom.localised_name
					},
				}
			end
			description_cache[atomic_number] = next_description_cache
		end
		description_cache = next_description_cache
	end
	data:extend({{
		type = "item",
		name = MOLECULE_ITEM_PREFIX..table.concat(MOLECULE_BUILDER),
		subgroup = MOLECULES_SUBGROUP_NAME,
		localised_name = table.concat(MOLECULE_DISPLAY_BUILDER),
		localised_description = description_cache[0],
		icons = icons,
		stack_size = 1,
		flags = {"hidden"},
	}})
	total_molecules = total_molecules + 1
end

local function gen_molecule_bonds(grid_i_i, grid_is)
	if grid_i_i > grid_is.n then
		-- only generate a molecule if we reached all the atoms
		if grid_i_i > current_atom_count then
			assign_valid_atoms(grid_is)
			gen_molecules(1, grid_is)
		end
		return
	end
	local grid_i = grid_is[grid_i_i]
	local slot = GRID[grid_i]
	local new_bonds_max = MAX_TOTAL_BONDS - slot.left_bonds - slot.up_bonds - slot.right_bonds - slot.down_bonds

	-- no room for new bonds on this molecule, keep going
	if new_bonds_max == 0 then
		gen_molecule_bonds(grid_i_i + 1, grid_is)
		return
	end

	-- calculate the max bonds per direction
	local single_bonds_max = math.min(current_max_single_bonds, new_bonds_max)
	local bond_depth_p1 = slot.bond_depth + 1
	local grid_0_i = grid_i - 1
	local left_bonds_max = 0
	local left_grid_i
	local left_slot
	local expand_left
	if grid_0_i % MAX_GRID_WIDTH >= 1 then
		left_grid_i = grid_i - 1
		left_slot = GRID[left_grid_i]
		if left_slot then
			expand_left = left_slot.bond_depth == 0
			if expand_left then
				left_bonds_max = single_bonds_max
			elseif left_slot.bond_depth == bond_depth_p1 then
				left_bonds_max = math.min(
					single_bonds_max,
					MAX_TOTAL_BONDS - left_slot.left_bonds - left_slot.up_bonds - left_slot.down_bonds)
			end
		end
	end
	local up_bonds_max = 0
	local up_grid_i
	local up_slot
	local expand_up
	if grid_0_i / MAX_GRID_WIDTH >= 1 then
		up_grid_i = grid_i - MAX_GRID_WIDTH
		up_slot = GRID[up_grid_i]
		if up_slot then
			expand_up = up_slot.bond_depth == 0
			if expand_up then
				up_bonds_max = single_bonds_max
			elseif up_slot.bond_depth == bond_depth_p1 then
				up_bonds_max = math.min(
					single_bonds_max,
					MAX_TOTAL_BONDS - up_slot.left_bonds - up_slot.up_bonds - up_slot.right_bonds)
			end
		end
	end
	local right_bonds_max = 0
	local right_grid_i
	local right_slot
	local expand_right
	if grid_0_i % MAX_GRID_WIDTH < MAX_GRID_WIDTH_M1 then
		right_grid_i = grid_i + 1
		right_slot = GRID[right_grid_i]
		if right_slot then
			expand_right = right_slot.bond_depth == 0
			if expand_right then
				right_bonds_max = single_bonds_max
			elseif right_slot.bond_depth == bond_depth_p1 then
				right_bonds_max = math.min(
					single_bonds_max,
					MAX_TOTAL_BONDS - right_slot.up_bonds - right_slot.right_bonds - right_slot.down_bonds)
			end
		end
	end
	local down_bonds_max = 0
	local down_grid_i
	local down_slot
	local expand_down
	if grid_0_i / MAX_GRID_WIDTH < MAX_GRID_HEIGHT_M1 then
		down_grid_i = grid_i + MAX_GRID_WIDTH
		down_slot = GRID[down_grid_i]
		if down_slot then
			expand_down = down_slot.bond_depth == 0
			if expand_down then
				down_bonds_max = single_bonds_max
			elseif down_slot.bond_depth == bond_depth_p1 then
				down_bonds_max = math.min(
					single_bonds_max,
					MAX_TOTAL_BONDS - down_slot.left_bonds - down_slot.right_bonds - down_slot.down_bonds)
			end
		end
	end

	-- iterate each permutation of bond numbers per direction, ensuring we don't go over the limit
	for left_bonds = 0, left_bonds_max do
		if left_bonds > 0 then
			left_slot.right_bonds = left_bonds
			slot.left_bonds = left_bonds
			if left_bonds == 1 and expand_left then
				left_slot.bond_depth = bond_depth_p1
				array_push(grid_is, left_grid_i)
			end
		end
		local bonds_after_left = new_bonds_max - left_bonds
		local up_bonds_loop_max = math.min(bonds_after_left, up_bonds_max)
		for up_bonds = 0, up_bonds_loop_max do
			if up_bonds > 0 then
				up_slot.down_bonds = up_bonds
				slot.up_bonds = up_bonds
				if up_bonds == 1 and expand_up then
					up_slot.bond_depth = bond_depth_p1
					array_push(grid_is, up_grid_i)
				end
			end
			local bonds_after_up = bonds_after_left - up_bonds
			local right_bonds_loop_max = math.min(bonds_after_up, right_bonds_max)
			for right_bonds = 0, right_bonds_loop_max do
				if right_bonds > 0 then
					right_slot.left_bonds = right_bonds
					slot.right_bonds = right_bonds
					if right_bonds == 1 and expand_right then
						right_slot.bond_depth = bond_depth_p1
						array_push(grid_is, right_grid_i)
					end
				end
				local down_bonds_loop_max = math.min(bonds_after_up - right_bonds, down_bonds_max)
				for down_bonds = 0, down_bonds_loop_max do
					if down_bonds > 0 then
						down_slot.up_bonds = down_bonds
						slot.down_bonds = down_bonds
						if down_bonds == 1 and expand_down then
							down_slot.bond_depth = bond_depth_p1
							array_push(grid_is, down_grid_i)
						end
					end
					-- deep in here, advance to the next atom in the grid
					gen_molecule_bonds(grid_i_i + 1, grid_is)
				end
				if down_bonds_loop_max > 0 then
					down_slot.up_bonds = 0
					slot.down_bonds = 0
					if expand_down then
						down_slot.bond_depth = 0
						array_pop(grid_is)
					end
				end
			end
			if right_bonds_loop_max > 0 then
				right_slot.left_bonds = 0
				slot.right_bonds = 0
				if expand_right then
					right_slot.bond_depth = 0
					array_pop(grid_is)
				end
			end
		end
		if up_bonds_loop_max > 0 then
			up_slot.down_bonds = 0
			slot.up_bonds = 0
			if expand_up then
				up_slot.bond_depth = 0
				array_pop(grid_is)
			end
		end
	end
	if left_bonds_max > 0 then
		left_slot.right_bonds = 0
		slot.left_bonds = 0
		if expand_left then
			left_slot.bond_depth = 0
			array_pop(grid_is)
		end
	end
end


-- Molecule shape generation
local function is_top_left(shape_n)
	local top_row_mask = 1
	local left_col_mask = 1
	for i = 1, MAX_GRID_WIDTH - 1 do top_row_mask = bit32.bor(top_row_mask, bit32.lshift(1, i)) end
	for i = 1, MAX_GRID_HEIGHT - 1 do left_col_mask = bit32.bor(left_col_mask, bit32.lshift(1, i * MAX_GRID_WIDTH)) end
	return bit32.band(shape_n, top_row_mask) ~= 0 and bit32.band(shape_n, left_col_mask) ~= 0
end

local function gen_atom_slot()
	return {
		left_bonds = 0,
		up_bonds = 0,
		right_bonds = 0,
		down_bonds = 0,
		bond_depth = 0,
	}
end

local function check_grid_connected(first_grid_i)
	-- BFS to check that this shape is properly connected
	GRID[first_grid_i].bond_depth = 1
	local connected_slot_count = 0
	local check_grid_is = array_with_contents({first_grid_i})
	for _, check_grid_i in ipairs(check_grid_is) do
		connected_slot_count = connected_slot_count + 1
		local adjacent_grid_is = empty_array()
		local check_grid_0_i = check_grid_i - 1
		if check_grid_0_i % MAX_GRID_WIDTH >= 1 then array_push(adjacent_grid_is, check_grid_i - 1) end
		if check_grid_0_i / MAX_GRID_WIDTH >= 1 then array_push(adjacent_grid_is, check_grid_i - MAX_GRID_WIDTH) end
		if check_grid_0_i % MAX_GRID_WIDTH < MAX_GRID_WIDTH_M1 then array_push(adjacent_grid_is, check_grid_i + 1) end
		if check_grid_0_i / MAX_GRID_WIDTH < MAX_GRID_HEIGHT_M1 then
			array_push(adjacent_grid_is, check_grid_i + MAX_GRID_WIDTH)
		end
		for _, adjacent_grid_i in ipairs(adjacent_grid_is) do
			local adjacent_slot = GRID[adjacent_grid_i]
			if adjacent_slot and adjacent_slot.bond_depth == 0 then
				adjacent_slot.bond_depth = 1
				array_push(check_grid_is, adjacent_grid_i)
			end
		end
	end
	for _, check_grid_i in ipairs(check_grid_is) do GRID[check_grid_i].bond_depth = 0 end
	return connected_slot_count == current_atom_count
end


-- Finally, go through all possible molecule shapes and generate molecules for each shape
for shape_n = 1, bit32.lshift(1, GRID_AREA) - 1 do
	-- only accept shapes anchored to the top left
	if not is_top_left(shape_n) then goto continue_shapes end

	-- build the grid of slots
	array_clear(GRID)
	current_atom_count = 0
	current_shape_width = 0
	current_shape_height = 0
	local first_grid_i = 0
	for grid_i = 1, GRID_AREA do
		if bit32.band(shape_n, bit32.lshift(1, grid_i - 1)) ~= 0 then
			array_push(GRID, gen_atom_slot())
			if first_grid_i == 0 then first_grid_i = grid_i end
			current_atom_count = current_atom_count + 1
			local grid_0_i = grid_i - 1
			local shape_height = math.floor(grid_0_i / MAX_GRID_WIDTH) + 1
			local shape_width = grid_0_i % MAX_GRID_WIDTH + 1
			if shape_height > current_shape_height then current_shape_height = shape_height end
			if shape_width > current_shape_width then current_shape_width = shape_width end
		else
			array_push(GRID, nil)
		end
	end

	-- make sure all atoms are connected orthogonally
	if not check_grid_connected(first_grid_i) then goto continue_shapes end

	-- generate a complex molecule for this shape
	local curtent_shape_s = string.format("%03X", shape_n)
	local complex_molecule = {
		type = "armor",
		name = COMPLEX_MOLECULE_ITEM_PREFIX..curtent_shape_s,
		subgroup = COMPLEX_MOLECULES_SUBGROUP_NAME,
		localised_name = {"item-name.complex-molecule"},
		icon = SHAPE_ICON_ROOT..curtent_shape_s..".png",
		icon_size = ITEM_ICON_SIZE,
		icon_mipmaps = MOLECULE_ICON_MIPMAPS,
		infinite = true,
		stack_size = 1,
	}
	if shape_n > 1 then
		complex_molecule.equipment_grid =
			COMPLEX_MOLECULE_ITEM_PREFIX.."grid-"..current_shape_height..current_shape_width
	end
	data:extend({complex_molecule})

	-- build atoms separately
	if current_atom_count == 1 then
		for _, atom in ipairs(MOLECULE_ATOMS_ACCEPT_BONDS[1][0]) do gen_atom(atom) end
		goto continue_shapes
	end

	-- don't generate a simple molecule if there are too many atoms
	if current_atom_count > MAX_ATOMS then goto continue_shapes end

	-- this is a valid shape, set the first bond depth and start searching for molecules
	GRID[first_grid_i].bond_depth = 1
	current_shape_icon = {
		icon = SHAPE_ICON_ROOT..curtent_shape_s..".png",
		icon_size = ITEM_ICON_SIZE,
		icon_mipmaps = MOLECULE_ICON_MIPMAPS,
	}
	if current_atom_count <= MAX_ATOMS_Ne then
		current_max_single_bonds = MAX_SINGLE_BONDS_Ne
	else
		current_max_single_bonds = MAX_SINGLE_BONDS_HCNO
	end
	local max_scale = math.max(current_shape_width, current_shape_height)
	local min_scale = math.min(current_shape_width, current_shape_height)
	gen_molecule_bonds(1, array_with_contents({first_grid_i}))
	::continue_shapes::
end


-- Add complex molecule equipment grids and bonds, and molecule builder bonds
data:extend({{type = "equipment-category", name = COMPLEX_MOLECULE_PARTS_NAME}})
for y_scale = 1, MAX_GRID_HEIGHT do
	for x_scale = 1, MAX_GRID_WIDTH do
		if y_scale == 1 and x_scale == 1 then goto continue end
		data:extend({{
			type = "equipment-grid",
			name = COMPLEX_MOLECULE_ITEM_PREFIX.."grid-"..y_scale..x_scale,
			width = x_scale * 2 - 1,
			height = y_scale * 2 - 1,
			equipment_categories = {COMPLEX_MOLECULE_PARTS_NAME},
			locked = true,
		}})
		::continue::
	end
end
data:extend({
	{
		type = "item-subgroup",
		name = MOLECULE_BUILDER_BONDS_SUBGROUP_PREFIX.."H",
		group = "signals",
		order = "k",
	},
	{
		type = "item-subgroup",
		name = MOLECULE_BUILDER_BONDS_SUBGROUP_PREFIX.."V",
		group = "signals",
		order = "l",
	},
})
for _, direction in ipairs({"H", "V"}) do
	for bonds = 1, MAX_SINGLE_BONDS do
		data:extend({
			{
				type = "battery-equipment",
				name = MOLECULE_BONDS_PREFIX..direction..bonds,
				categories = {COMPLEX_MOLECULE_PARTS_NAME},
				localised_name = {"factoriochem.complex-bonds-"..direction, bonds},
				sprite = {
					filename = BOND_ICON_ROOT..direction..bonds.."d.png",
					size = EQUIPMENT_GRID_SIZE,
					flags = {"icon"},
				},
				shape = {width = 1, height = 1, type = "full"},
				energy_source = {type = "void", usage_priority = "tertiary"},
				-- never used, but we have to specify something valid
				take_result = MOLECULE_ABSORBER_NAME,
			},
			-- also add a standalone sprite for molecule contents text
			{
				type = "sprite",
				name = MOLECULE_BONDS_PREFIX..direction..bonds,
				filename = BOND_ICON_ROOT..direction..bonds.."l.png",
				size = EQUIPMENT_GRID_SIZE,
			},
			-- and an item for the molecule builder
			{
				type = "item",
				name = MOLECULE_BONDS_PREFIX..direction..bonds,
				subgroup = MOLECULE_BUILDER_BONDS_SUBGROUP_PREFIX..direction,
				localised_name = {"factoriochem.complex-bonds-"..direction, bonds},
				icon = BOND_ICON_ROOT..direction..bonds.."l.png",
				icon_size = EQUIPMENT_GRID_SIZE,
				stack_size = 1,
			},
		})
	end
end


-- debug
local debug = false
-- debug = true
if debug then
	local total_atoms = 0
	for k, atom in pairs(ALL_ATOMS) do
		if atom.symbol == k then total_atoms = total_atoms + 1 end
	end
	data:extend({
		{
			type = "item-subgroup",
			name = "molecules-debug",
			group = MOLECULES_GROUP_NAME,
		},
		{
			type = "item",
			name = "atom-count",
			subgroup = "molecules-debug",
			localised_name = "Total atoms: "..total_atoms,
			icon = "__base__/graphics/icons/info.png",
			icon_size = 64,
			stack_size = 1,
		},
		{
			type = "item",
			name = "molecule-count",
			subgroup = "molecules-debug",
			localised_name = "Total molecules: "..total_molecules,
			icon = "__base__/graphics/icons/info.png",
			icon_size = 64,
			stack_size = 1,
		},
	})
end
