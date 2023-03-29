function close_gui(gui)
	if gui.relative["molecule-rotater"] then
		gui.relative["molecule-rotater"].destroy()
	end
end

function on_gui_opened(event)
	local entity = event.entity
	if not (entity and entity.valid) then return end
	if entity.name ~= "molecule-rotater" then return end

	local gui = game.get_player(event.player_index).gui
	close_gui(gui)
	local outer = gui.relative.add({
		type = "frame",
		caption = {"factoriochem-poc.reaction"},
		name = "molecule-rotater",
		anchor = {
			gui = defines.relative_gui_type.assembling_machine_gui,
			position = defines.relative_gui_position.right
		},
	})
	local inner = outer.add({type = "flow", style = "inset_frame_container_vertical_flow", direction = "vertical"})
	local reaction_frame = inner.add({type = "frame", style = "b_inner_frame"})
	local reaction_table = reaction_frame.add({type = "table", name = "reaction-table", column_count = 3})
	for _, name in ipairs({"base", "", "result", "catalyst", "description", "bonus", "modifier", "", "remainder"}) do
		if name == "" then
			reaction_table.add({type = "empty-widget"})
		elseif name == "description" then
			reaction_table.add({
				type = "label",
				caption = " > Results > ",
			})
		else
			reaction_table.add({
				type = "sprite-button",
				name = "reaction-"..name,
				style = "factoriochem-poc-big-slot-button",
				sprite = "item/O1-H|1H",
			})
		end
	end
	local reaction_demo_frame = inner.add({type = "frame", style = "b_inner_frame", direction = "vertical"})
	reaction_demo_frame.add({type = "label", caption = "Demo:"})
	local reaction_demo_table = reaction_demo_frame.add({type = "table", name = "reaction-demo-table", column_count = 3})
	for _, name in ipairs({"base", "", "result", "catalyst", "description", "bonus", "modifier", "", "remainder"}) do
		if name == "" then
			reaction_demo_table.add({type = "empty-widget"})
		elseif name == "description" then
			reaction_demo_table.add({
				type = "label",
				caption = " > Results > ",
			})
		else
			reaction_demo_table.add({
				type = "sprite-button",
				name = "reaction-demo-"..name,
				style = "factoriochem-poc-big-slot-button",
				sprite = "item/O1-H|1H",
			})
		end
	end
end

function on_gui_closed(event)
	local entity = event.entity
	if not (entity and entity.valid) then return end

	local gui = game.get_player(event.player_index).gui
	close_gui(gui)
end

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
