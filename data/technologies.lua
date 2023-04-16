-- Constants
local TECHNOLOGY_ICON_ROOT = GRAPHICS_ROOT.."technologies/"
local TECHNOLOGY_ICON_SIZE = 128
local TECHNOLOGY_ICON_MIPMAPS = 3


-- Helpers
local function table_remove_value(t, rv)
	for i, v in ipairs(t) do
		if v == rv then
			table.remove(t, i)
			break
		end
	end
end

local function unlock_tips_and_tricks_item(name)
	local tips_and_tricks_item = data.raw["tips-and-tricks-item"][name]
	tips_and_tricks_item.starting_status = "unlocked"
	tips_and_tricks_item.trigger = nil
end

local function assign_science_prerequisites(technology)
	-- collect all the science prerequisites needed to research this technology
	local new_prerequisites = {}
	for _, ingredient in ipairs(technology.unit.ingredients) do
		new_prerequisites[ingredient.name or ingredient[1]] = true
	end
	-- remove any science pack that is already used to research a previous science
	new_prerequisites["automation-science-pack"] = nil
	for prerequisite, _ in pairs(new_prerequisites) do
		for _, ingredient in ipairs(data.raw.technology[prerequisite].unit.ingredients) do
			new_prerequisites[ingredient.name or ingredient[1]] = nil
		end
	end
	-- now go through and reassign the prerequisites
	technology.prerequisites = {}
	for prerequisite, _ in pairs(new_prerequisites) do table.insert(technology.prerequisites, prerequisite) end
end

local function set_technology_properties(technology)
	technology.type = "technology"
	technology.effects = {}
	technology.icon = TECHNOLOGY_ICON_ROOT..technology.name..".png"
	technology.icon_size = TECHNOLOGY_ICON_SIZE
	technology.icon_mipmaps = TECHNOLOGY_ICON_MIPMAPS
	assign_science_prerequisites(technology)
end


-- We want all sciences with prerequisites (except space science) to only require the previous science, but first, we need to
--	pass their original prerequisites to all the technologies that have them as prerequisites
local future_science_packs = {
	["chemical-science-pack"] = true,
	["military-science-pack"] = true,
	["production-science-pack"] = true,
	["utility-science-pack"] = true,
}
-- Go through every single technology in bottom-up order, and for each recipe it unlocks, for each of its ingredients, check
--	that that ingredient is enabled by default or that there is a path to a recipe that makes that item, without going
--	through a science technology. For any ingredients that are missing, add a direct prerequisite to it. In a similar
--	manner, make sure that technologies with a level have their previous level as a prerequisite somewhere.
-- Start by collecting all the enabled items
local enabled_items = {}
for _, recipe in pairs(data.raw.recipe) do
	recipe = recipe.normal or recipe
	if recipe.enabled == false then goto continue end
	if recipe.results then
		for _, result in ipairs(recipe.results) do enabled_items[result.name or result[1]] = true end
	elseif recipe.result then
		enabled_items[recipe.result] = true
	end
	::continue::
end
for _, resource in pairs(data.raw.resource) do
	local minable = resource.minable
	if minable.results then
		for _, result in ipairs(minable.results) do enabled_items[result.name or result[1]] = true end
	else
		enabled_items[minable.result] = true
	end
end
-- Find technologies with no prerequisites, and build a list of what technologies are enabled after a given technology
local postrequisites = {}
local ordered_technologies = {}
for technology_name, technology in pairs(data.raw.technology) do
	if technology.prerequisites then
		for _, prerequisite in ipairs(technology.prerequisites) do
			if postrequisites[prerequisite] then
				table.insert(postrequisites[prerequisite], technology_name)
			else
				postrequisites[prerequisite] = {technology_name}
			end
		end
	else
		table.insert(ordered_technologies, technology_name)
		ordered_technologies[technology_name] = true
	end
end
-- DFS functions to find a technology matching a condition
local function find_matching_technology(technology_name, allow_through_science, match)
	local technology = data.raw.technology[technology_name]
	if future_science_packs[technology_name] then
		if not allow_through_science then return nil end
	elseif match(technology) then
		return technology_name
	end
	if not technology.prerequisites then return nil end
	for _, technology_name in ipairs(technology.prerequisites) do
		local found_technology_name = find_matching_technology(technology_name, allow_through_science, match)
		if found_technology_name then return found_technology_name end
	end
	return nil
end
local function build_technology_match_recipe(match_recipe)
	return function(technology)
		if not technology.effects then return false end
		for _, effect in ipairs(technology.effects) do
			if not effect.recipe then goto continue end
			local recipe = data.raw.recipe[effect.recipe]
			if match_recipe(recipe.normal or recipe) then return true end
			::continue::
		end
		return false
	end
end
local function find_technology_for_item(source_technology_name, allow_through_science, item)
	local technology_recipe_crafts_item = build_technology_match_recipe(function(recipe)
		-- not a valid producer of this item if the recipe itself requires the item
		for _, ingredient in ipairs((recipe.normal or recipe).ingredients) do
			if (ingredient.name or ingredient[1]) == item then return false end
		end
		if recipe.results then
			for _, result in ipairs(recipe.results) do
				if (result.name or result[1]) == item then return true end
			end
			return false
		end
		return recipe.result == item
	end)
	return find_matching_technology(source_technology_name, allow_through_science, technology_recipe_crafts_item)
