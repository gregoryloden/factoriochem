BUILDING_DEFINITIONS = {
	["molecule-rotater"] = {
		building_design = "assembling-machine-3",
		item_order = "b",
		reactants = {BASE_NAME, CATALYST_NAME, MODIFIER_NAME},
		products = {RESULT_NAME, BONUS_NAME, REMAINDER_NAME},
		reaction = function(data)
			-- TODO: real reaction
			local base_inventory = data.chests["base"].get_inventory(defines.inventory.chest)
			local catalyst_inventory = data.chests["catalyst"].get_inventory(defines.inventory.chest)
			local modifier_inventory = data.chests["modifier"].get_inventory(defines.inventory.chest)
			local base = next(base_inventory.get_contents())
			local catalyst = next(catalyst_inventory.get_contents())
			local modifier = next(modifier_inventory.get_contents())
			if base and catalyst and modifier then
				local reaction = data.reaction
				reaction.reactants["base"] = base
				reaction.reactants["catalyst"] = catalyst
				reaction.reactants["modifier"] = modifier
				reaction.products["result"] = base
				reaction.products["bonus"] = catalyst
				reaction.products["remainder"] = modifier
				base_inventory.remove({name = base, count = 1})
				catalyst_inventory.remove({name = catalyst, count = 1})
				modifier_inventory.remove({name = modifier, count = 1})
				return true
			end
			return false
		end,
	},
}
for _, building_definition in pairs(BUILDING_DEFINITIONS) do
	building_definition.has_reactant = {}
	for _, reactant_name in ipairs(building_definition.reactants) do
		building_definition.has_reactant[reactant_name] = true
	end
	building_definition.has_product = {}
	for _, product_name in ipairs(building_definition.products) do building_definition.has_product[product_name] = true end
end
