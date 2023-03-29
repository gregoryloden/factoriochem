local function on_built_entity(event)
	local entity = event.created_entity
	if not (entity and entity.valid) then return end
	if entity.name ~= "molecule-rotater" then return end

	entity.destructible = false
	entity.rotatable = false
	local building_data = {chests = {}, loaders = {}}
	function build_sub_entities(name, offset_x, offset_y)
		local is_output = offset_x > 0
		if entity.direction == defines.direction.south then
			offset_x, offset_y = -offset_x, -offset_y
		elseif entity.direction == defines.direction.east then
			offset_x, offset_y = -offset_y, offset_x
		elseif entity.direction == defines.direction.west then
			offset_x, offset_y = offset_y, -offset_x
		end
		local chest = entity.surface.create_entity({
			name = MOLECULE_REACTION_NAME.."-chest",
			position = {x = entity.position.x + offset_x, y = entity.position.y + offset_y},
			force = entity.force,
			create_build_effect_smoke = false,
		})
		chest.destructible = false
		building_data.chests[name] = chest

		if entity.direction == defines.direction.north or entity.direction == defines.direction.south then
			offset_x = offset_x * 2
		else
			offset_y = offset_y * 2
		end
		local loader_direction = defines.direction.east
		if offset_y < -1 then
			loader_direction = defines.direction.south
		elseif offset_x > 1 then
			loader_direction = defines.direction.west
		elseif offset_y > 1 then
			loader_direction = defines.direction.north
		end
		local loader = entity.surface.create_entity({
			name = MOLECULE_REACTION_NAME.."-loader",
			position = {x = entity.position.x + offset_x, y = entity.position.y + offset_y},
			force = entity.force,
			direction = loader_direction
		})
		if is_output then loader.rotate() end
		loader.destructible = false
		building_data.loaders[name] = loader
	end
	build_sub_entities(BASE_NAME, -1, -1)
	build_sub_entities(CATALYST_NAME, -1, 0)
	build_sub_entities(MODIFIER_NAME, -1, 1)
	build_sub_entities(RESULT_NAME, 1, -1)
	build_sub_entities(BONUS_NAME, 1, 0)
	build_sub_entities(REMAINDER_NAME, 1, 1)
	global.molecule_reaction_building_data[entity.unit_number] = building_data
end

local function on_mined_entity(event)
	local entity = event.entity
	if not (entity and entity.valid) then return end
	if entity.name ~= "molecule-rotater" then return end

	local data = global.molecule_reaction_building_data[entity.unit_number]
	global.molecule_reaction_building_data[entity.unit_number] = nil
	-- 30 slots should be enough to hold the contents of 6 loaders + 6 single-slot chests, but do 40 to be safe
	local transfer_inventory = game.create_inventory(40)
	for _, chest in pairs(data.chests) do chest.mine({inventory = transfer_inventory}) end
	for _, loader in pairs(data.loaders) do loader.mine({inventory = transfer_inventory}) end
	for name, count in pairs(transfer_inventory.get_contents()) do event.buffer.insert({name = name, count = count}) end
	transfer_inventory.destroy()
end

script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_robot_built_entity, on_built_entity)
script.on_event(defines.events.on_player_mined_entity, on_mined_entity)
script.on_event(defines.events.on_robot_mined_entity, on_mined_entity)

script.on_init(function() global.molecule_reaction_building_data = {} end)
