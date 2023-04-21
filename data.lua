require("shared/constants")
require("shared/molecules")
require("shared/buildings")
GRAPHICS_ROOT = "__FactorioChem__/graphics/"
ITEM_ICON_SIZE = 64
ITEM_ICON_MIPMAPS = 4
MOLECULE_ICON_MIPMAPS = 3
MOLECULES_SUBGROUP_NAME = "molecules"
MOLECULE_ITEMS_SUBGROUP_NAME = "molecule-items"
MOLECULIFY_RECIPE_CATEGORY = "moleculify"

require("data/molecules")
require("data/selectors")
require("data/technologies")
require("data/recipes")
require("data/buildings")
require("data/styles")


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
