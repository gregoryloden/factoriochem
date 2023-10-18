require("control/gui/molecule-builder")


-- Constants
local REACTION_PREFIX = "reaction-"
local REACTION_DEMO_PREFIX = "reaction-demo-"
local FRAME_NAME = "frame"
local TABLE_NAME = "table"
local SELECTOR_SUFFIX = "-selector"
local REACTION_TABLE_COMPONENT_NAME_MAP = {}
for _, component_name in ipairs(MOLECULE_REACTION_COMPONENT_NAMES) do
	REACTION_TABLE_COMPONENT_NAME_MAP[REACTION_PREFIX..component_name] = component_name
end
local REACTION_DEMO_TABLE_REACTANT_NAME_MAP = {}
local REACTION_TABLE_SELECTOR_NAME_MAP = {}
local REACTION_DEMO_TABLE_SELECTOR_NAME_MAP = {}
for _, reactant_name in ipairs(MOLECULE_REACTION_REACTANT_NAMES) do
	REACTION_DEMO_TABLE_REACTANT_NAME_MAP[REACTION_DEMO_PREFIX..reactant_name] = reactant_name
	REACTION_TABLE_SELECTOR_NAME_MAP[REACTION_PREFIX..reactant_name..SELECTOR_SUFFIX] = reactant_name
	REACTION_DEMO_TABLE_SELECTOR_NAME_MAP[REACTION_DEMO_PREFIX..reactant_name..SELECTOR_SUFFIX] = reactant_name
end
local REACTION_DEMO_TABLE_PRODUCT_NAME_MAP = {}
for _, product_name in ipairs(MOLECULE_REACTION_PRODUCT_NAMES) do
	REACTION_DEMO_TABLE_PRODUCT_NAME_MAP[REACTION_DEMO_PREFIX..product_name] = product_name
end
local ATOMS_SUBGROUP_PREFIX_MATCH = "^"..ATOMS_SUBGROUP_PREFIX
local BUILDING_EXAMPLES_TEXT = {}
local PERIODIC_TABLE_DEMO_NAME = "periodic-table-demo"
local MOLECULE_BUILDER_DEMO_NAME = "molecule-builder-demo"
local MOLECULE_CONTENTS_CACHE = {}
local MOLECULE_CONTENTS_STRING = "factoriochem.molecule-contents"
local GUI_READY = false


-- Setup
local function build_single_example_text_row(name, definition, example, reactant_name, product_name)
	local reactant_indicator, reactant, selector_val = "[img=empty-1x2]", EMPTY_SPRITE_1X1_TEXT, EMPTY_SPRITE_1X1_TEXT
	local reaction_spacing, product, product_indicator = "      ", EMPTY_SPRITE_1X1_TEXT, ""
	if definition.has_component[reactant_name] then
		reactant_indicator = "[img="..MOLECULE_INDICATOR_PREFIX..reactant_name.."]"
	end
	if example.reactants[reactant_name] then reactant = "[item="..example.reactants[reactant_name].."]" end
	if example.selectors[reactant_name] then
		if definition.selectors[reactant_name] == DROPDOWN_SELECTOR_NAME then
			selector_val = "  "..definition.dropdowns[reactant_name][example.selectors[reactant_name]]
		elseif definition.selectors[reactant_name] == CHECKBOX_SELECTOR_NAME then
			if example.selectors[reactant_name] then selector_val = "[virtual-signal=signal-check]" end
		elseif definition.selectors[reactant_name] == TEXT_SELECTOR_NAME then
			reactant_indicator = example.selectors[reactant_name]
			reactant = ""
			selector_val = ""
			reaction_spacing = ""
		else
			selector_val = "[item="..example.selectors[reactant_name].."]"
		end
	end
	if example.products[product_name] then product = "[item="..example.products[product_name].."]" end
	if definition.has_component[product_name] then
		product_indicator = "[img="..MOLECULE_INDICATOR_PREFIX..product_name.."]"
	end
	local row_builder = {reactant_indicator, reactant, selector_val, reaction_spacing, product, product_indicator}
	local row = table.concat(row_builder, " ")
	local row_len = #row
	repeat
		local old_row_len = row_len
		row = string.gsub(row, "%s+$", "")
		row = string.gsub(row, "%[img=empty-[^%]]+%]$", "")
		row_len = #row
	until row_len == old_row_len
	return row
end


