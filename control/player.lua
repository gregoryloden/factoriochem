-- Constants
local MOLECULE_ABSORBER_TICKS_PER_UPDATE = settings.global["factoriochem-building-ticks-per-update"].value


-- Event handling
local function init_player(event)
	local player = game.players[event.player_index]
	player.insert({name = "light-armor", count = 1})
end

local function init_player_in_freeplay(event)
	if remote.interfaces["freeplay"] then
		init_player(event)
	end
end

script.on_event(defines.events.on_player_created, init_player)
script.on_event(defines.events.on_cutscene_cancelled, init_player_in_freeplay)


-- Global event handling
function player_on_tick(event)
	if math.fmod(event.tick, MOLECULE_ABSORBER_TICKS_PER_UPDATE) == 0 then
		for _, player in pairs(game.players) do
			local player_inventory = player.get_main_inventory()
			if not player_inventory or player_inventory.get_item_count(MOLECULE_ABSORBER_NAME) == 0 then
				goto continue_players
			end
			for name, count in pairs(player_inventory.get_contents()) do
				if GAME_ITEM_PROTOTYPES[name].group.name ~= MOLECULES_GROUP_NAME then goto continue_items end
				if name == MOLECULE_ABSORBER_NAME then goto continue_items end
				player_inventory.remove({name = name, count = count})
				::continue_items::
			end
			::continue_players::
		end
	end
end

function player_on_settings_changed(event)
	MOLECULE_ABSORBER_TICKS_PER_UPDATE = settings.global["factoriochem-building-ticks-per-update"].value
end
