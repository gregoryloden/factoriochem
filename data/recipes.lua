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
})
local moleculify_recipes = {
	{
		name = "water",
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
	},
	{
		name = "air",
		order = "b",
		ingredients = {},
		results = {
			{name = MOLECULE_ITEM_PREFIX.."N3-N", amount = 1, probability = 0.375},
			{name = MOLECULE_ITEM_PREFIX.."N|3N", amount = 1, probability = 0.375},
			{name = MOLECULE_ITEM_PREFIX.."O2-O", amount = 1, probability = 0.125},
			{name = MOLECULE_ITEM_PREFIX.."O|2O", amount = 1, probability = 0.125},
		},
	},
	{
		name = "iron",
		order = "c",
		ingredients = {{"iron-plate", 1}},
		results = {{name = ATOM_ITEM_PREFIX.."Fe", amount = 1}},
	},
	{
		name = "copper",
		order = "d",
		ingredients = {{"copper-plate", 1}},
		results = {{name = ATOM_ITEM_PREFIX.."Cu", amount = 1}},
	}
}
for _, moleculify_recipe in ipairs(moleculify_recipes) do
	moleculify_recipe.type = "recipe"
	moleculify_recipe.category = MOLECULIFY_RECIPE_CATEGORY
	moleculify_recipe.subgroup = MOLECULIFY_SUBGROUP_NAME
	moleculify_recipe.icon = GRAPHICS_ROOT.."recipes/"..MOLECULIFY_PREFIX..moleculify_recipe.name..".png"
	moleculify_recipe.icon_size = ITEM_ICON_SIZE
	moleculify_recipe.icon_mipmaps = ITEM_ICON_MIPMAPS
	moleculify_recipe.energy_required = 1
	moleculify_recipe.name = MOLECULIFY_PREFIX..moleculify_recipe.name
end
data:extend(moleculify_recipes)

-- Science recipes
data.raw.recipe["automation-science-pack"].ingredients = {
	{MOLECULE_ITEM_PREFIX.."O1-H|1H", 1},
	{MOLECULE_ITEM_PREFIX.."H1-O|-1H", 1},
	{MOLECULE_ITEM_PREFIX.."-H|H1-1O", 1},
	{MOLECULE_ITEM_PREFIX.."H|1O1-H", 1},
	{MOLECULE_ITEM_PREFIX.."H|1O|1H", 1},
	{MOLECULE_ITEM_PREFIX.."H1-O1-H", 1},
}