-- Utilities
local function close_gui(player)
	local gui = player.gui
	if gui.relative[MOLECULE_REACTION_NAME] then
		gui.relative[MOLECULE_REACTION_NAME].destroy()
		global.current_gui_reaction_building_data[player.index] = nil
	end
	if gui.screen[PERIODIC_TABLE_NAME] then gui.screen[PERIODIC_TABLE_NAME].destroy() end
end

local function gui_add_recursive(gui, element_spec)
	local children_spec = element_spec.children
	element_spec.children = nil
	local element = gui.add(element_spec)
	if not children_spec then return end
	for _, child_spec in ipairs(children_spec) do gui_add_recursive(element, child_spec) end
	return element
end

local function build_molecule_contents_text(molecule)
	local shape, height, width = parse_molecule(molecule)
	local builder = {}
	for atom_y = 1, height do
		local shape_row = shape[atom_y]
		local row_builder = {}
		local up_builder
		if atom_y > 1 then up_builder = {} end
		local last_x = -1
		local last_up_x = -1
		for atom_x = 1, width do
			local atom = shape_row[atom_x]
			if not atom then goto continue end
			local x = (atom_x - 1) * 2
			local y = (atom_y - 1) * 2
			last_x = last_x + 1
			while last_x < x do
				table.insert(row_builder, EMPTY_SPRITE_1X1_TEXT)
				last_x = last_x + 1
			end
			table.insert(row_builder, ALL_ATOMS[atom.symbol].rich_text)
			if atom.right then
				table.insert(row_builder, H_BONDS_RICH_TEXT[atom.right])
				last_x = last_x + 1
			end
			if atom.up then
				last_up_x = last_up_x + 1
				while last_up_x < x do
					table.insert(up_builder, EMPTY_SPRITE_1X1_TEXT)
					last_up_x = last_up_x + 1
				end
				table.insert(up_builder, V_BONDS_RICH_TEXT[atom.up])
			end
			::continue::
		end
		if up_builder then table.insert(builder, table.concat(up_builder)) end
		table.insert(builder, table.concat(row_builder))
	end
	return table.concat(builder, "\n")
end

local function indexof_reactant(reactant_name)
	for i, found_reactant_name in ipairs(MOLECULE_REACTION_REACTANT_NAMES) do
		if reactant_name == found_reactant_name then return i end
	end
end

local function get_stack_if_valid_for_read(stack)
	return stack and stack.valid_for_read and stack
end

local function gui_update_complex_molecule_tooltip(element, complex_molecule)
	local tooltip = element.tooltip
	if complex_molecule then
		local molecule_contents_text = MOLECULE_CONTENTS_CACHE[complex_molecule]
		if not molecule_contents_text then
			molecule_contents_text = build_molecule_contents_text(complex_molecule)
			MOLECULE_CONTENTS_CACHE[complex_molecule] = molecule_contents_text
		end
		if tooltip[1] ~= MOLECULE_CONTENTS_STRING then
			tooltip = {MOLECULE_CONTENTS_STRING, molecule_contents_text, tooltip}
		else
			tooltip[2] = molecule_contents_text
		end
		element.tooltip = tooltip
	elseif tooltip[1] == MOLECULE_CONTENTS_STRING then
		element.tooltip = tooltip[3]
	end
end

function build_centered_titlebar_gui(gui, name, title, content)
	local gui_spec = {
		type = "frame",
		name = name,
		direction = "vertical",
		children = {
			{
				type = "flow",
				name = "titlebar",
				children = {{
					type = "label",
					caption = title,
					style = "frame_title",
					ignored_by_interaction = true,
				}, {
					type = "empty-widget",
					style = "factoriochem-titlebar-drag-handle",
					ignored_by_interaction = true,
				}, {
					type = "sprite-button",
					name = "close",
					style = "frame_action_button",
					sprite = "utility/close_white",
					hovered_sprite = "utility/close_black",
					clicked_sprite = "utility/close_black",
				}},
			},
			content,
		},
	}
	local titlebar_gui = gui_add_recursive(gui.screen, gui_spec)
	titlebar_gui.titlebar.drag_target = titlebar_gui
	titlebar_gui.force_auto_center()
	return titlebar_gui
end


-- Reaction display utilities
local function update_reaction_table_sprite(element, chest_stack, component)
	local complex_molecule
	if chest_stack and chest_stack.valid_for_read then
		component = chest_stack.name
		element.sprite = "item/"..component
		local complex_shape = COMPLEX_SHAPES[component]
		if complex_shape then complex_molecule = assemble_complex_molecule(chest_stack.grid, complex_shape) end
	elseif component then
		if GAME_ITEM_PROTOTYPES[component] then
			element.sprite = "item/"..component
		else
			complex_molecule = component
			element.sprite = "item/"..get_complex_molecule_item_name(parse_molecule(component))
		end
	else
		element.sprite = nil
	end
	gui_update_complex_molecule_tooltip(element, complex_molecule)
