-- Constants
local MOLECULE_BUILDER_CATEGORIES_NAME = "molecule-builder-categories"
local MOLECULE_BUILDER_SELECTIONS_NAME = "molecule-builder-selections"
local MOLECULE_BUILDER_MAIN_NAME = "molecule-builder-main"
local MOLECULE_BUILDER_TABLE_FRAME_NAME = "molecule-builder-table-frame"
local MOLECULE_BUILDER_TABLE_NAME = "molecule-builder-table"
local MOLECULE_BUILDER_CLEAR_NAME = "molecule-builder-clear"
local MOLECULE_BUILDER_RESULT_NAME = "molecule-builder-result"
local MOLECULE_BUILDER_RESULT_ID_NAME = "molecule-builder-result-id"
local MOLECULE_BUILDER_CATEGORIES = {
	"automation-science-pack",
	"logistic-science-pack",
	"military-science-pack",
	"chemical-science-pack",
	"production-science-pack",
	"utility-science-pack",
	MOLECULIFIER_NAME,
}
local MOLECULE_BUILDER_CATEGORIES_NAME_MAP = {}
local MOLECULE_BUILDER_SELECTIONS_NAME_MAP = {}
local MOLECULE_BUILDER_ROWS = MAX_GRID_HEIGHT * 2 - 1
local MOLECULE_BUILDER_COLS = MAX_GRID_WIDTH * 2 - 1
local MOLECULE_BUILDER_STATE_STACK = nil
local MOLECULE_BUILDER_EXPORT_STACK = nil


-- Global utility - molecule builder export stack
function get_molecule_builder_export_stack(player)
	local cursor_ghost = player.cursor_ghost
	if not cursor_ghost or not MOLECULE_BUILDER_EXPORT_STACK.valid_for_read then return nil end
	if cursor_ghost.name ~= MOLECULE_BUILDER_EXPORT_STACK.name then return nil end
	player.clear_cursor()
	return MOLECULE_BUILDER_EXPORT_STACK
end


-- Utilities
local function iter_molecule_builder_cells(handle_cell)
	for y = 1, MOLECULE_BUILDER_ROWS do
		for x = 1, MOLECULE_BUILDER_COLS do
			handle_cell(y, x, (y + 1) % 2 == 0, (x + 1) % 2 == 0, (y - 1) * MOLECULE_BUILDER_COLS + x)
		end
	end
end

