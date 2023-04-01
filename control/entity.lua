-- Constants
local MOLECULE_REACTION_COMPONENT_OFFSETS = {
	[BASE_NAME] = {x = -1, y = 1},
	[CATALYST_NAME] = {x = 0, y = 1},
	[MODIFIER_NAME] = {x = 1, y = 1},
	[RESULT_NAME] = {x = -1, y = -1},
	[BONUS_NAME] = {x = 0, y = -1},
	[REMAINDER_NAME] = {x = 1, y = -1},
}


-- Event handling
local function on_built_entity(event)
	local entity = event.created_entity
	local building_definition = BUILDING_DEFINITIONS[entity.name]
	if not building_definition then return end

	entity.destructible = false
	entity.rotatable = false

	local building_data = {entity = entity, chests = {}, loaders = {}, reaction = {reactants = {}, products = {}}}
	function build_sub_entities(component, is_output)
		local default_offset = MOLECULE_REACTION_COMPONENT_OFFSETS[component]
		local offset_x, offset_y = default_offset.x, default_offset.y
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
		building_data.chests[component] = chest

		if entity.direction == defines.direction.north or entity.direction == defines.direction.south then
			offset_y = offset_y * 2
		else
			offset_x = offset_x * 2
		end
		local loader_direction = defines.direction.north
		if offset_y < -1 then
			loader_direction = defines.direction.south
		elseif offset_x < -1 then
			loader_direction = defines.direction.east
		elseif offset_x > 1 then
			loader_direction = defines.direction.west
		end
		local loader = entity.surface.create_entity({
			name = MOLECULE_REACTION_NAME.."-loader",
			position = {x = entity.position.x + offset_x, y = entity.position.y + offset_y},
			force = entity.force,
			direction = loader_direction
		})
		if is_output then loader.rotate() end
		loader.destructible = false
		building_data.loaders[component] = loader
	end
	for reactant, _ in pairs(building_definition.reactants) do build_sub_entities(reactant, false) end
	for product, _ in pairs(building_definition.products) do build_sub_entities(product, true) end
	global.molecule_reaction_building_data[entity.unit_number] = building_data
end

local function on_mined_entity(event)
	local entity = event.entity
	if not BUILDING_DEFINITIONS[entity.name] then return end

	local data = global.molecule_reaction_building_data[entity.unit_number]
	global.molecule_reaction_building_data[entity.unit_number] = nil
	-- 33 slots should be enough to hold the contents of 6 loaders + 6 single-slot chests + 3 reactants/products, but do 60
	--	to be safe
	local transfer_inventory = game.create_inventory(60)
	for _, chest in pairs(data.chests) do chest.mine({inventory = transfer_inventory}) end
	for _, loader in pairs(data.loaders) do loader.mine({inventory = transfer_inventory}) end
	for name, count in pairs(transfer_inventory.get_contents()) do event.buffer.insert({name = name, count = count}) end
	transfer_inventory.destroy()
	local reactants = data.reaction.reactants
	if next(reactants) then
		for _, reactant in pairs(reactants) do event.buffer.insert({name = reactant, count = 1}) end
	else
		for _, product in pairs(data.reaction.products) do event.buffer.insert({name = product, count = 1}) end
	end
	event.buffer.remove({name = MOLECULE_REACTION_REACTANTS_NAME, count = 2})
end


-- Updates
local function update_entity(data)
	-- make sure the next reaction is ready
	local entity = data.entity
	local machine_inputs = entity.get_inventory(defines.inventory.assembling_machine_input)
	local has_next_craft = next(machine_inputs.get_contents())
	if has_next_craft or entity.crafting_progress > 0 and entity.crafting_progress < 0.9 then return end

	local reaction = data.reaction
	local chests = data.chests

	-- the reaction has products which means that it needs resolving
	if next(reaction.products) then
		-- complete the reaction if needed
		for reactant_name, _ in pairs(reaction.reactants) do reaction[reactant_name] = nil end

		-- deliver all remaining products and stop if there are any products remaining
		local products_remaining = false
		for product_name, product in pairs(reaction.products) do
			local chest_inventory = chests[product_name].get_inventory(DEFINES_INVENTORY_CHEST)
			if next(chest_inventory.get_contents()) then
				products_remaining = true
			else
				chest_inventory.insert({name = product, count = 1})
				reaction.products[product_name] = nil
			end
		end
		if products_remaining then return end
	end

	-- any previous reaction has been resolved, check to see if any reactants have changed
	local building_definition = BUILDING_DEFINITIONS[entity.name]
	local changed = false
	for reactant_name, _ in pairs(building_definition.reactants) do
		local reactant = next(chests[reactant_name].get_inventory(DEFINES_INVENTORY_CHEST).get_contents())
		if reactant ~= reaction.reactants[reactant_name] then
			reaction.reactants[reactant_name] = reactant
			changed = true
		end
	end
	if not changed then return end

	-- reactants have changed, make sure we only have molecules
	-- a missing reactant counts as a molecule
	for _, reactant in pairs(reaction.reactants) do
		if game.item_prototypes[reactant].group.name ~= MOLECULES_GROUP_NAME then return end
	end

	-- we have a full set of molecule reactants, so now do building-specific handling to start a next reaction
	if building_definition.reaction(data) then
		machine_inputs.insert({name = MOLECULE_REACTION_REACTANTS_NAME, count = 1})
	end
end


-- Global event handling
function entity_on_init()
	global.molecule_reaction_building_data = {}
end

function entity_on_nth_tick(data)
	for entity_number, data in pairs(global.molecule_reaction_building_data) do update_entity(data) end
end

script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_robot_built_entity, on_built_entity)
script.on_event(defines.events.on_player_mined_entity, on_mined_entity)
script.on_event(defines.events.on_robot_mined_entity, on_mined_entity)