end

local function update_all_reaction_table_sprites(gui, building_data)
	local reaction_table =
		gui.relative[MOLECULE_REACTION_NAME].outer[REACTION_PREFIX..FRAME_NAME][REACTION_PREFIX..TABLE_NAME]
	local building_definition = BUILDING_DEFINITIONS[building_data.entity.name]
	local chest_stacks = building_data.chest_stacks
	for _, reactant_name in ipairs(building_definition.reactants) do
		update_reaction_table_sprite(reaction_table[REACTION_PREFIX..reactant_name], chest_stacks[reactant_name])
	end
	local products = building_data.reaction.products
	for _, product_name in ipairs(building_definition.products) do
		update_reaction_table_sprite(
			reaction_table[REACTION_PREFIX..product_name], chest_stacks[product_name], products[product_name])
	end
end

local function get_demo_state(entity_name)
	local demo_state = global.gui_demo_items[entity_name]
	if not demo_state then
		demo_state = {reactants = {}, products = {}, selectors = {}}
		entity_assign_default_selectors(demo_state.selectors, BUILDING_DEFINITIONS[entity_name].selectors)
		global.gui_demo_items[entity_name] = demo_state
	end
	return demo_state
end

local function demo_reaction(building_data, demo_state, reaction_demo_table)
	for product_name, _ in pairs(demo_state.products) do demo_state.products[product_name] = nil end
	local building_definition = BUILDING_DEFINITIONS[building_data.entity.name]
	local valid_reaction = true
	for _, reactant in pairs(demo_state.reactants) do
		local item_prototype = GAME_ITEM_PROTOTYPES[reactant]
		if item_prototype and
				(item_prototype.group.name ~= MOLECULES_GROUP_NAME
					or item_prototype.subgroup.name == MOLECULE_ITEMS_SUBGROUP_NAME) then
			valid_reaction = false
			break
		end
	end
	if valid_reaction then building_definition.reaction(demo_state) end
	for _, product_name in ipairs(building_definition.products) do
		update_reaction_table_sprite(
			reaction_demo_table[REACTION_DEMO_PREFIX..product_name], nil, demo_state.products[product_name])
	end
end

local function demo_reaction_with_reactant(building_data, demo_state, element, reactant_name, reactant_stack)
	local reactant = reactant_stack and reactant_stack.name
	local complex_shape = reactant and COMPLEX_SHAPES[reactant]
	if complex_shape then reactant = assemble_complex_molecule(reactant_stack.grid, complex_shape) end
	demo_state.reactants[reactant_name] = reactant
	update_reaction_table_sprite(element, nil, reactant)
	demo_reaction(building_data, demo_state, element.parent)
end


