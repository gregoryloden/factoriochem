-- Constants
local SELECTOR_ICON_ROOT = GRAPHICS_ROOT.."selectors/"
local ROTATION_SELECTOR_SUBGROUP = MOLECULE_REACTION_SELECTOR_PREFIX..ROTATION_SELECTOR_NAME
local ATOM_BOND_SELECTOR_SUBGROUP = MOLECULE_REACTION_SELECTOR_PREFIX..ATOM_BOND_SELECTOR_NAME


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


-- Target and atom-bond
data:extend({
	{
		type = "item-subgroup",
		name = TARGET_SELECTOR_SUBGROUP,
		group = "signals",
		order = "g",
	},
	{
		type = "item-subgroup",
		name = ATOM_BOND_INNER_SELECTOR_SUBGROUP,
		group = "signals",
		order = "h",
	},
	{
		type = "item-subgroup",
		name = ATOM_BOND_OUTER_SELECTOR_SUBGROUP,
		group = "signals",
		order = "i",
	},
})
for y_scale = 1, 3 do
	for x_scale = 1, 3 do
		for y = 0, y_scale - 1 do
			for x = 0, x_scale - 1 do
				local name_spec = y_scale..x_scale..y..x
				data:extend({{
					type = "item",
					name = TARGET_SELECTOR_SUBGROUP.."-"..name_spec,
					subgroup = TARGET_SELECTOR_SUBGROUP,
					localised_name = {"item-name."..TARGET_SELECTOR_SUBGROUP, x_scale, y_scale, x, y},
					icon = SELECTOR_ICON_ROOT..TARGET_SELECTOR_NAME.."-"..name_spec..".png",
					icon_size = ITEM_ICON_SIZE,
					icon_mipmaps = ITEM_ICON_MIPMAPS,
					stack_size = 1,
				}})
				for direction_i, direction in ipairs({"N", "E", "S", "W"}) do
					local inner_y = (direction ~= "N" or y > 0) and (direction ~= "S" or y + 1 < y_scale)
					local inner_x = (direction ~= "W" or x > 0) and (direction ~= "E" or x + 1 < x_scale)
					local subgroup = ATOM_BOND_INNER_SELECTOR_SUBGROUP
					if not inner_y or not inner_x then subgroup = ATOM_BOND_OUTER_SELECTOR_SUBGROUP end
					if (y_scale < 3 or inner_y) and (x_scale < 3 or inner_x) then
						local atom_bond_name_spec = name_spec..direction
						local localised_name_format =
							"item-name."..ATOM_BOND_SELECTOR_SUBGROUP.."-"..direction
						local file_name = ATOM_BOND_SELECTOR_NAME.."-"..atom_bond_name_spec..".png"
						data:extend({{
							type = "item",
							name = ATOM_BOND_SELECTOR_SUBGROUP.."-"..atom_bond_name_spec,
							subgroup = subgroup,
							order = name_spec..direction_i,
							localised_name = {localised_name_format, x_scale, y_scale, x, y},
							icon = SELECTOR_ICON_ROOT..file_name,
							icon_size = ITEM_ICON_SIZE,
							icon_mipmaps = ITEM_ICON_MIPMAPS,
							stack_size = 1,
						}})
					end
				end
			end
		end
	end
end
