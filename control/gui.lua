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
	local inner = outer.add({
		type = "frame",
		style = "b_inner_frame",
	})
	local reaction_table = inner.add({
		type = "table",
		name = "reaction-table",
		column_count = 3,
	})
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
				name = "molecule-"..name,
				sprite = "item/O1-H|1H",
				style = "factoriochem-poc-big-slot-button",
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
