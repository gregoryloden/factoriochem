ATOM_ROWS = {
	-- Row 1
	{"H", "He"},
	-- Row 2
	{"Li", "Be", "B", "C", "N", "O", "F", "Ne"},
	-- Row 3
	{"Na", "Mg", "Al", "Si", "P", "S", "Cl", "Ar"},
	-- Row 4
	{"K", "Ca", "Sc", "Ti", "V", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Ge", "As", "Se", "Br", "Kr"},
	-- Row 5
	{"Rb", "Sr", "Y", "Zr", "Nb", "Mo", "Tc", "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn", "Sb", "Te", "I", "Xe"},
	-- Row 6
	{
		"Cs", "Ba",
		"La", "Ce", "Pr", "Nd", "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb",
		"Lu", "Hf", "Ta", "W", "Re", "Os", "Ir", "Pt", "Au", "Hg", "Tl", "Pb", "Bi", "Po", "At", "Rn",
	},
	-- Row 7
	{
		"Fr", "Ra",
		"Ac", "Th", "Pa", "U", "Np", "Pu", "Am", "Cm", "Bk", "Cf", "Es", "Fm", "Md", "No",
		"Lr", "Rf", "Db", "Sg", "Bh", "Hs", "Mt", "Ds", "Rg", "Cn", "Nh", "Fl", "Mc", "Lv", "Ts", "Og",
	},
}
ALL_ATOMS = {}
ATOM_ROW_SEPARATOR = "|"
ATOM_COL_SEPARATOR = "-"

local atomic_number = 0
for row_n, atoms_row in ipairs(ATOM_ROWS) do
	atoms_in_row = #atoms_row
	for i, symbol in ipairs(atoms_row) do
		atomic_number = atomic_number + 1
		local bonds = 0
		if i >= atoms_in_row - 4 then
			bonds = atoms_in_row - i
		elseif i == atoms_in_row - 5 then
			bonds = 3
		elseif i <= 2 then
			bonds = i
		end
		local atom = {
			symbol = symbol,
			bonds = bonds,
			row = row_n,
			number = atomic_number,
			localised_name = {"factoriochem-atom."..symbol},
		}
		ALL_ATOMS[symbol] = atom
		ALL_ATOMS[atomic_number] = atom
	end
end
