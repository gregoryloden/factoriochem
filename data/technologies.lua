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


-- Make splitters and underground belts available by default
data.raw.technology["logistics"] = nil
table_remove_value(data.raw.technology["logistics-2"].prerequisites, "logistics")
data.raw.recipe["underground-belt"].enabled = nil
data.raw.recipe["splitter"].enabled = nil
unlock_tips_and_tricks_item("splitters")
unlock_tips_and_tricks_item("underground-belts")
