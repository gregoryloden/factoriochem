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


-- Periodic table prototypes
local periodic_table = {type = "shortcut", name = PERIODIC_TABLE_NAME, action = "lua"}
for _, disabled_prefix in ipairs({"", "disabled_"}) do
	for size_prefix, size in pairs({[""] = 32, small_ = 24}) do
		if disabled_prefix ~= "" and size_prefix == "" then goto continue end
		local y = 0
		if size == 32 then y = 48 end
		if disabled_prefix ~= "" then y = y + size end
		periodic_table[disabled_prefix..size_prefix.."icon"] = {
			filename = GRAPHICS_ROOT..PERIODIC_TABLE_NAME..".png",
			size = size,
			y = y,
			mipmap_count = 2,
			flags = {"gui-icon"},
		}
		::continue::
	end
end
local periodic_table_24 = table.deepcopy(periodic_table.small_icon)
periodic_table_24.type = "sprite"
periodic_table_24.name = PERIODIC_TABLE_NAME.."-24"
data:extend({periodic_table, periodic_table_24})


-- Molecule builder sprite and dropper item
data:extend({
	{
		type = "sprite",
		name = MOLECULE_BUILDER_NAME.."-24",
		filename = GRAPHICS_ROOT..MOLECULE_BUILDER_NAME..".png",
		size = 24,
		flags = {"gui-icon"},
	},
	{
		type = "item",
		name = MOLECULE_BUILDER_DROPPER_NAME,
		icon = GRAPHICS_ROOT.."dropper.png",
		icon_size = 32,
		icon_mipmaps = 2,
		stack_size = 1,
		flags = {"hidden"},
	},
})
