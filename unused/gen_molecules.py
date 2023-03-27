class Atom:
	def __init__(self, symbol, bonds):
		self.symbol = symbol
		self.bonds = bonds
		ALL_ATOMS.append(self)
		ATOMS_ACCEPT_BONDS[bonds].append(self)
		self.number = len(ALL_ATOMS)
#		for i in range(bonds + 1):
#			ATOMS_ACCEPT_BONDS[i].append(self)

class AtomSlot:
	def __init__(self):
		self.left_bonds = 0
		self.up_bonds = 0
		self.right_bonds = 0
		self.down_bonds = 0
		self.bond_depth = 0
		self.atom = None
		self.valid_atoms = None

GRID_WIDTH = 3
GRID_HEIGHT = 3
GRID_AREA = GRID_WIDTH * GRID_HEIGHT
ALL_ATOMS = []
ATOMS_ACCEPT_BONDS = [ALL_ATOMS, [], [], [], []]
ATOM_H = Atom("H", 1)
#ATOM_He = Atom("He", 0)
#ATOM_Li = Atom("Li", 1)
#ATOM_Be = Atom("Be", 2)
#ATOM_B = Atom("B", 3)
ATOM_C = Atom("C", 4)
ATOM_N = Atom("N", 3)
ATOM_O = Atom("O", 2)
#ATOM_F = Atom("F", 1)
#ATOM_Ne = Atom("Ne", 0)
#ATOM_Na = Atom("Na", 1)
#ATOM_Mg = Atom("Mg", 2)
#ATOM_Al = Atom("Al", 3)
#ATOM_Si = Atom("Si", 4)
#ATOM_P = Atom("P", 3)
#ATOM_S = Atom("S", 2)
#ATOM_Cl = Atom("Cl", 1)
#ATOM_Ar = Atom("Ar", 0)
MAX_BONDS = max(atom.bonds for atom in ALL_ATOMS)
MAX_SINGLE_BONDS = 2
GRID = []
MOLECULES = set()
GRID_WIDTH_M1 = GRID_WIDTH - 1
GRID_HEIGHT_M1 = GRID_HEIGHT - 1
#8 atoms for HCNO
#4 atoms for everything up to Ne
#3 atoms for everything up to Ar
MAX_ATOMS = 8
#MAX_ATOMS = GRID_AREA
MOLECULE_BUILDER = []
ATOM_ROW_SEPARATOR = "|"
ATOM_COL_SEPARATOR = "-"
MOLECULES = []

def shape_check_2_2(shape_n):
	top_row_mask = 0b11
	left_col_mask = 0b101
	return shape_n & top_row_mask and shape_n & left_col_mask

def shape_check_3_2(shape_n):
	top_row_mask = 0b111
	left_col_mask = 0b1001
	return shape_n & top_row_mask and shape_n & left_col_mask

def shape_check_3_3(shape_n):
	top_row_mask = 0b111
	left_col_mask = 0b1001001
	return shape_n & top_row_mask and shape_n & left_col_mask

shape_check = {2: {2: shape_check_2_2}, 3: {2: shape_check_3_2, 3: shape_check_3_3}}[GRID_WIDTH][GRID_HEIGHT]

