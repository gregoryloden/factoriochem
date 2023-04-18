-- Global constants
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


-- Constants
local MOLECULE_ITEM_PREFIX_MATCH = "^"..MOLECULE_ITEM_PREFIX
local ATOM_ITEM_PREFIX_MATCH = "^"..ATOM_ITEM_PREFIX
local PARSE_MOLECULE_ROW_MATCH = "([^"..ATOM_ROW_SEPARATOR.."]+)"..ATOM_ROW_SEPARATOR
local PARSE_MOLECULE_ATOM_MATCH = "([^"..ATOM_COL_SEPARATOR.."]*)"..ATOM_COL_SEPARATOR


-- Global utilities
function parse_molecule_id(molecule)
	local shape = {}

	-- extract the initial data from the molecule
	local grid_height = 0
	local grid_width = 0
	for molecule_row in string.gmatch(molecule..ATOM_ROW_SEPARATOR, PARSE_MOLECULE_ROW_MATCH) do
		grid_height = grid_height + 1
		local shape_row = {}
		local x = 0
		for atom_data in string.gmatch(molecule_row..ATOM_COL_SEPARATOR, PARSE_MOLECULE_ATOM_MATCH) do
			x = x + 1
			local symbol = string.match(atom_data, "%a+")
			if symbol then
				local atom = {symbol = symbol}
				local up = string.match(atom_data, "^%d")
				if up then atom.up = tonumber(up) end
				local right = string.match(atom_data, "%d$")
				if right then atom.right = tonumber(right) end
				shape_row[x] = atom
			end
		end
		if x > grid_width then grid_width = x end
		shape[grid_height] = shape_row
	end

	-- add corresponding down and left bonds and add coordinates
	for y, shape_row in pairs(shape) do
		for x, atom in pairs(shape_row) do
			if atom.up then shape[y - 1][x].down = atom.up end
			if atom.right then shape_row[x + 1].left = atom.right end
			atom.x = x
			atom.y = y
		end
	end
	return shape, grid_height, grid_width
end

function parse_molecule(molecule)
	if string.find(molecule, MOLECULE_ITEM_PREFIX_MATCH) then
		return parse_molecule_id(string.sub(molecule, #MOLECULE_ITEM_PREFIX + 1))
	elseif string.find(molecule, ATOM_ITEM_PREFIX_MATCH) then
		return {{{symbol = string.sub(molecule, #ATOM_ITEM_PREFIX + 1), x = 1, y = 1}}}, 1, 1
	else
		error("Unexpected molecule ID \""..molecule.."\"")
	end
end

function assemble_molecule(shape, height, width)
	if height == 1 and width == 1 then return ATOM_ITEM_PREFIX..shape[1][1].symbol end
	local builder = {MOLECULE_ITEM_PREFIX}
	for y = 1, height do
		shape_row = shape[y]
		if y > 1 then table.insert(builder, ATOM_ROW_SEPARATOR) end
		local next_col = 1
		for x = 1, width do
			atom = shape_row[x]
			if atom then
				while next_col < x do
					table.insert(builder, ATOM_COL_SEPARATOR)
					next_col = next_col + 1
				end
				if atom.up then table.insert(builder, atom.up) end
				table.insert(builder, atom.symbol)
				if atom.right then table.insert(builder, atom.right) end
			end
		end
	end
	return table.concat(builder)
end

function parse_target(target)
	return tonumber(string.sub(target, -4, -4)), -- y_scale
		tonumber(string.sub(target, -3, -3)), -- x_scale
		tonumber(string.sub(target, -2, -2)) + 1, -- y
		tonumber(string.sub(target, -1, -1)) + 1 -- x
end

function parse_atom_bond(atom_bond)
	return tonumber(string.sub(atom_bond, -5, -5)), -- y_scale
		tonumber(string.sub(atom_bond, -4, -4)), -- x_scale
		tonumber(string.sub(atom_bond, -3, -3)) + 1, -- y
		tonumber(string.sub(atom_bond, -2, -2)) + 1, -- x
		string.sub(atom_bond, -1, -1) -- direction
end

function write_molecule_id_to_combinator(behavior, molecule_id)
end

function read_molecule_id_from_combinator(behavior)
	return ""
end
