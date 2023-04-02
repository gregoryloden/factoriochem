-- Constants
local SELECTOR_ICON_ROOT = GRAPHICS_ROOT.."selectors/"
local ROTATION_SELECTOR = MOLECULE_REACTION_SELECTOR_PREFIX..ROTATION_SELECTOR_NAME


-- Rotation
data:extend({{
	type = "item-subgroup",
	name = ROTATION_SELECTOR,
	group = "signals",
	order = "f",
}})
for val, suffix in ipairs({"l", "f", "r"}) do
	data:extend({{
		type = "item",
		name = ROTATION_SELECTOR.."-"..val,
		subgroup = ROTATION_SELECTOR,
		icon = SELECTOR_ICON_ROOT..ROTATION_SELECTOR_NAME.."-"..suffix..".png",
		icon_size = ITEM_ICON_SIZE,
		icon_mipmaps = ITEM_ICON_MIPMAPS,
		stack_size = 1,
	}})
end
