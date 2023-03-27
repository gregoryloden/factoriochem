class Atom:
	def __init__(self, symbol, bonds):
		self.symbol = symbol
		self.bonds = bonds
		for i in range(bonds + 1):
			ATOMS_ACCEPT_BONDS[i].append(self)

class AtomSlot:
	def __init__(self):
		self.atom = None
		self.left_bonds = 0
		self.up_bonds = 0
		self.right_bonds = 0
		self.down_bonds = 0
		self.available_bonds = 0
		self.bond_depth = None

#class GenMoleculesData:
#	def __init__(self):
#		pass

GRID_WIDTH = 2
GRID_HEIGHT = 2
GRID_AREA = GRID_WIDTH * GRID_HEIGHT
ALL_ATOMS = []
ATOMS_ACCEPT_BONDS = [ALL_ATOMS, [], [], [], []]
ATOM_None = Atom(".", 0)
ALL_ATOMS.pop()
ATOM_H = Atom("H", 1)
ATOM_He = Atom("He", 0)
ATOM_Li = Atom("Li", 1)
ATOM_Be = Atom("Be", 2)
ATOM_B = Atom("B", 3)
ATOM_C = Atom("C", 4)
ATOM_N = Atom("N", 3)
ATOM_O = Atom("O", 2)
ATOM_F = Atom("F", 1)
ATOM_Ne = Atom("Ne", 0)
MAX_BONDS = max(atom.bonds for atom in ALL_ATOMS)
ATOMS_ACCEPT_BONDS[0] = [None]
GRID = [AtomSlot() for _ in range(GRID_AREA)]
#GEN_MOLECULES_DATA_POOL = [GenMoleculesData() for _ in range(GRID_AREA)]
MOLECULES = set()
GRID_WIDTH_M1 = GRID_WIDTH - 1
GRID_HEIGHT_M1 = GRID_HEIGHT - 1

def grid_check_2_2():
	return GRID[0].atom or GRID[2].atom

def grid_check_3_3():
	return GRID[0].atom or GRID[3].atom or GRID[6].atom

grid_check = {2: {2: grid_check_2_2}, 3: {3: grid_check_3_3}}[GRID_WIDTH][GRID_HEIGHT]


#Generation rules:
#- Atoms can expand left and up, but can only form bonds to existing atoms right and down
#- Each atom is responsible for setting and clearing its neighbors - the start of a recursion at a spot assumes the atom is already there, and does not delete it
#- Maintain a list of atoms to expand, BFS-style; each recursion tracks which atoms it added that are further in the recursion
#	- Recursion proceeds linearly in the BFS list
#- All recursions reset values as they leave
#- Branching atoms (ex C top left): ?????????????????????????????????????
#
#Parameters:
#grid_i: the index of the current atom slot for this atom/recursion
#atoms: the BFS list of atoms
#atoms_i: the position in the BFS list of atoms for this atom/recursion
def gen_molecules(atoms, atoms_i):
	if atoms_i >= len(atoms):
		#TODO
		return
	grid_i = atoms[atoms_i]
	slot = GRID[grid_i]
	single_bonds_max = min(3, slot.available_bonds)
	if grid_i % GRID_WIDTH == 0:
		left_bonds_max = 0
	else:
		left_slot = GRID[grid_i - 1]
		left_bonds_max = 0 if slot.atom else single_bonds_max
	#TODO do like left/right/down
	up_bonds_max = single_bonds_max if grid_i // GRID_WIDTH > 0 and not GRID[grid_i - GRID_HEIGHT].atom else 0
	if grid_i % GRID_WIDTH == GRID_WIDTH_M1:
		right_bonds_max = 0
		gen_right = False
	else:
		right_slot = GRID[grid_i + 1]
		if right_slot.atom:
			gen_right = False
			right_bonds_max = right_slot.available_bonds
		else:
			gen_right = True
			right_bonds_max = single_bonds_max
	if grid_i // GRID_WIDTH == GRID_HEIGHT_M1:
		down_bonds_max = 0
		gen_down = False
	else:
		down_slot = GRID[grid_i + GRID_WIDTH]
		if down_slot.atom:
			gen_down = False
			down_bonds_max = down_slot.available_bonds
		else:
			gen_down = True
			down_bonds_max = single_bonds_max
	for left_bonds in range(slot.available_bonds + 1):
		for left_atom in ATOMS_ACCEPT_BONDS[bonds]:
			if left_atom:
				left_slot = GRID[grid_i - 1]
				left_slot.atom = left_atom
				left_slot.right_bonds = left_bonds
				slot.available_bonds -= left_bonds
			#TODO
			pass
			if left_atom:
				#TODO
				pass
		#TODO
		pass

#base_gen_molecules_data = GEN_MOLECULES_DATA_POOL.pop()
#gen_molecules_atoms = [base_gen_molecules_data]
gen_molecules_atoms = []
for top_col in range(GRID_WIDTH):
	gen_molecules_atoms.append(top_col)
	for atom in ALL_ATOMS:
		slot = GRID[top_col]
		slot.atom = atom
		slot.available_bonds = atom.bonds
		gen_molecules(gen_molecules_atoms, 0)
	GRID[top_col].atom = None
	gen_molecules_atoms.pop()
















#Terminology: "#-radical" for molecules with # unfilled bonds

