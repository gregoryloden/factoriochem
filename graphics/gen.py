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
	#no atom has 5 bonds - this is for shape images
	(128, 128, 128, 0),
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
BOND_COUNTS = {}
for (_, atom_row) in enumerate(ATOM_ROWS):
	atoms_in_row_m1 = len(atom_row) - 1
	for (i, symbol) in enumerate(atom_row):
		if i >= atoms_in_row_m1 - 4:
			BOND_COUNTS[symbol] = atoms_in_row_m1 - i
		elif i == atoms_in_row_m1 - 5:
			BOND_COUNTS[symbol] = 3
		elif i < 2:
			BOND_COUNTS[symbol] = i + 1
		else:
			BOND_COUNTS[symbol] = 0
ATOM_RADIUS_FRACTION = 30 / 64
PRECISION_BITS = 8
PRECISION_MULTIPLIER = 1 << PRECISION_BITS
CIRCLE_DATA = {}
HCNO = ["H", "C", "N", "O"]
MAX_ATOMS_HCNO = 8
MAX_ATOMS_Ne = 4
MAX_ATOMS_Ar = 3
MAX_ATOMS_OTHER = 2
MAX_SINGLE_BONDS = 3
FONT = cv2.FONT_HERSHEY_SIMPLEX
FONT_SCALE_FRACTIONS = [0, 1.25 / 64, 1 / 64]
FONT_THICKNESS_FRACTION = 2 / 64
TEXT_DATAS = {}
TEXT_COLOR = (0, 0, 0, 0)
SHAPE_TEXT_COLOR = (255, 255, 255, 0)
SHAPE_ATOM_CHARACTER = "+"
BOND_COUNTS[SHAPE_ATOM_CHARACTER] = 5
BOND_COLOR = (0, 0, 0, 0)
BOND_LENGTH_FRACTIONS = [0, 12 / 64, 12 / 64, 16 / 64]
BOND_THICKNESS_FRACTION = 6 / 64
BOND_SPACING_FRACTION = 18 / 64
ITEM_GROUP_SIZE = 128
ITEM_GROUP_MIPS = 2
ROTATION_SELECTOR_COLOR = (224, 224, 192, 0)
ROTATION_SELECTOR_RADIUS_FRACTION = 24 / 64
ROTATION_SELECTOR_THICKNESS_FRACTION = 4 / 64
ROTATION_SELECTOR_ARROW_SIZE_FRACTION = 6 / 64
ROTATION_SELECTOR_DOT_RADIUS_FRACTION = 4 / 64
TARGET_SELECTOR_DEFAULT_COLOR = (128, 128, 128, 0)
TARGET_SELECTOR_HIGHLIGHT_COLOR = (128, 224, 255, 0)
ATOM_BOND_SELECTOR_INNER_ARROW_SIZE_FRACTION = 18 / 64
ATOM_BOND_SELECTOR_INNER_ARROW_OFFSET_FRACTION = 6 / 64
BASE_OVERLAY_SIZE = 32
MOLECULIFIER_MOLECULE = "H--C|-He|N--O"
DETECTOR_ARROW_COLOR = (128, 224, 255, 0)
DETECTOR_SYMBOL_SIZE_FRACTION = 9 / 32
MOLECULE_ROTATOR_NAME = "molecule-rotator"
MOLECULE_ROTATOR_ICON_COLOR = (192, 192, 224, 0)
MOLECULE_SORTER_NAME = "molecule-sorter"
MOLECULE_SORTER_ARROW_COLORS = [(224, 224, 192, 0), None, (192, 224, 224, 0)]
MOLECULE_SORTER_ARROW_THICKNESS_FRACTION = 4 / 64
MOLECULE_SORTER_ARROW_LEFT_FRACTION = 32 / 64
MOLECULE_SORTER_ARROW_RIGHT_FRACTION = 48 / 64
MOLECULE_SORTER_ARROW_SIZE_FRACTION = 6 / 64
MOLECULE_DEBONDER_NAME = "molecule-debonder"
MOLECULE_DEBONDER_COLOR = (64, 64, 224, 0)
MOLECULE_DEBONDER_LEFT_FRACTION = 16 / 64
MOLECULE_DEBONDER_RIGHT_FRACTION = 32 / 64
MOLECULE_DEBONDER_THICKNESS_FRACTION = 4 / 64
MOLECULE_BONDER_NAME = "molecule-bonder"
MOLECULE_BONDER_COLOR = (64, 160, 64, 0)
MOLECULE_BONDER_TOP_FRACTION = 24 / 64
MOLECULE_BONDER_BOTTOM_FRACTION = 40 / 64
MOLECULE_FISSIONER_NAME = "molecule-fissioner"
MOLECULE_FISSIONER_THICKNESS_FRACTION = 4 / 64
MOLECULE_FISSIONER_COLOR = (192, 192, 224, 0)
MOLECULE_FUSIONER_NAME = "molecule-fusioner"
MOLECULE_FUSIONER_COLOR = (224, 224, 192, 0)
MOLECULE_VOIDER_NAME = "molecule-voider"
MOLECULE_VOIDER_COLOR = (64, 64, 224, 0)
MOLECULE_VOIDER_XY_FRACTION = 8 / 64
MOLECULE_VOIDER_THICKNESS_FRACTION = 6 / 64
with open("base-graphics-path.txt", "r") as file:
	BASE_GRAPHICS_PATH = file.read()
