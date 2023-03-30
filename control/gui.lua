-- Constants
local REACTION_TABLE_PREFIX = "reaction-"
local REACTION_DEMO_TABLE_PREFIX = "reaction-demo-"
local REACTION_TABLE_ELEMENT_NAME_MAP = {}
local REACTION_DEMO_TABLE_ELEMENT_NAME_MAP = {}
for _, name in ipairs(REACTION_ELEMENT_NAMES) do
	REACTION_TABLE_ELEMENT_NAME_MAP[REACTION_TABLE_PREFIX..name] = name
	REACTION_DEMO_TABLE_ELEMENT_NAME_MAP[REACTION_DEMO_TABLE_PREFIX..name] = name
end


-- Utilities
local function close_gui(gui)
	if gui.relative[MOLECULE_REACTION_NAME] then
		gui.relative[MOLECULE_REACTION_NAME].destroy()
		global.current_gui_entity = nil
	end
end

local function gui_add_recursive(gui, element_spec)
	local children_spec = element_spec.children
	element_spec.children = nil
	local element = gui.add(element_spec)
	if not children_spec then return end
	for _, child_spec in ipairs(children_spec) do gui_add_recursive(element, child_spec) end
end

local function update_reaction_table_sprites(reaction_table, chests, reaction_element_names)
	for _, element_name in ipairs(reaction_element_names) do
		local element = reaction_table[REACTION_TABLE_PREFIX..element_name]
		local item = next(chests[element_name].get_inventory(defines.inventory.chest).get_contents())
		if item then
			element.sprite = "item/"..item
		else
			element.sprite = nil
		end
	end
end


-- Event handling
local function on_gui_opened(event)
	local entity = event.entity
	if not (entity and entity.valid) then return end
	if entity.name ~= "molecule-rotater" then return end

	local gui = game.get_player(event.player_index).gui
	close_gui(gui)
	global.current_gui_entity = entity

	function build_molecule_spec(name)
		return {type = "sprite-button", name = name, style = "factoriochem-poc-big-slot-button"}
	end
	function build_reaction_table_spec(name_prefix, transition_spec)
		return {
			type = "table",
			name = name_prefix.."table",
			column_count = 3,
			children = {
				build_molecule_spec(name_prefix..BASE_NAME),
				{type = "empty-widget"},
				build_molecule_spec(name_prefix..RESULT_NAME),
				build_molecule_spec(name_prefix..CATALYST_NAME),
				transition_spec,
				build_molecule_spec(name_prefix..BONUS_NAME),
				build_molecule_spec(name_prefix..MODIFIER_NAME),
				{type = "empty-widget"},
				build_molecule_spec(name_prefix..REMAINDER_NAME),
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
				name = REACTION_TABLE_PREFIX.."frame",
				style = "inside_shallow_frame_with_padding",
				direction = "vertical",
				children = {
					{type = "label", caption = {"factoriochem-poc.reaction-table-header"}},
					build_reaction_table_spec(
						REACTION_TABLE_PREFIX,
						{type = "label", caption = {"factoriochem-poc.reaction-transition"}}),
				},
			}, {
				-- reaction demo frame
				type = "frame",
				style = "inside_shallow_frame_with_padding",
				direction = "vertical",
				children = {
					{type = "label", caption = {"factoriochem-poc.reaction-demo-table-header"}},
					build_reaction_table_spec(
						REACTION_DEMO_TABLE_PREFIX,
						{type = "label", caption = {"factoriochem-poc.reaction-transition"}}),
				},
			}},
		}},
	}
	gui_add_recursive(gui.relative, gui_spec)
	update_reaction_table_sprites(
		gui.relative[MOLECULE_REACTION_NAME].outer[REACTION_TABLE_PREFIX.."frame"][REACTION_TABLE_PREFIX.."table"],
		global.molecule_reaction_building_data[entity.unit_number].chests,
		REACTION_ELEMENT_NAMES)
end

local function on_gui_closed(event)
	local entity = event.entity
	if not (entity and entity.valid) then return end

	close_gui(game.get_player(event.player_index).gui)
end

local function on_gui_click(event)
	local element = event.element
	local player = game.get_player(event.player_index)

	local reaction_table_element = REACTION_TABLE_ELEMENT_NAME_MAP[element.name]
	if reaction_table_element then
		local player_inventory = player.get_main_inventory()
		local chests = global.molecule_reaction_building_data[global.current_gui_entity.unit_number].chests
		local chest_inventory = chests[reaction_table_element].get_inventory(defines.inventory.chest)
		local chest_contents = chest_inventory.get_contents()
		if next(chest_contents) then
			for name, count in pairs(chest_contents) do
				added = player_inventory.insert({name = name, count = count})
				if added > 0 then chest_inventory.remove({name = name, count = added}) end
			end
			update_reaction_table_sprites(element.parent, chests, {reaction_table_element})
		else
			--TODO
		end
		return
	end

	local reaction_demo_table_element = REACTION_DEMO_TABLE_ELEMENT_NAME_MAP[element.name]
	if reaction_demo_table_element then
		game.print("reaction demo table - "..reaction_demo_table_element)
		return
	end
end

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
script.on_event(defines.events.on_gui_click, on_gui_click)
