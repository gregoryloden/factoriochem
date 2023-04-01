-- Constants
local REACTION_PREFIX = "reaction-"
local REACTION_DEMO_PREFIX = "reaction-demo-"
local REACTION_TABLE_COMPONENT_NAME_MAP = {}
local REACTION_DEMO_TABLE_COMPONENT_NAME_MAP = {}
for _, name in ipairs(MOLECULE_REACTION_COMPONENT_NAMES) do
	REACTION_TABLE_COMPONENT_NAME_MAP[REACTION_PREFIX..name] = name
	REACTION_DEMO_TABLE_COMPONENT_NAME_MAP[REACTION_DEMO_PREFIX..name] = name
end


-- Utilities
local function close_gui(player_index, gui)
	if gui.relative[MOLECULE_REACTION_NAME] then
		gui.relative[MOLECULE_REACTION_NAME].destroy()
		global.current_gui_entity[player_index] = nil
	end
end

local function gui_add_recursive(gui, element_spec)
	local children_spec = element_spec.children
	element_spec.children = nil
	local element = gui.add(element_spec)
	if not children_spec then return end
	for _, child_spec in ipairs(children_spec) do gui_add_recursive(element, child_spec) end
end

local function update_reaction_table_sprite(element, chest, product)
	local item = next(chest.get_inventory(DEFINES_INVENTORY_CHEST).get_contents())
	if item then
		element.sprite = "item/"..item
	elseif product then
		element.sprite = "item/"..product
	else
		element.sprite = nil
	end
end

local function update_all_reaction_table_sprites(gui, entity_number)
	local reaction_table = gui.relative[MOLECULE_REACTION_NAME].outer[REACTION_PREFIX.."frame"][REACTION_PREFIX.."table"]
	local building_data = global.molecule_reaction_building_data[entity_number]
	local building_definition = BUILDING_DEFINITIONS[building_data.entity.name]
	local chests = building_data.chests
	for _, reactant_name in ipairs(building_definition.reactants) do
		update_reaction_table_sprite(reaction_table[REACTION_PREFIX..reactant_name], chests[reactant_name])
	end
	local products = building_data.reaction.products
	for _, product_name in ipairs(building_definition.products) do
		update_reaction_table_sprite(
			reaction_table[REACTION_PREFIX..product_name], chests[product_name], products[product_name])
	end
end


-- Event handling
local function on_gui_opened(event)
	local entity = event.entity
	if not entity then return end
	local building_definition = BUILDING_DEFINITIONS[entity.name]
	if not building_definition then return end

	local gui = game.get_player(event.player_index).gui
	close_gui(event.player_index, gui)
	global.current_gui_entity[event.player_index] = entity.unit_number

	function build_molecule_spec(name_prefix, component_name, is_reactant)
		if is_reactant then
			if not building_definition.has_reactant[component_name] then return {type = "empty-widget"} end
		else
			if not building_definition.has_product[component_name] then return {type = "empty-widget"} end
		end
		local spec = {
			type = "sprite-button",
			name = name_prefix..component_name,
			style = "factoriochem-poc-big-slot-button"
		}
		if name_prefix == REACTION_PREFIX then
			spec.tooltip = {"factoriochem-poc.reaction-table-element-tooltip"}
		elseif is_reactant and name_prefix == REACTION_DEMO_PREFIX then
			spec.tooltip = {"factoriochem-poc.reaction-demo-table-element-tooltip"}
			spec.type = "choose-elem-button"
			spec.elem_type = "item"
			local filters = {}
			for _, subgroup in ipairs(game.item_group_prototypes[MOLECULES_GROUP_NAME].subgroups) do
				table.insert(filters, {filter = "subgroup", subgroup = subgroup.name})
			end
			spec.elem_filters = filters
		end
		return spec
	end
	function build_reaction_table_spec(name_prefix)
		return {
			type = "table",
			name = name_prefix.."table",
			column_count = 3,
			children = {
				{type = "empty-widget"},
				{type = "label", caption = {"factoriochem-poc."..name_prefix.."table-header"}},
				{type = "empty-widget"},
				build_molecule_spec(name_prefix, BASE_NAME, true),
				{type = "empty-widget"},
				build_molecule_spec(name_prefix, RESULT_NAME),
				build_molecule_spec(name_prefix, CATALYST_NAME, true),
				{type = "label", caption = {"factoriochem-poc.reaction-transition"}},
				build_molecule_spec(name_prefix, BONUS_NAME),
				build_molecule_spec(name_prefix, MODIFIER_NAME, true),
				{type = "empty-widget"},
				build_molecule_spec(name_prefix, REMAINDER_NAME),
			},
		}

	end
	local gui_spec = {
		-- outer
		type = "frame",
		caption = {"factoriochem-poc.reaction"},
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
	update_all_reaction_table_sprites(gui, entity.unit_number)
end

local function on_gui_closed(event)
	close_gui(event.player_index, game.get_player(event.player_index).gui)
end

local function on_gui_click(event)
	local element = event.element
	local player = game.get_player(event.player_index)

	local reaction_table_component = REACTION_TABLE_COMPONENT_NAME_MAP[element.name]
	if reaction_table_component then
		local player_inventory = player.get_main_inventory()
		local chests = global.molecule_reaction_building_data[global.current_gui_entity[event.player_index]].chests
		local chest = chests[reaction_table_component]
		local chest_inventory = chest.get_inventory(DEFINES_INVENTORY_CHEST)
		local chest_contents = chest_inventory.get_contents()
		if next(chest_contents) then
			for name, count in pairs(chest_contents) do
				added = player_inventory.insert({name = name, count = count})
				if added > 0 then chest_inventory.remove({name = name, count = added}) end
			end
			update_reaction_table_sprite(element, chest)
		elseif player.cursor_stack then
			chest_inventory.find_empty_stack().transfer_stack(player.cursor_stack)
			update_reaction_table_sprite(element, chest)
		end
		return
	end

	local reaction_demo_table_component = REACTION_DEMO_TABLE_COMPONENT_NAME_MAP[element.name]
	if reaction_demo_table_component then
		return
	end
end


-- Global event handling
function gui_on_init()
	global.current_gui_entity = {}
end

function gui_on_nth_tick(data)
	for player_index, entity_number in pairs(global.current_gui_entity) do
		update_all_reaction_table_sprites(game.get_player(player_index).gui, entity_number)
	end
end

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
script.on_event(defines.events.on_gui_click, on_gui_click)