-- Molecule reaction building GUI construction
local function build_molecule_reaction_gui(entity, gui, building_definition)
	local demo_state = get_demo_state(entity.name)
	function build_molecule_spec(name_prefix, component_name)
		if not building_definition.has_component[component_name] then return {type = "empty-widget"} end
		local spec = {
			type = "sprite-button",
			name = name_prefix..component_name,
			tooltip = {"factoriochem."..entity.name.."-"..component_name.."-tooltip"},
			style = "factoriochem-big-slot-button",
		}
		if building_definition.selectors[component_name] == MUTATION_SELECTOR_NAME then
			table.insert(spec.tooltip, {"factoriochem.molecule-"..component_name.."-mutation-tooltip"})
		end
		if name_prefix == REACTION_PREFIX then
			spec.tooltip = {"factoriochem.reaction-table-component-tooltip", spec.tooltip}
		elseif name_prefix == REACTION_DEMO_PREFIX then
			if MOLECULE_REACTION_IS_REACTANT[component_name] then
				spec.tooltip = {"factoriochem.reaction-demo-table-reactant-tooltip", spec.tooltip}
				if demo_state.reactants[component_name] then
					update_reaction_table_sprite(spec, nil, demo_state.reactants[component_name])
				end
			elseif demo_state.products[component_name] then
				update_reaction_table_sprite(spec, nil, demo_state.products[component_name])
			end
		end
		return spec
	end
	function build_selector_spec(name_prefix, reactant_name)
		local selector = building_definition.selectors[reactant_name]
		if not selector then return {type = "empty-widget"} end
		local spec = {
			name = name_prefix..reactant_name..SELECTOR_SUFFIX,
			tooltip = {"factoriochem."..entity.name.."-"..reactant_name..SELECTOR_SUFFIX.."-tooltip"},
		}
		local selector_val
		if name_prefix == REACTION_PREFIX then
			selector_val =
				global.molecule_reaction_building_data[entity.unit_number].reaction.selectors[reactant_name]
		else
			selector_val = demo_state.selectors[reactant_name]
		end
		if selector == ATOM_SELECTOR_NAME or selector == MUTATION_SELECTOR_NAME then
			spec.elem_filters = {}
			if selector == MUTATION_SELECTOR_NAME then
				table.insert(
					spec.elem_filters, {filter = "subgroup", subgroup = PERFORM_FUSION_SELECTOR_SUBGROUP})
				table.insert(
					spec.tooltip, {"factoriochem.molecule-"..reactant_name.."-selector-mutation-tooltip"})
			end
			for _, subgroup in ipairs(GAME_ITEM_GROUP_PROTOTYPES[MOLECULES_GROUP_NAME].subgroups) do
				if string.find(subgroup.name, ATOMS_SUBGROUP_PREFIX_MATCH) then
					table.insert(spec.elem_filters, {filter = "subgroup", subgroup = subgroup.name})
				end
			end
		elseif selector == ATOM_BOND_SELECTOR_NAME then
			spec.elem_filters = {
				{filter = "subgroup", subgroup = ATOM_BOND_INNER_SELECTOR_SUBGROUP},
				{filter = "subgroup", subgroup = ATOM_BOND_OUTER_SELECTOR_SUBGROUP},
			}
		elseif selector == DROPDOWN_SELECTOR_NAME then
			spec.type = "drop-down"
			spec.items = building_definition.dropdowns[reactant_name]
			spec.style = "factoriochem-dropdown"
			spec.selected_index = selector_val or 1
			-- this selector doesn't select an item so stop here
			return spec
		elseif selector == CHECKBOX_SELECTOR_NAME then
			spec.type = "checkbox"
			spec.style = "factoriochem-area-checkbox"
			spec.state = selector_val or false
			-- this selector doesn't select an item so stop here
			return spec
		elseif selector == TEXT_SELECTOR_NAME then
			spec.type = "textfield"
			spec.style = "factoriochem-textfield"
			spec.text = selector_val
			-- this selector doesn't select an item so stop here
			return spec
		else
			spec.elem_filters = {{filter = "subgroup", subgroup = MOLECULE_REACTION_SELECTOR_PREFIX..selector}}
		end
		spec.type = "choose-elem-button"
		spec.elem_type = "item"
		spec.item = selector_val
		return spec
	end
	function build_indicator_spec(component_name)
		if not building_definition.has_component[component_name] then return {type = "empty-widget"} end
		return {type = "sprite", sprite = MOLECULE_INDICATOR_PREFIX..component_name}
	end
	function build_periodic_table_button_spec(name_prefix)
		if name_prefix ~= REACTION_DEMO_PREFIX then return {type = "empty-widget"} end
		return {
			type = "flow",
			children = {{
				type = "sprite-button",
				name = PERIODIC_TABLE_DEMO_NAME,
				tooltip = {"shortcut-name."..PERIODIC_TABLE_NAME},
				sprite = PERIODIC_TABLE_NAME.."-24",
				style = "factoriochem-tool-button-24",
			}, {
				type = "sprite-button",
				name = MOLECULE_BUILDER_DEMO_NAME,
				tooltip = {"shortcut-name."..MOLECULE_BUILDER_NAME},
				sprite = MOLECULE_BUILDER_NAME.."-24",
				style = "factoriochem-tool-button-24",
			}}
		}
	end
	function build_reaction_table_spec(name_prefix)
		local spec = {
			type = "table",
			name = name_prefix.."table",
			column_count = 6,
			children = {
				-- title row
				{type = "empty-widget"},
				{type = "empty-widget"},
				{type = "empty-widget"},
				{type = "label", caption = {"factoriochem."..name_prefix.."table-header"}},
				{type = "empty-widget"},
				{type = "empty-widget"},
				-- base/result row
				build_indicator_spec(BASE_NAME),
				build_molecule_spec(name_prefix, BASE_NAME),
				build_selector_spec(name_prefix, BASE_NAME),
				build_periodic_table_button_spec(name_prefix),
				build_molecule_spec(name_prefix, RESULT_NAME),
				build_indicator_spec(RESULT_NAME),
				-- catalyst/byproduct row
				build_indicator_spec(CATALYST_NAME),
				build_molecule_spec(name_prefix, CATALYST_NAME),
				build_selector_spec(name_prefix, CATALYST_NAME),
				{type = "label", caption = {"factoriochem.reaction-transition"}},
				build_molecule_spec(name_prefix, BYPRODUCT_NAME),
				build_indicator_spec(BYPRODUCT_NAME),
				-- modifier/remainder row
				build_indicator_spec(MODIFIER_NAME),
				build_molecule_spec(name_prefix, MODIFIER_NAME),
				build_selector_spec(name_prefix, MODIFIER_NAME),
				{type = "empty-widget"},
				build_molecule_spec(name_prefix, REMAINDER_NAME),
				build_indicator_spec(REMAINDER_NAME),
			},
		}
		if name_prefix == REACTION_DEMO_PREFIX then
			local examples_label = {
				type = "label",
				caption = {"factoriochem.molecule-reaction-examples"},
				tooltip = BUILDING_EXAMPLES_TEXT[entity.name],
			}
			table.insert(spec.children, {type = "empty-widget"})
			table.insert(spec.children, {type = "empty-widget"})
			table.insert(spec.children, {type = "empty-widget"})
			table.insert(spec.children, examples_label)
			table.insert(spec.children, {type = "empty-widget"})
			table.insert(spec.children, {type = "empty-widget"})
		end
		return spec

	end
	local gui_spec = {
		-- outer
		type = "frame",
		caption = {"factoriochem.reaction"},
		name = MOLECULE_REACTION_NAME,
		anchor = {
			gui = defines.relative_gui_type.assembling_machine_gui,
			position = defines.relative_gui_position.right
		},
		children = {{
			-- inner
			type = "flow",
			name = "outer",
			style = "inset_frame_container_vertical_flow",
			direction = "vertical",
			children = {{
				-- reaction frame
				type = "frame",
				name = REACTION_PREFIX.."frame",
				style = "inside_shallow_frame_with_padding",
				direction = "vertical",
				children = {build_reaction_table_spec(REACTION_PREFIX)},
			}, {
				-- reaction demo frame
				type = "frame",
				style = "inside_shallow_frame_with_padding",
				direction = "vertical",
				children = {build_reaction_table_spec(REACTION_DEMO_PREFIX)},
			}},
		}},
	}
	gui_add_recursive(gui.relative, gui_spec)
	update_all_reaction_table_sprites(gui, global.molecule_reaction_building_data[entity.unit_number])
