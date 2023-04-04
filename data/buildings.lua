-- Constants
local MOLECULE_REACTION_BUILDINGS_SUBGROUP_NAME = MOLECULE_REACTION_NAME.."-buildings"
local DIRECTION_ANIMATION_DATA = {
	north = function(shift_x, shift_y) return {width = 32, height = 56, x = 0, y = 0, shift = {shift_x, shift_y}} end,
	east = function(shift_x, shift_y) return {width = 56, height = 32, x = 32, y = 0, shift = {-shift_y, shift_x}} end,
	south = function(shift_x, shift_y) return {width = 32, height = 56, x = 56, y = 32, shift = {-shift_x, -shift_y}} end,
	west = function(shift_x, shift_y) return {width = 56, height = 32, x = 0, y = 56, shift = {shift_y, -shift_x}} end,
}
local HIDDEN_ENTITY_FLAGS = {"hidden", "not-deconstructable", "not-blueprintable", "player-creation"}
local RECIPE_ICON_MIPMAPS = 4


-- Molecule reaction buildings
data:extend({
	{
		type = "item-subgroup",
		name = MOLECULE_REACTION_BUILDINGS_SUBGROUP_NAME,
		group = "production",
		order = "e-a",
	},
	{
		type = "item",
		name = MOLECULE_REACTION_REACTANTS_NAME,
		localised_name = {"item-name."..MOLECULE_REACTION_REACTANTS_NAME},
		icon = GRAPHICS_ROOT..MOLECULE_REACTION_REACTANTS_NAME..".png",
		icon_size = ITEM_ICON_SIZE,
		icon_mipmaps = ITEM_ICON_MIPMAPS,
		stack_size = 1,
		flags = {"hidden"},
	},
})
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
	entity.fixed_recipe = name.."-reaction"
	entity.module_specification = nil
	entity.fast_replaceable_group = nil
	entity.selection_box[1][2] = entity.selection_box[1][2] - 1
	entity.selection_box[2][2] = entity.selection_box[2][2] + 1
	entity.collision_box[1][2] = entity.collision_box[1][2] - 1
	entity.collision_box[2][2] = entity.collision_box[2][2] + 1
	local building_animation = data.raw[definition.building_design[1]][definition.building_design[2]].animation
	entity.animation = {
		north = table.deepcopy(building_animation.north or building_animation),
		east = table.deepcopy(building_animation.east or building_animation),
		south = table.deepcopy(building_animation.south or building_animation),
		west = table.deepcopy(building_animation.west or building_animation),
	}
	for _, direction in ipairs({"north", "east", "south", "west"}) do
		layers = entity.animation[direction].layers
		for _, component in ipairs(MOLECULE_REACTION_COMPONENT_NAMES) do
			if definition.has_component[component] then
				local shift = MOLECULE_REACTION_COMPONENT_OFFSETS[component]
				local direction_data = DIRECTION_ANIMATION_DATA[direction](shift.x, shift.y * 1.375)
				local layer = {
					filename = GRAPHICS_ROOT.."building-overlays/"..component..".png",
					width = direction_data.width,
					height = direction_data.height,
					x = direction_data.x,
					y = direction_data.y,
					repeat_count = layers[1].frame_count,
					priority = "high",
					shift = direction_data.shift,
					hr_version = {
						filename = GRAPHICS_ROOT.."building-overlays/"..component.."-hr.png",
						width = direction_data.width * 2,
						height = direction_data.height * 2,
						x = direction_data.x * 2,
						y = direction_data.y * 2,
						repeat_count = layers[1].hr_version.frame_count,
						priority = "high",
						shift = direction_data.shift,
					},
				}
				table.insert(layers, layer)
			end
		end
	end

	local reaction_recipe = {
		type = "recipe",
		name = name.."-reaction",
		subgroup = MOLECULES_SUBGROUP_NAME,
		enabled = true,
		ingredients = {{MOLECULE_REACTION_REACTANTS_NAME, 1}},
		results = {},
		energy_required = 1,
		icon = GRAPHICS_ROOT.."recipes/"..name..".png",
		icon_size = ITEM_ICON_SIZE,
		icon_mipmaps = RECIPE_ICON_MIPMAPS,
		hidden = true,
	}

	local item = table.deepcopy(data.raw.item[definition.building_design[2]])
	item.name = name
	item.place_result = name
	item.subgroup = MOLECULE_REACTION_BUILDINGS_SUBGROUP_NAME
	item.order = definition.item_order
	item.icons = {
		{icon = item.icon, icon_size = item.icon_size, icon_mipmaps = item.icon_mipmaps},
		{
			icon = GRAPHICS_ROOT.."recipes/"..name..".png",
			icon_size = ITEM_ICON_SIZE,
			icon_mipmaps = RECIPE_ICON_MIPMAPS,
		},
	}
	item.icon = nil
	item.icon_size = nil
	item.icon_mipmaps = nil

	local recipe = {
		type = "recipe",
		name = name,
		enabled = true,
		ingredients = {},
		result = name,
	}

	data:extend({entity, reaction_recipe, item, recipe})
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
