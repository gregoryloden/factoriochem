require("constants")
BUILDING_DEFINITIONS = require("shared/buildings")
DEFINES_INVENTORY_CHEST = defines.inventory.chest

require("control/entity")
require("control/gui")

script.on_init(function()
	entity_on_init()
	gui_on_init()
end)
script.on_nth_tick(10, function(data)
	entity_on_nth_tick(data)
	gui_on_nth_tick(data)
end)
