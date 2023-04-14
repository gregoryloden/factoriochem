require("shared/constants")
require("shared/molecules")
require("shared/buildings")
require("control/entity")
require("control/gui")


-- Event handling
script.on_init(function()
	entity_on_init()
	gui_on_init()
end)
script.on_event(defines.events.on_tick, function(event_data)
	entity_on_tick(event_data)
	gui_on_tick(event_data)
end)


-- Player creation
function init_player(event)
	local player = game.players[event.player_index]
	player.insert({name = "light-armor", count = 1})
end

function init_player_in_freeplay(event)
	if remote.interfaces["freeplay"] then
		init_player(event)
	end
end

script.on_event(defines.events.on_player_created, init_player)
script.on_event(defines.events.on_cutscene_cancelled, init_player_in_freeplay)