end
local function find_technology_for_recipe(source_technology_name, allow_through_science, recipe_category)
	function item_entity_crafts_recipe(item)
		if not item then return false end
		item = data.raw.item[item]
		if not item then return false end
		local entity = item.place_result
		if not entity then return false end
		entity = data.raw["assembling-machine"][entity]
		if not entity then return false end
		for _, crafting_category in ipairs(entity.crafting_categories) do
			if crafting_category == recipe_category then return true end
		end
		return false
	end
	local technology_recipe_entity_crafts_recipe = build_technology_match_recipe(function(recipe)
		if recipe.results then
			for _, result in ipairs(recipe.results) do
				if item_entity_crafts_recipe(result.name or result[1]) then return true end
			end
			return false
		end
		return item_entity_crafts_recipe(recipe.result)
	end)
	return find_matching_technology(source_technology_name, allow_through_science, technology_recipe_entity_crafts_recipe)
end
local function find_technology_previous_level(source_technology_name, allow_through_science, previous_technology_name)
	function technology_name_matches(technology)
		return technology.name == previous_technology_name
	end
	return find_matching_technology(source_technology_name, allow_through_science, technology_name_matches)
end
-- Go through every technology in bottom-up order and make sure it has its proper prerequisites without going through science
local ordered_technologies_i = 1
while ordered_technologies[ordered_technologies_i] do
	local technology_name = ordered_technologies[ordered_technologies_i]
	local technology = data.raw.technology[technology_name]
	-- add the next items in the order, if applicable
	if postrequisites[technology_name] then
		for _, postrequisite in ipairs(postrequisites[technology_name]) do
			if not ordered_technologies[postrequisite] then
				table.insert(ordered_technologies, postrequisite)
				ordered_technologies[postrequisite] = true
			end
		end
	end
	-- check if this technology is a later level that needs its previous level
	if string.match(technology_name, "-%d$") then
		local level = tonumber(string.sub(technology_name, -1))
		if level >= 2 then
			local previous_technology_name = string.sub(technology_name, 1, -3)
			if level > 2 then
				previous_technology_name = previous_technology_name.."-"..(level - 1)
			elseif not data.raw.technology[previous_technology_name] then
				previous_technology_name = previous_technology_name.."-1"
			end
			if not find_technology_previous_level(technology_name, false, previous_technology_name) then
				table.insert(technology.prerequisites, previous_technology_name)
			end
		end
	end
	-- check for items not enabled and not produced by any current prerequisites without going through a science, if
	--	applicable, and for any missing items, add a prerequisite for the technology with the recipe that produces those
	--	items
	if not technology.prerequisites or not technology.effects then goto continue_technologies end
	for _, effect in ipairs(technology.effects) do
		if not effect.recipe then goto continue_recipes end
		local recipe = data.raw.recipe[effect.recipe]
		-- if a recipe can't be made by hand, make sure that its building is a prerequisite
		if recipe.category
				and recipe.category ~= "crafting"
				and not find_technology_for_recipe(technology_name, false, recipe.category) then
			table.insert(
				technology.prerequisites, find_technology_for_recipe(technology_name, true, recipe.category))
		end
		-- check whether each ingredient is available with the technology's existing prerequisites
		for _, ingredient in ipairs((recipe.normal or recipe).ingredients) do
			local ingredient_name = ingredient.name or ingredient[1]
			-- the item is already available, no need for another prerequisite
			if enabled_items[ingredient_name] then goto continue_ingredients end
			-- the item is available through prerequisites without going through a science, no need for another
			--	prerequisite
			if find_technology_for_item(technology_name, false, ingredient_name) then goto continue_ingredients end
			-- the item is only available through a science prerequisite, add a recipe technology that creates it to
			--	this technology's prerequisites
			table.insert(technology.prerequisites, find_technology_for_item(technology_name, true, ingredient_name))
			::continue_ingredients::
		end
		::continue_recipes::
	end
	::continue_technologies::
	ordered_technologies_i = ordered_technologies_i + 1
end


-- Now that all technologies can reach all their prerequisites without going through a science, go through each science, and
--	reassign new prerequisites containing exclusively the science pack that it uses that none of its prerequisites use
for science_pack, _ in pairs(future_science_packs) do
	assign_science_prerequisites(data.raw.technology[science_pack])
end


-- Make splitters and underground belts available by default
data.raw.technology["logistics"] = nil
table_remove_value(data.raw.technology["logistics-2"].prerequisites, "logistics")
data.raw.recipe["underground-belt"].enabled = nil
data.raw.recipe["splitter"].enabled = nil
unlock_tips_and_tricks_item("splitters")
unlock_tips_and_tricks_item("underground-belts")


-- Add technologies to unlock molecule building recipes and make them prerequisites for sciences, recipes will add themselves as
--	effects
local reaction_building_unlock_technologies = {
	{
		name = "molecule-reaction-buildings-2",
		unit = {count = 50, time = 10},
		postrequisite = "logistic-science-pack",
	},
}
for _, technology in pairs(reaction_building_unlock_technologies) do
	local science_technology = data.raw.technology[technology.postrequisite]
	technology.unit.ingredients = science_technology.unit.ingredients
	technology.postrequisite = nil
	set_technology_properties(technology)
	science_technology.prerequisites = {technology.name}
end
data:extend(reaction_building_unlock_technologies)


-- Add technologies to unlock moleculify recipes, recipes will add themselves as effects
local moleculify_unlock_technologies = {
	{
		name = "moleculify-plates",
		unit = {
			count = 50,
			time = 10,
			ingredients = {{"automation-science-pack", 1}},
		},
	},
	{
		name = "moleculify-air",
		unit = {
			count = 50,
			time = 10,
			ingredients = {{"automation-science-pack", 1}},
		},
		prerequisites = {"molecule-reaction-buildings-2"},
	},
}
for _, technology in pairs(moleculify_unlock_technologies) do
	local old_prerequisites = technology.prerequisites
	set_technology_properties(technology)
	if old_prerequisites then
		for _, prerequisite in pairs(old_prerequisites) do table.insert(technology.prerequisites, prerequisite) end
	end
end
data:extend(moleculify_unlock_technologies)
