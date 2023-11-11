# FactorioChem
FactorioChem Proof-of-Concept - SpaceChem in Factorio. Factorio by Wube. SpaceChem by Zachtronics Industries.

Design and shape molecules in 2D space within the confines of a single item slot.

https://mods.factorio.com/mod/FactorioChem  

# Description
What if Factorio items had physical shape and occupied physical space?

This mod explores the idea of manipulating molecules like SpaceChem by Zachtronics Industries. In this mod, you'll rotate, bond, fission, and splice molecules and more to obtain the right ingredients to produce science.

![Science assembling machines](https://raw.githubusercontent.com/gregoryloden/factoriochem/main/overview/science.png)

The thing is, there are a lot of possible molecules. Molecules have shape, and depending on how you configure your assembly buildings to position them, the resulting reactions will cause totally different results. Solve open-ended puzzles around manufacturing molecules to obtain the progressively more complicated sets of molecules you need for science.

Aside from space science, science recipes exclusively require molecule ingredients, and only require molecule reaction buildings and previous science packs as technology prerequisites.

### Please note: this mod generates over 59,000 different items - it takes a long time to load

There are too many possible molecule conversions to make a recipe for each one, so instead, most buildings added by this mod use a pseudo-assembling-machine system that dynamically converts molecules based on presets that you specify in each machine. Settings are copy-pastable and blueprintable. (Undo/redo also works but only with robots; hand-mined buildings will lose their settings)

## How do the machines work?

Molecule reaction buildings look something like this:

![A molecule reaction building](https://raw.githubusercontent.com/gregoryloden/factoriochem/main/overview/building.png)

To handle the dynamic nature of transforming molecules, molecule reaction buildings use a separate set of inventories to hold each part of its reaction. Every building consumes up to 3 inputs and produces up to 3 outputs. Each input and output has its own inventory in a specific position per building, and is moved into or out of the building via loaders (technically you can also use inserters).

Every molecule reaction building contains a GUI that looks similar to this:

![The molecule reaction building GUI](https://raw.githubusercontent.com/gregoryloden/factoriochem/main/overview/gui.png)

Inputs on the left, outputs on the right, and up to 3 settings in the middle.

When a building is idle, it continually checks its inputs and settings to see if they produce a valid reaction. If so, the inputs are consumed and the assembly building begins a "craft" of its fixed recipe; once the recipe is complete, the building places the results in the output inventories. Should a building be mined in the middle of a reaction, the ingredients of the unfinished reaction are returned to the miner just like regular assembling machines.

The lower half of each building's GUI is a demo area where you can test out reactions with different settings. Some example reactions are provided for each building type.

For convenience you can refer to the periodic table accessible through a bottom bar shortcut or in the GUI.

## How do molecules work?

Every molecule is a grid of atoms, up to 3x3. This is the largest that either dimension can be - neither dimension can be 4 or greater.

Each atom gets its own item, as well as many of the possible molecules (see the next section for further explanation).

Within each molecule, all atoms are connected to each other through vertically or horizontally adjacent bonds. Any two atoms can be connected by up to 3 bonds, and any single atom can be connected by bonds up to its bond count (but not more). Bond count per atom is indicated by its color and provided in its description.

Atoms and molecules all have a stack limit of 1 and cannot be handcrafted. Molecule items are hidden and there are no recipes to convert one molecule into another.

There are four basic interactions involved in modifying molecules, split into two categories:
- Fusion/Fission: combines two atoms into one or splits one atom into two (but no nuclear explosions, sorry). Fusion and fission perform simple additions and subtractions on the atomic numbers of the atoms used, so the total proton count never changes. Depending on the building, fission and fusion either apply to lone atoms or to atoms within molecules.
- Bonding/Debonding: add or remove a bond between two atoms. This can be used to join two molecules or split one molecule into two, or to add or remove a bond between existing atoms within a molecule. The atoms themselves do not change (unless specified due to settings).

Additionally, Splicing joins two molecules into one by overlapping them and performing fusion on the overlapping atoms, and Severing splits one molecule into two by performing fission on one atom. Bonds are moved between the resulting molecules but are not added or removed otherwise.

## How many molecules are there?

To work around item limitations, molecules are divided into two categories: simple molecules and complex molecules.

Simple molecules are the single- and multi-atom molecules that fit all of these properties:
- Aside from single atoms, all atoms in all simple molecules have bonds exactly equal to their bond count. Multi-atom radical molecules are never simple molecules.
- Molecules consisting of only H, C, N, and O can contain up to 8 atoms
- Molecules with 4 atoms can contain elements up to Ne
- Molecules with 3 atoms can contain elements up to Ar
- Molecules with 2 atoms can contain any elements
- Molecules with 5-8 atoms can contain single and double bonds, but not triple bonds or higher
- Molecules with 2-4 atoms can contain single, double, and triple bonds

There are 59,584 simple molecules and each simple molecule receives its own unique item. (Fun fact: multi-atom simple molecules always have an even sum of atomic numbers)

Complex molecules do not have the same restrictions as simple molecules, and
- can contain up to 9 atoms,
- can always form up to triple bonds, and
- can be radicals.

However, they are mostly visually indistinguishable from each other. To see what's in a complex molecule, you'll have to inspect it in your inventory. There are 68,574,768,928,886,778 possible complex molecules, minus the 59,584 simple molecules. There are 150 different shapes for complex molecules, and each shape gets its own item.

![A sample of molecules showing the contents of a complex molecule](https://raw.githubusercontent.com/gregoryloden/factoriochem/main/overview/complex.png)

All sciences only use simple molecule ingredients and can be obtained without ever creating complex molecules, but you can always create complex molecules anyways and most molecules are easier to create using complex molecules as intermediates.

Bond, Debond, Splice, and Sever buildings allow optional fission or fusion on atoms within molecules - this is necessary to ensure that there is always a way to create simple molecules without ever creating complex molecules.

----

Likely not compatible with mods that modify sciences or heavily modify the technology tree (by default; you can enable a setting to prevent changes to technologies or science recipes), but likely compatible with most other mods.

I don't currently have anything I'm planning on adding but definitely leave a suggestion if there's something you'd like to see.

# Gallery
![Molecule buildings sorting water](https://raw.githubusercontent.com/gregoryloden/factoriochem/main/overview/gallery1.png)

![Molecule reaction building GUI](https://raw.githubusercontent.com/gregoryloden/factoriochem/main/overview/gallery2.png)

![Molecule reaction building examples](https://raw.githubusercontent.com/gregoryloden/factoriochem/main/overview/gallery3.png)

![Blueprint to convert 12 water per second to Neon](https://raw.githubusercontent.com/gregoryloden/factoriochem/main/overview/gallery4.png)

![A mess of belts and buildings making science molecules](https://raw.githubusercontent.com/gregoryloden/factoriochem/main/overview/gallery5.png)

![The Periodic Table GUI](https://raw.githubusercontent.com/gregoryloden/factoriochem/main/graphics/tips-and-tricks/gui-periodic-table.png)

![The Molecule Builder GUI](https://raw.githubusercontent.com/gregoryloden/factoriochem/main/graphics/tips-and-tricks/gui-molecule-builder.png)
