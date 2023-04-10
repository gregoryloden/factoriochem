-- Constants
local MOLECULE_REACTION_BUILDINGS_SUBGROUP_NAME = MOLECULE_REACTION_NAME.."-buildings"
local DIRECTION_ANIMATION_DATA = {
	north = function(shift_x, shift_y) return {width = 32, height = 56, x = 0, y = 0, shift = {shift_x, shift_y}} end,
	east = function(shift_x, shift_y) return {width = 56, height = 32, x = 32, y = 0, shift = {-shift_y, shift_x}} end,
	south = function(shift_x, shift_y) return {width = 32, height = 56, x = 56, y = 32, shift = {-shift_x, -shift_y}} end,
	west = function(shift_x, shift_y) return {width = 56, height = 32, x = 0, y = 56, shift = {shift_y, -shift_x}} end,
}
local HIDDEN_ENTITY_FLAGS = {"hidden", "not-deconstructable", "not-blueprintable", "player-creation"}
local BUILDING_OVERLAY_ICON_SIZE = 64
local MOLECULIFIER_NAME = "moleculifier"
local MOLECULE_DETECTOR_NAME = "molecule-detector"
local BASE_BUILDING_PROTOTYPE = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
BASE_BUILDING_PROTOTYPE.energy_source = {type = "void"}
BASE_BUILDING_PROTOTYPE.crafting_speed = 1
BASE_BUILDING_PROTOTYPE.fluid_boxes = nil
BASE_BUILDING_PROTOTYPE.module_specification = nil
BASE_BUILDING_PROTOTYPE.fast_replaceable_group = nil
BASE_BUILDING_PROTOTYPE.selection_box[1][2] = BASE_BUILDING_PROTOTYPE.selection_box[1][2] - 1
BASE_BUILDING_PROTOTYPE.selection_box[2][2] = BASE_BUILDING_PROTOTYPE.selection_box[2][2] + 1
BASE_BUILDING_PROTOTYPE.collision_box[1][2] = BASE_BUILDING_PROTOTYPE.collision_box[1][2] - 1
BASE_BUILDING_PROTOTYPE.collision_box[2][2] = BASE_BUILDING_PROTOTYPE.collision_box[2][2] + 1


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
		icon_mipmaps = MOLECULE_ICON_MIPMAPS,
		stack_size = 1,
		flags = {"hidden"},
	},
})
for name, definition in pairs(BUILDING_DEFINITIONS) do
	local entity = table.deepcopy(BASE_BUILDING_PROTOTYPE)
	entity.name = name
	entity.minable.result = name
	entity.fixed_recipe = name.."-reaction"
	local building_design = data.raw[definition.building_design[1]][definition.building_design[2]]
	local building_animation = building_design.animation
	entity.animation = {
		north = table.deepcopy(building_animation.north or building_animation),
		east = table.deepcopy(building_animation.east or building_animation),
		south = table.deepcopy(building_animation.south or building_animation),
		west = table.deepcopy(building_animation.west or building_animation),
	}
	for _, direction in ipairs({"north", "east", "south", "west"}) do
		layers = entity.animation[direction].layers
		for _, component in ipairs(MOLECULE_REACTION_COMPONENT_NAMES) do
			if not definition.has_component[component] then goto continue end
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
			::continue::
		end
	end
	entity.working_sound = building_design.working_sound

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
		icon_mipmaps = ITEM_ICON_MIPMAPS,
		hidden = true,
	}

	local item_design = data.raw.item[definition.building_design[2]]
	local item = {
		type = "item",
		name = name,
		place_result = name,
		subgroup = MOLECULE_REACTION_BUILDINGS_SUBGROUP_NAME,
		order = definition.item_order,
		icons = {
			{icon = item_design.icon, icon_size = item_design.icon_size, icon_mipmaps = item_design.icon_mipmaps},
			{
				icon = GRAPHICS_ROOT.."icon-overlays/"..name..".png",
				icon_size = ITEM_ICON_SIZE,
				icon_mipmaps = ITEM_ICON_MIPMAPS,
			},
		},
		stack_size = 50,
	}

	local recipe = {
		type = "recipe",
		name = name,
		enabled = true,
		ingredients = {},
		result = name,
	}

	data:extend({entity, reaction_recipe, item, recipe})
end


-- Hidden chests, loaders, and constant combinators for molecule reaction buildings
local reaction_chest = {
	type = "container",
	name = MOLECULE_REACTION_CHEST_NAME,
	flags = HIDDEN_ENTITY_FLAGS,
	collision_mask = {},
	inventory_size = 1,
	picture = {filename = "__core__/graphics/empty.png", size = 1},
	collision_box = {{-0.5, -0.5}, {0.5, 0.5}},
}

local reaction_loader = table.deepcopy(data.raw["loader-1x1"]["loader-1x1"])
reaction_loader.name = MOLECULE_REACTION_LOADER_NAME
reaction_loader.structure.direction_in = {filename = "__core__/graphics/empty.png", size = 1}
reaction_loader.structure.direction_out = {filename = "__core__/graphics/empty.png", size = 1}
reaction_loader.flags = HIDDEN_ENTITY_FLAGS
reaction_loader.selection_box = nil
reaction_loader.collision_mask = {"transport-belt-layer"}

