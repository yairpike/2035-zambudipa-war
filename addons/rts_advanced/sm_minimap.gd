class_name SMMinimap
extends Control
## Flat map of the domain grid. Land, water, both sides, and the camera view.
## A view script may hand in a baked terrain image; without one the grid paints per cell.

const LAND_COLOR: Color = Color(0.40, 0.36, 0.24)
const CLIFF_COLOR: Color = Color(0.50, 0.46, 0.40)
const WATER_COLOR: Color = Color(0.10, 0.32, 0.55)
const FRAME_COLOR: Color = Color(0.93, 0.94, 0.96)
const VIEW_COLOR: Color = Color(0.96, 0.92, 0.72)
const FOG_HIDDEN: Color = Color(0.02, 0.025, 0.035, 0.94)
const FOG_DIM: Color = Color(0.02, 0.025, 0.035, 0.55)

var grid: SMDomainGrid
var field: SMPointer
var camera: RTSCamera
var sight: SMSight
var goods: SMCommodityNet
var yard: SMBuildYard
var backdrop: Texture2D
var player_dots: int = 0
var enemy_dots: int = 0
var building_dots: int = 0
var claimed_dots: int = 0
var structure_dots: int = 0
var saw_land: bool = false
var saw_water: bool = false
var camera_rect: Rect2 = Rect2()
var frustum: PackedVector2Array = PackedVector2Array()
var fog_image: Image
var _fog_tex: ImageTexture
var _terrain_scanned: bool = false
var _corridor_cache: Image

func setup(p_grid: SMDomainGrid, p_field: SMPointer, p_camera: RTSCamera) -> void:
	grid = p_grid
	field = p_field
	camera = p_camera
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(156, 108)
	size = Vector2(156, 108)

func map_size() -> Vector2:
	if size.x < 8.0 or size.y < 8.0:
		return Vector2(200, 160)
	return size

func terrain_kind(cell: Vector2i) -> String:
	if grid == null:
		return "land"
	var domain: int = grid.domain_at_cell(cell)
	if domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.DEEP:
		return "water"
	return "land"

## A sight with no grid only carries weather. It cannot fog the map.
func fogged() -> bool:
	return sight != null and sight.grid != null

func sample() -> void:
	if not _terrain_scanned:
		saw_land = false
		saw_water = false
		if grid != null:
			for y: int in grid.rows:
				for x: int in grid.cols:
					if terrain_kind(Vector2i(x, y)) == "water":
						saw_water = true
					else:
						saw_land = true
			_terrain_scanned = true
	player_dots = 0
	enemy_dots = 0
	building_dots = 0
	claimed_dots = 0
	structure_dots = 0
	if field != null:
		player_dots = field.units_of(SMPointer.PLAYER).size()
		for u: RTSUnit in field.units_of(SMPointer.ENEMY):
			if _spotted(u.global_position):
				enemy_dots += 1
	if sight != null:
		for at: Vector3 in sight.posts:
			if _spotted(at):
				building_dots += 1
	if goods != null:
		for node: Dictionary in goods.nodes:
			if int(node.get("team", -1)) >= 0:
				claimed_dots += 1
	if yard != null:
		for id: StringName in yard.structure_pos:
			if yard.structure_alive(id):
				structure_dots += 1
	camera_rect = _view_rect()
	_paint_fog()

func covers_focus() -> bool:
	if camera == null:
		return false
	return camera_rect.grow(0.5).has_point(Vector2(camera.focus.x, camera.focus.z))

func pan_to(local: Vector2) -> Vector3:
	var world: Vector3 = _local_to_world(local)
	if camera != null:
		camera.focus_on(world)
		camera_rect = _view_rect()
	return world

