-- Utilities
local function table_remove_value(t, rv)
	for i, v in ipairs(t) do
		if v == rv then
			table.remove(t, i)
			break
		end
	end
end

local function remove_technology(technology)
	for _, effect in ipairs(data.raw.technology[technology].effects) do
		if effect.type == "unlock-recipe" then data.raw.recipe[effect.recipe].enabled = nil end
	end
	data.raw.technology[technology] = nil
	for _, other_technology in pairs(data.raw.technology) do
		if other_technology.prerequisites then table_remove_value(other_technology.prerequisites, technology) end
	end
end

local function unlock_tips_and_tricks_item(name)
	local tips_and_tricks_item = data.raw["tips-and-tricks-item"][name]
	tips_and_tricks_item.starting_status = "unlocked"
	tips_and_tricks_item.trigger = nil
end


-- Make splitters and underground belts available by default
remove_technology("logistics")
unlock_tips_and_tricks_item("splitters")
unlock_tips_and_tricks_item("underground-belts")
