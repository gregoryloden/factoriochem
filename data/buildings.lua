-- Molecule reaction buildings
local rotater_name = "molecule-rotater"
local rotater_entity = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
rotater_entity.name = rotater_name
rotater_entity.minable.result = rotater_name
rotater_entity.energy_source = {type = "void"}
rotater_entity.crafting_speed = 1
rotater_entity.fluid_boxes = {
	{
		pipe_connections = {{position = {-2, 0}}},
		production_type = "input",
		hide_connection_info = true,
	},
}
rotater_entity.fixed_recipe = "small-electric-pole"
rotater_entity.module_specification = nil
rotater_entity.fast_replaceable_group = nil

local rotater_item = table.deepcopy(data.raw.item["assembling-machine-3"])
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


-- Hidden chests for molecule reaction buildings
data:extend({
	{
		type = "container",
		name = MOLECULE_REACTION_NAME.."-chest",
		flags = {"hidden", "placeable-off-grid", "not-on-map", "not-deconstructable", "not-blueprintable"},
		collision_mask = {},
		inventory_size = 1,
		picture = {filename = "__core__/graphics/empty.png", size = 1},
	}
})
