-- Constants
local SELECTOR_ICON_ROOT = GRAPHICS_ROOT.."selectors/"
local ROTATION_SELECTOR_SUBGROUP = MOLECULE_REACTION_SELECTOR_PREFIX..ROTATION_SELECTOR_NAME
local TARGET_SELECTOR_SUBGROUP = MOLECULE_REACTION_SELECTOR_PREFIX..TARGET_SELECTOR_NAME


-- Rotation
data:extend({{
	type = "item-subgroup",
	name = ROTATION_SELECTOR_SUBGROUP,
	group = "signals",
	order = "f",
}})
for val, suffix in ipairs({"l", "f", "r"}) do
	data:extend({{
		type = "item",
		name = ROTATION_SELECTOR_SUBGROUP.."-"..val,
		subgroup = ROTATION_SELECTOR_SUBGROUP,
		icon = SELECTOR_ICON_ROOT..ROTATION_SELECTOR_NAME.."-"..suffix..".png",
		icon_size = ITEM_ICON_SIZE,
		icon_mipmaps = ITEM_ICON_MIPMAPS,
		stack_size = 1,
	}})
end


-- Target
data:extend({{
	type = "item-subgroup",
	name = TARGET_SELECTOR_SUBGROUP,
	group = "signals",
	order = "g",
}})
for y_scale = 1, 3 do
	for x_scale = 1, 3 do
		for y = 0, y_scale - 1 do
			for x = 0, x_scale - 1 do
				local name_spec = y_scale..x_scale..y..x
				data:extend({{
					type = "item",
					name = TARGET_SELECTOR_SUBGROUP.."-"..name_spec,
					subgroup = TARGET_SELECTOR_SUBGROUP,
					localised_name = {"item-name.molecule-reaction-selector-target", x_scale, y_scale, x, y},
					icon = SELECTOR_ICON_ROOT..TARGET_SELECTOR_NAME.."-"..name_spec..".png",
					icon_size = ITEM_ICON_SIZE,
					icon_mipmaps = ITEM_ICON_MIPMAPS,
					stack_size = 1,
				}})
			end
		end
	end
end