#Generation rules v2:
#- Build a list of all possible "shapes" of atoms, 2^area possibilities (each cell can have an atom or not)
#- For each shape, recursively assign bonds:
#	- Atoms next to each other are not necessarily bonded
#	- BFS to determine what atoms to do next:
#		- can only bond to already-bonded cell if its depth matches what would be the next bond depth
#	- Can only accept molecule once all cells are bonded
#	- Abandon molecule if we reach end of BFS and not all cells are visited/bonded
#	- In each recursion, the bond depth for the current slot has already been set
def gen_molecule_bonds(grid_i_i, grid_is, atom_count):
	if grid_i_i >= len(grid_is):
		#only generate a molecule if we reached all the atoms
		if grid_i_i == atom_count:
			assign_valid_atoms(grid_is)
			gen_molecules(0, grid_is)
		return
	grid_i = grid_is[grid_i_i]
	slot = GRID[grid_i]
	new_bonds_max = MAX_BONDS - slot.left_bonds - slot.up_bonds - slot.right_bonds - slot.down_bonds

	#no room for new bonds on this molecule, keep going
	if new_bonds_max == 0:
		gen_molecule_bonds(grid_i_i + 1, grid_is, atom_count)
		return

	#calculate the max bonds per direction
	single_bonds_max = min(MAX_SINGLE_BONDS, new_bonds_max)
	bond_depth_p1 = slot.bond_depth + 1
	if grid_i % GRID_WIDTH == 0:
		left_bonds_max = 0
	else:
		left_grid_i = grid_i - 1
		left_slot = GRID[left_grid_i]
		if not left_slot:
			left_bonds_max = 0
		else:
			expand_left = left_slot.bond_depth == 0
			if expand_left:
				left_bonds_max = single_bonds_max
			elif left_slot.bond_depth == bond_depth_p1:
				left_bonds_max = min(
					single_bonds_max,
					MAX_BONDS - left_slot.left_bonds - left_slot.up_bonds - left_slot.down_bonds)
			else:
				left_bonds_max = 0
	if grid_i // GRID_WIDTH == 0:
		up_bonds_max = 0
	else:
		up_grid_i = grid_i - GRID_WIDTH
		up_slot = GRID[up_grid_i]
		if not up_slot:
			up_bonds_max = 0
		else:
			expand_up = up_slot.bond_depth == 0
			if expand_up:
				up_bonds_max = single_bonds_max
			elif up_slot.bond_depth == bond_depth_p1:
				up_bonds_max = min(
					single_bonds_max,
					MAX_BONDS - up_slot.left_bonds - up_slot.up_bonds - up_slot.right_bonds)
			else:
				up_bonds_max = 0
	if grid_i % GRID_WIDTH == GRID_WIDTH_M1:
		right_bonds_max = 0
	else:
		right_grid_i = grid_i + 1
		right_slot = GRID[right_grid_i]
		if not right_slot:
			right_bonds_max = 0
		else:
			expand_right = right_slot.bond_depth == 0
			if expand_right:
				right_bonds_max = single_bonds_max
			elif right_slot.bond_depth == bond_depth_p1:
				right_bonds_max = min(
					single_bonds_max,
					MAX_BONDS - right_slot.up_bonds - right_slot.right_bonds - right_slot.down_bonds)
			else:
				right_bonds_max = 0
	if grid_i // GRID_WIDTH == GRID_HEIGHT_M1:
		down_bonds_max = 0
	else:
		down_grid_i = grid_i + GRID_WIDTH
		down_slot = GRID[down_grid_i]
		if not down_slot:
			down_bonds_max = 0
		else:
			expand_down = down_slot.bond_depth == 0
			if expand_down:
				down_bonds_max = single_bonds_max
			elif down_slot.bond_depth == bond_depth_p1:
				down_bonds_max = min(
					single_bonds_max,
					MAX_BONDS - down_slot.left_bonds - down_slot.right_bonds - down_slot.down_bonds)
			else:
				down_bonds_max = 0

	#iterate each permutation of bond numbers per direction, ensuring we don't go over the limit
	for left_bonds in range(left_bonds_max + 1):
		if left_bonds > 0:
			left_slot.right_bonds = left_bonds
			slot.left_bonds = left_bonds
			if left_bonds == 1 and expand_left:
				left_slot.bond_depth = bond_depth_p1
				grid_is.append(left_grid_i)
		bonds_after_left = new_bonds_max - left_bonds
		up_bonds_loop_max = min(bonds_after_left, up_bonds_max)
		for up_bonds in range(up_bonds_loop_max + 1):
			if up_bonds > 0:
				up_slot.down_bonds = up_bonds
				slot.up_bonds = up_bonds
				if up_bonds == 1 and expand_up:
					up_slot.bond_depth = bond_depth_p1
					grid_is.append(up_grid_i)
			bonds_after_up = bonds_after_left - up_bonds
			right_bonds_loop_max = min(bonds_after_up, right_bonds_max)
			for right_bonds in range(right_bonds_loop_max + 1):
				if right_bonds > 0:
					right_slot.left_bonds = right_bonds
					slot.right_bonds = right_bonds
					if right_bonds == 1 and expand_right:
						right_slot.bond_depth = bond_depth_p1
						grid_is.append(right_grid_i)
				down_bonds_loop_max = min(bonds_after_up - right_bonds, down_bonds_max)
				for down_bonds in range(down_bonds_loop_max + 1):
					if down_bonds > 0:
						down_slot.up_bonds = down_bonds
						slot.down_bonds = down_bonds
						if down_bonds == 1 and expand_down:
							down_slot.bond_depth = bond_depth_p1
							grid_is.append(down_grid_i)
					#deep in here, advance to the next atom in the grid
					gen_molecule_bonds(grid_i_i + 1, grid_is, atom_count)
				if down_bonds_loop_max > 0:
					down_slot.up_bonds = 0
					slot.down_bonds = 0
					if expand_down:
						down_slot.bond_depth = 0
						grid_is.pop()
			if right_bonds_loop_max > 0:
				right_slot.left_bonds = 0
				slot.right_bonds = 0
				if expand_right:
					right_slot.bond_depth = 0
					grid_is.pop()
		if up_bonds_loop_max > 0:
			up_slot.down_bonds = 0
			slot.up_bonds = 0
			if expand_up:
				up_slot.bond_depth = 0
				grid_is.pop()
	if left_bonds_max > 0:
		left_slot.right_bonds = 0
		slot.left_bonds = 0
		if expand_left:
			left_slot.bond_depth = 0
			grid_is.pop()

