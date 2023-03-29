function close_gui(gui)
	if gui.relative["molecule-rotater"] then
		gui.relative["molecule-rotater"].destroy()
	end
end

function gui_add_recursive(gui, element_spec)
	local children_spec = element_spec.children
	element_spec.children = nil
	local element = gui.add(element_spec)
	if not children_spec then return end
	for _, child_spec in ipairs(children_spec) do gui_add_recursive(element, child_spec) end
end

function on_gui_opened(event)
	local entity = event.entity
	if not (entity and entity.valid) then return end
	if entity.name ~= "molecule-rotater" then return end

	local gui = game.get_player(event.player_index).gui
	close_gui(gui)

	function build_molecule_spec(name)
		return {
			type = "sprite-button",
			name = name,
			style = "factoriochem-poc-big-slot-button",
			sprite = "item/O1-H|1H",
		}
	end
	function build_reaction_table_spec(name_prefix, transition_spec)
		return {
			type = "table",
			name = name_prefix.."table",
			column_count = 3,
			children = {
				build_molecule_spec(name_prefix.."base"),
				{type = "empty-widget"},
				build_molecule_spec(name_prefix.."result"),
				build_molecule_spec(name_prefix.."catalyst"),
				transition_spec,
				build_molecule_spec(name_prefix.."bonus"),
				build_molecule_spec(name_prefix.."modifier"),
				{type = "empty-widget"},
				build_molecule_spec(name_prefix.."remainder"),
			},
		}

	end
	local gui_spec = {
		-- outer
		type = "frame",
		caption = {"factoriochem-poc.reaction"},
		name = "molecule-rotater",
		anchor = {
			gui = defines.relative_gui_type.assembling_machine_gui,
			position = defines.relative_gui_position.right
		},
		children = {{
			-- inner
			type = "flow",
			style = "inset_frame_container_vertical_flow",
			direction = "vertical",
			children = {{
				-- reaction frame
				type = "frame",
				style = "b_inner_frame",
				children = {
					build_reaction_table_spec("reaction-", {type = "label", caption = " > Results > "}),
				},
			}, {
				-- reaction demo frame
				type = "frame",
				style = "b_inner_frame",
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
end

function on_gui_closed(event)
	local entity = event.entity
	if not (entity and entity.valid) then return end

	local gui = game.get_player(event.player_index).gui
	close_gui(gui)
end

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