local reaction_settings_item = {
	type = "item",
	name = MOLECULE_REACTION_SETTINGS_NAME,
	icon = GRAPHICS_ROOT.."reaction-settings.png",
	icon_size = ITEM_ICON_SIZE,
	icon_mipmaps = ITEM_ICON_MIPMAPS,
	stack_size = 1,
	flags = {"hidden"},
}

local reaction_settings = {
	type = "constant-combinator",
	name = MOLECULE_REACTION_SETTINGS_NAME,
	placeable_by = {item = MOLECULE_REACTION_SETTINGS_NAME, count = 1},
	flags = {"hidden", "player-creation", "hide-alt-info", "not-deconstructable"},
	collision_box = table.deepcopy(BASE_BUILDING_PROTOTYPE.collision_box),
	selection_box = table.deepcopy(BASE_BUILDING_PROTOTYPE.selection_box),
	collision_mask = {},
	item_slot_count = #MOLECULE_REACTION_REACTANT_NAMES,
	sprites = {filename = "__core__/graphics/empty.png", size = 1},
	activity_led_sprites = {filename = "__core__/graphics/empty.png", size = 1},
	activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}},
	circuit_wire_connection_points =
		{{wire = {}, shadow = {}}, {wire = {}, shadow = {}}, {wire = {}, shadow = {}}, {wire = {}, shadow = {}}},
}

data:extend({reaction_chest, reaction_loader, reaction_settings_item, reaction_settings})


-- Moleculifier building
local moleculifier_entity = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
moleculifier_entity.name = MOLECULIFIER_NAME
moleculifier_entity.minable.result = MOLECULIFIER_NAME
moleculifier_entity.energy_source = {type = "void"}
moleculifier_entity.crafting_speed = 1
moleculifier_entity.crafting_categories = {MOLECULIFY_RECIPE_CATEGORY}
moleculifier_entity.module_specification = nil
moleculifier_entity.fast_replaceable_group = nil
moleculifier_entity.next_upgrade = nil
local moleculifier_overlay_layer = {
	filename = GRAPHICS_ROOT.."building-overlays/"..MOLECULIFIER_NAME..".png",
	size = BUILDING_OVERLAY_ICON_SIZE,
	repeat_count = moleculifier_entity.animation.layers[1].frame_count,
	priority = "high",
	hr_version = {
		filename = GRAPHICS_ROOT.."building-overlays/"..MOLECULIFIER_NAME.."-hr.png",
		size = BUILDING_OVERLAY_ICON_SIZE * 2,
		repeat_count = moleculifier_entity.animation.layers[1].hr_version.frame_count,
		priority = "high",
	},
}
table.insert(moleculifier_entity.animation.layers, moleculifier_overlay_layer)

local moleculifier_item = table.deepcopy(data.raw.item["assembling-machine-2"])
moleculifier_item.name = MOLECULIFIER_NAME
moleculifier_item.place_result = MOLECULIFIER_NAME
moleculifier_item.subgroup = MOLECULE_REACTION_BUILDINGS_SUBGROUP_NAME
moleculifier_item.order = "b"
moleculifier_item.icons = {
	{icon = moleculifier_item.icon, icon_size = moleculifier_item.icon_size, icon_mipmaps = moleculifier_item.icon_mipmaps},
	{
		icon = GRAPHICS_ROOT.."icon-overlays/"..MOLECULIFIER_NAME..".png",
		icon_size = ITEM_ICON_SIZE,
		icon_mipmaps = ITEM_ICON_MIPMAPS,
	},
}
moleculifier_item.icon = nil
moleculifier_item.icon_size = nil
moleculifier_item.icon_mipmaps = nil

local moleculifier_recipe = {
	type = "recipe",
	name = MOLECULIFIER_NAME,
	enabled = true,
	ingredients = {},
	result = MOLECULIFIER_NAME,
}

data:extend({moleculifier_entity, moleculifier_item, moleculifier_recipe})


-- Molecule detector combinator
local detector = table.deepcopy(data.raw["arithmetic-combinator"]["arithmetic-combinator"])
detector.name = MOLECULE_DETECTOR_NAME
detector.minable.result = MOLECULE_DETECTOR_NAME
detector.energy_source = {type = "void"}

local detector_item = table.deepcopy(data.raw.item["arithmetic-combinator"])
detector_item.name = MOLECULE_DETECTOR_NAME
detector_item.place_result = MOLECULE_DETECTOR_NAME
detector_item.subgroup = MOLECULE_REACTION_BUILDINGS_SUBGROUP_NAME
detector_item.order = "a"
detector_item.icons = {
	{icon = detector_item.icon, icon_size = detector_item.icon_size, icon_mipmaps = detector_item.icon_mipmaps},
	{
		icon = GRAPHICS_ROOT.."icon-overlays/"..MOLECULE_DETECTOR_NAME..".png",
		icon_size = ITEM_ICON_SIZE,
		icon_mipmaps = ITEM_ICON_MIPMAPS,
	},
}
detector_item.icon = nil
detector_item.icon_size = nil
detector_item.icon_mipmaps = nil

local detector_recipe = {
	type = "recipe",
	name = MOLECULE_DETECTOR_NAME,
	enabled = true,
	ingredients = {},
	result = MOLECULE_DETECTOR_NAME,
}

data:extend({detector, detector_item, detector_recipe})