MOLECULIFY_ARROW_COLOR = (128, 64, 224, 0)
MOLECULIFY_ARROW_THICKNESS_FRACTION = 6 / 64
MOLECULIFY_ARROW_SIZE_FRACTION = 8 / 64
ICON_OVERLAY_OUTLINE_COLOR = (64, 64, 64, 0)
ICON_OVERLAY_OUTLINE_FRACTION = 4 / 64
ICON_OVERLAY_ARROW_OUTLINE_FRACTION = ICON_OVERLAY_OUTLINE_FRACTION * (1 + math.sqrt(2)) / 2
REACTION_SETTINGS_RECT_HALF_WIDTH_FRACTION = 20 / 64
REACTION_SETTINGS_RECT_OUTER_THICKNESS_FRACTION = 16 / 64
REACTION_SETTINGS_OUTER_COLOR = (64, 64, 64, 0)
REACTION_SETTINGS_RECT_INNER_THICKNESS_FRACTION = 8 / 64
REACTION_SETTINGS_INNER_COLOR = (128, 128, 128, 0)
REACTION_SETTINGS_BOX_SIZE_FRACTION = 12 / 64
REACTION_SETTINGS_BOX_LEFT_SHIFT_FRACTION = 4 / 64

image_counter = 0
total_images = 0

#Image utilities
def write_image(folder, name, image):
	cv2.imwrite(os.path.join(folder, name + ".png"), image, [cv2.IMWRITE_PNG_COMPRESSION, 9])
	global image_counter
	global total_images
	image_counter += 1
	total_images += 1

def write_images(folder, images):
	for (name, image) in images:
		write_image(folder, name, image)

def image_counter_print(s):
	global image_counter
	print(f"{s} ({image_counter} images)")
	image_counter = 0

def filled_mip_image(base_size, mips, color = None):
	shape = (base_size, sum(base_size >> i for i in range(mips)), 4)
	return numpy.full(shape, color, numpy.uint8) if color else numpy.zeros(shape, numpy.uint8)

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

def iter_mips(base_size, mips):
	place_x = 0
	for mip in range(mips):
		size = base_size >> mip
		yield (mip, place_x, size)
		place_x += size


#Drawing utilities
def draw_coords_from(x, y):
	return (round((x - 0.5) * PRECISION_MULTIPLIER), round((y - 0.5) * PRECISION_MULTIPLIER))

def draw_radius_from(radius):
	return round((radius - 0.5) * PRECISION_MULTIPLIER)

def draw_alpha_on(image, draw):
	mask = numpy.zeros(image.shape[:2], numpy.uint8)
	draw(mask)
	mask_section = mask > 0
	image[:, :, 3][mask_section] = mask[mask_section]
	return mask

def draw_filled_circle_alpha(mask, draw_center, draw_radius):
	cv2.circle(mask, draw_center, draw_radius, 255, cv2.FILLED, cv2.LINE_AA, PRECISION_BITS)

def draw_poly_alpha(mask, poly_pointss):
	cv2.fillPoly(mask, numpy.array(poly_pointss), 255, cv2.LINE_AA, PRECISION_BITS)

def get_draw_arrow_points(center_x, center_y, x_offset, y_offset):
	draw_arrow_points = []
	for _ in range(3):
		(x_offset, y_offset) = -y_offset, x_offset
		draw_arrow_points.append(draw_coords_from(center_x + x_offset, center_y + y_offset))
	return draw_arrow_points


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
			"outline_radius": (ATOM_RADIUS_FRACTION / scale + ICON_OVERLAY_OUTLINE_FRACTION) * base_size,
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
		draw_center = draw_coords_from(mip_center_x, mip_center_y)
		alpha = numpy.zeros((size, size), numpy.uint8)
		draw_filled_circle_alpha(alpha, draw_center, draw_radius_from(scale_data["radius"] * shrink))
		outline_alpha = numpy.zeros((size, size), numpy.uint8)
		draw_filled_circle_alpha(outline_alpha, draw_center, draw_radius_from(scale_data["outline_radius"] * shrink))
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
	color = SHAPE_TEXT_COLOR if symbol == SHAPE_ATOM_CHARACTER else TEXT_COLOR
	text = numpy.full((text_full_height, text_full_width, 4), color, numpy.uint8)
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

def gen_single_atom_image(base_size, mips, symbol, y_scale, x_scale, y, x):
	image = gen_single_atom_shape_image(base_size, mips, y_scale, x_scale, y, x, COLOR_FOR_BONDS[BOND_COUNTS[symbol]])
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

def gen_atom_images(base_size, mips, symbol, molecule_max_atoms):
	atom_folder = os.path.join("atoms", symbol)
	if not os.path.exists(atom_folder):
		os.makedirs(atom_folder)
	for y_scale in range(1, min(molecule_max_atoms, MAX_GRID_HEIGHT) + 1):
		for x_scale in range(1, min(molecule_max_atoms + 1 - y_scale, MAX_GRID_WIDTH) + 1):
			for y in range(y_scale):
				for x in range(x_scale):
					image = gen_single_atom_image(base_size, mips, symbol, y_scale, x_scale, y, x)
					write_image(atom_folder, f"{y_scale}{x_scale}{y}{x}", image)