local function set_molecule_builder_selections(outer_gui, recipe_name, use_products)
	local selections
	if use_products then
		selections = GAME_RECIPE_PROTOTYPES[recipe_name].products
	else
		selections = GAME_RECIPE_PROTOTYPES[recipe_name].ingredients
	end
	local selections_gui = outer_gui[MOLECULE_BUILDER_SELECTIONS_NAME]
	if selections_gui then selections_gui.destroy() end
	selections_gui = outer_gui.add({
		type = "table",
		name = MOLECULE_BUILDER_SELECTIONS_NAME,
		column_count = math.ceil((#selections + 2) / 9),
		index = 2,
	})
	for _, selection in ipairs(selections) do
		selections_gui.add({
			type = "sprite-button",
			name = MOLECULE_BUILDER_SELECTIONS_NAME.."-"..selection.name,
			sprite = "item/"..selection.name,
			tooltip = {"factoriochem.molecule-builder-selection"},
		})
	end
	selections_gui.add({
		type = "sprite-button",
		name = MOLECULE_BUILDER_DROPPER_NAME,
		sprite = "item/"..MOLECULE_BUILDER_DROPPER_NAME,
		tooltip = {"factoriochem.molecule-builder-dropper"},
	})
	selections_gui.add({
		type = "sprite-button",
		name = MOLECULE_BUILDER_CLEAR_NAME,
		sprite = "cancel",
		tooltip = {"factoriochem.molecule-builder-clear"},
	})
end

local function get_molecule_builder_shape(table_children)
	-- assemble the shape of the molecule
	local shape = {}
	local height = 0
	local width = 0
	local valid = true
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
	if not valid or height == 0 then return nil end

	-- add corresponding up and left bonds
	for y, shape_row in pairs(shape) do
		for x, atom in pairs(shape_row) do
			if atom.down then
				local other_atom = y + 1 <= height and shape[y + 1][x]
				if not other_atom then return nil end
				other_atom.up = atom.down
			end
			if atom.right then
				local other_atom = shape_row[x + 1]
				if not other_atom then return nil end
				other_atom.left = atom.right
			end
		end
	end

	-- validate the shape before returning it
	shape, height, width = normalize_shape(shape)
	if not validate_molecule(shape, height, width) then return nil end
	return shape, height, width
end

local function export_built_molecule(source, table_gui, player)
	-- the act of getting the stack will clear the cursor if it matches
	get_molecule_builder_export_stack(player)
	local main_gui = table_gui.parent.parent
	local result = main_gui[MOLECULE_BUILDER_RESULT_NAME]
	local result_id = main_gui[MOLECULE_BUILDER_RESULT_ID_NAME]
	local complex_molecule = nil
	local result_val = nil
	local result_id_val = ""
	local shape, height, width = get_molecule_builder_shape(table_gui.children)
	if shape then
		-- set the result ID
		local molecule = assemble_molecule(shape, height, width)
		if height == 1 and width == 1 then
			result_id_val = string.sub(molecule, #ATOM_ITEM_PREFIX + 1)
		else
			result_id_val = string.sub(molecule, #MOLECULE_ITEM_PREFIX + 1)
		end

		-- set the result and the stack item
		local complex_contents = nil
		if not GAME_ITEM_PROTOTYPES[molecule] then
			complex_molecule = molecule
			complex_contents = build_complex_contents(shape, height, width)
			molecule = complex_contents.item
		end
		result_val = "item/"..molecule
		MOLECULE_BUILDER_EXPORT_STACK.set_stack({name = molecule})
		if complex_contents then
			local grid = MOLECULE_BUILDER_EXPORT_STACK.grid
			for _, equipment in ipairs(complex_contents) do grid.put(equipment) end
		end
	else
		MOLECULE_BUILDER_EXPORT_STACK.clear()
	end

	-- write the results to the GUI elements
	result.sprite = result_val
	gui_update_complex_molecule_tooltip(result, complex_molecule, false)
	if source.name ~= MOLECULE_BUILDER_RESULT_ID_NAME then result_id.text = result_id_val end

	-- save the state into the stack
	local grid = MOLECULE_BUILDER_STATE_STACK.grid
	local table_children = table_gui.children
	grid.clear()
	iter_molecule_builder_cells(function(y, x, is_row, is_col, cell_i)
		if not is_row and not is_col then return end
		local val = table_children[cell_i].elem_value
		if val then grid.put({name = val, position = {x - 1, y - 1}}) end
	end)
end

local function show_molecule_in_builder(source, main_gui, shape, height, player)
	local table_gui = main_gui[MOLECULE_BUILDER_TABLE_FRAME_NAME][MOLECULE_BUILDER_TABLE_NAME]
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
	export_built_molecule(source, table_gui, player)
end

function load_molecule_into_builder(molecule_builder_gui, player)
	local grid = MOLECULE_BUILDER_STATE_STACK.grid
	local table_gui = molecule_builder_gui
		.outer
		[MOLECULE_BUILDER_MAIN_NAME]
		[MOLECULE_BUILDER_TABLE_FRAME_NAME]
		[MOLECULE_BUILDER_TABLE_NAME]
	local table_children = table_gui.children
	iter_molecule_builder_cells(function(y, x, is_row, is_col, cell_i)
		if not is_row and not is_col then return end
		local equipment = grid.get({x - 1, y - 1})
		if equipment then
			table_children[cell_i].elem_value = equipment.name
		else
			table_children[cell_i].elem_value = nil
		end
	end)
	export_built_molecule(molecule_builder_gui, table_gui, player)
end

local function write_molecule_into_builder(player, molecule)
	local complex_contents = build_complex_contents(parse_molecule(molecule))
	local grid = MOLECULE_BUILDER_STATE_STACK.grid
	grid.clear()
	for _, equipment in ipairs(complex_contents) do grid.put(equipment) end
	local molecule_builder_gui = player.gui.screen[MOLECULE_BUILDER_NAME]
	if molecule_builder_gui then
		load_molecule_into_builder(molecule_builder_gui, player)
		molecule_builder_gui.bring_to_front()
	end
end

local function try_write_molecule_from_stack_into_builder(player, stack)
	local molecule = stack.name
	local complex_shape = COMPLEX_SHAPES[molecule]
	local item_prototype = GAME_ITEM_PROTOTYPES[molecule]
	if complex_shape then
		write_molecule_into_builder(player, assemble_complex_molecule(stack.grid, complex_shape))
	elseif item_prototype and item_prototype.group.name == MOLECULES_GROUP_NAME then
		write_molecule_into_builder(player, molecule)
	end
end


-- Global utility - molecule builder GUI construction / destruction and cross-GUI interaction
function toggle_molecule_builder_gui(player, ATOMS_SUBGROUP_PREFIX_MATCH)
	local gui = player.gui
	if gui.screen[MOLECULE_BUILDER_NAME] then
		gui.screen[MOLECULE_BUILDER_NAME].destroy()
		return
	end

	function build_category_buttons()
		local buttons = {}
		for _, category in ipairs(MOLECULE_BUILDER_CATEGORIES) do
			local spec = {name = MOLECULE_BUILDER_CATEGORIES_NAME.."-"..category}
			if category == MOLECULIFIER_NAME then
				spec.type = "choose-elem-button"
				spec.elem_type = "recipe"
				spec.elem_filters = {{filter = "subgroup", subgroup = MOLECULIFY_SUBGROUP_NAME}}
				spec.recipe = MOLECULIFIER_NAME
				spec.tooltip = {"factoriochem.molecule-builder-moleculifier"}
			else
				spec.type = "sprite-button"
				spec.sprite = "item/"..category
				spec.tooltip = {"factoriochem.molecule-builder-science", {"item-name."..category}}
			end
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
			name = MOLECULE_BUILDER_CATEGORIES_NAME,
			direction = "vertical",
			children = build_category_buttons(),
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
					tooltip = {"factoriochem.molecule-builder-table"},
					children = build_molecule_builder_table_children(),
				}},
			}, {
				type = "sprite-button",
				name = MOLECULE_BUILDER_RESULT_NAME,
				tooltip = {"factoriochem.molecule-builder-result"},
			}, {
				type = "textfield",
				name = MOLECULE_BUILDER_RESULT_ID_NAME,
				tooltip = {"factoriochem.molecule-builder-result-id"},
			}}
		}},
	}
	local molecule_builder_gui = build_centered_titlebar_gui(
		gui, MOLECULE_BUILDER_NAME, {"shortcut-name."..MOLECULE_BUILDER_NAME}, inner_gui_spec)

	set_molecule_builder_selections(molecule_builder_gui.outer, MOLECULE_BUILDER_CATEGORIES[1], false)
	load_molecule_into_builder(molecule_builder_gui, player)
