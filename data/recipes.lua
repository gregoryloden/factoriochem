-- Constants
local MOLECULIFY_SUBGROUP_NAME = "moleculify"
local MOLECULIFY_PREFIX = "moleculify-"


-- Global utilities
function recipe_set_unlocking_technology(recipe, unlocking_technology)
	if not unlocking_technology then return false end
	table.insert(data.raw.technology[unlocking_technology].effects, {type = "unlock-recipe", recipe = recipe.name})
	recipe.enabled = false
	return true
end


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
local moleculify_stone_recipe = {
	name = "stone",
	order = "f",
	ingredients = {{"stone", 1}},
	results = {},
	unlocking_technology = "moleculify-stone",
}
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
		name = "iron",
		order = "b",
		ingredients = {{"iron-plate", 1}},
		results = {{name = ATOM_ITEM_PREFIX.."Fe", amount = 1}},
		unlocking_technology = "moleculify-plates",
	},
	{
		name = "copper",
		order = "c",
		ingredients = {{"copper-plate", 1}},
		results = {{name = ATOM_ITEM_PREFIX.."Cu", amount = 1}},
		unlocking_technology = "moleculify-plates",
	},
	{
		name = "air",
		order = "d",
		ingredients = {},
		results = {
			{name = MOLECULE_ITEM_PREFIX.."N3-N", amount = 1, probability = 0.375},
			{name = MOLECULE_ITEM_PREFIX.."N|3N", amount = 1, probability = 0.375},
			{name = MOLECULE_ITEM_PREFIX.."O2-O", amount = 1, probability = 0.125},
			{name = MOLECULE_ITEM_PREFIX.."O|2O", amount = 1, probability = 0.125},
		},
		unlocking_technology = "moleculify-air",
	},
	{
		name = "coal",
		order = "e",
		ingredients = {{"coal", 1}},
		results = {
			{name = MOLECULE_ITEM_PREFIX.."C2-C2-C|2C2-C2-2C", amount = 1, probability = 0.5},
			{name = MOLECULE_ITEM_PREFIX.."C2-C|2C-2C|2C2-2C", amount = 1, probability = 0.5},
		},
		unlocking_technology = "moleculify-coal",
	},
	moleculify_stone_recipe,
	{
		name = "oil",
		order = "g",
		ingredients = {{name = "crude-oil", amount = 1, type = "fluid"}},
		results = {
			{name = MOLECULE_ITEM_PREFIX.."-H|H1-1C1-H|-1H", amount = 1, probability = 1 / 3},
			{name = MOLECULE_ITEM_PREFIX.."H-H|1C2-1C|1H-1H", amount = 1, probability = 1 / 3},
			{name = MOLECULE_ITEM_PREFIX.."H1-C1-H|H1-2C1-H", amount = 1, probability = 1 / 3},
		},
		unlocking_technology = "moleculify-oil",
	},
}
for atom_row_i = 3, 4 do
	local atom_row = ATOM_ROWS[atom_row_i]
	local atom_row_n = #atom_row - 1
	local probability = 0.5 / atom_row_n
	for atom_i = 1, atom_row_n do
		local result = {name = ATOM_ITEM_PREFIX..atom_row[atom_i], amount = 1, probability = probability}
		table.insert(moleculify_stone_recipe.results, result)
	end
end
for _, moleculify_recipe in ipairs(moleculify_recipes) do
	moleculify_recipe.type = "recipe"
	moleculify_recipe.category = MOLECULIFY_RECIPE_CATEGORY
	moleculify_recipe.subgroup = MOLECULIFY_SUBGROUP_NAME
	moleculify_recipe.icon = GRAPHICS_ROOT.."recipes/"..MOLECULIFY_PREFIX..moleculify_recipe.name..".png"
	moleculify_recipe.icon_size = ITEM_ICON_SIZE
	moleculify_recipe.icon_mipmaps = ITEM_ICON_MIPMAPS
	moleculify_recipe.energy_required = 1
	moleculify_recipe.name = MOLECULIFY_PREFIX..moleculify_recipe.name
	if recipe_set_unlocking_technology(moleculify_recipe, moleculify_recipe.unlocking_technology) then
		moleculify_recipe.unlocking_technology = nil
	end
end
data:extend(moleculify_recipes)


-- Science recipes
local science_ingredients = {
	["automation-science-pack"] = {
		{MOLECULE_ITEM_PREFIX.."O1-H|1H", 1},
		{MOLECULE_ITEM_PREFIX.."H1-O|-1H", 1},
		{MOLECULE_ITEM_PREFIX.."-H|H1-1O", 1},
		{MOLECULE_ITEM_PREFIX.."H|1O1-H", 1},
		{MOLECULE_ITEM_PREFIX.."H|1O|1H", 1},
		{MOLECULE_ITEM_PREFIX.."H1-O1-H", 1},
	},
	["logistic-science-pack"] = {
		{ATOM_ITEM_PREFIX.."Fe", 1},
		{ATOM_ITEM_PREFIX.."Cu", 1},
		{ATOM_ITEM_PREFIX.."Al", 1},
		{MOLECULE_ITEM_PREFIX.."Be1-F|1Li", 1},
		{MOLECULE_ITEM_PREFIX.."S1-Cl|1Li", 1},
	},
	["chemical-science-pack"] = {
		{ATOM_ITEM_PREFIX.."Xe", 1},
		{MOLECULE_ITEM_PREFIX.."K1-Br", 1},
		{MOLECULE_ITEM_PREFIX.."N1-F|2S", 1},
		{MOLECULE_ITEM_PREFIX.."N1-O1-N|2C2-C2-2C", 1},
	},
}
for science, ingredients in pairs(science_ingredients) do
	local recipe = data.raw.recipe[science]
	recipe.ingredients = ingredients
	recipe.result_count = nil
	local total_atomic_number = 0
	for _, ingredient in ipairs(ingredients) do
		local shape = parse_molecule(ingredient[1])
		for _, shape_row in pairs(shape) do
			for _, atom in pairs(shape_row) do
				total_atomic_number = total_atomic_number + ALL_ATOMS[atom.symbol].number * ingredient[2]
			end
		end
	end
	recipe.localised_description = {"recipe-description.science-pack-atomic-number", total_atomic_number}
end