def gen_all_atom_images(base_size, mips):
	for (atom_row_i, atom_row) in enumerate(ATOM_ROWS):
		for (i, symbol) in enumerate(atom_row):
			bonds = BOND_COUNTS[symbol]
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
			gen_atom_images(base_size, mips, symbol, molecule_max_atoms)
		image_counter_print(f"Atom row {atom_row_i + 1} written")


#Generate bond images
def gen_bond_images(base_size, mips, y_scale, x_scale, y, x):
	scale = max(x_scale, y_scale)
	center_x = base_size * (x + 0.5 * (1 + scale - x_scale)) / scale
	center_y = base_size * (y + 0.5 * (1 + scale - y_scale)) / scale
	bond_thickness = int(BOND_THICKNESS_FRACTION * base_size / scale)
	bond_spacing = BOND_SPACING_FRACTION * base_size / scale
	direction_data = [
		("L", {"center": (center_x - base_size * 0.5 / scale, center_y), "orientation": "H", "bonds": [1, 2]}),
		("R", {"center": (center_x + base_size * 0.5 / scale, center_y), "orientation": "H", "bonds": [3]}),
		("U", {"center": (center_x, center_y - base_size * 0.5 / scale), "orientation": "V", "bonds": [1, 2]}),
		("D", {"center": (center_x, center_y + base_size * 0.5 / scale), "orientation": "V", "bonds": [3]}),
	]
	images = {}
	for (direction, data) in direction_data:
		if (direction == "L" and x == 0 or direction == "R" and x == x_scale - 1) \
				or (direction == "U" and y == 0 or direction == "D" and y == y_scale - 1):
			continue
		images[direction] = {}
		for bonds in data["bonds"]:
			half_bond_length = BOND_LENGTH_FRACTIONS[bonds] * base_size / scale * 0.5
			image = filled_mip_image(base_size, mips, BOND_COLOR)
			(center_x, center_y) = data["center"]
			bond_xy_min_offset = bond_spacing * (1 - bonds) * 0.5
			for bond in range(bonds):
				#triple bonds render 1 bond in front of the atoms and 2 behind
				if bonds == 3 and bond == 1:
					continue
				bond_xy_offset = bond_xy_min_offset + bond * bond_spacing
				if data["orientation"] == "H":
					bond_y = center_y + bond_xy_offset
					draw_start = draw_coords_from(center_x - half_bond_length, bond_y)
					draw_end = draw_coords_from(center_x + half_bond_length, bond_y)
				else:
					bond_x = center_x + bond_xy_offset
					draw_start = draw_coords_from(bond_x, center_y - half_bond_length)
					draw_end = draw_coords_from(bond_x, center_y + half_bond_length)
				def draw_bond(mask):
					cv2.line(mask, draw_start, draw_end, 255, bond_thickness, cv2.LINE_AA, PRECISION_BITS)
				draw_alpha_on(image, draw_bond)
			images[direction][bonds] = easy_mips(image, multi_color_alpha_weighting=False)
	return images

def iter_bond_images(bond_images, name_spec, min_atoms):
	for (direction, direction_bond_images) in bond_images.items():
		for (bonds, image) in direction_bond_images.items():
			if bonds > 2 and min_atoms > MAX_ATOMS_Ne:
				continue
			yield (f"{direction}{name_spec}{bonds}", image)

def gen_all_bond_images(base_size, mips):
	bonds_folder = "bonds"
	if not os.path.exists(bonds_folder):
		os.mkdir(bonds_folder)
	for y_scale in range(1, MAX_GRID_HEIGHT + 1):
		for x_scale in range(1, MAX_GRID_WIDTH + 1):
			min_atoms = y_scale + x_scale - 1
			for y in range(y_scale):
				for x in range(x_scale):
					name_spec = f"{y_scale}{x_scale}{y}{x}"
					bond_images = gen_bond_images(base_size, mips, y_scale, x_scale, y, x)
					write_images(bonds_folder, iter_bond_images(bond_images, name_spec, min_atoms))
	image_counter_print("Bond images written")


#Generate specific full molecule images
def gen_single_atom_outline_image(base_size, mips, y_scale, x_scale, y, x):
	mip_datas = get_circle_mip_datas(base_size, mips, y_scale, x_scale, y, x)
	image = filled_mip_image(base_size, mips, ICON_OVERLAY_OUTLINE_COLOR)
	for (mip, place_x, size) in iter_mips(base_size, mips):
		#patch over the circle alpha mask for each mip
		image[0:size, place_x:place_x + size, 3] = mip_datas[mip]["outline_alpha"]
	return image