func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pan_to(mb.position)
		accept_event()
		return
	var drag: InputEventMouseMotion = event as InputEventMouseMotion
	if drag != null and (drag.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pan_to(drag.position)
		accept_event()

func _spotted(at: Vector3) -> bool:
	return not fogged() or sight.sees(at)

func _paint_fog() -> void:
	if not fogged() or grid == null or grid.cols <= 0 or grid.rows <= 0:
		fog_image = null
		return
	var cols: int = grid.cols
	var rows: int = grid.rows
	if fog_image == null or fog_image.get_width() != cols or fog_image.get_height() != rows:
		fog_image = Image.create(cols, rows, false, Image.FORMAT_RGBA8)
		_fog_tex = null
	var clear_ink: Color = Color(0, 0, 0, 0)
	for y: int in rows:
		var row_base: int = y * cols
		for x: int in cols:
			var exp_val: int = sight.explored[row_base + x] if row_base + x < sight.explored.size() else 0
			fog_image.set_pixel(x, y, FOG_DIM if exp_val == 1 else FOG_HIDDEN)
	if sight.river_lit:
		for y: int in rows:
			for x: int in cols:
				if sight._on_corridor(grid.cell_center(Vector2i(x, y))):
					fog_image.set_pixel(x, y, clear_ink)
	var cs: float = grid.cell_size
	var ox: float = grid.origin.x
	var oz: float = grid.origin.z
	for i: int in mini(sight.seers.size(), sight.radii.size()):
		var at: Vector3 = sight.seers[i]
		var r: float = sight.radii[i]
		var y0: int = maxi(0, ceili((at.z - r - oz) / cs - 0.5))
		var y1: int = mini(rows - 1, floori((at.z + r - oz) / cs - 0.5))
		for y: int in range(y0, y1 + 1):
			var dz: float = oz + (float(y) + 0.5) * cs - at.z
			var reach: float = r * r - dz * dz
			if reach < 0.0:
				continue
			var half: float = sqrt(reach)
			var x0: int = maxi(0, ceili((at.x - half - ox) / cs - 0.5))
			var x1: int = mini(cols - 1, floori((at.x + half - ox) / cs - 0.5))
			if x1 >= x0:
				fog_image.fill_rect(Rect2i(x0, y, x1 - x0 + 1, 1), clear_ink)
	if _fog_tex == null:
		_fog_tex = ImageTexture.create_from_image(fog_image)
	else:
		_fog_tex.update(fog_image)

func _draw() -> void:
	var extent: Vector2 = map_size()
	if grid == null or grid.cols <= 0 or grid.rows <= 0:
		draw_rect(Rect2(Vector2.ZERO, extent), LAND_COLOR, true)
		return
	if backdrop != null:
		draw_texture_rect(backdrop, Rect2(Vector2.ZERO, extent), false)
	else:
		var step: Vector2 = Vector2(extent.x / float(grid.cols), extent.y / float(grid.rows))
		for y: int in grid.rows:
			for x: int in grid.cols:
				var cell: Vector2i = Vector2i(x, y)
				draw_rect(Rect2(Vector2(float(x) * step.x, float(y) * step.y), step + Vector2(0.5, 0.5)), _cell_color(cell), true)
	if _fog_tex != null and fogged():
		draw_texture_rect(_fog_tex, Rect2(Vector2.ZERO, extent), false)
	var friendly: Color = Color(0.3, 0.85, 0.4)
	var hostile: Color = Color(0.9, 0.25, 0.2)
	if field != null:
		friendly = field.teams.color_of(SMPointer.PLAYER)
		hostile = field.teams.color_of(SMPointer.ENEMY)
	if yard != null:
		for id: StringName in yard.structure_pos:
			if yard.structure_alive(id):
				_block(yard.structure_pos[id], friendly)
	if sight != null:
		for at: Vector3 in sight.posts:
			if _spotted(at):
				_block(at, hostile)
	if goods != null:
		for node: Dictionary in goods.nodes:
			var spot: Vector3 = node.get("pos", Vector3.ZERO) as Vector3
			var team: int = int(node.get("team", -1))
			var ink: Color = Color(0.95, 0.78, 0.22)
			if team == SMPointer.PLAYER:
				ink = friendly
			elif team > 0:
				ink = hostile
			_diamond(spot, ink)
	if field != null:
		for u: RTSUnit in field.units_of(SMPointer.ENEMY):
			if _spotted(u.global_position):
				_dot(u.global_position, hostile)
		for u: RTSUnit in field.units_of(SMPointer.PLAYER):
			_dot(u.global_position, friendly.lightened(0.25) if u.selected else friendly)
		if field.beacon_at != Vector3.INF:
			var beacon_p: Vector2 = _world_to_local(field.beacon_at)
			var pulse: float = 4.0 + 1.5 * sin(float(Time.get_ticks_msec()) * 0.006)
			draw_arc(beacon_p, pulse, 0.0, TAU, 16, Color(0.98, 0.82, 0.28), 1.5, true)
	if frustum.size() == 4:
		var edge: Vector2 = size - Vector2(1, 1)
		var bounds: PackedVector2Array = PackedVector2Array([Vector2(1, 1), Vector2(edge.x, 1), edge, Vector2(1, edge.y)])
		var clipped: Array[PackedVector2Array] = Geometry2D.intersect_polygons(frustum, bounds)
		for part: PackedVector2Array in clipped:
			if part.size() < 3:
				continue
			var loop: PackedVector2Array = part.duplicate()
			loop.append(part[0])
			draw_polyline(loop, Color(0, 0, 0, 0.5), 3.0, true)
			draw_polyline(loop, VIEW_COLOR, 1.5, true)
	else:
		var local_view: Rect2 = _world_rect_local(camera_rect)
		if local_view.size.x > 1.0 and local_view.size.y > 1.0:
			draw_rect(local_view, VIEW_COLOR, false, 1.5)

func _cell_color(cell: Vector2i) -> Color:
	var domain: int = grid.domain_at_cell(cell)
	var base: Color = LAND_COLOR
	if domain == SMDomainGrid.Domain.SHALLOW or domain == SMDomainGrid.Domain.DEEP:
		base = WATER_COLOR
	elif domain == SMDomainGrid.Domain.CLIFF:
		base = CLIFF_COLOR
	return base

func _dot(at: Vector3, color: Color) -> void:
	var p: Vector2 = _world_to_local(at)
	draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0, 0, 0, 0.7), true)
	draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), color, true)

