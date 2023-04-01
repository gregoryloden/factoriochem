-- Constants
local BUILDING_DEFINITIONS = require("shared/buildings")
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
	for _, reactant in ipairs(building_definition.reactants) do build_sub_entities(reactant, false) end
	for _, product in ipairs(building_definition.products) do build_sub_entities(product, true) end
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
local MOLECULE_REACTIONS = {
	["molecule-rotater"] = function(data)
		local base_inventory = data.chests["base"].get_inventory(defines.inventory.chest)
		local catalyst_inventory = data.chests["catalyst"].get_inventory(defines.inventory.chest)
		local modifier_inventory = data.chests["modifier"].get_inventory(defines.inventory.chest)
		local base = next(base_inventory.get_contents())
		local catalyst = next(catalyst_inventory.get_contents())
		local modifier = next(modifier_inventory.get_contents())
		if base and catalyst and modifier then
			local reaction = data.reaction
			reaction.reactants["base"] = base
			reaction.reactants["catalyst"] = catalyst
			reaction.reactants["modifier"] = modifier
			reaction.products["result"] = base
			reaction.products["bonus"] = catalyst
			reaction.products["remainder"] = modifier
			base_inventory.remove({name = base, count = 1})
			catalyst_inventory.remove({name = catalyst, count = 1})
			modifier_inventory.remove({name = modifier, count = 1})
			return true
		end
		return false
	end,
}

local function update_entity(data)
	-- make sure the next reaction is ready
	local entity = data.entity
	local machine_inputs = entity.get_inventory(defines.inventory.assembling_machine_input)
	local has_next_craft = next(machine_inputs.get_contents())
	if has_next_craft or entity.crafting_progress > 0 and entity.crafting_progress < 0.9 then return end
	local reaction = data.reaction

	-- complete the reaction if needed
	for reactant_name, _ in pairs(reaction.reactants) do reaction[reactant_name] = nil end

	-- if there are products remaining to deliver, do so
	local products_remaining = false
	for product_name, product in pairs(reaction.products) do
		local chest_inventory = data.chests[product_name].get_inventory(defines.inventory.chest)
		if next(chest_inventory.get_contents()) then
			products_remaining = true
		else
			chest_inventory.insert({name = product, count = 1})
			reaction.products[product_name] = nil
		end
	end
	if products_remaining then return end

	-- now do building-specific handling to start a next reaction
	if MOLECULE_REACTIONS[entity.name](data) then
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