end


-- Periodic table GUI construction / destruction
local function toggle_periodic_table_gui(player)
	local gui = player.gui
	if gui.screen[PERIODIC_TABLE_NAME] then
		gui.screen[PERIODIC_TABLE_NAME].destroy()
		return
	end

	function build_element_table_children()
		local children = {}
		for row = 1, 10 do
			local atom_row = ATOM_ROWS[row]
			if row >= 9 then atom_row = ATOM_ROWS[row - 3] end
			local atom_row_count
			if atom_row then atom_row_count = #atom_row end
			for col = 1, 19 do
				local atom
				if row == 1 then
					if col == 1 then
						atom = atom_row[1]
					elseif col == 19 then
						atom = atom_row[2]
					end
				elseif row <= 7 then
					if col <= 2 then
						atom = atom_row[col]
					elseif col >= 4 then
						col = atom_row_count - 19 + col
						if col > 2 then atom = atom_row[col] end
					end
				elseif row >= 9 then
					if col >= 4 and col <= 17 then atom = atom_row[col - 1] end
				end
				local child
				if atom then
					item_name = ATOM_ITEM_PREFIX..atom
					item = GAME_ITEM_PROTOTYPES[item_name]
					child = {
						type = "sprite",
						sprite = "item/"..item_name,
						tooltip = {
							"factoriochem."..PERIODIC_TABLE_NAME.."-tooltip",
							item.localised_name,
							item.localised_description,
						},
						number = ALL_ATOMS[atom].number,
					}
				elseif col == 3 then
					if row == 6 or row == 9 then
						child = {type = "label", caption = "*"}
					elseif row == 7 or row == 10 then
						child = {type = "label", caption = "**"}
					else
						child = {type = "label", caption = " "}
					end
				else
					child = {type = "empty-widget"}
				end
				table.insert(children, child)
			end
			if row ~= 8 then
				start = #children - 18
				for child_i = start, start + 18 do
					local child = children[child_i]
					if child.number then
						local number = {
							type = "label",
							caption = child.number,
							style = "factoriochem-small-label"
						}
						child.number = nil
						table.insert(children, number)
					else
						table.insert(children, {type = "empty-widget"})
					end
				end
			end
		end
		return children
	end
	local inner_gui_spec = {
		type = "frame",
		style = "factoriochem-inside-deep-frame-with-padding",
		children = {{
			type = "table",
			name = PERIODIC_TABLE_NAME.."-table",
			column_count = 19,
			style = "factoriochem-periodic-table",
			children = build_element_table_children(),
		}},
	}
	local periodic_table_gui =
		build_centered_titlebar_gui(gui, PERIODIC_TABLE_NAME, {"shortcut-name."..PERIODIC_TABLE_NAME}, inner_gui_spec)
	if player.opened_gui_type == defines.gui_type.none then
		periodic_table_gui.titlebar.close.tooltip = {"gui.close-instruction"}
		player.opened = periodic_table_gui
	end
