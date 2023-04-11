-- Constants
local REACTION_CACHE = {}
-- give each building type a base cache, buildings will add to it based on their own selectors and reactants
for name, definition in pairs(BUILDING_DEFINITIONS) do REACTION_CACHE[name] = {} end
local LOGISTIC_WIRE_TYPES = {defines.wire_type.red, defines.wire_type.green}
local DETECTOR_CACHE = {}
local DETECTOR_TARGET_CACHE = {}


-- Setup
local function build_update_group_building_data(ticks_per_update)
	local update_groups = {}
	for update_group = 0, ticks_per_update - 1 do update_groups[update_group] = {n = 0} end
	return {update_groups = update_groups, ticks_per_update = ticks_per_update}
end


-- Shared global entity utilities
function entity_assign_cache(building_data, building_definition)
	local cache = REACTION_CACHE[building_data.entity.name]
	for reactant_name, _ in pairs(building_definition.selectors) do
		local selector_val = building_data.reaction.selectors[reactant_name] or ""
		local new_cache = cache[selector_val]
		if not new_cache then
			new_cache = {}
			cache[selector_val] = new_cache
		end
		cache = new_cache
	end
	building_data.reaction.cache = cache
end


-- Building setup
local function add_building_data(entity_number, building_datas, building_data)
	building_datas[entity_number] = building_data
	local update_group = 0
	local update_entities_n = building_datas.update_groups[0].n
	for i = 1, building_datas.ticks_per_update - 1 do
		local new_update_entities_n = building_datas.update_groups[i].n
		if new_update_entities_n < update_entities_n then
			update_group = i
			update_entities_n = new_update_entities_n
		end
	end
	local update_entities = building_datas.update_groups[update_group]
	update_entities[entity_number] = building_data
	update_entities.n = update_entities_n + 1
	building_data.update_group = update_group
end

