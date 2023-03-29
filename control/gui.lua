local function close_gui(gui)
	if gui.relative[MOLECULE_REACTION_NAME] then gui.relative[MOLECULE_REACTION_NAME].destroy() end
end

local function gui_add_recursive(gui, element_spec)
	local children_spec = element_spec.children
	element_spec.children = nil
	local element = gui.add(element_spec)
	if not children_spec then return end
	for _, child_spec in ipairs(children_spec) do gui_add_recursive(element, child_spec) end
end

local function on_gui_opened(event)
	local entity = event.entity
	if not (entity and entity.valid) then return end
	if entity.name ~= "molecule-rotater" then return end

	local gui = game.get_player(event.player_index).gui
	close_gui(gui)

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
				name = "reaction-frame",
				style = "inside_shallow_frame_with_padding",
				children = {
					build_reaction_table_spec("reaction-", {type = "label", caption = " > Results > "}),
				},
			}, {
				-- reaction demo frame
				type = "frame",
				style = "inside_shallow_frame_with_padding",
				direction = "vertical",
				children = {
					{type = "label", caption = "Demo:"},
					build_reaction_table_spec(
						"reaction-demo-", {type = "label", caption = " > Results > "}),
				},
			}},
		}},
	}
	gui_add_recursive(gui.relative, gui_spec)

	local chests = global.molecule_reaction_building_chests[entity.unit_number]
	local reaction_table = gui.relative[MOLECULE_REACTION_NAME].outer["reaction-frame"]["reaction-table"]
	for _, reaction_name in ipairs(REACTION_ELEMENT_NAMES) do
		chest_contents = chests[reaction_name].get_inventory(defines.inventory.chest).get_contents()
		local item, _ = next(chest_contents, nil)
		if item then reaction_table["reaction-"..reaction_name].sprite = "item/"..item end
	end
end

local function on_gui_closed(event)
	local entity = event.entity
	if not (entity and entity.valid) then return end

	close_gui(game.get_player(event.player_index).gui)
end

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
