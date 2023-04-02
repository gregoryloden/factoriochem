BUILDING_DEFINITIONS = {
	["molecule-rotater"] = {
		-- data fields
		building_design = "assembling-machine-3",
		item_order = "b",
		-- control fields
		reactants = {BASE_NAME, CATALYST_NAME, MODIFIER_NAME},
		products = {RESULT_NAME, BONUS_NAME, REMAINDER_NAME},
		selectors = {[BASE_NAME] = "rotation", [MODIFIER_NAME] = "rotation"},
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
	building_definition.has_component = {}
	for _, reactant_name in ipairs(building_definition.reactants) do
		building_definition.has_component[reactant_name] = true
	end
	for _, product_name in ipairs(building_definition.products) do
		building_definition.has_component[product_name] = true
	end
end
