BUILDING_DEFINITIONS = {
	["molecule-rotater"] = {
		building_design = "assembling-machine-3",
		item_order = "b",
		reactants = {BASE_NAME, CATALYST_NAME, MODIFIER_NAME},
		products = {RESULT_NAME, BONUS_NAME, REMAINDER_NAME},
		reaction = function(reaction)
			local reactants = reaction.reactants
			-- TODO: real reaction
			if reactants.base and reactants.catalyst and reactants.modifier then
				reaction.products.result = reactants.base
				reaction.products.bonus = reactants.catalyst
				reaction.products.remainder = reactants.modifier
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