def assign_valid_atoms(grid_is):
	for grid_i in grid_is:
		slot = GRID[grid_i]
		slot.valid_atoms = ATOMS_ACCEPT_BONDS[slot.left_bonds + slot.up_bonds + slot.right_bonds + slot.down_bonds]

#molecule_total = 0
def gen_molecules(grid_i_i, grid_is):
#	new_molecules = 1
#	for grid_i in grid_is:
#		new_molecules *= len(GRID[grid_i].valid_atoms)
#	global molecule_total
#	molecule_total += new_molecules
#	return
	if grid_i_i < len(grid_is):
		slot = GRID[grid_is[grid_i_i]]
		for atom in slot.valid_atoms:
			slot.atom = atom
			gen_molecules(grid_i_i + 1, grid_is)
	else:
		has_new_element = False
		MOLECULE_BUILDER.clear()
		last_row = 0
		last_col = 0
		for grid_i in range(GRID_AREA):
			slot = GRID[grid_i]
			if not slot:
				continue
			row = grid_i // GRID_WIDTH
			col = grid_i % GRID_WIDTH
			if row > last_row:
				last_row = row
				MOLECULE_BUILDER.append(ATOM_ROW_SEPARATOR)
				last_col = 0
			while last_col < col:
				MOLECULE_BUILDER.append(ATOM_COL_SEPARATOR)
				last_col += 1
			if slot.up_bonds > 0:
				MOLECULE_BUILDER.append(str(slot.up_bonds))
			MOLECULE_BUILDER.append(slot.atom.symbol)
			if slot.right_bonds > 0:
				MOLECULE_BUILDER.append(str(slot.right_bonds))
#			has_new_element = has_new_element or (slot.atom.symbol != "H" and slot.atom.symbol != "C" and slot.atom.symbol != "O" and slot.atom.symbol != "N")
		#f = "".join(MOLECULE_BUILDER)
		#if "L" not in f and "B" not in f and "F" not in f:
		#	return
		#fsplit = f.split("|")
		#if len(fsplit) == 3 and max(len(a.split(".")) for a in fsplit) == 3:
		#	return
#		if not has_new_element:
#			return
		MOLECULES.append("".join(MOLECULE_BUILDER))
		if len(MOLECULES) % 1000000 == 0:
			print(len(MOLECULES))
#		f = "".join(MOLECULE_BUILDER)
#		if f in MOLECULES:
#			raise "bogus"
#		MOLECULES.add(f)
#		MOLECULES.add("".join(MOLECULE_BUILDER))