end


-- Event handling
local function on_gui_opened(event)
	-- don't do anything GUI related until initialization has run
	if not GUI_READY then return end

	local entity = event.entity
	if not entity then return end
	local player = game.get_player(event.player_index)

	-- open the GUI for a molecule reaction building
	local building_definition = BUILDING_DEFINITIONS[entity.name]
	if building_definition then
		build_molecule_reaction_gui(entity, player.gui, building_definition)
		global.current_gui_reaction_building_data[player.index] =
			global.molecule_reaction_building_data[entity.unit_number]
	-- prevent the GUI from opening for a molecule detector
	elseif entity.name == MOLECULE_DETECTOR_OUTPUT_NAME then
		player.opened = nil
	end
end

local function on_gui_closed(event)
	close_gui(game.get_player(event.player_index))
end

local function on_gui_click(event)
	local element = event.element
	local building_data = global.current_gui_reaction_building_data[event.player_index]
	local player = game.get_player(event.player_index)

	if element.name == "close" then
		-- assumes the close button is a child of a titlebar flow that is a child of the GUI frame
		element.parent.parent.destroy()
		return
	end

	-- transfer a stack between the player's cursor and one of the chests if applicable
	local reaction_table_component_name = REACTION_TABLE_COMPONENT_NAME_MAP[element.name]
	if reaction_table_component_name then
		-- instead of doing a transfer, copy a molecule into the molecule builder if applicable
		if molecule_builder_copy_reaction_slot(player, reaction_table_component_name, building_data) then return end

		-- otherwise, proceed with a transfer
		local chest_stack = building_data.chest_stacks[reaction_table_component_name]
		if chest_stack.valid_for_read then
			local empty_player_stack = player.get_main_inventory().find_empty_stack()
			if empty_player_stack then
				empty_player_stack.transfer_stack(chest_stack)
				update_reaction_table_sprite(element, chest_stack)
			end
		elseif player.cursor_stack and player.cursor_stack.valid_for_read then
			chest_stack.transfer_stack(player.cursor_stack)
			update_reaction_table_sprite(element, chest_stack)
		end
		return
	end

	-- set or clear one of the demo reactant slots if applicable
	local reaction_demo_table_reactant_name = REACTION_DEMO_TABLE_REACTANT_NAME_MAP[element.name]
	if reaction_demo_table_reactant_name then
		-- first things first, clear the slot if the user clicked the right mouse button
		local demo_state = get_demo_state(building_data.entity.name)
		if event.button == defines.mouse_button_type.right then
			demo_reaction_with_reactant(building_data, demo_state, element, reaction_demo_table_reactant_name, nil)
			return
		end

		-- instead of modifying a slot, copy a molecule into the molecule builder if applicable
		if molecule_builder_copy_reaction_demo_slot(player, reaction_demo_table_reactant_name, demo_state) then
			return
		end

		-- otherwise, proceed with setting the reactant stack to one of the source stacks, in order of priority
		local reactant_stack =
			get_molecule_builder_export_stack(player)
				or get_stack_if_valid_for_read(player.cursor_stack)
				or get_stack_if_valid_for_read(building_data.chest_stacks[reaction_demo_table_reactant_name])
		if reactant_stack then
			demo_reaction_with_reactant(
				building_data, demo_state, element, reaction_demo_table_reactant_name, reactant_stack)
		end
		return
	end

	-- copy a demo result molecule into the molecule builder if applicable
	local reaction_demo_table_product_name = REACTION_DEMO_TABLE_PRODUCT_NAME_MAP[element.name]
	if reaction_demo_table_product_name then
		local demo_state = get_demo_state(building_data.entity.name)
		molecule_builder_copy_reaction_demo_slot(player, reaction_demo_table_product_name, demo_state)
		-- whether there was a valid molecule to copy or not, we're done
		return
	end

	-- open or close the periodic table
	if element.name == PERIODIC_TABLE_DEMO_NAME then
		toggle_periodic_table_gui(player)
		return
	end

	-- open or close the molecule builder
	if element.name == MOLECULE_BUILDER_DEMO_NAME then
		toggle_molecule_builder_gui(player, ATOMS_SUBGROUP_PREFIX_MATCH)
		return
	end

	-- check molecule builder events
	if molecule_builder_on_gui_click(element, player) then return end
