require("shared/constants")
require("shared/molecules")
require("shared/buildings")
GAME_ITEM_PROTOTYPES = nil
GAME_ITEM_GROUP_PROTOTYPES = nil

require("control/entity")
require("control/gui")
require("control/player")


-- Event handling
script.on_init(function()
	entity_on_init()
	gui_on_init()
end)
script.on_event(defines.events.on_tick, function(event)
	if not GAME_ITEM_PROTOTYPES then
		GAME_ITEM_PROTOTYPES = game.item_prototypes
		GAME_ITEM_GROUP_PROTOTYPES = game.item_group_prototypes
	end
	entity_on_tick(event)
	gui_on_tick(event)
	player_on_tick(event)
end)