#find all possible shapes and generate molecules from them
for shape_n in range(2 ** GRID_AREA):
	if not shape_check(shape_n):
		continue
	GRID.clear()
	for i in range(GRID_AREA):
		GRID.append(AtomSlot() if shape_n & (1 << i) else None)
	first_slot_i = next(i for (i, slot) in enumerate(GRID) if slot)
	atom_count = sum(1 for slot in GRID if slot)

	#stop if we have too many atoms
	if atom_count > MAX_ATOMS:
		continue

	#BFS to check if all atoms are reachable
	GRID[first_slot_i].bond_depth = 1
	check_slot_is = [first_slot_i]
	check_slot_i_i = 0
	while check_slot_i_i < len(check_slot_is):
		check_slot_i = check_slot_is[check_slot_i_i]
		adjacent_slot_is = []
		if check_slot_i % GRID_WIDTH > 0:
			adjacent_slot_is.append(check_slot_i - 1)
		if check_slot_i // GRID_WIDTH > 0:
			adjacent_slot_is.append(check_slot_i - GRID_WIDTH)
		if check_slot_i % GRID_WIDTH < GRID_WIDTH_M1:
			adjacent_slot_is.append(check_slot_i + 1)
		if check_slot_i // GRID_WIDTH < GRID_HEIGHT_M1:
			adjacent_slot_is.append(check_slot_i + GRID_WIDTH)
		for adjacent_slot_i in adjacent_slot_is:
			adjacent_slot = GRID[adjacent_slot_i]
			if adjacent_slot and adjacent_slot.bond_depth == 0:
				adjacent_slot.bond_depth = 1
				check_slot_is.append(adjacent_slot_i)
		check_slot_i_i += 1
	if len(check_slot_is) < atom_count:
		continue

	#this is a valid shape, reset the bond depths and start searching for molecules
	for check_slot_i in check_slot_is:
		GRID[check_slot_i].bond_depth = 0
	GRID[first_slot_i].bond_depth = 1
	gen_molecule_bonds(0, [first_slot_i], atom_count)




#print(f"Molecules total for {GRID_WIDTH}x{GRID_HEIGHT} @ <={MAX_SINGLE_BONDS} bonds, max {MAX_ATOMS} atoms: {molecule_total}")
all_atom_symbols = ",".join(atom.symbol for atom in ALL_ATOMS)
print(f"Molecules total for {GRID_WIDTH}x{GRID_HEIGHT} @ <={MAX_SINGLE_BONDS} bonds, max {MAX_ATOMS} atoms of {all_atom_symbols}: {len(MOLECULES)}")

import random
import re
molecules = list(MOLECULES)
print("")
while True:
	molecule = random.choice(molecules)
	print(molecule + "\n")
	all_lines = []
	for molecule_row in molecule.split(ATOM_ROW_SEPARATOR):
		lines = ["", "", "", ""]
		up_bondss = []
		for atom in molecule_row.split(ATOM_COL_SEPARATOR):
			if atom == "":
				lines[3] += "      "
				up_bondss.append(0)
				continue
			symbol = re.search("[A-Z][a-z]?", atom).group(0)
			right_bonds_s = atom[-1]
			right_bonds = int(right_bonds_s) if right_bonds_s.isdigit() else 0
			lines[3] += " " + symbol.ljust(2) + (f"-{right_bonds}-" if right_bonds > 0 else "   ")
			up_bonds_s = atom[0]
			up_bondss.append(int(up_bonds_s) if up_bonds_s.isdigit() else 0)
		for up_bonds in up_bondss:
			if up_bonds == 0:
				lines[0] += "      "
				lines[1] += "      "
				lines[2] += "      "
			else:
				lines[0] += " |    "
				lines[1] += f" {up_bonds}    "
				lines[2] += " |    "
		all_lines.extend(lines)
	for line in all_lines[3:]:
		print(line)
	print("")
	if len(input("")) != 0:
		break









#Terminology: "#-radical" for molecules with # unfilled bonds