end

function molecule_builder_copy_reaction_slot(player, component_name, building_data)
	local cursor_ghost = player.cursor_ghost
	if not cursor_ghost or cursor_ghost.name ~= MOLECULE_BUILDER_DROPPER_NAME then return false end
	local chest_stack = building_data.chest_stacks[component_name]
	if chest_stack.valid_for_read then
		try_write_molecule_from_stack_into_builder(player, chest_stack)
	elseif not MOLECULE_REACTION_IS_REACTANT[component_name] then
		local product = building_data.reaction.products[component_name]
		if product then write_molecule_into_builder(player, product) end
	end
	return true
end

function molecule_builder_copy_reaction_demo_slot(player, component_name, demo_state)
	local cursor_ghost = player.cursor_ghost
	if not cursor_ghost or cursor_ghost.name ~= MOLECULE_BUILDER_DROPPER_NAME then return false end
	local component
	if MOLECULE_REACTION_IS_REACTANT[component_name] then
		component = demo_state.reactants[component_name]
	else
		component = demo_state.products[component_name]
	end
	if component then write_molecule_into_builder(player, component) end
	return true
end


-- Global event handling
function molecule_builder_on_gui_click(element, player)
	-- show the ingredients of a science in the molecule builder
	local molecule_builder_category_name = MOLECULE_BUILDER_CATEGORIES_NAME_MAP[element.name]
	if molecule_builder_category_name then
		if molecule_builder_category_name ~= MOLECULIFIER_NAME then
			set_molecule_builder_selections(element.parent.parent, molecule_builder_category_name, false)
		end
		return true
	end

	-- show the contents of a science ingredient or a product from the moleculifier in the molecule builder
	local molecule_builder_selection_name = MOLECULE_BUILDER_SELECTIONS_NAME_MAP[element.name]
	if molecule_builder_selection_name then
		local shape, height
		-- the "clear" button stores its molecule as ""
		if molecule_builder_selection_name == "" then
			shape, height = {}, 0
		else
			shape, height = parse_molecule(molecule_builder_selection_name)
		end
		show_molecule_in_builder(element, element.parent.parent[MOLECULE_BUILDER_MAIN_NAME], shape, height, player)
		return true
	end

	-- put the result molecule under the cursor if possible
	if element.name == MOLECULE_BUILDER_RESULT_NAME then
		if MOLECULE_BUILDER_EXPORT_STACK.valid_for_read then
			player.clear_cursor() -- remove anything that was there before
			player.cursor_ghost = MOLECULE_BUILDER_EXPORT_STACK.name
		end
		return true
	end

	-- put the dropper item under the cursor
	if element.name == MOLECULE_BUILDER_DROPPER_NAME then
		player.clear_cursor() -- remove anything that was there before
		player.cursor_ghost = MOLECULE_BUILDER_DROPPER_NAME
		return true
	end

	-- copy a molecule if there is one under the cursor
	if element.name == MOLECULE_BUILDER_TABLE_NAME then
		if player.cursor_stack and player.cursor_stack.valid_for_read then
			try_write_molecule_from_stack_into_builder(player, player.cursor_stack)
		end
		return true
	end

	return false
