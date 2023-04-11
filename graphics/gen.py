import os
import cv2
import numpy
import math
os.chdir(os.path.dirname(os.path.abspath(__file__)))


#Constants
MAX_GRID_WIDTH = 3
MAX_GRID_HEIGHT = 3
MAX_GRID_AREA = MAX_GRID_WIDTH * MAX_GRID_HEIGHT
BASE_ICON_SIZE = 64
BASE_ICON_MIPS = 4
MOLECULE_ICON_MIPS = 3
COLOR_FOR_BONDS = [
	(192, 240, 192, 0),
	(240, 240, 240, 0),
	(176, 176, 240, 0),
	(240, 176, 176, 0),
	(176, 176, 176, 0),
]
ATOM_ROWS = [
	#Row 1
	["H", "He"],
	#Row 2
	["Li", "Be", "B", "C", "N", "O", "F", "Ne"],
	#Row 3
	["Na", "Mg", "Al", "Si", "P", "S", "Cl", "Ar"],
	#Row 4
	["K", "Ca", "Sc", "Ti", "V", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Ge", "As", "Se", "Br", "Kr"],
	#Row 5
	["Rb", "Sr", "Y", "Zr", "Nb", "Mo", "Tc", "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn", "Sb", "Te", "I", "Xe"],
	#Row 6
	[
		"Cs", "Ba",
		"La", "Ce", "Pr", "Nd", "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb",
		"Lu", "Hf", "Ta", "W", "Re", "Os", "Ir", "Pt", "Au", "Hg", "Tl", "Pb", "Bi", "Po", "At", "Rn",
	],
	#Row 7
	[
		"Fr", "Ra",
		"Ac", "Th", "Pa", "U", "Np", "Pu", "Am", "Cm", "Bk", "Cf", "Es", "Fm", "Md", "No",
		"Lr", "Rf", "Db", "Sg", "Bh", "Hs", "Mt", "Ds", "Rg", "Cn", "Nh", "Fl", "Mc", "Lv", "Ts", "Og",
	],
]
ATOM_RADIUS_FRACTION = 30 / 64
ATOM_OUTLINE_RADIUS_FRACTION = 42 / 64
PRECISION_BITS = 8
PRECISION_MULTIPLIER = 1 << PRECISION_BITS
CIRCLE_DATA = {}
HCNO = ["H", "C", "N", "O"]
MAX_ATOMS = 8
MAX_ATOMS_HCNO = MAX_ATOMS
MAX_ATOMS_Ne = 4
MAX_ATOMS_Ar = 3
MAX_ATOMS_OTHER = 2
MAX_SINGLE_BONDS = 2
FONT = cv2.FONT_HERSHEY_SIMPLEX
FONT_SCALE_FRACTIONS = [0, 1.25 / 64, 1 / 64]
FONT_THICKNESS_FRACTION = 2 / 64
TEXT_COLOR = (0, 0, 0, 0)
TEXT_DATAS = {}
BOND_COLOR = (0, 0, 0, 0)
BOND_LENGTH_FRACTIONS = [0, 12 / 64, 12 / 64]
BOND_THICKNESS_FRACTION = 6 / 64
BOND_SPACING_FRACTION = 18 / 64
ITEM_GROUP_SIZE = 128
ITEM_GROUP_MIPS = 2
ROTATION_SELECTOR_COLOR = (224, 224, 192, 0)
ROTATION_SELECTOR_RADIUS_FRACTION = 24 / 64
ROTATION_SELECTOR_THICKNESS_FRACTION = 4 / 64
ROTATION_SELECTOR_ARROW_SIZE_FRACTION = 6 / 64
ROTATION_SELECTOR_DOT_RADIUS_FRACTION = 4 / 64
ROTATION_SELECTOR_OUTLINE_FRACTION = 4 / 64
TARGET_SELECTOR_DEFAULT_COLOR = (128, 128, 128, 0)
TARGET_SELECTOR_HIGHLIGHT_COLOR = (128, 224, 255, 0)
ATOM_BOND_SELECTOR_INNER_ARROW_SIZE_FRACTION = 18 / 64
ATOM_BOND_SELECTOR_INNER_ARROW_OFFSET_FRACTION = 6 / 64
BASE_OVERLAY_SIZE = 32
MOLECULIFIER_MOLECULE = "H--C|-He|N--O"
MOLECULE_ROTATOR_NAME = "molecule-rotator"
MOLECULE_ROTATOR_ICON_COLOR = (192, 192, 224, 0)
with open("base-graphics-path.txt", "r") as file:
	BASE_GRAPHICS_PATH = file.read()
MOLECULIFY_ARROW_COLOR = (64, 64, 224, 0)
MOLECULIFY_ARROW_THICKNESS_FRACTION = 6 / 64
MOLECULIFY_ARROW_SIZE_FRACTION = 8 / 64
ICON_OVERLAY_OUTLINE_COLOR = (64, 64, 64, 0)
SHAPE_BACKGROUND_COLOR = (128, 128, 128, 0)
REACTION_SETTINGS_RECT_HALF_WIDTH_FRACTION = 20 / 64
REACTION_SETTINGS_RECT_OUTER_THICKNESS_FRACTION = 16 / 64
REACTION_SETTINGS_OUTER_COLOR = (64, 64, 64, 0)
REACTION_SETTINGS_RECT_INNER_THICKNESS_FRACTION = 8 / 64
REACTION_SETTINGS_INNER_COLOR = (128, 128, 128, 0)
REACTION_SETTINGS_BOX_SIZE_FRACTION = 12 / 64
REACTION_SETTINGS_BOX_LEFT_SHIFT_FRACTION = 4 / 64


#Utility functions
def imwrite(file_path, image):
	cv2.imwrite(file_path, image, [cv2.IMWRITE_PNG_COMPRESSION, 9])

def write_images(folder, images):
	for (name, image) in images:
		imwrite(os.path.join(folder, name + ".png"), image)
	
def filled_mip_image(base_size, mips, color = None):
	shape = (base_size, sum(base_size >> i for i in range(mips)), 4)
	return numpy.full(shape, color, numpy.uint8) if color else numpy.zeros(shape, numpy.uint8)

def draw_coords(x, y):
	return (round((x - 0.5) * PRECISION_MULTIPLIER), round((y - 0.5) * PRECISION_MULTIPLIER))

def draw_radius(radius):
	return round((radius - 0.5) * PRECISION_MULTIPLIER)

def draw_alpha_on(image, draw):
	mask = numpy.zeros(image.shape[:2], numpy.uint8)
	draw(mask)
	mask_section = mask > 0
	image[:, :, 3][mask_section] = mask[mask_section]
	return mask

def draw_filled_circle_alpha(mask, draw_center, draw_radius):
	cv2.circle(mask, draw_center, draw_radius, 255, cv2.FILLED, cv2.LINE_AA, PRECISION_BITS)

def overlay_image(back_image, back_left, back_top, front_image, front_left, front_top, width, height):
	back_right = back_left + width
	back_bottom = back_top + height
	front_right = front_left + width
	front_bottom = front_top + height
	back_alpha = back_image[back_top:back_bottom, back_left:back_right, 3] / 255.0
	front_alpha = front_image[front_top:front_bottom, front_left:front_right, 3] / 255.0
	new_alpha = back_alpha + front_alpha * (1 - back_alpha)
	back_image[back_top:back_bottom, back_left:back_right, 3] = new_alpha * 255
	#prevent NaN issues on fully-transparent pixels
	new_alpha[new_alpha == 0] = 1
	for color in range(0, 3):
		back_color = back_image[back_top:back_bottom, back_left:back_right, color]
		front_color = front_image[front_top:front_bottom, front_left:front_right, color]
		back_image[back_top:back_bottom, back_left:back_right, color] = \
			back_color + (front_color * 1.0 - back_color) * front_alpha / new_alpha
	return back_image

def simple_overlay_image(back_image, front_image):
	shape = front_image.shape
	return overlay_image(back_image, 0, 0, front_image, 0, 0, shape[1], shape[0])

def simple_overlay_image_at(back_image, back_left, back_top, front_image):
	shape = front_image.shape
	return overlay_image(back_image, back_left, back_top, front_image, 0, 0, shape[1], shape[0])

def iter_mips(base_size, mips):
	place_x = 0
	for mip in range(mips):
		size = base_size >> mip
		yield (mip, place_x, size)
		place_x += size

def resize(image, width, height, multi_color_alpha_weighting = True):
	if multi_color_alpha_weighting:
		#in an image with different colors, each color should only affect its resulting pixel based on its alpha
		#to apply weights, multiply all colors by their alpha, then after resizing, divide by the alpha at that pixel
		#to start, we'll need the precision of floats
		image = image.astype(numpy.float32)
		#multiply each channel by the alpha
		alpha = image[:, :, 3]
		for channel in range(3):
			image[:, :, channel] *= alpha
		#resize the image now
		image = cv2.resize(image, (width, height), interpolation=cv2.INTER_AREA)
		#divide away the alpha, where it's not 0
		alpha = image[:, :, 3]
		has_alpha = alpha > 0
		alpha = alpha[has_alpha]
		for channel in range(3):
			image[:, :, channel][has_alpha] /= alpha
		#and now convert back to 8-bit, after rounding
		return numpy.around(image).astype(numpy.uint8)
	else:
		#every pixel color is the same already, we don't need to weight colors since the average will always be the same
		return cv2.resize(image, (width, height), interpolation=cv2.INTER_AREA)

def easy_mips(image, multi_color_alpha_weighting = True):
	#copy the entire outer mip, performance isn't really an issue
	(base_size, total_size, _) = image.shape
	mip_0 = image[:, 0:base_size]
	place_x = base_size
	for mip in range(1, 64):
		if place_x >= total_size:
			return image
		size = base_size >> mip
		image[0:size, place_x:place_x + size] = resize(mip_0, size, size, multi_color_alpha_weighting)
		place_x += size


#Sub-image generation
def get_circle_mip_datas(base_size, mips, y_scale, x_scale, y, x):
	base_size_data = CIRCLE_DATA.get(base_size, None)
	if not base_size_data:
		base_size_data = {}
		CIRCLE_DATA[base_size] = base_size_data
	y_scale_data = base_size_data.get(y_scale, None)
	if not y_scale_data:
		y_scale_data = {}
		base_size_data[y_scale] = y_scale_data
	scale_data = y_scale_data.get(x_scale, None)
	if not scale_data:
		scale = max(x_scale, y_scale)
		scale_data = {
			"scale": scale,
			"radius": ATOM_RADIUS_FRACTION * base_size / scale,
			"outline_radius": ATOM_OUTLINE_RADIUS_FRACTION * base_size / scale,
			"center_y_min": 0.5 * (1 + scale - y_scale),
			"center_x_min": 0.5 * (1 + scale - x_scale),
		}
		y_scale_data[x_scale] = scale_data
	y_data = scale_data.get(y, None)
	if not y_data:
		y_data = {}
		scale_data[y] = y_data
	mip_datas = y_data.get(x, None)
	if not mip_datas:
		mip_datas = {}
	elif mip_datas.get(mips - 1, False):
		return mip_datas
	y_data[x] = mip_datas
	scale = scale_data["scale"]
	center_y = base_size * (y + scale_data["center_y_min"]) / scale
	center_x = base_size * (x + scale_data["center_x_min"]) / scale
	for mip in range(mips):
		if mip_datas.get(mip, False):
			continue
		size = base_size >> mip
		shrink = 1 / (1 << mip)
		mip_center_x = center_x * shrink
		mip_center_y = center_y * shrink
		draw_center = draw_coords(mip_center_x, mip_center_y)
		alpha = numpy.zeros((size, size), numpy.uint8)
		draw_filled_circle_alpha(alpha, draw_center, draw_radius(scale_data["radius"] * shrink))
		outline_alpha = numpy.zeros((size, size), numpy.uint8)
		draw_filled_circle_alpha(outline_alpha, draw_center, draw_radius(scale_data["outline_radius"] * shrink))
		mip_datas[mip] = {
			"alpha": alpha,
			"outline_alpha": outline_alpha,
			"center_x": mip_center_x,
			"center_y": mip_center_y,
			"scale": scale,
		}
	return mip_datas

def get_text_data(base_size, mips, symbol):
	base_size_data = TEXT_DATAS.get(base_size, None)
	if not base_size_data:
		base_size_data = {}
		TEXT_DATAS[base_size] = base_size_data
	text_mips_data = base_size_data.get(mips, None)
	if not text_mips_data:
		text_mips_data = {}
		base_size_data[mips] = text_mips_data
	text_data = text_mips_data.get(symbol, None)
	if text_data:
		return text_data
	font_scale = FONT_SCALE_FRACTIONS[len(symbol)] * base_size
	font_thickness = int(FONT_THICKNESS_FRACTION * base_size)
	((text_width, text_height), _) = cv2.getTextSize(symbol, FONT, font_scale, font_thickness)
	#add a buffer in all directions so that we can adjust what part of the image we resize for a given
	#	mip/scale
	text_buffer_border = 1 << (mips - 1)
	for scale in range(2, max(MAX_GRID_WIDTH, MAX_GRID_HEIGHT) + 1):
		text_buffer_border = text_buffer_border * scale // math.gcd(text_buffer_border, scale)
	text_full_width = text_width + text_buffer_border * 2
	text_full_height = text_height + font_thickness * 3 + text_buffer_border * 2
	text_bottom_left = (text_buffer_border, text_buffer_border + text_height + font_thickness)
	text = numpy.full((text_full_height, text_full_width, 4), TEXT_COLOR, numpy.uint8)
	def draw_text(mask):
		cv2.putText(mask, symbol, text_bottom_left, FONT, font_scale, 255, font_thickness, cv2.LINE_AA)
	text_mask = draw_alpha_on(text, draw_text)

	#find the edges of the text
	for left_edge in range(text_full_width):
		if text_mask[:, left_edge].sum() > 0:
			break
	for top_edge in range(text_full_height):
		if text_mask[top_edge].sum() > 0:
			break
	for right_edge in range(text_full_width, -1, -1):
		if text_mask[:, right_edge - 1].sum() > 0:
			break
	for bottom_edge in range(text_full_height, -1, -1):
		if text_mask[bottom_edge - 1].sum() > 0:
			break
	text_data = {
		"image": text,
		"center_x": (left_edge + right_edge) / 2,
		"center_y": (top_edge + bottom_edge) / 2,
		"half_width": (right_edge - left_edge) / 2,
		"half_height": (bottom_edge - top_edge) / 2,
	}
	text_mips_data[symbol] = text_data
	return text_data


#Generate atom images
def gen_single_atom_shape_image(base_size, mips, y_scale, x_scale, y, x, color):
	#set the base color for this atom
	image = filled_mip_image(base_size, mips, color)
	mip_datas = get_circle_mip_datas(base_size, mips, y_scale, x_scale, y, x)
	for (mip, place_x, size) in iter_mips(base_size, mips):
		#patch over the circle alpha mask for each mip
		image[0:size, place_x:place_x + size, 3] = mip_datas[mip]["alpha"]
	return image

def gen_single_atom_image(base_size, mips, symbol, bonds, y_scale, x_scale, y, x):
	image = gen_single_atom_shape_image(base_size, mips, y_scale, x_scale, y, x, COLOR_FOR_BONDS[bonds])
	mip_datas = get_circle_mip_datas(base_size, mips, y_scale, x_scale, y, x)
	scale = max(x_scale, y_scale)
	for (mip, place_x, size) in iter_mips(base_size, mips):
		#overlay text by finding the best section to resize to match the target size and position
		#first determine the area we're going to draw to, in full pixel dimensions
		text_data = get_text_data(base_size, mips, symbol)
		text = text_data["image"]
		text_scale = scale << mip
		mip_data = mip_datas[mip]
		mip_center_x = place_x + mip_data["center_x"]
		mip_center_y = mip_data["center_y"]
		text_dst_left = math.floor(mip_center_x - text_data["half_width"] / text_scale)
		text_dst_top = math.floor(mip_center_y - text_data["half_height"] / text_scale)
		text_dst_right = math.ceil(mip_center_x + text_data["half_width"] / text_scale)
		text_dst_bottom = math.ceil(mip_center_y + text_data["half_height"] / text_scale)
		text_dst_width = text_dst_right - text_dst_left
		text_dst_height = text_dst_bottom - text_dst_top

		#next, find the corresponding spot in the text image to retrieve, and in most cases, shrink the image to fit the
		#	area we're going to draw to
		text_src_left = round(text_data["center_x"] - (mip_center_x - text_dst_left) * text_scale)
		text_src_top = round(text_data["center_y"] - (mip_center_y - text_dst_top) * text_scale)
		if text_scale > 0:
			text_src_right = text_src_left + text_dst_width * text_scale
			text_src_bottom = text_src_top + text_dst_height * text_scale
			text_src = text[text_src_top:text_src_bottom, text_src_left:text_src_right]
			text = resize(text_src, text_dst_width, text_dst_height, multi_color_alpha_weighting=False)
			text_src_left = 0
			text_src_top = 0

		#finally, overlay the text image over the atom image
		overlay_image(
			image, text_dst_left, text_dst_top, text, text_src_left, text_src_top, text_dst_width, text_dst_height)
	return image

def gen_atom_images(base_size, mips, symbol, bonds, molecule_max_atoms):
	atom_folder = os.path.join("atoms", symbol)
	if not os.path.exists(atom_folder):
		os.makedirs(atom_folder)
	for y_scale in range(1, min(molecule_max_atoms, MAX_GRID_HEIGHT) + 1):
		for x_scale in range(1, min(molecule_max_atoms + 1 - y_scale, MAX_GRID_WIDTH) + 1):
			for y in range(y_scale):
				for x in range(x_scale):
					image = gen_single_atom_image(base_size, mips, symbol, bonds, y_scale, x_scale, y, x)
					imwrite(os.path.join(atom_folder, f"{y_scale}{x_scale}{y}{x}.png"), image)

def gen_all_atom_images(base_size, mips):
	element_number = 0
	last_element_number = 0
	for (atom_row_i, atom_row) in enumerate(ATOM_ROWS):
		last_element_number += len(atom_row)
		for (i, symbol) in enumerate(atom_row):
			element_number += 1
			if element_number >= last_element_number - 4:
				bonds = last_element_number - element_number
			elif element_number == last_element_number - 5:
				bonds = 3
			elif i < 2:
				bonds = i + 1
			else:
				bonds = 0
			if bonds == 0:
				molecule_max_atoms = 1
			elif atom_row_i > 2:
				molecule_max_atoms = MAX_ATOMS_OTHER
			elif atom_row_i == 2:
				molecule_max_atoms = MAX_ATOMS_Ar
			elif symbol in HCNO:
				molecule_max_atoms = MAX_ATOMS_HCNO
			else:
				molecule_max_atoms = MAX_ATOMS_Ne
			#larger-number atoms with many bonds can't fulfill all their bonds within their max atom count, so to
			#	save on images, treat them like they can only be single atoms, but still draw them with their
			#	right bond color
			molecule_min_atoms = math.ceil(bonds / MAX_SINGLE_BONDS) + 1
			if molecule_min_atoms > molecule_max_atoms:
				molecule_max_atoms = 1
			gen_atom_images(base_size, mips, symbol, bonds, molecule_max_atoms)
		print(f"Atom row {atom_row_i + 1} written")


#Generate bond images
def gen_bond_images(base_size, mips, y_scale, x_scale, y, x):
	#generate both L and U images at once
	#L bond images will use the original values, U bond images will use the inverse
	scale = max(x_scale, y_scale)
	scale_center_y_min = 0.5 * (1 + scale - y_scale)
	scale_center_x_min = 0.5 * (1 + scale - x_scale)
	center_y = base_size * (y + scale_center_y_min) / scale
	center_x = base_size * (x + scale_center_x_min - 0.5) / scale
	images = {"L": {}, "U": {}}
	for bond_count in range(1, 3):
		half_bond_length = BOND_LENGTH_FRACTIONS[bond_count] * base_size / scale * 0.5
		l = filled_mip_image(base_size, mips, BOND_COLOR)
		u = filled_mip_image(base_size, mips, BOND_COLOR)
		bond_spacing = BOND_SPACING_FRACTION * base_size / scale
		center_y_min = center_y - bond_spacing * (bond_count - 1) / 2
		for bond in range(bond_count):
			bond_y = center_y_min + bond * bond_spacing
			draw_start = draw_coords(center_x - half_bond_length, bond_y)
			draw_end = draw_coords(center_x + half_bond_length, bond_y)
			bond_thickness = int(BOND_THICKNESS_FRACTION * base_size / scale)
			def draw_bond(mask):
				cv2.line(mask, draw_start, draw_end, 255, bond_thickness, cv2.LINE_AA, PRECISION_BITS)
			draw_alpha_on(l, draw_bond)
			draw_start = draw_start[::-1]
			draw_end = draw_end[::-1]
			draw_alpha_on(u, draw_bond)
		images["L"][bond_count] = easy_mips(l, multi_color_alpha_weighting=False)
		images["U"][bond_count] = easy_mips(u, multi_color_alpha_weighting=False)
	return images

def iter_bond_images(bond_images, name_specs):
	for (direction, direction_bond_images) in bond_images.items():
		for (bonds, image) in direction_bond_images.items():
			yield (f"{direction}{name_specs[direction]}{bonds}", image)

def gen_all_bond_images(base_size, mips):
	bonds_folder = "bonds"
	if not os.path.exists(bonds_folder):
		os.mkdir(bonds_folder)
	for y_scale in range(1, MAX_GRID_HEIGHT + 1):
		for x_scale in range(1, MAX_GRID_WIDTH + 1):
			for y in range(y_scale):
				for x in range(x_scale):
					#L and U images are identical only with X and Y swapped, so do them at the same time
					#generate "left" bonds: generate a bond only if x >= 1
					if x == 0:
						continue
					#file names represent left and up bonds for an atom with the same number set
					name_specs = {"L": f"{y_scale}{x_scale}{y}{x}", "U":f"{x_scale}{y_scale}{x}{y}"}
					bond_images = gen_bond_images(base_size, mips, y_scale, x_scale, y, x)
					write_images(bonds_folder, iter_bond_images(bond_images, name_specs))
	print("Bond images written")


#Generate specific full molecule images
def gen_single_atom_outline_image(base_size, mips, y_scale, x_scale, y, x):
	mip_datas = get_circle_mip_datas(base_size, mips, y_scale, x_scale, y, x)
	image = filled_mip_image(base_size, mips, ICON_OVERLAY_OUTLINE_COLOR)
	for (mip, place_x, size) in iter_mips(base_size, mips):
		#patch over the circle alpha mask for each mip
		image[0:size, place_x:place_x + size, 3] = mip_datas[mip]["outline_alpha"]
	return image

def gen_specific_molecule(base_size, mips, molecule, include_outline = False):
	image = filled_mip_image(base_size, mips)
	shape = [row.split("-") for row in molecule.split("|")]
	bonds = {"H": 1, "C": 4, "N": 3, "O": 2, "He": 0}
	y_scale = len(shape)
	x_scale = max(len(row) for row in shape)
	scale = max(y_scale, x_scale)
	for (y, row) in enumerate(shape):
		left_bonds = 0
		for (x, symbol) in enumerate(row):
			if symbol == "":
				left_bonds = 0
				continue
			up_bonds = 0
			right_bonds = 0
			if symbol[0].isdigit():
				up_bonds = int(symbol[0])
				symbol = symbol[1:]
			if symbol[-1].isdigit():
				right_bonds = int(symbol[-1])
				symbol = symbol[:-1]
			if include_outline:
				image = simple_overlay_image(
					gen_single_atom_outline_image(base_size, mips, y_scale, x_scale, y, x), image)
			simple_overlay_image(
				image, gen_single_atom_image(base_size, mips, symbol, bonds[symbol], y_scale, x_scale, y, x))
			if left_bonds > 0:
				simple_overlay_image(
					image, gen_bond_images(base_size, mips, y_scale, x_scale, y, x)["L"][left_bonds])
			if up_bonds > 0:
				simple_overlay_image(
					image, gen_bond_images(base_size, mips, x_scale, y_scale, x, y)["U"][up_bonds])
			left_bonds = right_bonds
	return image

def gen_item_group_icon(base_size, mips):
	imwrite("item-group.png", gen_specific_molecule(base_size, mips, "O1-C2-N|1N1-1O-1H|1H"))
	print("Item group written")

def gen_molecule_reaction_reactants_icon(base_size, mips):
	imwrite("molecule-reaction-reactants.png", gen_specific_molecule(base_size, mips, "-H1-O|H--1H|1O1-H"))
	print("Molecule reaction reactants written")


#Generate selector icons
def get_rotation_selector_arc_values(base_size):
	radius = ROTATION_SELECTOR_RADIUS_FRACTION * base_size
	center = base_size / 2
	arrow_size = ROTATION_SELECTOR_ARROW_SIZE_FRACTION * base_size
	return (radius, center, arrow_size)

def get_draw_arrow_points(center_x, center_y, x_offset, y_offset):
	draw_arrow_points = []
	for _ in range(3):
		(x_offset, y_offset) = -y_offset, x_offset
		draw_arrow_points.append(draw_coords(center_x + x_offset, center_y + y_offset))
	return draw_arrow_points

def gen_prepared_rotation_selector_image(
		base_size,
		mips,
		arcs,
		draw_arrow_pointss,
		is_outline = False,
		color = None,
		include_dot = True,
		center_offset = None):
	(radius, center, _) = get_rotation_selector_arc_values(base_size)
	if center_offset is not None:
		center += center_offset
	thickness = int(ROTATION_SELECTOR_THICKNESS_FRACTION * base_size)
	dot_radius = ROTATION_SELECTOR_DOT_RADIUS_FRACTION * base_size
	if is_outline:
		thickness += int(ROTATION_SELECTOR_OUTLINE_FRACTION * base_size * 2)
		dot_radius += ROTATION_SELECTOR_OUTLINE_FRACTION * base_size
	draw_center = draw_coords(center, center)
	draw_axes = draw_coords(radius, radius)

	if not color:
		color = ROTATION_SELECTOR_COLOR
	image = filled_mip_image(base_size, mips, color)
	def draw_arcs_and_dot(mask):
		for (start_angle, arc) in arcs:
			cv2.ellipse(
				mask, draw_center, draw_axes, start_angle, 0, arc, 255, thickness, cv2.LINE_AA, PRECISION_BITS)
		if include_dot:
			draw_filled_circle_alpha(mask, draw_center, draw_radius(dot_radius))
	draw_alpha_on(image, draw_arcs_and_dot)
	arrows_image = filled_mip_image(base_size, mips, color)
	def draw_arrows(mask):
		cv2.fillPoly(mask, numpy.array(draw_arrow_pointss), 255, cv2.LINE_AA, PRECISION_BITS)
	draw_alpha_on(arrows_image, draw_arrows)
	return easy_mips(simple_overlay_image(image, arrows_image), multi_color_alpha_weighting=False)

def gen_left_right_rotation_selector_image(base_size, mips, start_angle, arrow_center_x_radius_multiplier):
	(radius, center, arrow_size) = get_rotation_selector_arc_values(base_size)
	draw_arrow_points = get_draw_arrow_points(center + radius * arrow_center_x_radius_multiplier, center, 0, -arrow_size)
	return gen_prepared_rotation_selector_image(base_size, mips, [(start_angle, 90)], [draw_arrow_points])

def gen_flip_rotation_selector_image(base_size, mips, is_outline = False, color = None):
	(radius, center, arrow_size) = get_rotation_selector_arc_values(base_size)
	if is_outline:
		arrow_size += ROTATION_SELECTOR_OUTLINE_FRACTION * base_size
	draw_arrow_pointss = []
	for mult in [-1, 1]:
		center_x = center + radius / 2 * mult
		center_y = center - radius / 2 * math.sqrt(3) * mult
		x_offset = arrow_size / 2 * math.sqrt(3) * mult
		y_offset = arrow_size / 2 * mult
		draw_arrow_pointss.append(get_draw_arrow_points(center_x, center_y, x_offset, y_offset))
	return gen_prepared_rotation_selector_image(
		base_size, mips, [(120, 120), (300, 120)], draw_arrow_pointss, is_outline, color)

def iter_gen_rotation_selectors(base_size, mips):
	yield ("rotation-l", gen_left_right_rotation_selector_image(base_size, mips, 180, -1))
	yield ("rotation-r", gen_left_right_rotation_selector_image(base_size, mips, 270, 1))
	yield ("rotation-f", gen_flip_rotation_selector_image(base_size, mips))

def iter_gen_single_target_and_atom_bond_selectors(base_size, mips, y_scale, x_scale, highlight_i):
	#generate the base target image
	target_image = filled_mip_image(base_size, mips)
	for slot_i in range(y_scale * x_scale):
		x = slot_i % x_scale
		y = slot_i // x_scale
		color = TARGET_SELECTOR_HIGHLIGHT_COLOR if slot_i == highlight_i else TARGET_SELECTOR_DEFAULT_COLOR
		simple_overlay_image(target_image, gen_single_atom_shape_image(base_size, mips, y_scale, x_scale, y, x, color))
	highlight_x = highlight_i % x_scale
	highlight_y = highlight_i // x_scale
	name_spec = f"{y_scale}{x_scale}{highlight_y}{highlight_x}"
	yield ("target-" + name_spec, target_image)

	#generate the atom-bond images
	atom_bond_directions = [(0, -1, "N"), (1, 0, "E"), (0, 1, "S"), (-1, 0, "W")]
	mip_data_0 = get_circle_mip_datas(base_size, mips, y_scale, x_scale, highlight_y, highlight_x)[0]
	negative_inner_arrow_size = -ATOM_BOND_SELECTOR_INNER_ARROW_SIZE_FRACTION * base_size / mip_data_0["scale"]
	inner_arrow_offset = ATOM_BOND_SELECTOR_INNER_ARROW_OFFSET_FRACTION * base_size / mip_data_0["scale"]
	negative_outer_arrow_size = -ATOM_RADIUS_FRACTION * base_size / math.sqrt(2) / mip_data_0["scale"]
	outer_arrow_offset = (1 - ATOM_RADIUS_FRACTION) * base_size / mip_data_0["scale"]
	for (x_offset, y_offset, direction) in atom_bond_directions:
		atom_bond_image = numpy.copy(target_image)
		target_x = highlight_x + x_offset
		target_y = highlight_y + y_offset
		inner_y = target_y >= 0 and target_y < y_scale
		inner_x = target_x >= 0 and target_x < x_scale
		if y_scale == 3 and not inner_y or x_scale == 3 and not inner_x:
			continue
		if inner_x and inner_y:
			arrow_color = TARGET_SELECTOR_HIGHLIGHT_COLOR
			arrow_offset = outer_arrow_offset
			negative_arrow_size = negative_outer_arrow_size
		else:
			arrow_color = TARGET_SELECTOR_DEFAULT_COLOR
			arrow_offset = inner_arrow_offset
			negative_arrow_size = negative_inner_arrow_size
		arrow_image = filled_mip_image(base_size, mips, arrow_color)
		draw_arrow_points = get_draw_arrow_points(
			mip_data_0["center_x"] + x_offset * arrow_offset,
			mip_data_0["center_y"] + y_offset * arrow_offset,
			x_offset * negative_arrow_size,
			y_offset * negative_arrow_size)
		def draw_arrow(mask):
			cv2.fillPoly(mask, numpy.array([draw_arrow_points]), 255, cv2.LINE_AA, PRECISION_BITS)
		draw_alpha_on(arrow_image, draw_arrow)
		easy_mips(arrow_image, multi_color_alpha_weighting=False)
		yield (f"atom-bond-{name_spec}{direction}", simple_overlay_image(atom_bond_image, arrow_image))

def iter_gen_target_and_atom_bond_selectors(base_size, mips):
	for y_scale in range(1, MAX_GRID_HEIGHT + 1):
		for x_scale in range(1, MAX_GRID_WIDTH + 1):
			for highlight_i in range(y_scale * x_scale):
				yield from iter_gen_single_target_and_atom_bond_selectors(
					base_size, mips, y_scale, x_scale, highlight_i)

def gen_all_selectors(base_size, mips):
	selectors_folder = "selectors"
	if not os.path.exists(selectors_folder):
		os.mkdir(selectors_folder)
	write_images(selectors_folder, iter_gen_rotation_selectors(base_size, mips))
	write_images(selectors_folder, iter_gen_target_and_atom_bond_selectors(base_size, mips))
	print("Selectors written")


#Generate building overlays
def build_4_way_image(base_image):
	(base_height, base_width, _) = base_image.shape
	image = numpy.zeros((base_height + base_width, base_height + base_width, 4), numpy.uint8)
	image[0:base_height, 0:base_width] = base_image
	placements = [
		(base_width, 0, cv2.ROTATE_90_CLOCKWISE),
		(base_height, base_width, cv2.ROTATE_180),
		(0, base_height, cv2.ROTATE_90_COUNTERCLOCKWISE),
	]
	for (left, top, rotation) in placements:
		rotated = cv2.rotate(base_image, rotation)
		image[top:top + rotated.shape[0], left:left + rotated.shape[1]] = rotated
	return image

def gen_building_overlays(base_size):
	building_overlays_folder = "building-overlays"
	if not os.path.exists(building_overlays_folder):
		os.mkdir(building_overlays_folder)
	overlays = [
		("base", (160, 160, 224, 0), False),
		("catalyst", (160, 224, 160, 0), False),
		("modifier", (224, 160, 160, 0), False),
		("result", (224, 224, 160, 0), True),
		("bonus", (224, 160, 224, 0), True),
		("remainder", (160, 224, 224, 0), True),
	]
	for (base_size, suffix) in [(base_size, ""), (base_size * 2, "-hr")]:
		for (component, color, is_output) in overlays:
			#generate the base loader shape
			base_height = int(base_size * 1.75)
			base_image = numpy.full((base_height, base_size, 4), color, numpy.uint8)
			if is_output:
				loader_points = [
					(2 / 32, 1.25),
					(30 / 32, 1.25),
					(30 / 32, 0.25),
					(0.5, 0 + 1 / 32),
					(2 / 32, 0.25),
				]
			else:
				loader_points = [
					(2 / 32, 0.5),
					(30 / 32, 0.5),
					(30 / 32, 1.75 - 1 / 32),
					(0.5, 1.5),
					(2 / 32, 1.75 - 1 / 32),
				]
			draw_loader_points = [draw_coords(x * base_size, y * base_size) for (x, y) in loader_points]
			def draw_loader(mask):
				cv2.fillPoly(mask, numpy.array([draw_loader_points]), 255, cv2.LINE_AA, PRECISION_BITS)
			draw_alpha_on(base_image, draw_loader)
			circle_image = numpy.full((base_size, base_size, 4), color, numpy.uint8)
			draw_circle_center = draw_coords(base_size / 2, base_size / 2)
			def draw_circle(mask):
				draw_filled_circle_alpha(mask, draw_circle_center, draw_radius(base_size / 2))
			draw_alpha_on(circle_image, draw_circle)
			simple_overlay_image_at(base_image, 0, base_height - base_size if is_output else 0, circle_image)

			image = build_4_way_image(base_image)
			imwrite(os.path.join(building_overlays_folder, component + suffix + ".png"), image)
		moleculifier_image = gen_specific_molecule(base_size * 2, 1, MOLECULIFIER_MOLECULE)
		imwrite(os.path.join(building_overlays_folder, f"moleculifier{suffix}.png"), moleculifier_image)
	print("Building overlays written")


#Generate recipe icons
def get_molecule_rotator_rotation_image(base_size, mips, is_outline):
	(radius, center, arrow_size) = get_rotation_selector_arc_values(base_size)
	if is_outline:
		arrow_size += ROTATION_SELECTOR_OUTLINE_FRACTION * base_size
	center_offset = base_size / -8
	return gen_prepared_rotation_selector_image(
		base_size,
		mips,
		[(0, 90)],
		[get_draw_arrow_points(center + radius + center_offset, center + center_offset, 0, arrow_size)],
		is_outline,
		ICON_OVERLAY_OUTLINE_COLOR if is_outline else MOLECULE_ROTATOR_ICON_COLOR,
		include_dot=False,
		center_offset=center_offset)

def iter_gen_all_building_recipe_icons(base_size, mips, include_outline):
	images = {
		MOLECULE_ROTATOR_NAME: simple_overlay_image(
			gen_specific_molecule(base_size, mips, "H1-H-|1H|", include_outline),
			get_molecule_rotator_rotation_image(base_size, mips, False)),
	}
	if include_outline:
		images[MOLECULE_ROTATOR_NAME] = simple_overlay_image(
			get_molecule_rotator_rotation_image(base_size, mips, True), images[MOLECULE_ROTATOR_NAME])
	return images.items()

def iter_gen_moleculify_recipe_icons(base_size, mips):
	base_icons_folder = os.path.join(BASE_GRAPHICS_PATH, "icons")
	base_fluid_icons_folder = os.path.join(base_icons_folder, "fluid")
	image_pairs = [
		(
			"water",
			gen_specific_molecule(base_size, mips, "-H|H1-1O"),
			os.path.join(base_fluid_icons_folder, "water.png"),
		),
	]
	for (name, moleculify_result_image, moleculify_source_image_path) in image_pairs:
		moleculify_source_image = cv2.imread(moleculify_source_image_path, cv2.IMREAD_UNCHANGED)
		image = filled_mip_image(base_size, mips)
		#overlay the sub images at half-size at each mip level
		for (mip, place_x, size) in iter_mips(base_size, mips):
			half_size = size // 2
			image[0:half_size, place_x:place_x + half_size] = \
				resize(moleculify_source_image[0:size, place_x:place_x + size], half_size, half_size)
			image[half_size:size, place_x + half_size:place_x + size] = \
				resize(moleculify_result_image[0:size, place_x:place_x + size], half_size, half_size)
		#draw the arrow line
		arrow_image = filled_mip_image(base_size, mips, MOLECULIFY_ARROW_COLOR)
		arrow_thickness = int(MOLECULIFY_ARROW_THICKNESS_FRACTION * base_size)
		start_xy = base_size * 3 / 8
		end_xy = base_size * 5 / 8
		draw_start = draw_coords(start_xy, start_xy)
		draw_end = draw_coords(end_xy, end_xy)
		def draw_arrow_line(mask):
			cv2.line(mask, draw_start, draw_end, 255, arrow_thickness, cv2.LINE_AA, PRECISION_BITS)
		draw_alpha_on(arrow_image, draw_arrow_line)
		#draw the arrow tip
		arrow_tip_image = numpy.full((base_size, base_size, 4), MOLECULIFY_ARROW_COLOR, numpy.uint8)
		arrow_size_offset = MOLECULIFY_ARROW_SIZE_FRACTION * base_size / -math.sqrt(2)
		draw_arrow_points = get_draw_arrow_points(end_xy, end_xy, arrow_size_offset, arrow_size_offset)
		def draw_arrow_tip(mask):
			cv2.fillPoly(mask, numpy.array([draw_arrow_points]), 255, cv2.LINE_AA, PRECISION_BITS)
		draw_alpha_on(arrow_tip_image, draw_arrow_tip)
		#combine arrow images, add mips, and then combine it with the rest of the image
		image = simple_overlay_image(image, easy_mips(simple_overlay_image(arrow_image, arrow_tip_image)))
		yield (f"moleculify-{name}", image)

def gen_all_recipe_icons(base_size, mips):
	recipes_folder = "recipes"
	if not os.path.exists(recipes_folder):
		os.mkdir(recipes_folder)
	write_images(recipes_folder, iter_gen_all_building_recipe_icons(base_size, mips, False))
	write_images(recipes_folder, iter_gen_moleculify_recipe_icons(base_size, mips))
	print("Recipe icons written")


#Generate building icon overlays
def gen_icon_overlays(base_size, mips):
	icon_overlays_folder = "icon-overlays"
	if not os.path.exists(icon_overlays_folder):
		os.mkdir(icon_overlays_folder)
	detector_image = gen_specific_molecule(base_size, mips, "H|1O|1H", True)
	imwrite(os.path.join(icon_overlays_folder, "molecule-detector.png"), detector_image)
	write_images(icon_overlays_folder, iter_gen_all_building_recipe_icons(base_size, mips, True))
	moleculifier_image = gen_specific_molecule(base_size, mips, MOLECULIFIER_MOLECULE, include_outline=True)
	imwrite(os.path.join(icon_overlays_folder, "moleculifier.png"), moleculifier_image)
	print("Icon overlays written")


#Generate molecule shape backgrounds
def gen_molecule_shape_backgrounds(base_size, mips):
	shapes_folder = "shapes"
	if not os.path.exists(shapes_folder):
		os.mkdir(shapes_folder)
	for shape_n in range(2, 1 << MAX_GRID_AREA):
		if not any((shape_n & 1 << i) != 0 for i in range(MAX_GRID_WIDTH)) \
				or not any((shape_n & 1 << i) != 0 for i in range(0, MAX_GRID_AREA, MAX_GRID_WIDTH)):
			continue
		grid = []
		for i in range(MAX_GRID_AREA):
			grid.append(1 if shape_n & 1 << i != 0 else 0)
		atom_count = sum(grid)

		#stop if we have too many atoms
		if atom_count > MAX_ATOMS:
			continue

		#BFS to check if all atoms are reachable
		first_slot_i = next(i for (i, slot) in enumerate(grid) if slot == 1)
		grid[first_slot_i] = 2
		check_slot_is = [first_slot_i]
		check_slot_i_i = 0
		x_scale = 1
		y_scale = 1
		while check_slot_i_i < len(check_slot_is):
			check_slot_i = check_slot_is[check_slot_i_i]
			adjacent_slot_is = []
			x = check_slot_i % MAX_GRID_WIDTH
			y = check_slot_i // MAX_GRID_WIDTH
			if x + 1 > x_scale:
				x_scale = x + 1
			if y + 1 > y_scale:
				y_scale = y + 1
			if x > 0:
				adjacent_slot_is.append(check_slot_i - 1)
			if y > 0:
				adjacent_slot_is.append(check_slot_i - MAX_GRID_WIDTH)
			if x < MAX_GRID_WIDTH - 1:
				adjacent_slot_is.append(check_slot_i + 1)
			if y < MAX_GRID_HEIGHT - 1:
				adjacent_slot_is.append(check_slot_i + MAX_GRID_WIDTH)
			for adjacent_slot_i in adjacent_slot_is:
				if grid[adjacent_slot_i] == 1:
					grid[adjacent_slot_i] = 2
					check_slot_is.append(adjacent_slot_i)
			check_slot_i_i += 1
		if len(check_slot_is) < atom_count:
			continue
		image = filled_mip_image(base_size, mips)
		for (i, slot) in enumerate(grid):
			if slot == 0:
				continue
			x = i % MAX_GRID_WIDTH
			y = i // MAX_GRID_WIDTH
			simple_overlay_image(
				image,
				gen_single_atom_shape_image(base_size, mips, y_scale, x_scale, y, x, SHAPE_BACKGROUND_COLOR))
		imwrite(os.path.join(shapes_folder, f"{shape_n:03X}.png"), image)
	print("Molecule shape backgrounds written")


#Generate the reaction settings icon
def gen_reaction_settings_icon(base_size, mips):
	#draw the outer and inner frame rects
	image = filled_mip_image(base_size, mips, REACTION_SETTINGS_OUTER_COLOR)
	half_size = base_size / 2
	top_left = half_size - REACTION_SETTINGS_RECT_HALF_WIDTH_FRACTION * base_size
	bottom_right = base_size - top_left
	draw_top_left = draw_coords(top_left, top_left)
	draw_bottom_right = draw_coords(bottom_right, bottom_right)
	thickness = int(REACTION_SETTINGS_RECT_OUTER_THICKNESS_FRACTION * base_size)
	def draw_rect(mask):
		cv2.rectangle(mask, draw_top_left, draw_bottom_right, 255, thickness, cv2.LINE_AA, PRECISION_BITS)
		cv2.rectangle(mask, draw_top_left, draw_bottom_right, 255, cv2.FILLED, shift=PRECISION_BITS)
	draw_alpha_on(image, draw_rect)
	inner_image = filled_mip_image(base_size, mips, REACTION_SETTINGS_INNER_COLOR)
	thickness = int(REACTION_SETTINGS_RECT_INNER_THICKNESS_FRACTION * base_size)
	draw_alpha_on(inner_image, draw_rect)

	#draw the selector boxes
	box_color = REACTION_SETTINGS_OUTER_COLOR[:3] + (255,)
	box_size = REACTION_SETTINGS_BOX_SIZE_FRACTION * base_size
	box_top = (half_size + top_left - box_size) / 2
	box_bottom = box_top + box_size
	box_left = top_left + REACTION_SETTINGS_BOX_LEFT_SHIFT_FRACTION * base_size
	box_right = box_left + box_size
	draw_top_left = draw_coords(box_left, box_top)
	draw_bottom_right = draw_coords(box_right, box_bottom)
	cv2.rectangle(inner_image, draw_top_left, draw_bottom_right, box_color, cv2.FILLED, cv2.LINE_AA, PRECISION_BITS)
	draw_top_left = draw_coords(box_left, base_size - box_bottom)
	draw_bottom_right = draw_coords(box_right, base_size - box_top)
	cv2.rectangle(inner_image, draw_top_left, draw_bottom_right, box_color, cv2.FILLED, cv2.LINE_AA, PRECISION_BITS)

	#draw mini selectors
	top_selector_image = resize(
		list(iter_gen_single_target_and_atom_bond_selectors(base_size, 1, 1, 2, 1))[4][1], int(box_size), int(box_size))
	simple_overlay_image_at(inner_image, int(box_left), int(box_top), top_selector_image)
	bottom_selector_image = \
		resize(gen_left_right_rotation_selector_image(base_size, 1, 270, 1), int(box_size), int(box_size))
	simple_overlay_image_at(inner_image, int(box_left), int(base_size - box_bottom), bottom_selector_image)

	#write the file
	easy_mips(image, multi_color_alpha_weighting=False)
	easy_mips(inner_image, multi_color_alpha_weighting=False)
	imwrite("reaction-settings.png", simple_overlay_image(image, inner_image))
	print("Reaction settings icon written")


#Generate all graphics
gen_all_atom_images(BASE_ICON_SIZE, MOLECULE_ICON_MIPS)
gen_all_bond_images(BASE_ICON_SIZE, MOLECULE_ICON_MIPS)
gen_item_group_icon(ITEM_GROUP_SIZE, ITEM_GROUP_MIPS)
gen_molecule_reaction_reactants_icon(BASE_ICON_SIZE, MOLECULE_ICON_MIPS)
gen_all_selectors(BASE_ICON_SIZE, BASE_ICON_MIPS)
gen_building_overlays(BASE_OVERLAY_SIZE)
gen_all_recipe_icons(BASE_ICON_SIZE, BASE_ICON_MIPS)
gen_icon_overlays(BASE_ICON_SIZE, BASE_ICON_MIPS)
gen_molecule_shape_backgrounds(BASE_ICON_SIZE, MOLECULE_ICON_MIPS)
gen_reaction_settings_icon(BASE_ICON_SIZE, BASE_ICON_MIPS)

import time
print(time.strftime("Images generated at %Y-%m-%d %H:%M:%S"))