end

local function on_gui_elem_changed(event)
	local element = event.element
	local building_data = global.current_gui_reaction_building_data[event.player_index]

	-- update the selector from a choose-elem-button, and save the setting
	local reaction_table_selector_reactant_name = REACTION_TABLE_SELECTOR_NAME_MAP[element.name]
	if reaction_table_selector_reactant_name then
		building_data.reaction.selectors[reaction_table_selector_reactant_name] = element.elem_value
		local reactant_i = indexof_reactant(reaction_table_selector_reactant_name)
		local settings_behavior = building_data.settings.get_control_behavior()
		if element.elem_value then
			settings_behavior.set_signal(
				reactant_i, {signal = {type = "item", name = element.elem_value}, count = 1})
		else
			settings_behavior.set_signal(reactant_i, nil)
		end
		entity_assign_cache(building_data, BUILDING_DEFINITIONS[building_data.entity.name])
		return
	end

	-- update the selector from a choose-elem-button in the demo area
	local reaction_demo_table_selector_reactant_name = REACTION_DEMO_TABLE_SELECTOR_NAME_MAP[element.name]
	if reaction_demo_table_selector_reactant_name then
		local demo_state = get_demo_state(building_data.entity.name)
		demo_state.selectors[reaction_demo_table_selector_reactant_name] = element.elem_value
		demo_reaction(building_data, demo_state, element.parent)
		return
	end

	-- check molecule builder events
	if molecule_builder_on_gui_elem_changed(element, event) then return end
end

local function on_gui_selection_state_changed(event)
	local element = event.element
	local building_data = global.current_gui_reaction_building_data[event.player_index]

	-- update the selector from a drop-down, and save the setting
	local reaction_table_selector_reactant_name = REACTION_TABLE_SELECTOR_NAME_MAP[element.name]
	if reaction_table_selector_reactant_name then
		building_data.reaction.selectors[reaction_table_selector_reactant_name] = element.selected_index
		local reactant_i = indexof_reactant(reaction_table_selector_reactant_name)
		local settings_behavior = building_data.settings.get_control_behavior()
		if element.selected_index ~= 1 then
			settings_behavior.set_signal(
				reactant_i, {signal = {type = "virtual", name = "signal-info"}, count = element.selected_index})
		else
			settings_behavior.set_signal(reactant_i, nil)
		end
		entity_assign_cache(building_data, BUILDING_DEFINITIONS[building_data.entity.name])
		return
	end

	-- update the selector from a drop-down in the demo area
	local reaction_demo_table_selector_reactant_name = REACTION_DEMO_TABLE_SELECTOR_NAME_MAP[element.name]
	if reaction_demo_table_selector_reactant_name then
		local demo_state = get_demo_state(building_data.entity.name)
		demo_state.selectors[reaction_demo_table_selector_reactant_name] = element.selected_index
		demo_reaction(building_data, demo_state, element.parent)
		return
	end
end

