require("shared/constants")
require("shared/molecules")
require("shared/buildings")
GRAPHICS_ROOT = "__FactorioChem__/graphics/"
ITEM_ICON_SIZE = 64
ITEM_ICON_MIPMAPS = 4
MOLECULE_ICON_MIPMAPS = 3
MOLECULES_SUBGROUP_NAME = "molecules"
MOLECULIFY_RECIPE_CATEGORY = "moleculify"

require("data/molecules")
require("data/selectors")
require("data/technologies")
require("data/recipes")
require("data/buildings")
require("data/styles")
require("data/tips-and-tricks")


-- Empty and cancel sprites
for _, size in ipairs({{1, 1}, {1, 2}}) do
	data:extend({{
		type = "sprite",
		name = "empty-"..size[1].."x"..size[2],
		filename = GRAPHICS_ROOT.."empty.png",
		width = size[1],
		height = size[2],
	}})
end
data:extend({{
	type = "sprite",
	name = "cancel",
	filename = "__core__/graphics/cancel.png",
	size = 64,
}})


-- Periodic table and molecule builder prototypes
for _, name in ipairs({PERIODIC_TABLE_NAME, MOLECULE_BUILDER_NAME}) do
	local shortcut_icon = {type = "shortcut", name = name, action = "lua"}
	for _, disabled_prefix in ipairs({"", "disabled_"}) do
		for size_prefix, size in pairs({[""] = 32, small_ = 24}) do
			if disabled_prefix ~= "" and size_prefix == "" then goto continue end
			local y = 0
			if size == 32 then y = 48 end
			if disabled_prefix ~= "" then y = y + size end
			shortcut_icon[disabled_prefix..size_prefix.."icon"] = {
				filename = GRAPHICS_ROOT..name..".png",
				size = size,
				y = y,
				mipmap_count = 2,
				flags = {"gui-icon"},
			}
			::continue::
		end
	end
	local reaction_table_icon = table.deepcopy(shortcut_icon.small_icon)
	reaction_table_icon.type = "sprite"
	reaction_table_icon.name = name.."-24"
	data:extend({shortcut_icon, reaction_table_icon})
end


-- Molecule builder dropper item
data:extend({{
	type = "item",
	name = MOLECULE_BUILDER_DROPPER_NAME,
	icon = GRAPHICS_ROOT.."dropper.png",
	icon_size = 32,
	icon_mipmaps = 2,
	stack_size = 1,
	flags = {"hidden"},
}})
