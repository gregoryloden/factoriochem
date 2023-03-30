-- Molecule reaction buildings
local rotater_name = "molecule-rotater"
local rotater_entity = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
rotater_entity.name = rotater_name
rotater_entity.minable.result = rotater_name
rotater_entity.energy_source = {type = "void"}
rotater_entity.crafting_speed = 1
rotater_entity.fluid_boxes = {
	{
		-- can't rotate an assembling machine without a fluidbox, so stick one by the outputs area
		pipe_connections = {{position = {0, -3}}},
		production_type = "output",
		hide_connection_info = true,
	},
}
rotater_entity.fixed_recipe = "small-electric-pole"
rotater_entity.module_specification = nil
rotater_entity.next_upgrade = nil
rotater_entity.fast_replaceable_group = nil
rotater_entity.selection_box[1][2] = rotater_entity.selection_box[1][2] - 1
rotater_entity.selection_box[2][2] = rotater_entity.selection_box[2][2] + 1
rotater_entity.collision_box[1][2] = rotater_entity.collision_box[1][2] - 1
rotater_entity.collision_box[2][2] = rotater_entity.collision_box[2][2] + 1

local rotater_item = table.deepcopy(data.raw.item["assembling-machine-2"])
rotater_item.name = rotater_name
rotater_item.place_result = rotater_name

local rotater_recipe = {
	type = "recipe",
	name = rotater_name,
	enabled = true,
	ingredients = {},
	result = rotater_name,
}

data:extend({rotater_entity, rotater_item, rotater_recipe})


-- Hidden chests and loaders for molecule reaction buildings
local hidden_entity_flags = {"hidden", "not-deconstructable", "not-blueprintable", "player-creation"}
data:extend({
	{
		type = "container",
		name = MOLECULE_REACTION_NAME.."-chest",
		flags = hidden_entity_flags,
		collision_mask = {},
		inventory_size = 1,
		picture = {filename = "__core__/graphics/empty.png", size = 1},
		collision_box = {{-0.5, -0.5}, {0.5, 0.5}},
	}
})
local reaction_loader = table.deepcopy(data.raw["loader-1x1"]["loader-1x1"])
reaction_loader.name = MOLECULE_REACTION_NAME.."-loader"
reaction_loader.structure.direction_in = {filename = "__core__/graphics/empty.png", size = 1}
reaction_loader.structure.direction_out = {filename = "__core__/graphics/empty.png", size = 1}
reaction_loader.flags = hidden_entity_flags
reaction_loader.selection_box = nil
reaction_loader.collision_mask = {"transport-belt-layer"}
data:extend({reaction_loader})