local function on_gui_checked_state_changed(event)
	local element = event.element
	local building_data = global.current_gui_reaction_building_data[event.player_index]

	-- update the selector from a checkbox, and save the setting
	local reaction_table_selector_reactant_name = REACTION_TABLE_SELECTOR_NAME_MAP[element.name]
	if reaction_table_selector_reactant_name then
		building_data.reaction.selectors[reaction_table_selector_reactant_name] = element.state
		local reactant_i = indexof_reactant(reaction_table_selector_reactant_name)
		local settings_behavior = building_data.settings.get_control_behavior()
		if element.state then
			settings_behavior.set_signal(
				reactant_i, {signal = {type = "virtual", name = "signal-check"}, count = 1})
		else
			settings_behavior.set_signal(reactant_i, nil)
		end
		entity_assign_cache(building_data, BUILDING_DEFINITIONS[building_data.entity.name])
		return
	end

	-- update the selector from a checkbox in the demo area
	local reaction_demo_table_selector_reactant_name = REACTION_DEMO_TABLE_SELECTOR_NAME_MAP[element.name]
	if reaction_demo_table_selector_reactant_name then
		local demo_state = get_demo_state(building_data.entity.name)
		demo_state.selectors[reaction_demo_table_selector_reactant_name] = element.state
		demo_reaction(building_data, demo_state, element.parent)
		return
	end
end

local function on_gui_text_changed(event)
	local element = event.element
	local building_data = global.current_gui_reaction_building_data[event.player_index]

	-- update the selector from a textfield, and save the setting
	local reaction_table_selector_reactant_name = REACTION_TABLE_SELECTOR_NAME_MAP[element.name]
	if reaction_table_selector_reactant_name then
		building_data.reaction.selectors[reaction_table_selector_reactant_name] = element.text
		if building_data.entity.name == MOLECULE_PRINTER_NAME then
			write_molecule_id_to_combinator(building_data.settings.get_control_behavior(), element.text)
		end
		entity_assign_cache(building_data, BUILDING_DEFINITIONS[building_data.entity.name])
		return
	end

	-- update the selector from a textfield in the demo area
	local reaction_demo_table_selector_reactant_name = REACTION_DEMO_TABLE_SELECTOR_NAME_MAP[element.name]
	if reaction_demo_table_selector_reactant_name then
		local demo_state = get_demo_state(building_data.entity.name)
		demo_state.selectors[reaction_demo_table_selector_reactant_name] = element.text
		demo_reaction(building_data, demo_state, element.parent)
		return
	end

	-- check molecule builder events
	if molecule_builder_on_gui_text_changed(element, event) then return end
end

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)
script.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
script.on_event(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
script.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)


-- Global event handling
function gui_on_init()
	global.current_gui_reaction_building_data = {}
	global.gui_demo_items = {}
	global.molecule_builder_inventory = game.create_inventory(2)
end

function gui_on_first_tick()
	-- build the example text for every building by performing actual reactions on the examples
	for name, definition in pairs(BUILDING_DEFINITIONS) do
		local examples_text
		local examples = definition.examples
		for i, example in ipairs(examples) do
			example.products = {}
			if not definition.reaction(example) then error("Invalid reaction for "..name.." example "..i) end
			local example_builder = {}
			for i, reactant_name in ipairs(MOLECULE_REACTION_REACTANT_NAMES) do
				local product_name = MOLECULE_REACTION_PRODUCT_NAMES[i]
				local row_text = ""
				if example.selectors[reactant_name]
						or definition.has_component[reactant_name]
						or definition.has_component[product_name] then
					row_text = build_single_example_text_row(
						name, definition, example, reactant_name, product_name)
				end
				table.insert(example_builder, row_text)
			end
			while example_builder[#example_builder] == "" do example_builder[#example_builder] = nil end
			local example_text = table.concat(example_builder, "\n")
			if examples_text then
				examples_text =
					{"factoriochem.molecule-reaction-example-continuation", examples_text, example_text}
			else
				examples_text = {"factoriochem.molecule-reaction-example-header", example_text}
			end
		end
		BUILDING_EXAMPLES_TEXT[name] = examples_text
	end
	gui_molecule_buider_on_first_tick()
	GUI_READY = true
end

function gui_on_tick(event)
	local reaction_building_update_group = math.fmod(event.tick, global.molecule_reaction_building_data.ticks_per_update)
	for player_index, building_data in pairs(global.current_gui_reaction_building_data) do
		if building_data.update_group == reaction_building_update_group then
			local player = game.get_player(player_index)
			if building_data.entity.valid then
				update_all_reaction_table_sprites(player.gui, building_data)
			else
				close_gui(player)
			end
		end
	end
end

function gui_on_lua_shortcut(event)
	local player = game.get_player(event.player_index)

	-- open or close the periodic table
	if event.prototype_name == PERIODIC_TABLE_NAME then
		toggle_periodic_table_gui(player)
		return
	end

	-- open or close the molecule builder
	if event.prototype_name == MOLECULE_BUILDER_NAME then
		toggle_molecule_builder_gui(player, ATOMS_SUBGROUP_PREFIX_MATCH)
		return
	end
end
