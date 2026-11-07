extends RefCounted
## Bakes the minimap terrain from the same rules the ground mesh uses:
## grass, mud, sand, roads, rock, shallow and deep water, with coast shading.

const Ground = preload("res://game/ground_view.gd")
const PX: int = 4

const GRASS: Color = Color(0.25, 0.4, 0.19)
const MUD: Color = Color(0.36, 0.28, 0.17)
const SAND: Color = Color(0.68, 0.61, 0.4)
const ROAD: Color = Color(0.66, 0.55, 0.38)
const ROCK: Color = Color(0.5, 0.48, 0.44)
const SHALLOW: Color = Color(0.15, 0.42, 0.5)
const DEEP: Color = Color(0.05, 0.19, 0.33)

## Terrain profile from the match scene. Matches the ground_view.dress() calls.
static func profile_for(host: Node) -> String:
	if host == null:
		return "mission"
	var map_id: String = str(host.get("map_id")) if "map_id" in host else ""
	match map_id:
		"burma_road":
			return "burma"
		"ten_degree_atolls":
			return "atolls"
		"mekong_delta":
			return "mekong"
		"chiang_rai":
			return "chiang"
		"showcase":
			return "showcase"
	var file: String = host.scene_file_path.get_file().get_basename()
	if file.contains("kokang"):
		return "kokang"
	if file.contains("sop_ruak"):
		return "sop"
	if file.contains("phillips"):
		return "phillips"
	if file.contains("nmrf"):
		return "nmrf"
	if file.contains("mvd"):
		return "mvd"
	return "mission"

static func kind_at(profile: String, grid: SMDomainGrid, cell: Vector2i) -> String:
	var domain: int = grid.domain_at_cell(cell)
	if domain == SMDomainGrid.Domain.DEEP:
		return "deep"
	if domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.AIR:
		return "shallow"
	if domain == SMDomainGrid.Domain.CLIFF:
		return "rock"
	return Ground._kind_at(profile, grid, cell)

static func bake(grid: SMDomainGrid, profile: String) -> ImageTexture:
	if grid == null or grid.cols <= 0 or grid.rows <= 0:
		return null
	var w: int = grid.cols * PX
	var h: int = grid.rows * PX
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	var kinds: Array[PackedStringArray] = []
	for y: int in grid.rows:
		var row: PackedStringArray = PackedStringArray()
		for x: int in grid.cols:
			row.append(kind_at(profile, grid, Vector2i(x, y)))
		kinds.append(row)
	for y: int in grid.rows:
		for x: int in grid.cols:
			var kind: String = kinds[y][x]
			var base: Color = _ink(kind)
			var wet: bool = kind == "deep" or kind == "shallow"
			for py: int in PX:
				for px: int in PX:
					var ink: Color = base
					var n: float = float(Ground._hash(x * PX + px, y * PX + py) % 100) / 100.0
					ink = ink.lightened(0.05 * n) if not wet else ink
					if not wet and _near_water(kinds, grid, x, y, px, py):
						ink = ink.lerp(SAND, 0.55)
					if wet and _near_land(kinds, grid, x, y, px, py):
						ink = ink.lerp(SHALLOW.lightened(0.25), 0.5)
					if kind == "rock":
						ink = ink.lightened(0.18) if px + py < PX else ink.darkened(0.22)
					img.set_pixel(x * PX + px, y * PX + py, ink)
	return ImageTexture.create_from_image(img)

static func _ink(kind: String) -> Color:
	match kind:
		"deep":
			return DEEP
		"shallow":
			return SHALLOW
		"rock":
			return ROCK
		"road":
			return ROAD
		"sand":
			return SAND
		"mud":
			return MUD
	return GRASS

static func _wet_at(kinds: Array[PackedStringArray], grid: SMDomainGrid, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= grid.cols or y >= grid.rows:
		return -1
	var k: String = kinds[y][x]
	return 1 if k == "deep" or k == "shallow" else 0

static func _near_water(kinds: Array[PackedStringArray], grid: SMDomainGrid, x: int, y: int, px: int, py: int) -> bool:
	return (px == 0 and _wet_at(kinds, grid, x - 1, y) == 1) or (px == PX - 1 and _wet_at(kinds, grid, x + 1, y) == 1) or (py == 0 and _wet_at(kinds, grid, x, y - 1) == 1) or (py == PX - 1 and _wet_at(kinds, grid, x, y + 1) == 1)

static func _near_land(kinds: Array[PackedStringArray], grid: SMDomainGrid, x: int, y: int, px: int, py: int) -> bool:
	return (px <= 1 and _wet_at(kinds, grid, x - 1, y) == 0) or (px >= PX - 2 and _wet_at(kinds, grid, x + 1, y) == 0) or (py <= 1 and _wet_at(kinds, grid, x, y - 1) == 0) or (py >= PX - 2 and _wet_at(kinds, grid, x, y + 1) == 0)
