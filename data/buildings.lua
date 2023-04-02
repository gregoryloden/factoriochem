require("shared/buildings")


-- Constants
local MOLECULE_REACTION_BUILDINGS_SUBGROUP_NAME = MOLECULE_REACTION_NAME.."-buildings"
local HIDDEN_ENTITY_FLAGS = {"hidden", "not-deconstructable", "not-blueprintable", "player-creation"}


-- Molecule reaction buildings
data:extend({{
	type = "item-subgroup",
	name = MOLECULE_REACTION_BUILDINGS_SUBGROUP_NAME,
	group = "production",
	order = "e-a",
}})
for name, definition in pairs(BUILDING_DEFINITIONS) do
	local entity = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
	entity.name = name
	entity.minable.result = name
	entity.energy_source = {type = "void"}
	entity.crafting_speed = 1
	entity.fluid_boxes = {{
		-- can't rotate an assembling machine without a fluidbox, so stick one by the outputs area
		pipe_connections = {{position = {0, -3}}},
		production_type = "output",
		hide_connection_info = true,
	}}
	entity.fixed_recipe = MOLECULE_REACTION_REACTANTS_NAME
	entity.module_specification = nil
	entity.fast_replaceable_group = nil
	entity.selection_box[1][2] = entity.selection_box[1][2] - 1
	entity.selection_box[2][2] = entity.selection_box[2][2] + 1
	entity.collision_box[1][2] = entity.collision_box[1][2] - 1
	entity.collision_box[2][2] = entity.collision_box[2][2] + 1

	local item = table.deepcopy(data.raw.item[definition.building_design])
	item.name = name
	item.place_result = name
	item.subgroup = MOLECULE_REACTION_BUILDINGS_SUBGROUP_NAME
	item.order = definition.item_order

	local recipe = {
		type = "recipe",
		name = name,
		enabled = true,
		ingredients = {},
		result = name,
	}

	data:extend({entity, item, recipe})
end


-- Hidden chests and loaders for molecule reaction buildings
local reaction_chest = {
	type = "container",
	name = MOLECULE_REACTION_NAME.."-chest",
	flags = HIDDEN_ENTITY_FLAGS,
	collision_mask = {},
	inventory_size = 1,
	picture = {filename = "__core__/graphics/empty.png", size = 1},
	collision_box = {{-0.5, -0.5}, {0.5, 0.5}},
}

local reaction_loader = table.deepcopy(data.raw["loader-1x1"]["loader-1x1"])
reaction_loader.name = MOLECULE_REACTION_NAME.."-loader"
reaction_loader.structure.direction_in = {filename = "__core__/graphics/empty.png", size = 1}
reaction_loader.structure.direction_out = {filename = "__core__/graphics/empty.png", size = 1}
reaction_loader.flags = HIDDEN_ENTITY_FLAGS
reaction_loader.selection_box = nil
reaction_loader.collision_mask = {"transport-belt-layer"}

data:extend({reaction_chest, reaction_loader})
