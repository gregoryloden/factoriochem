-- Constants
local BUILDING_OVERLAYS_ROOT = GRAPHICS_ROOT.."building-overlays/"
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
BASE_BUILDING_PROTOTYPE.allowed_effects = nil
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

local function add_filename_and_hr_version(layer, filename_base)
	local hr_version = table.deepcopy(layer)
	for _, property in pairs(layer) do hr_version[property] = layer[property] end
	for _, property in ipairs({"width", "height", "size", "x", "y"}) do
		if hr_version[property] then hr_version[property] = hr_version[property] * 2 end
	end
	layer.filename = filename_base..".png"
	hr_version.filename = filename_base.."-hr.png"
	layer.hr_version = hr_version
end

local function add_4_way_layer(sprites, overlay_name, overlay, width, height, shift_x, shift_y)
	for direction, get_sprite_data in pairs(DIRECTION_GET_SPRITE_DATA) do
		local layers = sprites[direction].layers
		local sprite_data = get_sprite_data(width, height, shift_x, shift_y)
		local layer = {
			width = sprite_data.width,
			height = sprite_data.height,
			x = sprite_data.x,
			y = sprite_data.y,
			priority = "high",
			shift = sprite_data.shift,
		}
		if layers[1].frame_count then layer.repeat_count = layers[1].frame_count end
		add_filename_and_hr_version(layer, BUILDING_OVERLAYS_ROOT..overlay_name)
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
		subgroup = MOLECULES_SUBGROUP_NAME,
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
		name = entity.fixed_recipe,
		subgroup = MOLECULES_SUBGROUP_NAME,
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
		ingredients = {{"iron-gear-wheel", 25}, {"copper-plate", 50}},
		result = name,
	}
	if name == "molecule-voider" then
		for _, ingredient in ipairs(recipe.ingredients) do ingredient[2] = ingredient[2] * 10 end
	end
	recipe_set_unlocking_technology(recipe, definition.unlocking_technology)

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
	size = BUILDING_OVERLAY_ICON_SIZE,
	repeat_count = moleculifier_entity.animation.layers[1].frame_count,
	priority = "high",
}
add_filename_and_hr_version(moleculifier_overlay_layer, BUILDING_OVERLAYS_ROOT..MOLECULIFIER_NAME)
table.insert(moleculifier_entity.animation.layers, moleculifier_overlay_layer)

local moleculifier_item = table.deepcopy(data.raw.item["assembling-machine-2"])
moleculifier_item.name = MOLECULIFIER_NAME
moleculifier_item.place_result = MOLECULIFIER_NAME
moleculifier_item.subgroup = MOLECULE_REACTION_BUILDINGS_SUBGROUP_NAME
moleculifier_item.order = "a"
overlay_icon(moleculifier_item, MOLECULIFIER_NAME)

local moleculifier_recipe = {
	type = "recipe",
	name = MOLECULIFIER_NAME,
	ingredients = {{"iron-gear-wheel", 25}, {"copper-plate", 50}},
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
local detector_symbol_shifts = {
	north = {1 / 64, -11 / 64},
	east = {1 / 64, -23 / 64},
	south = {1 / 64, -11 / 64},
	west = {1 / 64, -23 / 64},
}
for direction, shift in pairs(detector_symbol_shifts) do
	local layer = {size = 9, priority = "high", shift = shift}
	add_filename_and_hr_version(layer, BUILDING_OVERLAYS_ROOT..MOLECULE_DETECTOR_NAME.."-symbol")
	table.insert(detector.sprites[direction].layers, layer)
end

local detector_item = table.deepcopy(data.raw.item["arithmetic-combinator"])
detector_item.name = MOLECULE_DETECTOR_NAME
detector_item.place_result = MOLECULE_DETECTOR_NAME
detector_item.subgroup = "circuit-network"
detector_item.order = "c[combinators]-d"
detector_item.icons = detector.icons
detector_item.icon = nil
detector_item.icon_size = nil
detector_item.icon_mipmaps = nil

local detector_recipe = {
	type = "recipe",
	name = MOLECULE_DETECTOR_NAME,
	ingredients = {{"iron-plate", 10}, {"electronic-circuit", 20}},
	result = MOLECULE_DETECTOR_NAME,
}
recipe_set_unlocking_technology(detector_recipe, "circuit-network")

data:extend({detector, detector_item, detector_recipe})


-- Molecule detector combinator output
local detector_output = table.deepcopy(detector)
detector_output.name = MOLECULE_DETECTOR_OUTPUT_NAME
detector_output.minable = nil
detector_output.item_slot_count = 30
detector_output.selection_box = {{-0.5, -1}, {0.5, 0}}
detector_output.flags = table.deepcopy(HIDDEN_ENTITY_FLAGS)
table.insert(detector_output.flags, "hide-alt-info")
detector_output.allow_copy_paste = false
detector_output.collision_mask = {}
detector_output.sprites = EMPTY_SPRITE
detector_output.activity_led_sprites = EMPTY_SPRITE
detector_output.activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}}
detector_output.circuit_wire_connection_points = table.deepcopy(arithmetic_combinator.output_connection_points)

data:extend({detector_output})


-- Incidator sprites for molecule reaction building GUIs
for _, component in ipairs(MOLECULE_REACTION_COMPONENT_NAMES) do
	x = 32
	if not MOLECULE_REACTION_IS_REACTANT[component] then x = 72 end
	sprite = {width = 16, height = 32, x = x, priority = "high"}
	add_filename_and_hr_version(sprite, BUILDING_OVERLAYS_ROOT..component)
	sprite.type = "sprite"
	sprite.name = MOLECULE_INDICATOR_PREFIX..component
	data:extend({sprite})
end
