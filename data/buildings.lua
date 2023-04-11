-- Constants
local MOLECULE_REACTION_BUILDINGS_SUBGROUP_NAME = MOLECULE_REACTION_NAME.."-buildings"
local DIRECTION_GET_SPRITE_DATA = {
	north = function(width, height, shift_x, shift_y)
		return {width = width, height = height, x = 0, y = 0, shift = {shift_x, shift_y}}
	end,
	east = function(width, height, shift_x, shift_y)
		return {width = height, height = width, x = width, y = 0, shift = {-shift_y, shift_x}}
	end,
	south = function(width, height, shift_x, shift_y)
		return {width = width, height = height, x = height, y = width, shift = {-shift_x, -shift_y}}
	end,
	west = function(width, height, shift_x, shift_y)
		return {width = height, height = width, x = 0, y = height, shift = {shift_y, -shift_x}}
	end,
}
local HIDDEN_ENTITY_FLAGS = {"hidden", "not-deconstructable", "not-blueprintable", "player-creation"}
local EMPTY_SPRITE = {filename = "__core__/graphics/empty.png", size = 1}
local BUILDING_OVERLAY_ICON_SIZE = 64
local MOLECULIFIER_NAME = "moleculifier"
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


-- Utilities
local function overlay_icon(prototype, icon_overlay_name, base_design)
	if not base_design then base_design = prototype end
	prototype.icons = {
		{icon = base_design.icon, icon_size = base_design.icon_size, icon_mipmaps = base_design.icon_mipmaps},
		{
			icon = GRAPHICS_ROOT.."icon-overlays/"..icon_overlay_name..".png",
			icon_size = ITEM_ICON_SIZE,
			icon_mipmaps = ITEM_ICON_MIPMAPS,
		},
	}
	if prototype.icon then prototype.icon = nil end
	if prototype.icon_size then prototype.icon_size = nil end
	if prototype.icon_mipmaps then prototype.icon_mipmaps = nil end
end

local function add_4_way_layer(sprites, overlay_name, overlay, width, height, shift_x, shift_y)
	for direction, get_sprite_data in pairs(DIRECTION_GET_SPRITE_DATA) do
		local layers = sprites[direction].layers
		local sprite_data = get_sprite_data(width, height, shift_x, shift_y)
		local layer = {
			filename = GRAPHICS_ROOT.."building-overlays/"..overlay_name..".png",
			width = sprite_data.width,
			height = sprite_data.height,
			x = sprite_data.x,
			y = sprite_data.y,
			priority = "high",
			shift = sprite_data.shift,
			hr_version = {
				filename = GRAPHICS_ROOT.."building-overlays/"..overlay_name.."-hr.png",
				width = sprite_data.width * 2,
				height = sprite_data.height * 2,
				x = sprite_data.x * 2,
				y = sprite_data.y * 2,
				priority = "high",
				shift = sprite_data.shift,
			},
		}
		if layers[1].frame_count then
			layer.repeat_count = layers[1].frame_count
			layer.hr_version.repeat_count = layers[1].hr_version.frame_count
		end
		if overlay then
			table.insert(layers, layer)
		else
			table.insert(layers, 1, layer)
		end
	end
end


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
	for _, component in ipairs(MOLECULE_REACTION_COMPONENT_NAMES) do
		if not definition.has_component[component] then goto continue end
		local shift = MOLECULE_REACTION_COMPONENT_OFFSETS[component]
		add_4_way_layer(entity.animation, component, true, 32, 56, shift.x, shift.y * 1.375)
		::continue::
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
		stack_size = 50,
	}
	overlay_icon(item, name, item_design)

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
	picture = EMPTY_SPRITE,
	collision_box = {{-0.5, -0.5}, {0.5, 0.5}},
}

local reaction_loader = table.deepcopy(data.raw["loader-1x1"]["loader-1x1"])
reaction_loader.name = MOLECULE_REACTION_LOADER_NAME
reaction_loader.structure.direction_in = EMPTY_SPRITE
reaction_loader.structure.direction_out = EMPTY_SPRITE
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
	sprites = EMPTY_SPRITE,
	activity_led_sprites = EMPTY_SPRITE,
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
overlay_icon(moleculifier_item, MOLECULIFIER_NAME)

local moleculifier_recipe = {
	type = "recipe",
	name = MOLECULIFIER_NAME,
	enabled = true,
	ingredients = {},
	result = MOLECULIFIER_NAME,
}

data:extend({moleculifier_entity, moleculifier_item, moleculifier_recipe})


-- Molecule detector combinator input
local detector = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
detector.name = MOLECULE_DETECTOR_NAME
detector.minable.result = MOLECULE_DETECTOR_NAME
detector.item_slot_count = 10
detector.selection_box = {{-0.5, 0}, {0.5, 1}}
local arithmetic_combinator_copy_properties = {
	sprites = false,
	collision_box = false,
	activity_led_light_offsets = false,
	activity_led_sprites = false,
	circuit_wire_connection_points = "input_connection_points",
}
local arithmetic_combinator = data.raw["arithmetic-combinator"]["arithmetic-combinator"]
for dst_property, src_property in pairs(arithmetic_combinator_copy_properties) do
	detector[dst_property] = table.deepcopy(arithmetic_combinator[src_property or dst_property])
end
overlay_icon(detector, MOLECULE_DETECTOR_NAME, arithmetic_combinator)
add_4_way_layer(detector.sprites, MOLECULE_DETECTOR_NAME, false, 32, 64, 0, 0)

local detector_item = table.deepcopy(data.raw.item["arithmetic-combinator"])
detector_item.name = MOLECULE_DETECTOR_NAME
detector_item.place_result = MOLECULE_DETECTOR_NAME
detector_item.subgroup = MOLECULE_REACTION_BUILDINGS_SUBGROUP_NAME
detector_item.order = "a"
detector_item.icons = detector.icons
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


-- Molecule detector combinator output
local detector_output = table.deepcopy(detector)
detector_output.name = MOLECULE_DETECTOR_OUTPUT_NAME
detector_output.minable = nil
detector_output.item_slot_count = 30
detector_output.selection_box = {{-0.5, -1}, {0.5, 0}}
detector_output.flags = table.deepcopy(HIDDEN_ENTITY_FLAGS)
table.insert(detector_output.flags, "hide-alt-info")
detector_output.collision_mask = {}
detector_output.sprites = EMPTY_SPRITE
detector_output.activity_led_sprites = EMPTY_SPRITE
detector_output.activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}}
detector_output.circuit_wire_connection_points = table.deepcopy(arithmetic_combinator.output_connection_points)

data:extend({detector_output})
