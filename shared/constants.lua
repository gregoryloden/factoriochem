MAX_GRID_WIDTH = 3
MAX_GRID_HEIGHT = 3
MOLECULES_GROUP_NAME = "molecules"
ATOMS_SUBGROUP_PREFIX = "atoms-"
ATOM_ITEM_PREFIX = "atom-"
MOLECULE_ITEM_PREFIX = "molecule-"
COMPLEX_MOLECULE_ITEM_PREFIX = "complex-molecule-"
MOLECULE_ABSORBER_NAME = "molecule-absorber"
MOLECULE_REACTION_NAME = "molecule-reaction"
MOLECULE_REACTION_CHEST_NAME = MOLECULE_REACTION_NAME.."-chest"
MOLECULE_REACTION_LOADER_NAME = MOLECULE_REACTION_NAME.."-loader"
MOLECULE_REACTION_SETTINGS_NAME = MOLECULE_REACTION_NAME.."-settings"
MOLECULE_VOIDER_NAME = "molecule-voider"
MOLECULE_PRINTER_NAME = "molecule-printer"
MOLECULE_DETECTOR_NAME = "molecule-detector"
MOLECULE_DETECTOR_OUTPUT_NAME = MOLECULE_DETECTOR_NAME.."-output"
MOLECULE_INDICATOR_PREFIX = "molecule-indicator-"
BASE_NAME = "base"
CATALYST_NAME = "catalyst"
MODIFIER_NAME = "modifier"
RESULT_NAME = "result"
BYPRODUCT_NAME = "byproduct"
REMAINDER_NAME = "remainder"
MOLECULE_REACTION_REACTANT_NAMES = {BASE_NAME, CATALYST_NAME, MODIFIER_NAME}
MOLECULE_REACTION_PRODUCT_NAMES = {RESULT_NAME, BYPRODUCT_NAME, REMAINDER_NAME}
MOLECULE_REACTION_COMPONENT_NAMES = {}
MOLECULE_REACTION_IS_REACTANT = {}
for _, reactant_name in ipairs(MOLECULE_REACTION_REACTANT_NAMES) do
	table.insert(MOLECULE_REACTION_COMPONENT_NAMES, reactant_name)
	MOLECULE_REACTION_IS_REACTANT[reactant_name] = true
end
for _, product_name in ipairs(MOLECULE_REACTION_PRODUCT_NAMES) do
	table.insert(MOLECULE_REACTION_COMPONENT_NAMES, product_name)
end
MOLECULE_REACTION_COMPONENT_OFFSETS = {
	[BASE_NAME] = {x = -1, y = 1},
	[CATALYST_NAME] = {x = 0, y = 1},
	[MODIFIER_NAME] = {x = 1, y = 1},
	[RESULT_NAME] = {x = -1, y = -1},
	[BYPRODUCT_NAME] = {x = 0, y = -1},
	[REMAINDER_NAME] = {x = 1, y = -1},
}
MOLECULE_REACTION_REACTANTS_NAME = MOLECULE_REACTION_NAME.."-reactants"
MOLECULE_REACTION_SELECTOR_PREFIX = MOLECULE_REACTION_NAME.."-selector-"
ROTATION_SELECTOR_NAME = "rotation"
TARGET_SELECTOR_NAME = "target"
TARGET_SELECTOR_SUBGROUP = MOLECULE_REACTION_SELECTOR_PREFIX..TARGET_SELECTOR_NAME
ATOM_SELECTOR_NAME = "atom"
ATOM_BOND_SELECTOR_NAME = "atom-bond"
ATOM_BOND_INNER_SELECTOR_NAME = ATOM_BOND_SELECTOR_NAME.."-outer"
ATOM_BOND_INNER_SELECTOR_SUBGROUP = MOLECULE_REACTION_SELECTOR_PREFIX..ATOM_BOND_INNER_SELECTOR_NAME
ATOM_BOND_OUTER_SELECTOR_NAME = ATOM_BOND_SELECTOR_NAME.."-inner"
ATOM_BOND_OUTER_SELECTOR_SUBGROUP = MOLECULE_REACTION_SELECTOR_PREFIX..ATOM_BOND_OUTER_SELECTOR_NAME
DROPDOWN_SELECTOR_NAME = "dropdown"
COMPARISON_SELECTOR_VALUES = {"=", "<", ">", "≤", "≥", "≠"}
TEXT_SELECTOR_NAME = "text"
PERIODIC_TABLE_NAME = "periodic-table"
