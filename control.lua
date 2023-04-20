require("shared/constants")
require("shared/molecules")
require("shared/buildings")
require("control/entity")
require("control/gui")
require("control/player")


-- Event handling
script.on_init(function()
	entity_on_init()
	gui_on_init()
end)
script.on_event(defines.events.on_tick, function(event)
	entity_on_tick(event)
	gui_on_tick(event)
	player_on_tick(event)
end)
