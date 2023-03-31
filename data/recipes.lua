-- Dummy recipe for machines
data:extend({
	{
		type = "recipe",
		name = "molecule-reaction-reactants",
		subgroup = MOLECULES_SUBGROUP,
		enabled = true,
		ingredients = {{"molecule-reaction-reactants", 1}},
		results = {},
		energy_required = 1,
		icon = GRAPHICS_ROOT.."molecule-reaction-reactants.png",
		icon_size = ITEM_ICON_SIZE,
		icon_mipmaps = ITEM_ICON_MIPMAPS,
		hidden = true,
	}
})
