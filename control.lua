require("shared/constants")
require("shared/molecules")
require("shared/buildings")
GAME_ITEM_PROTOTYPES = nil
GAME_ITEM_GROUP_PROTOTYPES = nil

require("control/molecules")
require("control/entity")
require("control/gui")
require("control/player")


-- Event handling
script.on_init(function()
	entity_on_init()
	gui_on_init()
end)
script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
	entity_on_settings_changed(event)
	player_on_settings_changed(event)
end)
script.on_event(defines.events.on_lua_shortcut, function(event)
	gui_on_lua_shortcut(event)
end)
local function on_tick(event)
	entity_on_tick(event)
	gui_on_tick(event)
	player_on_tick(event)
end
local function on_first_tick(event)
	-- intialization
	GAME_ITEM_PROTOTYPES = game.item_prototypes
	GAME_ITEM_GROUP_PROTOTYPES = game.item_group_prototypes
	molecules_on_first_tick()
	entity_on_first_tick()
	gui_on_first_tick()

	-- defer to the regular tick handler and re-register the event listener with it
	on_tick(event)
	script.on_event(defines.events.on_tick, on_tick)
end
script.on_event(defines.events.on_tick, on_first_tick)