def gen_specific_molecule(base_size, mips, molecule, include_outline = False):
	image_back = filled_mip_image(base_size, mips)
	image_front = filled_mip_image(base_size, mips)
	shape = [row.split("-") for row in molecule.split("|")]
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
				simple_overlay_image(
					image_back, gen_single_atom_outline_image(base_size, mips, y_scale, x_scale, y, x))
			atom_image = gen_single_atom_image(base_size, mips, symbol, y_scale, x_scale, y, x)
			simple_overlay_image(image_front, atom_image)
			if left_bonds > 0:
				if left_bonds == 3:
					right_bond_images = gen_bond_images(base_size, mips, y_scale, x_scale, y, x - 1)["R"]
					simple_overlay_image(image_back, right_bond_images[3])
					left_bonds -= 2
				simple_overlay_image(
					image_front, gen_bond_images(base_size, mips, y_scale, x_scale, y, x)["L"][left_bonds])
			if up_bonds > 0:
				if up_bonds == 3:
					down_bond_images = gen_bond_images(base_size, mips, y_scale, x_scale, y - 1, x)["D"]
					simple_overlay_image(image_back, down_bond_images[3])
					up_bonds -= 2
				simple_overlay_image(
					image_front, gen_bond_images(base_size, mips, y_scale, x_scale, y, x)["U"][up_bonds])
			left_bonds = right_bonds
	return simple_overlay_image(image_back, image_front)

def gen_item_group_icon(base_size, mips):
	write_image(".", "item-group", gen_specific_molecule(base_size, mips, "O1-C2-N|1N1-1O-1H|1H"))
	image_counter_print("Item group written")

def gen_molecule_reaction_reactants_icon(base_size, mips):
	write_image(".", "molecule-reaction-reactants", gen_specific_molecule(base_size, mips, "-H1-O|H--1H|1O1-H"))
	image_counter_print("Molecule reaction reactants written")


#Composite image utility
def gen_composite_image(layers, base_image = None, include_outline = False):
	layer_image = None
	layer_outline_image = None
	layer_needs_mips = False
	base_layer_image = None
	base_layer_outline_image = None
	base_layer_needs_mips = False
	for (type, layer) in layers:
		if type == "layer":
			if base_layer_image is not None:
				simple_overlay_image(base_layer_image, layer_image)
				if include_outline:
					simple_overlay_image(base_layer_outline_image, layer_outline_image)
			else:
				base_layer_image = layer_image
				base_layer_outline_image = layer_outline_image
				base_layer_needs_mips = layer_needs_mips
			layer_needs_mips = "mips" in layer
			if layer_needs_mips:
				layer_image = filled_mip_image(layer["size"], layer["mips"], layer["color"])
				if include_outline:
					layer_outline_image = \
						filled_mip_image(layer["size"], layer["mips"], ICON_OVERLAY_OUTLINE_COLOR)
			else:
				height = layer.get("height", None) or layer["size"]
				width = layer.get("width", None) or layer["size"]
				layer_image = numpy.full((height, width, 4), layer["color"], numpy.uint8)
				if include_outline:
					layer_outline_image = \
						numpy.full((height, width, 4), ICON_OVERLAY_OUTLINE_COLOR, numpy.uint8)
		elif type == "overlay_at":
			layer_image = simple_overlay_image_at(base_layer_image, *layer, layer_image)
			layer_needs_mips = base_layer_needs_mips
			base_layer_image = None
		elif type == "circle":
			draw_center = draw_coords_from(*layer["center"])
			draw_radius = draw_radius_from(layer["radius"])
			draw_alpha_on(layer_image, lambda mask: draw_filled_circle_alpha(mask, draw_center, draw_radius))
		elif type == "arc":
			draw_center = draw_coords_from(*layer["center"])
			draw_axes = (draw_radius_from(layer["radius"]),) * 2
			thickness = layer["thickness"]
			def draw_arc(mask):
				(start_angle, arc) = layer["arc"]
				cv2.ellipse(
					#image, center, size
					mask, draw_center, draw_axes,
					#angles
					start_angle, 0, arc,
					#color, thickness, line type, precision
					255, thickness, cv2.LINE_AA, PRECISION_BITS)
			draw_alpha_on(layer_image, draw_arc)
			if include_outline:
				thickness += int(ICON_OVERLAY_OUTLINE_FRACTION * layer_image.shape[0] * 2)
				draw_alpha_on(layer_outline_image, draw_arc)
		elif type == "arrow":
			def draw_arrow(mask):
				draw_poly_alpha(mask, [get_draw_arrow_points(*layer)])
			draw_alpha_on(layer_image, draw_arrow)
			if include_outline:
				outline_add = ICON_OVERLAY_ARROW_OUTLINE_FRACTION * layer_image.shape[0]
				old_arrow_magnitude = math.sqrt(layer[2] ** 2 + layer[3] ** 2)
				arrow_size_multiplier = (old_arrow_magnitude + outline_add) / old_arrow_magnitude
				layer = layer[:2] + tuple(xy * arrow_size_multiplier for xy in layer[2:])
				draw_alpha_on(layer_outline_image, draw_arrow)
		elif type == "poly":
			layer = [draw_coords_from(*point) for point in layer]
			draw_alpha_on(layer_image, lambda mask: draw_poly_alpha(mask, [layer]))
		elif type == "line":
			draw_start = draw_coords_from(*layer["start"])
			draw_end = draw_coords_from(*layer["end"])
			thickness = layer["thickness"]
			def draw_line(mask):
				cv2.line(mask, draw_start, draw_end, 255, thickness, cv2.LINE_AA, PRECISION_BITS)
			draw_alpha_on(layer_image, draw_line)
			if include_outline:
				thickness += int(ICON_OVERLAY_OUTLINE_FRACTION * layer_image.shape[0] * 2)
				draw_alpha_on(layer_outline_image, draw_line)
	if base_layer_image is not None:
		layer_image = simple_overlay_image(base_layer_image, layer_image)
		if include_outline:
			layer_outline_image = simple_overlay_image(base_layer_outline_image, layer_outline_image)
		layer_needs_mips = base_layer_needs_mips
	if layer_needs_mips:
		easy_mips(layer_image)
		if include_outline:
			easy_mips(layer_outline_image, multi_color_alpha_weighting=False)
	if base_image is not None:
		layer_image = simple_overlay_image(base_image, layer_image)
	return simple_overlay_image(layer_outline_image, layer_image) if include_outline else layer_image