func _block(at: Vector3, color: Color) -> void:
	var p: Vector2 = _world_to_local(at)
	draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), Color(0, 0, 0, 0.75), true)
	draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), color, true)

func _diamond(at: Vector3, color: Color) -> void:
	var p: Vector2 = _world_to_local(at)
	var pts: PackedVector2Array = PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)])
	draw_colored_polygon(pts, color)

func _world_to_local(at: Vector3) -> Vector2:
	var extent: Vector2 = map_size()
	var span: Vector2 = _span()
	var u: float = clampf((at.x - grid.origin.x) / span.x, 0.0, 1.0)
	var v: float = clampf((at.z - grid.origin.z) / span.y, 0.0, 1.0)
	return Vector2(u * extent.x, v * extent.y)

func _local_to_world(local: Vector2) -> Vector3:
	var extent: Vector2 = map_size()
	var span: Vector2 = _span()
	var u: float = clampf(local.x / extent.x, 0.0, 1.0)
	var v: float = clampf(local.y / extent.y, 0.0, 1.0)
	return Vector3(grid.origin.x + u * span.x, 0.0, grid.origin.z + v * span.y)

func _span() -> Vector2:
	return Vector2(float(grid.cols) * grid.cell_size, float(grid.rows) * grid.cell_size)

func _world_rect_local(world: Rect2) -> Rect2:
	if grid == null:
		return Rect2()
	var a: Vector2 = _world_to_local(Vector3(world.position.x, 0.0, world.position.y))
	var b: Vector2 = _world_to_local(Vector3(world.end.x, 0.0, world.end.y))
	return Rect2(a, b - a).abs()

func _view_rect() -> Rect2:
	frustum = PackedVector2Array()
	if camera == null:
		return Rect2()
	var vs: Vector2 = Vector2(1280, 720)
	var vp: Viewport = camera.get_viewport()
	if vp != null:
		var visible: Vector2 = vp.get_visible_rect().size
		if visible.x >= 2.0 and visible.y >= 2.0:
			vs = visible
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	var hits: int = 0
	var corners: Array[Vector2] = [Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(0, vs.y)]
	var ground_pts: PackedVector2Array = PackedVector2Array()
	for corner: Vector2 in corners:
		var ground: Vector3 = camera.ground_at(corner)
		if ground == Vector3.INF:
			continue
		hits += 1
		min_x = minf(min_x, ground.x)
		max_x = maxf(max_x, ground.x)
		min_z = minf(min_z, ground.z)
		max_z = maxf(max_z, ground.z)
		if grid != null:
			ground_pts.append(_world_to_local(ground))
	var projected: Rect2 = Rect2()
	if hits == 4:
		projected = Rect2(min_x, min_z, maxf(0.5, max_x - min_x), maxf(0.5, max_z - min_z))
	if hits == 4 and projected.grow(0.5).has_point(Vector2(camera.focus.x, camera.focus.z)):
		if ground_pts.size() == 4:
			frustum = ground_pts
		return projected
	var half: float = maxf(6.0, camera.distance * 0.35)
	return Rect2(camera.focus.x - half, camera.focus.z - half, half * 2.0, half * 2.0)
