-- Dummy recipe for machines
data:extend({
	{
		type = "item",
		name = MOLECULE_REACTION_REACTANTS_NAME,
		localised_name = {"item-name."..MOLECULE_REACTION_REACTANTS_NAME},
		icon = GRAPHICS_ROOT..MOLECULE_REACTION_REACTANTS_NAME..".png",
		icon_size = ITEM_ICON_SIZE,
		icon_mipmaps = ITEM_ICON_MIPMAPS,
		stack_size = 1,
		flags = {"hidden"},
	},
	{
		type = "recipe",
		name = MOLECULE_REACTION_REACTANTS_NAME,
		subgroup = MOLECULES_SUBGROUP_NAME,
		enabled = true,
		ingredients = {{MOLECULE_REACTION_REACTANTS_NAME, 1}},
		results = {},
		energy_required = 1,
		icon = GRAPHICS_ROOT..MOLECULE_REACTION_REACTANTS_NAME..".png",
		icon_size = ITEM_ICON_SIZE,
		icon_mipmaps = ITEM_ICON_MIPMAPS,
		hidden = true,
	},
})
