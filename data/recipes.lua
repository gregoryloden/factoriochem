-- Constants
local MOLECULIFY_SUBGROUP_NAME = "moleculify"
local MOLECULIFY_PREFIX = "moleculify-"


-- Moleculifier recipes
data:extend({
	{
		type = "item-subgroup",
		name = MOLECULIFY_SUBGROUP_NAME,
		group = MOLECULES_GROUP_NAME,
	},
	{
		type = "recipe-category",
		name = MOLECULIFY_RECIPE_CATEGORY,
	},
	{
		type = "recipe",
		name = MOLECULIFY_PREFIX.."water",
		category = MOLECULIFY_RECIPE_CATEGORY,
		subgroup = MOLECULIFY_SUBGROUP_NAME,
		order = "a",
		ingredients = {{name = "water", amount = 1, type = "fluid"}},
		results = {
			{name = MOLECULE_ITEM_PREFIX.."O1-H|1H", amount = 1, probability = 0.75},
			{name = MOLECULE_ITEM_PREFIX.."H1-O|-1H", amount = 1, probability = 0.05},
			{name = MOLECULE_ITEM_PREFIX.."-H|H1-1O", amount = 1, probability = 0.05},
			{name = MOLECULE_ITEM_PREFIX.."H|1O1-H", amount = 1, probability = 0.05},
			{name = MOLECULE_ITEM_PREFIX.."H|1O|1H", amount = 1, probability = 0.05},
			{name = MOLECULE_ITEM_PREFIX.."H1-O1-H", amount = 1, probability = 0.05},
		},
		icon = GRAPHICS_ROOT.."recipes/"..MOLECULIFY_PREFIX.."water.png",
		icon_size = 64,
		icon_mipmaps = 4,
		energy_required = 1,
	},
	{
		type = "recipe",
		name = MOLECULIFY_PREFIX.."air",
		category = MOLECULIFY_RECIPE_CATEGORY,
		subgroup = MOLECULIFY_SUBGROUP_NAME,
		order = "b",
		ingredients = {},
		results = {
			{name = MOLECULE_ITEM_PREFIX.."N3-N", amount = 1, probability = 0.375},
			{name = MOLECULE_ITEM_PREFIX.."N|3N", amount = 1, probability = 0.375},
			{name = MOLECULE_ITEM_PREFIX.."O2-O", amount = 1, probability = 0.125},
			{name = MOLECULE_ITEM_PREFIX.."O|2O", amount = 1, probability = 0.125},
		},
		icon = GRAPHICS_ROOT.."recipes/"..MOLECULIFY_PREFIX.."air.png",
		icon_size = 64,
		icon_mipmaps = 4,
		energy_required = 1,
	},
})


-- Science recipes
data.raw.recipe["automation-science-pack"].ingredients = {
	{MOLECULE_ITEM_PREFIX.."O1-H|1H", 1},
	{MOLECULE_ITEM_PREFIX.."H1-O|-1H", 1},
	{MOLECULE_ITEM_PREFIX.."-H|H1-1O", 1},
	{MOLECULE_ITEM_PREFIX.."H|1O1-H", 1},
	{MOLECULE_ITEM_PREFIX.."H|1O|1H", 1},
	{MOLECULE_ITEM_PREFIX.."H1-O1-H", 1},
}
