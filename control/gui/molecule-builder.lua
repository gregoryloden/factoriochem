-- Constants
local MOLECULE_BUILDER_SCIENCES_NAME = "molecule-builder-sciences"
local MOLECULE_BUILDER_INGREDIENTS_NAME = "molecule-builder-ingredients"
local MOLECULE_BUILDER_MAIN_NAME = "molecule-builder-main"
local MOLECULE_BUILDER_TABLE_FRAME_NAME = "molecule-builder-table-frame"
local MOLECULE_BUILDER_TABLE_NAME = "molecule-builder-table"
local MOLECULE_BUILDER_CLEAR_NAME = "molecule-builder-clear"
local MOLECULE_BUILDER_RESULT_NAME = "molecule-builder-result"
local MOLECULE_BUILDER_RESULT_TEXT_NAME = "molecule-builder-result-text"
local MOLECULE_BUILDER_SCIENCES = {
	"automation-science-pack",
	"logistic-science-pack",
	"military-science-pack",
	"chemical-science-pack",
	"production-science-pack",
	"utility-science-pack",
}
local MOLECULE_BUILDER_SCIENCES_NAME_MAP = {}
local MOLECULE_BUILDER_INGREDIENTS_NAME_MAP = {}
local MOLECULE_BUILDER_ROWS = MAX_GRID_HEIGHT * 2 - 1
local MOLECULE_BUILDER_COLS = MAX_GRID_WIDTH * 2 - 1


-- Utilities
local function iter_molecule_builder_cells(handle_cell)
	for y = 1, MOLECULE_BUILDER_ROWS do
		for x = 1, MOLECULE_BUILDER_COLS do
			handle_cell(y, x, (y + 1) % 2 == 0, (x + 1) % 2 == 0, (y - 1) * MOLECULE_BUILDER_COLS + x)
		end
	end
end

local function set_molecule_builder_ingredients(gui, molecule_builder_science_name)
	local recipe = GAME_RECIPE_PROTOTYPES[molecule_builder_science_name]
	local ingredients_gui = gui.screen[MOLECULE_BUILDER_NAME].outer[MOLECULE_BUILDER_INGREDIENTS_NAME]
	for _, child in pairs(ingredients_gui.children) do child.destroy() end
	for _, ingredient in pairs(recipe.ingredients) do
		ingredients_gui.add({
			type = "sprite-button",
			name = MOLECULE_BUILDER_INGREDIENTS_NAME.."-"..ingredient.name,
			sprite = "item/"..ingredient.name,
		})
	end
	ingredients_gui.add({type = "sprite-button", name = MOLECULE_BUILDER_CLEAR_NAME, sprite = "cancel"})
end

