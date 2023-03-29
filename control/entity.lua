function on_built_entity(event)
	local entity = event.created_entity
	if not (entity and entity.valid) then return end
	if entity.name ~= "molecule-rotater" then return end

	entity.destructible = false
	entity.rotatable = false
	function build_chest(offset_x, offset_y)
		if entity.direction == defines.direction.south then
			offset_x, offset_y = -offset_x, -offset_y
		elseif entity.direction == defines.direction.east then
			offset_x, offset_y = -offset_y, offset_x
		elseif entity.direction == defines.direction.west then
			offset_x, offset_y = offset_y, -offset_x
		end
		local chest = entity.surface.create_entity({
			name = "molecule-manipulator-chest",
			position = {x = entity.position.x + offset_x, y = entity.position.y + offset_y},
			force = entity.force,
		})
		chest.destructible = false
		return chest
	end
	global.molecule_manipulator_building_chests[entity.unit_number] = {
		in_base = build_chest(-1, -1),
		in_catalyst = build_chest(-1, 0),
		in_modifier = build_chest(-1, 1),
		out_result = build_chest(1, -1),
		out_bonus = build_chest(1, 0),
		out_remainder = build_chest(1, 1),
	}
end

function on_mined_entity(event)
	local entity = event.entity
	if not (entity and entity.valid) then return end
	if entity.name ~= "molecule-rotater" then return end

	local chests = global.molecule_manipulator_building_chests[entity.unit_number]
	global.molecule_manipulator_building_chests[entity.unit_number] = nil
	for _, chest in pairs(chests) do
		local chest_inventory = chest.get_inventory(defines.inventory.chest)
		for name, count in pairs(chest_inventory.get_contents()) do
			event.buffer.insert({name = name, count = count})
		end
		chest_inventory.clear()
		chest.mine()
	end
end

script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_robot_built_entity, on_built_entity)
script.on_event(defines.events.on_player_mined_entity, on_mined_entity)
script.on_event(defines.events.on_robot_mined_entity, on_mined_entity)

script.on_init(function()
	global.molecule_manipulator_building_chests = {}
end)