#Generate selector icons
def get_rotation_selector_arc_values(base_size):
	radius = ROTATION_SELECTOR_RADIUS_FRACTION * base_size
	center = base_size / 2
	arrow_size = ROTATION_SELECTOR_ARROW_SIZE_FRACTION * base_size
	return (radius, center, arrow_size)

def gen_prepared_rotation_selector_image(base_size, mips, arcs, arrow_pointss):
	(radius, center, _) = get_rotation_selector_arc_values(base_size)
	thickness = int(ROTATION_SELECTOR_THICKNESS_FRACTION * base_size)
	dot_radius = ROTATION_SELECTOR_DOT_RADIUS_FRACTION * base_size
	center = (center, center)
	layers = [
		("layer", {"size": base_size, "mips": mips, "color": ROTATION_SELECTOR_COLOR}),
		("circle", {"center": center, "radius": dot_radius}),
	]
	layers.extend(("arc", {"center": center, "radius": radius, "arc": arc, "thickness": thickness}) for arc in arcs)
	layers.append(("layer", {"size": base_size, "color": ROTATION_SELECTOR_COLOR}))
	layers.extend(("arrow", arrow_points) for arrow_points in arrow_pointss)
	return gen_composite_image(layers)

def gen_left_right_rotation_selector_image(base_size, mips, start_angle, arrow_center_x_radius_multiplier):
	(radius, center, arrow_size) = get_rotation_selector_arc_values(base_size)
	arrow_points = (center + radius * arrow_center_x_radius_multiplier, center, 0, -arrow_size)
	return gen_prepared_rotation_selector_image(base_size, mips, [(start_angle, 90)], [arrow_points])

def gen_flip_rotation_selector_image(base_size, mips):
	(radius, center, arrow_size) = get_rotation_selector_arc_values(base_size)
	arrow_pointss = []
	for mult in [-1, 1]:
		center_x = center + radius / 2 * mult
		center_y = center - radius / 2 * math.sqrt(3) * mult
		x_offset = arrow_size / 2 * math.sqrt(3) * mult
		y_offset = arrow_size / 2 * mult
		arrow_pointss.append((center_x, center_y, x_offset, y_offset))
	return gen_prepared_rotation_selector_image(base_size, mips, [(120, 120), (300, 120)], arrow_pointss)

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
		draw_alpha_on(arrow_image, lambda mask: draw_poly_alpha(mask, [draw_arrow_points]))
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
	image_counter_print("Selectors written")


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

def iter_gen_component_overlays(base_size, suffix):
	loader_input_poly_points = [
		(base_size * 2 / 32, base_size * 16 / 32),
		(base_size * 2 / 32, base_size * 55 / 32),
		(base_size * 16 / 32, base_size * 48 / 32),
		(base_size * 30 / 32, base_size * 55 / 32),
		(base_size * 30 / 32, base_size * 16 / 32),
	]
	loader_output_poly_points = [
		(base_size * 2 / 32, base_size * 40 / 32),
		(base_size * 2 / 32, base_size * 8 / 32),
		(base_size * 16 / 32, base_size * 1 / 32),
		(base_size * 30 / 32, base_size * 8 / 32),
		(base_size * 30 / 32, base_size * 40 / 32),
	]
	overlays = [
		("base", (160, 160, 224, 0), loader_input_poly_points),
		("catalyst", (160, 224, 160, 0), loader_input_poly_points),
		("modifier", (224, 160, 160, 0), loader_input_poly_points),
		("result", (224, 224, 160, 0), loader_output_poly_points),
		("byproduct", (224, 160, 224, 0), loader_output_poly_points),
		("remainder", (160, 224, 224, 0), loader_output_poly_points),
	]
	for (component, color, loader_poly_points) in overlays:
		image = gen_composite_image([
			("layer", {"height": int(base_size * 1.75), "width": base_size, "color": color}),
			("poly", loader_poly_points),
			("layer", {"size": base_size, "color": color}),
			("circle", {"center": (base_size / 2, base_size / 2), "radius": base_size / 2}),
			("overlay_at", (0, int(loader_poly_points[0][1] - base_size / 2))),
		])
		yield (component + suffix, build_4_way_image(image))