local function export_built_molecule(source, table_gui)
	local result = table_gui.parent.parent[MOLECULE_BUILDER_RESULT_NAME]
	local result_text = table_gui.parent.parent[MOLECULE_BUILDER_RESULT_TEXT_NAME]
	local table_children = table_gui.children
	local valid = true

	-- assemble the shape of the molecule
	local shape = {}
	local height = 0
	local width = 0
	iter_molecule_builder_cells(function(y, x, is_row, is_col, cell_i)
		-- use math.floor to get the right atom for right and down bonds
		local atom_x = math.floor((x + 1) / 2)
		local atom_y = math.floor((y + 1) / 2)
		local element = table_children[cell_i]
		-- nothing to see here
		if (not is_row and not is_col) or not element.elem_value then
			-- pass
		-- add atoms
		elseif is_row and is_col then
			while height < atom_y do
				height = height + 1
				shape[height] = {}
			end
			if width < atom_x then width = atom_x end
			shape[atom_y][atom_x] =
				{symbol = string.sub(element.elem_value, #ATOM_ITEM_PREFIX + 1), x = atom_x, y = atom_y}
		-- add right or down bonds
		elseif is_row or is_col then
			local atom = atom_y <= height and shape[atom_y][atom_x]
			if not atom then
				valid = false
			elseif is_row then
				atom.right = tonumber(string.sub(element.elem_value, #element.elem_value))
			else
				atom.down = tonumber(string.sub(element.elem_value, #element.elem_value))
			end
		end
	end)

	-- add corresponding up and left bonds
	for y, shape_row in pairs(shape) do
		for x, atom in pairs(shape_row) do
			if atom.down then
				local other_atom = y + 1 <= height and shape[y + 1][x]
				if other_atom then
					other_atom.up = atom.down
				else
					valid = false
				end
			end
			if atom.right then
				local other_atom = shape_row[x + 1]
				if other_atom then
					other_atom.left = atom.right
				else
					valid = false
				end
			end
		end
	end

	-- validate the shape and write it to the results
	if not valid then
		-- pass
	elseif height == 0 then
		valid = false
	else
		shape, height, width = normalize_shape(shape)
		valid = validate_molecule(shape, height, width)
	end
	local result_val = nil
	local result_text_val = ""
	if valid then
		local molecule = assemble_molecule(shape, height, width)
		if GAME_ITEM_PROTOTYPES[molecule] then
			result_val = "item/"..molecule
		else
			result_val = "item/"..get_complex_molecule_item_name(shape)
		end
		if height == 1 and width == 1 then
			result_text_val = string.sub(molecule, #ATOM_ITEM_PREFIX + 1)
		else
			result_text_val = string.sub(molecule, #MOLECULE_ITEM_PREFIX + 1)
		end
	end
	result.sprite = result_val
	if source.name ~= MOLECULE_BUILDER_RESULT_TEXT_NAME then result_text.text = result_text_val end
end

local function show_molecule_in_builder(source, table_gui, shape, height)
	local table_children = table_gui.children
	iter_molecule_builder_cells(function(y, x, is_row, is_col, cell_i)
		-- use math.floor to get the right atom for right and down bonds
		local atom_x = math.floor((x + 1) / 2)
		local atom_y = math.floor((y + 1) / 2)
		local atom = atom_y <= height and shape[atom_y][atom_x]
		local element = table_children[cell_i]
		-- show atoms
		if is_row and is_col then
			-- we can receive molecules from the ID field, which may have invalid symbols which parse fine
			-- this is OK, it's better to extract an invalid molecule into the builder than to clear the builder
			if atom and ALL_ATOMS[atom.symbol] then
				element.elem_value = ATOM_ITEM_PREFIX..atom.symbol
			else
				element.elem_value = nil
			end
		-- show right bonds
		elseif is_row then
			if atom and atom.right then
				element.elem_value = MOLECULE_BONDS_PREFIX.."H"..atom.right
			else
				element.elem_value = nil
			end
		-- show down bonds
		elseif is_col then
			if atom and atom.down then
				element.elem_value = MOLECULE_BONDS_PREFIX.."V"..atom.down
			else
				element.elem_value = nil
			end
		end
	end)
	export_built_molecule(source, table_gui)
end


-- Global utility - molecule builder GUI construction / destruction
function toggle_molecule_builder_gui(gui, ATOMS_SUBGROUP_PREFIX_MATCH, build_title_bar_gui_spec, gui_add_recursive)
	if gui.screen[MOLECULE_BUILDER_NAME] then
		gui.screen[MOLECULE_BUILDER_NAME].destroy()
		return
	end

	function build_science_buttons()
		local buttons = {}
		for _, science in ipairs(MOLECULE_BUILDER_SCIENCES) do
			local spec = {
				type = "sprite-button",
				name = MOLECULE_BUILDER_SCIENCES_NAME.."-"..science,
				sprite = "item/"..science,
			}
			table.insert(buttons, spec)
		end
		return buttons
	end
	function build_molecule_builder_table_children()
		-- cache atom and bond filters
		local atom_filters = {}
		for _, subgroup in ipairs(GAME_ITEM_GROUP_PROTOTYPES[MOLECULES_GROUP_NAME].subgroups) do
			if string.find(subgroup.name, ATOMS_SUBGROUP_PREFIX_MATCH) then
				table.insert(atom_filters, {filter = "subgroup", subgroup = subgroup.name})
			end
		end
		local h_bond_filters = {{filter = "subgroup", subgroup = MOLECULE_BUILDER_BONDS_SUBGROUP_PREFIX.."H"}}
		local v_bond_filters = {{filter = "subgroup", subgroup = MOLECULE_BUILDER_BONDS_SUBGROUP_PREFIX.."V"}}
		local cells = {}
		iter_molecule_builder_cells(function(y, x, is_row, is_col, cell_i)
			if is_row or is_col then
				local spec = {type = "choose-elem-button", elem_type = "item"}
				if not is_col then
					spec.elem_filters = h_bond_filters
				elseif not is_row then
					spec.elem_filters = v_bond_filters
				else
					spec.elem_filters = atom_filters
					spec.style = "factoriochem-big-slot-button"
				end
				cells[cell_i] = spec
			else
				cells[cell_i] = {type = "empty-widget"}
			end
		end)
		return cells
	end
	local inner_gui_spec = {
		type = "frame",
		name = "outer",
		style = "inside_shallow_frame_with_padding",
		children = {{
			type = "flow",
			name = MOLECULE_BUILDER_SCIENCES_NAME,
			direction = "vertical",
			children = build_science_buttons(),
		}, {
			type = "flow",
			name = MOLECULE_BUILDER_INGREDIENTS_NAME,
			direction = "vertical",
		}, {
			type = "flow",
			name = MOLECULE_BUILDER_MAIN_NAME,
			style = "factoriochem-centered-vertical-flow",
			direction = "vertical",
			children = {{
				type = "frame",
				name = MOLECULE_BUILDER_TABLE_FRAME_NAME,
				style = "factoriochem-deep-frame-in-shallow-frame-with-padding",
				children = {{
					type = "table",
					name = MOLECULE_BUILDER_TABLE_NAME,
					style = "factoriochem-molecule-builder-table",
					column_count = MOLECULE_BUILDER_COLS,
					children = build_molecule_builder_table_children(),
				}},
			}, {
				type = "sprite-button",
				name = MOLECULE_BUILDER_RESULT_NAME,
			}, {
				type = "textfield",
				name = MOLECULE_BUILDER_RESULT_TEXT_NAME,
			}}
		}},
	}
	local gui_spec =
		build_title_bar_gui_spec(MOLECULE_BUILDER_NAME, {"factoriochem."..MOLECULE_BUILDER_NAME}, inner_gui_spec)
	local molecule_builder_gui = gui_add_recursive(gui.screen, gui_spec)
	molecule_builder_gui.force_auto_center()
	molecule_builder_gui.titlebar.drag_target = molecule_builder_gui

	set_molecule_builder_ingredients(gui, MOLECULE_BUILDER_SCIENCES[1])
end


-- Global event handling
function molecule_builder_on_gui_click(element, player)
	-- show the ingredients of a science in the molecule builder
	local molecule_builder_science_name = MOLECULE_BUILDER_SCIENCES_NAME_MAP[element.name]
	if molecule_builder_science_name then
		set_molecule_builder_ingredients(player.gui, molecule_builder_science_name)
		return true
	end

	-- show the contents of a science ingredient in the molecule builder
	local molecule_builder_ingredient_name = MOLECULE_BUILDER_INGREDIENTS_NAME_MAP[element.name]
	if molecule_builder_ingredient_name then
		local shape, height
		-- the "clear" button stores its ingredient as ""
		if molecule_builder_ingredient_name == "" then
			shape, height = {}, 0
		else
			shape, height = parse_molecule(molecule_builder_ingredient_name)
		end
		local table_gui = element
			.parent
			.parent
			[MOLECULE_BUILDER_MAIN_NAME]
			[MOLECULE_BUILDER_TABLE_FRAME_NAME]
			[MOLECULE_BUILDER_TABLE_NAME]
		show_molecule_in_builder(element, table_gui, shape, height)
		return true
	end

	return false
end

function molecule_builder_on_gui_elem_changed(element)
	-- update the molecule builder result and result text after changing part of it
	if element.parent.name == MOLECULE_BUILDER_TABLE_NAME then
		export_built_molecule(element, element.parent)
		return true
	end

	return false
end

function molecule_builder_on_gui_text_changed(element)
	-- update the molecule builder and the result if the text changed
	if element.name == MOLECULE_BUILDER_RESULT_TEXT_NAME then
		local shape, height
		if not pcall(function() shape, height = parse_molecule_id(element.text) end) then shape, height = {}, 0 end
		local table_gui = element.parent[MOLECULE_BUILDER_TABLE_FRAME_NAME][MOLECULE_BUILDER_TABLE_NAME]
		show_molecule_in_builder(element, table_gui, shape, height)
		return true
	end

	return false
end

function gui_molecule_buider_on_first_tick()
	-- match GUI names with sciences/science ingredients
	for _, science in ipairs(MOLECULE_BUILDER_SCIENCES) do
		MOLECULE_BUILDER_SCIENCES_NAME_MAP[MOLECULE_BUILDER_SCIENCES_NAME.."-"..science] = science
		local recipe = GAME_RECIPE_PROTOTYPES[science]
		for _, ingredient in pairs(recipe.ingredients) do
			ingredient = ingredient.name
			MOLECULE_BUILDER_INGREDIENTS_NAME_MAP[MOLECULE_BUILDER_INGREDIENTS_NAME.."-"..ingredient] = ingredient
		end
	end
	MOLECULE_BUILDER_INGREDIENTS_NAME_MAP[MOLECULE_BUILDER_CLEAR_NAME] = ""
end
