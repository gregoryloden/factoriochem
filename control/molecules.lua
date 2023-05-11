-- Global constants
COMPLEX_SHAPES = {}


-- Constants
local COMPLEX_MOLECULE_BUILDER = {MOLECULE_ITEM_PREFIX}


-- Global utilities
function parse_complex_molecule(grid, complex_shape)
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
end