def gen_detector_indicators(base_size):
	layers = [
		("layer", {"height": base_size * 2, "width": base_size, "color": DETECTOR_ARROW_COLOR}),
		("poly", [
			(base_size * 10 / 32, base_size * 8 / 32),
			(base_size * 16 / 32, base_size * 2 / 32),
			(base_size * 22 / 32, base_size * 8 / 32),
		]),
		("poly", [
			(base_size * 10 / 32, base_size * 62 / 32),
			(base_size * 16 / 32, base_size * 56 / 32),
			(base_size * 22 / 32, base_size * 62 / 32),
		]),
	]
	return build_4_way_image(gen_composite_image(layers))

def gen_detector_symbol(base_size):
	symbol_image = gen_single_atom_shape_image(base_size, 1, 2, 2, 0, 0, TARGET_SELECTOR_HIGHLIGHT_COLOR)
	simple_overlay_image(symbol_image, gen_single_atom_shape_image(base_size, 1, 2, 2, 0, 1, TARGET_SELECTOR_DEFAULT_COLOR))
	simple_overlay_image(symbol_image, gen_single_atom_shape_image(base_size, 1, 2, 2, 1, 0, TARGET_SELECTOR_DEFAULT_COLOR))
	simple_overlay_image(
		symbol_image, gen_single_atom_shape_image(base_size, 1, 2, 2, 1, 1, TARGET_SELECTOR_HIGHLIGHT_COLOR))
	size = int(DETECTOR_SYMBOL_SIZE_FRACTION * base_size)
	return resize(symbol_image, size, size)

def gen_building_overlays(base_size):
	building_overlays_folder = "building-overlays"
	if not os.path.exists(building_overlays_folder):
		os.mkdir(building_overlays_folder)
	for (base_size, suffix) in [(base_size, ""), (base_size * 2, "-hr")]:
		write_images(building_overlays_folder, iter_gen_component_overlays(base_size, suffix))
		moleculifier_image = gen_specific_molecule(base_size * 2, 1, MOLECULIFIER_MOLECULE)
		write_image(building_overlays_folder, f"moleculifier{suffix}", moleculifier_image)
		write_image(building_overlays_folder, f"molecule-detector{suffix}", gen_detector_indicators(base_size))
		write_image(building_overlays_folder, f"molecule-detector-symbol{suffix}", gen_detector_symbol(base_size))
	image_counter_print("Building overlays written")


#Generate recipe icons
def gen_molecule_rotator_image(base_size, mips, include_outline):
	(radius, center_xy, arrow_size) = get_rotation_selector_arc_values(base_size)
	center_xy += base_size / -8
	thickness = int(ROTATION_SELECTOR_THICKNESS_FRACTION * base_size)
	layers = [
		("layer", {"size": base_size, "mips": mips, "color": MOLECULE_ROTATOR_ICON_COLOR}),
		("arc", {"center": (center_xy, center_xy), "radius": radius, "arc": (0, 90), "thickness": thickness}),
		("layer", {"size": base_size, "color": MOLECULE_ROTATOR_ICON_COLOR}),
		("arrow", (center_xy + radius, center_xy, 0, arrow_size)),
	]
	image = gen_specific_molecule(base_size, mips, "H1-H-|1H|", include_outline)
	return gen_composite_image(layers, image, include_outline)

def gen_molecule_sorter_image(base_size, mips, include_outline):
	image = gen_specific_molecule(base_size, mips, "O--||H", include_outline)
	left_x = MOLECULE_SORTER_ARROW_LEFT_FRACTION * base_size
	right_x = MOLECULE_SORTER_ARROW_RIGHT_FRACTION * base_size
	thickness = int(MOLECULE_SORTER_ARROW_THICKNESS_FRACTION * base_size)
	arrow_size = MOLECULE_SORTER_ARROW_SIZE_FRACTION * base_size
	layers = []
	for y in [0, 2]:
		color = MOLECULE_SORTER_ARROW_COLORS[y]
		center_y = get_circle_mip_datas(base_size, mips, 3, 3, y, 1)[0]["center_y"]
		layers.extend([
			("layer", {"size": base_size, "mips": mips, "color": color}),
			("line", {"start": (left_x, center_y), "end": (right_x, center_y), "thickness": thickness}),
			("layer", {"size": base_size, "color": color}),
			("arrow", (right_x, center_y, -arrow_size, 0)),
		])
	return gen_composite_image(layers, image, include_outline)

def gen_molecule_debonder_image(base_size, mips, include_outline):
	image = gen_specific_molecule(base_size, mips, "-O|-2O", include_outline)
	left = MOLECULE_DEBONDER_LEFT_FRACTION * base_size
	right = MOLECULE_DEBONDER_RIGHT_FRACTION * base_size
	thickness = int(MOLECULE_DEBONDER_THICKNESS_FRACTION * base_size)
	layers = [
		("layer", {"size": base_size, "mips": mips, "color": MOLECULE_DEBONDER_COLOR}),
		("line", {"start": (left, base_size / 2), "end": (right, base_size / 2), "thickness": thickness}),
	]
	return gen_composite_image(layers, image, include_outline)

