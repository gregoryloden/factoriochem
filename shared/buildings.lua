return {
	["molecule-rotater"] = {
		building_design = "assembling-machine-3",
		item_order = "a",
		reactants = {[BASE_NAME] = true, [CATALYST_NAME] = true, [MODIFIER_NAME] = true},
		products = {[RESULT_NAME] = true, [BONUS_NAME] = true, [REMAINDER_NAME] = true},
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