end

function molecule_builder_on_gui_elem_changed(element, event)
	-- show the products of a moleculifier recipe in the molecule builder
	local molecule_builder_category_name = MOLECULE_BUILDER_CATEGORIES_NAME_MAP[element.name]
	if molecule_builder_category_name then
		if molecule_builder_category_name == MOLECULIFIER_NAME then
			set_molecule_builder_selections(element.parent.parent, element.elem_value, true)
			element.elem_value = MOLECULIFIER_NAME
		end
		return true
	end

	-- update the molecule builder result and result ID after changing part of it
	if element.parent.name == MOLECULE_BUILDER_TABLE_NAME then
		export_built_molecule(element, element.parent, game.get_player(event.player_index))
		return true
	end

	return false
end

function molecule_builder_on_gui_text_changed(element, event)
	-- update the molecule builder and the result if the text changed
	if element.name == MOLECULE_BUILDER_RESULT_ID_NAME then
		local shape, height
		if not pcall(function() shape, height = parse_molecule_id(element.text) end) then shape, height = {}, 0 end
		show_molecule_in_builder(element, element.parent, shape, height, game.get_player(event.player_index))
		return true
	end

	return false
end

function gui_molecule_buider_on_first_tick()
	-- match GUI names with sciences/science ingredients and the moleculifier/its recipes' products, plus the clear button
	for _, category in ipairs(MOLECULE_BUILDER_CATEGORIES) do
		MOLECULE_BUILDER_CATEGORIES_NAME_MAP[MOLECULE_BUILDER_CATEGORIES_NAME.."-"..category] = category
		if category == MOLECULIFIER_NAME then
			local moleculify_recipes_filters = {{filter = "subgroup", subgroup = MOLECULIFY_SUBGROUP_NAME}}
			for _, recipe in pairs(game.get_filtered_recipe_prototypes(moleculify_recipes_filters)) do
				for _, product in ipairs(recipe.products) do
					local selection_name = MOLECULE_BUILDER_SELECTIONS_NAME.."-"..product.name
					MOLECULE_BUILDER_SELECTIONS_NAME_MAP[selection_name] = product.name
				end
			end
		else
			for _, ingredient in pairs(GAME_RECIPE_PROTOTYPES[category].ingredients) do
				MOLECULE_BUILDER_SELECTIONS_NAME_MAP[MOLECULE_BUILDER_SELECTIONS_NAME.."-"..ingredient.name] =
					ingredient.name
			end
		end
	end
	MOLECULE_BUILDER_SELECTIONS_NAME_MAP[MOLECULE_BUILDER_CLEAR_NAME] = ""

	-- set up stacks
	MOLECULE_BUILDER_STATE_STACK = global.molecule_builder_inventory[1]
	MOLECULE_BUILDER_EXPORT_STACK = global.molecule_builder_inventory[2]
	if not MOLECULE_BUILDER_STATE_STACK.valid_for_read then
		local shape_n = bit32.lshift(1, MAX_GRID_HEIGHT * MAX_GRID_WIDTH) - 1
		MOLECULE_BUILDER_STATE_STACK.set_stack({name = COMPLEX_MOLECULE_ITEM_PREFIX..string.format("%03X", shape_n)})
	end
end