def gen_molecule_bonder_image(base_size, mips, include_outline):
	image = gen_specific_molecule(base_size, mips, "-H|-H", include_outline)
	left = MOLECULE_DEBONDER_LEFT_FRACTION * base_size
	right = MOLECULE_DEBONDER_RIGHT_FRACTION * base_size
	center_x = (left + right) * 0.5
	top = MOLECULE_BONDER_TOP_FRACTION * base_size
	bottom = MOLECULE_BONDER_BOTTOM_FRACTION * base_size
	thickness = int(MOLECULE_DEBONDER_THICKNESS_FRACTION * base_size)
	layers = [
		("layer", {"size": base_size, "mips": mips, "color": MOLECULE_BONDER_COLOR}),
		("line", {"start": (left, base_size / 2), "end": (right, base_size / 2), "thickness": thickness}),
		("layer", {"size": base_size, "color": MOLECULE_BONDER_COLOR}),
		("line", {"start": (center_x, top), "end": (center_x, bottom), "thickness": thickness}),
	]
	return gen_composite_image(layers, image, include_outline)

def gen_molecule_fissioner_image(base_size, mips, include_outline):
	image = gen_specific_molecule(base_size, mips, "C--He||--Be", include_outline)
	thickness = int(MOLECULE_FISSIONER_THICKNESS_FRACTION * base_size)
	one_third = base_size / 3
	two_thirds = base_size * 2 / 3
	layers = [
		("layer", {"size": base_size, "mips": mips, "color": MOLECULE_FISSIONER_COLOR}),
		("line", {"start": (one_third, one_third), "end": (two_thirds, one_third), "thickness": thickness}),
		("layer", {"size": base_size, "color": MOLECULE_FISSIONER_COLOR}),
		("line", {"start": (one_third, one_third), "end": (two_thirds, two_thirds), "thickness": thickness}),
	]
	return gen_composite_image(layers, image, include_outline)

def gen_molecule_fusioner_image(base_size, mips, include_outline):
	image = gen_specific_molecule(base_size, mips, "N--O||H", include_outline)
	thickness = int(MOLECULE_FISSIONER_THICKNESS_FRACTION * base_size)
	one_third = base_size / 3
	two_thirds = base_size * 2 / 3
	layers = [
		("layer", {"size": base_size, "mips": mips, "color": MOLECULE_FUSIONER_COLOR}),
		("line", {"start": (one_third, one_third), "end": (two_thirds, one_third), "thickness": thickness}),
		("layer", {"size": base_size, "color": MOLECULE_FUSIONER_COLOR}),
		("line", {"start": (one_third, two_thirds), "end": (two_thirds, one_third), "thickness": thickness}),
	]
	return gen_composite_image(layers, image, include_outline)

def gen_molecule_voider_image(base_size, mips, include_outline):
	image = gen_specific_molecule(base_size, mips, "N3-N", include_outline)
	top_left = MOLECULE_VOIDER_XY_FRACTION * base_size
	bottom_right = base_size - top_left
	thickness = int(MOLECULE_VOIDER_THICKNESS_FRACTION * base_size)
	layers = [
		("layer", {"size": base_size, "mips": mips, "color": MOLECULE_VOIDER_COLOR}),
		("line", {"start": (top_left, top_left), "end": (bottom_right, bottom_right), "thickness": thickness}),
		("layer", {"size": base_size, "color": MOLECULE_VOIDER_COLOR}),
		("line", {"start": (top_left, bottom_right), "end": (bottom_right, top_left), "thickness": thickness}),
	]
	return gen_composite_image(layers, image, include_outline)

def iter_gen_all_building_recipe_icons(base_size, mips, include_outline):
	yield (MOLECULE_ROTATOR_NAME, gen_molecule_rotator_image(base_size, mips, include_outline))
	yield (MOLECULE_SORTER_NAME, gen_molecule_sorter_image(base_size, mips, include_outline))
	yield (MOLECULE_DEBONDER_NAME, gen_molecule_debonder_image(base_size, mips, include_outline))
	yield (MOLECULE_BONDER_NAME, gen_molecule_bonder_image(base_size, mips, include_outline))
	yield (MOLECULE_FISSIONER_NAME, gen_molecule_fissioner_image(base_size, mips, include_outline))
	yield (MOLECULE_FUSIONER_NAME, gen_molecule_fusioner_image(base_size, mips, include_outline))
	yield (MOLECULE_VOIDER_NAME, gen_molecule_voider_image(base_size, mips, include_outline))

