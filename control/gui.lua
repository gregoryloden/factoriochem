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
	local frame = gui.relative.add({
		type = "frame",
		caption = "frame",
		name = "molecule-rotater",
		anchor = {
			gui = defines.relative_gui_type.assembling_machine_gui,
			position = defines.relative_gui_position.right
		},
	})
	frame.add({
		type = "label",
		caption = "label",
	})
end

function on_gui_closed(event)
	local entity = event.entity
	if not (entity and entity.valid) then return end

	local gui = game.get_player(event.player_index).gui
	close_gui(gui)
end

script.on_event(defines.events.on_gui_opened, on_gui_opened)
script.on_event(defines.events.on_gui_closed, on_gui_closed)
