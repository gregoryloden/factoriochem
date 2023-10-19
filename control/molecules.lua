-- Global constants
COMPLEX_SHAPES = {}


-- Constants
local COMPLEX_MOLECULE_BUILDER = {MOLECULE_ITEM_PREFIX}
local MOLECULE_ID_ATOMS_PER_SIGNAL = 3


-- Global utilities - complex molecules
function assemble_complex_molecule(grid, complex_shape)
	local max_x = complex_shape.max_x
	local builder_i = 2
	for y = 0, complex_shape.max_y, 2 do
		if y > 0 then
			COMPLEX_MOLECULE_BUILDER[builder_i] = ATOM_ROW_SEPARATOR
			builder_i = builder_i + 1
		end
		local last_x = 0
		for _, x in ipairs(complex_shape[y]) do
			while last_x < x do
				COMPLEX_MOLECULE_BUILDER[builder_i] = ATOM_COL_SEPARATOR
				builder_i = builder_i + 1
				last_x = last_x + 2
			end
			if y > 0 then
				local up = grid.get({x, y - 1})
				if up then
					COMPLEX_MOLECULE_BUILDER[builder_i] = string.sub(up.name, -1)
					builder_i = builder_i + 1
				end
			end
			COMPLEX_MOLECULE_BUILDER[builder_i] = string.sub(grid.get({x, y}).name, #ATOM_ITEM_PREFIX + 1)
			builder_i = builder_i + 1
			if x < max_x then
				local right = grid.get({x + 1, y})
				if right then
					COMPLEX_MOLECULE_BUILDER[builder_i] = string.sub(right.name, -1)
					builder_i = builder_i + 1
				end
			end
		end
	end
	while COMPLEX_MOLECULE_BUILDER[builder_i] do
		COMPLEX_MOLECULE_BUILDER[builder_i] = nil
		builder_i = builder_i + 1
	end
	return table.concat(COMPLEX_MOLECULE_BUILDER)
end

function get_complex_molecule_item_name(shape)
	local shape_n = 0
	for y, shape_row in pairs(shape) do
		for x, _ in pairs(shape_row) do shape_n = shape_n + bit32.lshift(1, (y - 1) * MAX_GRID_WIDTH + x - 1) end
	end
	return COMPLEX_MOLECULE_ITEM_PREFIX..string.format("%03X", shape_n)
end

function build_complex_contents(shape, height, width)
	local contents = {item = get_complex_molecule_item_name(shape)}
	for y, shape_row in pairs(shape) do
		y = (y - 1) * 2
		for x, atom in pairs(shape_row) do
			x = (x - 1) * 2
			table.insert(contents, {name = "atom-"..atom.symbol, position = {x, y}})
			if atom.right then
				table.insert(contents, {name = MOLECULE_BONDS_PREFIX.."H"..atom.right, position = {x + 1, y}})
			end
			if atom.down then
				table.insert(contents, {name = MOLECULE_BONDS_PREFIX.."V"..atom.down, position = {x, y + 1}})
			end
		end
	end
	return contents
end


-- Global utilities - read and write combinators
function write_molecule_id_to_combinator(behavior, molecule_id)
	local shape
	if not pcall(function() shape = parse_molecule_id(molecule_id) end) then shape = {{}} end
	for signal_i = 1, behavior.signals_count do
		local signal = nil
		for shape_0_i_i = 0, MOLECULE_ID_ATOMS_PER_SIGNAL - 1 do
			-- check for an atom at this position
			local shape_0_i = (signal_i - 1) * MOLECULE_ID_ATOMS_PER_SIGNAL + shape_0_i_i
			local shape_row = shape[math.floor(shape_0_i / MAX_GRID_WIDTH) + 1]
			if not shape_row then goto continue end
			local atom = shape_row[math.fmod(shape_0_i, MAX_GRID_WIDTH) + 1]
			if not atom then goto continue end
			local atom_atom = ALL_ATOMS[atom.symbol]
			if not atom_atom then goto continue end

			-- write it and its bonds into the signal
			if shape_0_i_i == 0 then
				signal = {signal = {type = "item", name = ATOM_ITEM_PREFIX..atom.symbol}, count = 0}
			else
				if not signal then signal = {signal = {type = "virtual", name = "signal-info"}, count = 0} end
				signal.count = signal.count + bit32.lshift(atom_atom.number, shape_0_i_i * 11 - 7)
			end
			local right_bits = bit32.lshift(atom.right or 0, shape_0_i_i * 11)
			local up_bits = bit32.lshift(atom.up or 0, shape_0_i_i * 11 + 2)
			signal.count = signal.count + right_bits + up_bits
			::continue::
		end
		behavior.set_signal(signal_i, signal)
	end
end

function read_molecule_id_from_combinator(behavior)
	local builder = {}
	local last_row = 1
	local last_col = 1
	for signal_i = 1, behavior.signals_count do
		local signal = behavior.get_signal(signal_i)
		if not signal.signal then goto continue_signals end
		for shape_0_i_i = 0, MOLECULE_ID_ATOMS_PER_SIGNAL - 1 do
			-- get an atom symbol
			local symbol
			if shape_0_i_i == 0 then
				if signal.signal.type ~= "item" then goto continue_shape end
				symbol = string.sub(signal.signal.name, #ATOM_ITEM_PREFIX + 1)
			else
				local atom = ALL_ATOMS[bit32.band(bit32.rshift(signal.count, shape_0_i_i * 11 - 7), 127)]
				if not atom then goto continue_shape end
				symbol = atom.symbol
			end

			-- add separators to the ID builder
			local shape_0_i = (signal_i - 1) * MOLECULE_ID_ATOMS_PER_SIGNAL + shape_0_i_i
			local y = math.floor(shape_0_i / MAX_GRID_WIDTH) + 1
			while last_row < y do
				table.insert(builder, ATOM_ROW_SEPARATOR)
				last_row = last_row + 1
				last_col = 1
			end
			local x = math.fmod(shape_0_i, MAX_GRID_WIDTH) + 1
			while last_col < x do
				table.insert(builder, ATOM_COL_SEPARATOR)
				last_col = last_col + 1
			end

			-- get atom bonds and write the atom + bonds to the ID
			local right_bits = bit32.band(bit32.rshift(signal.count, shape_0_i_i * 11), 3)
			local up_bits = bit32.band(bit32.rshift(signal.count, shape_0_i_i * 11 + 2), 3)
			if up_bits > 0 then table.insert(builder, up_bits) end
			table.insert(builder, symbol)
			if right_bits > 0 then table.insert(builder, right_bits) end
			::continue_shape::
		end
		::continue_signals::
	end
	return table.concat(builder)
end


-- Global event handling
function molecules_on_first_tick()
	-- build the lists of which equipment grid positions to read for complex molecules
	local complex_molecule_subgroup_filter = {filter = "subgroup", subgroup = COMPLEX_MOLECULES_SUBGROUP_NAME}
	for name, prototype in pairs(game.get_filtered_item_prototypes({complex_molecule_subgroup_filter})) do
		local equipment_grid = prototype.equipment_grid
		if not equipment_grid then goto continue end
		local complex_shape = {max_y = equipment_grid.height - 1, max_x = equipment_grid.width - 1}
		local shape_n = tonumber(string.sub(name, -3, -1), 16)
		for y = 0, complex_shape.max_y / 2 do
			local shape_row = {}
			for x = 0, complex_shape.max_x / 2 do
				if bit32.band(shape_n, bit32.lshift(1, y * MAX_GRID_WIDTH + x)) > 0 then
					table.insert(shape_row, x * 2)
				end
			end
			complex_shape[y * 2] = shape_row
		end
		COMPLEX_SHAPES[name] = complex_shape
		::continue::
	end

	-- complete the examples for every building by performing actual reactions on the examples
	for name, definition in pairs(BUILDING_DEFINITIONS) do
		for i, example in ipairs(definition.examples) do
			example.products = {}
			if not definition.reaction(example) then error("Invalid reaction for "..name.." example "..i) end
		end
	end
end