def iter_gen_moleculify_recipe_icons(base_size, mips):
	base_icons_folder = os.path.join(BASE_GRAPHICS_PATH, "icons")
	base_fluid_icons_folder = os.path.join(base_icons_folder, "fluid")
	image_pairs = [
		("water", "-H|H1-1O", os.path.join(base_fluid_icons_folder, "water.png")),
		("air", "N-O|3N-2O", os.path.join(base_fluid_icons_folder, "steam.png")),
	]
	for (name, moleculify_result_molecule, moleculify_source_image_path) in image_pairs:
		moleculify_result_image = gen_specific_molecule(base_size, mips, moleculify_result_molecule)
		moleculify_source_image = cv2.imread(moleculify_source_image_path, cv2.IMREAD_UNCHANGED)
		image = filled_mip_image(base_size, mips)
		#overlay the sub images at half-size at each mip level
		for (mip, place_x, size) in iter_mips(base_size, mips):
			half_size = size // 2
			image[0:half_size, place_x:place_x + half_size] = \
				resize(moleculify_source_image[0:size, place_x:place_x + size], half_size, half_size)
			image[half_size:size, place_x + half_size:place_x + size] = \
				resize(moleculify_result_image[0:size, place_x:place_x + size], half_size, half_size)
		#add an arrow image over the sub images
		thickness = int(MOLECULIFY_ARROW_THICKNESS_FRACTION * base_size)
		arrow_size_offset = MOLECULIFY_ARROW_SIZE_FRACTION * base_size / -math.sqrt(2)
		start_xy = base_size * 3 / 8
		end_xy = base_size * 5 / 8
		layers = [
			("layer", {"size": base_size, "mips": mips, "color": MOLECULIFY_ARROW_COLOR}),
			("line", {"start": (start_xy, start_xy), "end": (end_xy, end_xy), "thickness": thickness}),
			("layer", {"size": base_size, "color": MOLECULIFY_ARROW_COLOR}),
			("arrow", (end_xy, end_xy, arrow_size_offset, arrow_size_offset)),
		]
		yield (f"moleculify-{name}", gen_composite_image(layers, image))

def gen_all_recipe_icons(base_size, mips):
	recipes_folder = "recipes"
	if not os.path.exists(recipes_folder):
		os.mkdir(recipes_folder)
	write_images(recipes_folder, iter_gen_all_building_recipe_icons(base_size, mips, False))
	write_images(recipes_folder, iter_gen_moleculify_recipe_icons(base_size, mips))
	image_counter_print("Recipe icons written")


#Generate building icon overlays
def gen_icon_overlays(base_size, mips):
	icon_overlays_folder = "icon-overlays"
	if not os.path.exists(icon_overlays_folder):
		os.mkdir(icon_overlays_folder)
	write_image(icon_overlays_folder, "molecule-detector", gen_specific_molecule(base_size, mips, "H|1O|1H", True))
	write_images(icon_overlays_folder, iter_gen_all_building_recipe_icons(base_size, mips, True))
	moleculifier_image = gen_specific_molecule(base_size, mips, MOLECULIFIER_MOLECULE, include_outline=True)
	write_image(icon_overlays_folder, "moleculifier", moleculifier_image)
	image_counter_print("Icon overlays written")


#Generate molecule shape backgrounds
def gen_molecule_shape_backgrounds(base_size, mips):
	shapes_folder = "shapes"
	if not os.path.exists(shapes_folder):
		os.mkdir(shapes_folder)
	for shape_n in range(1, 1 << MAX_GRID_AREA):
		if not any((shape_n & 1 << i) != 0 for i in range(MAX_GRID_WIDTH)) \
				or not any((shape_n & 1 << i) != 0 for i in range(0, MAX_GRID_AREA, MAX_GRID_WIDTH)):
			continue
		grid = []
		for i in range(MAX_GRID_AREA):
			grid.append(1 if shape_n & 1 << i != 0 else 0)
		atom_count = sum(grid)

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
		for (i, slot) in enumerate(grid):
			if slot == 0:
				continue
			x = i % MAX_GRID_WIDTH
			y = i // MAX_GRID_WIDTH
			atom_image = gen_single_atom_image(base_size, mips, SHAPE_ATOM_CHARACTER, y_scale, x_scale, y, x)
			if i == first_slot_i:
				image = atom_image
			else:
				simple_overlay_image(image, atom_image)
		write_image(shapes_folder, f"{shape_n:03X}", image)
	image_counter_print("Molecule shape backgrounds written")


#Generate the reaction settings icon
def gen_reaction_settings_icon(base_size, mips):
	#draw the outer and inner frame rects
	image = filled_mip_image(base_size, mips, REACTION_SETTINGS_OUTER_COLOR)
	half_size = base_size / 2
	top_left = half_size - REACTION_SETTINGS_RECT_HALF_WIDTH_FRACTION * base_size
	bottom_right = base_size - top_left
	draw_top_left = draw_coords_from(top_left, top_left)
	draw_bottom_right = draw_coords_from(bottom_right, bottom_right)
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
	draw_top_left = draw_coords_from(box_left, box_top)
	draw_bottom_right = draw_coords_from(box_right, box_bottom)
	cv2.rectangle(inner_image, draw_top_left, draw_bottom_right, box_color, cv2.FILLED, cv2.LINE_AA, PRECISION_BITS)
	draw_top_left = draw_coords_from(box_left, base_size - box_bottom)
	draw_bottom_right = draw_coords_from(box_right, base_size - box_top)
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
	write_image(".", "reaction-settings", simple_overlay_image(image, inner_image))
	image_counter_print("Reaction settings icon written")


#Generate all graphics
import time
start = time.time()
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
print(time.strftime(f"Images generated at %Y-%m-%d %H:%M:%S after {(time.time() - start):.3f}s ({total_images} images total)"))
