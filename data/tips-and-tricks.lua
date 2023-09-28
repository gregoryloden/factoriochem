-- Constants
local TIPS_AND_TRICKS_GRAPHICS_ROOT = GRAPHICS_ROOT.."tips-and-tricks/"


-- Tips and tricks
data:extend({
	{
		type = "tips-and-tricks-item-category",
		name = "factoriochem",
		order = "_",
	},
	{
		type = "tips-and-tricks-item",
		name = "factoriochem-introduction",
		category = "factoriochem",
		order = "a",
		starting_status = "suggested",
		is_title = true,
		image = TIPS_AND_TRICKS_GRAPHICS_ROOT.."introduction.png",
	},
	{
		type = "tips-and-tricks-item",
		name = "factoriochem-buildings",
		category = "factoriochem",
		order = "aa",
		starting_status = "suggested",
		indent = 1,
		image = TIPS_AND_TRICKS_GRAPHICS_ROOT.."buildings.png",
	},
	{
		type = "tips-and-tricks-item",
		name = "factoriochem-moleculifier",
		category = "factoriochem",
		order = "aaa",
		starting_status = "unlocked",
		indent = 2,
		image = TIPS_AND_TRICKS_GRAPHICS_ROOT.."moleculifier.png",
	},
	{
		type = "tips-and-tricks-item",
		name = "factoriochem-gui",
		category = "factoriochem",
		order = "ab",
		starting_status = "unlocked",
		indent = 1,
		image = TIPS_AND_TRICKS_GRAPHICS_ROOT.."gui.png",
	},
})