local function build_molecule_reaction_building(entity, building_definition)
	entity.destructible = false
	entity.rotatable = false

	local building_data = {
		entity = entity,
		chests = {},
		chest_inventories = {},
		loaders = {},
		reaction = {reactants = {}, products = {}, selectors = {}},
	}
	function build_sub_entities(component, is_output)
		local default_offset = MOLECULE_REACTION_COMPONENT_OFFSETS[component]
		local offset_x, offset_y = default_offset.x, default_offset.y
		if entity.direction == defines.direction.east then
			offset_x, offset_y = -offset_y, offset_x
		elseif entity.direction == defines.direction.south then
			offset_x, offset_y = -offset_x, -offset_y
		elseif entity.direction == defines.direction.west then
			offset_x, offset_y = offset_y, -offset_x
		end
		local chest = entity.surface.create_entity({
			name = MOLECULE_REACTION_CHEST_NAME,
			position = {x = entity.position.x + offset_x, y = entity.position.y + offset_y},
			force = entity.force,
			create_build_effect_smoke = false,
		})
		chest.destructible = false
		building_data.chests[component] = chest
		building_data.chest_inventories[component] = chest.get_inventory(defines.inventory.chest)

		if entity.direction == defines.direction.north or entity.direction == defines.direction.south then
			offset_y = offset_y * 2
		else
			offset_x = offset_x * 2
		end
		local loader_direction = defines.direction.north
		if offset_x < -1 then
			loader_direction = defines.direction.east
		elseif offset_y < -1 then
			loader_direction = defines.direction.south
		elseif offset_x > 1 then
			loader_direction = defines.direction.west
		end
		local loader = entity.surface.create_entity({
			name = MOLECULE_REACTION_LOADER_NAME,
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

	local settings = entity.surface
		.find_entities_filtered({ghost_name = MOLECULE_REACTION_SETTINGS_NAME, position = entity.position})
		[1]
	if settings then
		_, settings = settings.silent_revive()
		local settings_behavior = settings.get_control_behavior()
		for i, reactant_name in ipairs(MOLECULE_REACTION_REACTANT_NAMES) do
			if not building_definition.selectors[reactant_name] then goto continue end
			local signal = settings_behavior.get_signal(i).signal
			if signal then building_data.reaction.selectors[reactant_name] = signal.name end
			::continue::
		end
	else
		settings = entity.surface.create_entity({
			name = MOLECULE_REACTION_SETTINGS_NAME,
			position = entity.position,
			direction = entity.direction,
			force = entity.force,
			create_build_effect_smoke = false,
		})
	end
	settings.destructible = false
	building_data.settings = settings

	entity_assign_cache(building_data, building_definition)
	add_building_data(entity.unit_number, global.molecule_reaction_building_data, building_data)
end

local function build_molecule_detector(entity)
	entity.destructible = false
	entity.rotatable = false

	local output = entity.surface.create_entity({
		name = MOLECULE_DETECTOR_OUTPUT_NAME,
		position = entity.position,
		direction = entity.direction,
		force = entity.force,
		create_build_effect_smoke = false,
	})
	output.destructible = false
	output.rotatable = false

	add_building_data(entity.unit_number, global.molecule_detector_data, {entity = entity, output = output, targets = {}})
end


-- Building teardown
local function remove_building_data(entity_number, building_datas)
	local building_data = building_datas[entity_number]
	building_datas[entity_number] = nil
	local update_entities = building_datas.update_groups[building_data.update_group]
	update_entities[entity_number] = nil
	update_entities.n = update_entities.n - 1
	return building_data
end

local function delete_molecule_reaction_building(entity, event_buffer)
	local building_data = remove_building_data(entity.unit_number, global.molecule_reaction_building_data)
	building_data.settings.mine()
	-- 33 slots should be enough to hold the contents of 6 loaders + 6 single-slot chests + 3 reactants/products, but do 60
	--	to be safe
	local transfer_inventory = game.create_inventory(60)
	for _, chest in pairs(building_data.chests) do chest.mine({inventory = transfer_inventory}) end
	for _, loader in pairs(building_data.loaders) do loader.mine({inventory = transfer_inventory}) end
	for name, count in pairs(transfer_inventory.get_contents()) do event_buffer.insert({name = name, count = count}) end
	transfer_inventory.destroy()
	-- the presence of products indicates an unresolved reaction, which means we have items to return to the player
	if next(building_data.reaction.products) then
		-- the presence of reactants indicates that the reaction is not complete
		if next(building_data.reaction.reactants) then
			for _, reactant in pairs(building_data.reaction.reactants) do
				event_buffer.insert({name = reactant, count = 1})
			end
		else
			for _, product in pairs(building_data.reaction.products) do
				event_buffer.insert({name = product, count = 1})
			end
		end
	end
	event_buffer.remove({name = MOLECULE_REACTION_REACTANTS_NAME, count = 2})
end

local function delete_molecule_detector(entity)
	local building_data = remove_building_data(entity.unit_number, global.molecule_detector_data)
	building_data.output.mine()
end


-- Updates
local function update_buildings(building_datas, tick, update_building)
	local update_entities = building_datas.update_groups[math.fmod(tick, building_datas.ticks_per_update)]
	-- temporarily remove the count so that we don't iterate it
	local update_entities_n = update_entities.n
	update_entities.n = nil
	for _, building_data in pairs(update_entities) do update_building(building_data) end
	update_entities.n = update_entities_n
end

local function start_reaction(reaction, chest_inventories, machine_inputs)
	for reactant_name, reactant in pairs(reaction.reactants) do
		chest_inventories[reactant_name].remove({name = reactant, count = 1})
	end
	machine_inputs.insert({name = MOLECULE_REACTION_REACTANTS_NAME, count = 1})
end

local function update_reaction_building(building_data)
	-- make sure the next reaction is ready
	local entity = building_data.entity
	local machine_inputs = entity.get_inventory(defines.inventory.assembling_machine_input)
	local has_next_craft = next(machine_inputs.get_contents())
	if has_next_craft or entity.crafting_progress > 0 and entity.crafting_progress < 0.9 then return end

	local reaction = building_data.reaction
	local chest_inventories = building_data.chest_inventories

	-- the reaction has products which means that it needs resolving
	if next(reaction.products) then
		-- complete the reaction if needed
		for reactant_name, _ in pairs(reaction.reactants) do reaction[reactant_name] = nil end

		-- deliver all remaining products and stop if there are any products remaining
		local products_remaining = false
		for product_name, product in pairs(reaction.products) do
			local chest_inventory = chest_inventories[product_name]
			if next(chest_inventory.get_contents()) then
				products_remaining = true
			else
				chest_inventory.insert({name = product, count = 1})
				reaction.products[product_name] = nil
			end
		end
		if products_remaining then return end
	end

	-- any previous reaction has been resolved, check to see if our current reactant set is cached
	local cache = reaction.cache
	local building_definition = BUILDING_DEFINITIONS[entity.name]
	for _, reactant_name in ipairs(building_definition.reactants) do
		local reactant = next(chest_inventories[reactant_name].get_contents())
		reaction.reactants[reactant_name] = reactant
		if not reactant then reactant = "" end
		local new_cache = cache[reactant]
		if not new_cache then
			new_cache = {}
			cache[reactant] = new_cache
		end
		cache = new_cache
	end
	if cache.products then
		for product_name, product in pairs(cache.products) do reaction.products[product_name] = product end
		start_reaction(reaction, chest_inventories, machine_inputs)
		return
	elseif cache.invalid then
		return
	end

	-- our current reaction is not cached, make sure we only have molecules
	-- a missing reactant counts as a molecule
	for _, reactant in pairs(reaction.reactants) do
		if game.item_prototypes[reactant].group.name ~= MOLECULES_GROUP_NAME then
			cache.invalid = true
			return
		end
	end

	-- our reactants are exclusively molecules, so now do building-specific handling to generate a next reaction
	if building_definition.reaction(reaction) then
		-- the reaction was valid, start it and cache it
		start_reaction(reaction, chest_inventories, machine_inputs)
		cache.products = {}
		for product_name, product in pairs(reaction.products) do cache.products[product_name] = product end
	else
		-- the reaction was not valid, cache that fact
		cache.invalid = true
	end
end

local function update_detector(detector_data)
	-- collect all target signals
	local input = detector_data.entity.get_control_behavior()
	local targets = detector_data.targets
	local target_i = 1
	for _, parameter in ipairs(input.parameters) do
		local signal = parameter.signal.name
		if not signal then goto continue end
		local cache = DETECTOR_TARGET_CACHE[signal]
		if not cache then
			cache = {}
			DETECTOR_TARGET_CACHE[signal] = cache
			local item_prototype = game.item_prototypes[signal]
			if item_prototype and item_prototype.subgroup.name == TARGET_SELECTOR_SUBGROUP then
				cache.height, cache.width, cache.y, cache.x = parse_target(signal)
				cache.name = signal
			end
		end
		if not cache.name then goto continue end
		targets[target_i] = cache
		target_i = target_i + 1
		::continue::
	end
	while targets[target_i] do
		targets[target_i] = nil
		target_i = target_i + 1
	end

	-- go through all input signals compared against each target, and output the corresponding signals
	local output = detector_data.output.get_control_behavior()
	local output_signal_i = 1
	for _, wire_type in ipairs(LOGISTIC_WIRE_TYPES) do
		local circuit_network = input.get_circuit_network(wire_type)
		if not circuit_network then goto continue_wire_types end
		local signals = circuit_network.signals
		if not signals then goto continue_wire_types end
		for _, signal in ipairs(signals) do
			signal = signal.signal.name
			local cache = DETECTOR_CACHE[signal]
			if not cache then
				cache = {}
				DETECTOR_CACHE[signal] = cache
				local item_prototype = game.item_prototypes[signal]
				if item_prototype and item_prototype.group.name == MOLECULES_GROUP_NAME then
					cache.shape, cache.height, cache.width = parse_molecule(signal)
				end
			end
			if not cache.shape then goto continue_signals end
			for _, target in ipairs(targets) do
				local output_cache = cache[target.name]
				if not output_cache then
					output_cache = {}
					cache[target.name] = output_cache
					if cache.height ~= target.height or cache.width ~= target.width then
						goto continue_targets
					end
					local atom = cache.shape[target.y][target.x]
					if not atom then goto continue_targets end
					local atom_signal_id = {type = "item", name = ATOM_ITEM_PREFIX..atom.symbol}
					local atomic_number_signal_id = {type = "virtual", name = "signal-A"}
					local atomic_number = ALL_ATOMS[atom.symbol].number
					table.insert(output_cache, {signal = atom_signal_id, count = 1})
					table.insert(output_cache, {signal = atomic_number_signal_id, count = atomic_number})
				end
				for _, signal in ipairs(output_cache) do
					output.set_signal(output_signal_i, signal)
					output_signal_i = output_signal_i + 1
				end
				::continue_targets::
			end
			::continue_signals::
		end
		::continue_wire_types::
	end
	while output.get_signal(output_signal_i).signal do
		output.set_signal(output_signal_i, nil)
		output_signal_i = output_signal_i + 1
	end
end

local function paste_molecule_reaction_building(source, destination)
	local source_building_data = global.molecule_reaction_building_data[source.unit_number]
	local destination_building_data = global.molecule_reaction_building_data[destination.unit_number]
	destination_building_data.settings.get_control_behavior().parameters =
		source_building_data.settings.get_control_behavior().parameters
	for _, reactant_name in ipairs(MOLECULE_REACTION_REACTANT_NAMES) do
		destination_building_data.reaction.selectors[reactant_name] =
			source_building_data.reaction.selectors[reactant_name]
	end
	entity_assign_cache(destination_building_data, BUILDING_DEFINITIONS[destination.name])
end


-- Event handling
local function on_built_entity(event)
	local entity = event.created_entity
	local building_definition = BUILDING_DEFINITIONS[entity.name]
	if building_definition then
		build_molecule_reaction_building(entity, building_definition)
	elseif entity.name == MOLECULE_DETECTOR_NAME then
		build_molecule_detector(entity)
	end
end

local function on_mined_entity(event)
	local entity = event.entity
	if BUILDING_DEFINITIONS[entity.name] then
		delete_molecule_reaction_building(entity, event.buffer)
	elseif entity.name == MOLECULE_DETECTOR_NAME then
		delete_molecule_detector(entity)
	end
end

local function on_entity_settings_pasted(event)
	local source = event.source
	local destination = event.destination
	if source.name ~= destination.name then return end
	if BUILDING_DEFINITIONS[source.name] then
		paste_molecule_reaction_building(source, destination)
	end
end


-- Global event handling
function entity_on_init()
	global.molecule_reaction_building_data = build_update_group_building_data(10)
	global.molecule_detector_data = build_update_group_building_data(10)
end

function entity_on_tick(event_data)
	local tick = event_data.tick
	update_buildings(global.molecule_reaction_building_data, tick, update_reaction_building)
	update_buildings(global.molecule_detector_data, tick, update_detector)
end

script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_robot_built_entity, on_built_entity)
script.on_event(defines.events.on_player_mined_entity, on_mined_entity)
script.on_event(defines.events.on_robot_mined_entity, on_mined_entity)
script.on_event(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)
