extends Node
## Makes building placement unmistakable. While a ghost is out:
## - a local grid aura (the footprint grown by AURA cells, 7x7 around a 3x3 building) tints every cell: emerald where
##   the building may stand, crimson on roads, cliffs, scenery and other plots, cyan on water a land building cannot
##   use (a naval building reads water as emerald and land as crimson);
## - a high-contrast pill under the ghost names the exact rule while the spot is blocked.
## A refused click plays the EVA refusal for that rule, the error buzz, and flashes the blocked cells.
## It reads SMPlacement / SMBasePlan and draws nothing into the sim.

const VoiceBank = preload("res://game/voice_bank.gd")
const SoundBank = preload("res://game/sound_bank.gd")
const AURA: int = 2
const FLASH_TIME: float = 0.8
const EMERALD: Color = Color(0.12, 0.86, 0.46, 0.5)
const CRIMSON: Color = Color(0.9, 0.08, 0.16, 0.55)
const CYAN: Color = Color(0.16, 0.8, 0.98, 0.5)

const ROAD: String = "CANNOT DEPLOY HERE — BLOCKED BY ROAD"
const WATER: String = "CANNOT DEPLOY HERE — WATER (LAND STRUCTURE)"
const NAVAL: String = "CANNOT DEPLOY HERE — NEEDS DEEP WATER & OPEN CHANNEL"
const STEEP: String = "CANNOT DEPLOY HERE — TOO STEEP / OBSTRUCTED"
const OCCUPIED: String = "CANNOT DEPLOY HERE — OCCUPIED BY UNIT/BUILDING"
const FAR: String = "CANNOT DEPLOY HERE — MUST BUILD NEAR AN ALLIED STRUCTURE"

var side: SMSide
var flash_left: float = 0.0
var refusals: int = 0
var _host: Node3D
var _pill: PanelContainer
var _pill_line: Label
var _legend: Label

static func attach(host: Node3D, p_side: SMSide) -> Node:
	if host == null or p_side == null:
		return null
	var have: Node = host.get_node_or_null("PlacementFeedback")
	if have != null:
		return have
	var node: Node = Node.new()
	node.name = "PlacementFeedback"
	node.set_script(load("res://game/placement_feedback.gd") as GDScript)
	host.add_child(node)
	node.call("bind", host, p_side)
	return node

## The pill line for a refusal reason from SMBasePlan / SMSide.
static func pill_text(reason: String) -> String:
	match reason:
		"blocked by a road":
			return ROAD
		"needs dry ground":
			return WATER
		"naval structures go on water", "the bay must face open water", "no open water in reach":
			return NAVAL
		"too steep", "the exit is blocked", "off the map", "blocks a resource site":
			return STEEP
		"the ground is taken", "too close to another building", "an enemy unit is in the way":
			return OCCUPIED
		"outside the build radius":
			return FAR
	return "CANNOT DEPLOY HERE — %s" % reason

## Aura tint for one SMBasePlan.cell_state.
static func ink_of(state: String) -> Color:
	if state == "ok":
		return EMERALD
	if state == "water":
		return CYAN
	if state == "far":
		return Color(CRIMSON.r, CRIMSON.g, CRIMSON.b, 0.28)
	return CRIMSON

func bind(host: Node3D, p_side: SMSide) -> void:
	_host = host
	side = p_side
	if not side.placement.changed.is_connected(paint):
		side.placement.changed.connect(paint)
	if not side.placement.refused.is_connected(_on_refused):
		side.placement.refused.connect(_on_refused)
	if not side.placement.finished.is_connected(_on_finished):
		side.placement.finished.connect(_on_finished)

## Cells of the aura with their state, footprint first. Empty while nothing is being placed.
func aura() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var plan: SMPlacement = side.placement if side != null else null
	if plan == null or not plan.active or plan.spot == Vector3.INF or side.plan.grid == null:
		return out
	var wet: bool = side.floats(plan.id) and not plan.redeploy
	var foot: Array[Vector2i] = plan.cells()
	var rect: Rect2i = side.plan.rect_at(plan.spot, side.footprint_at(plan.id, plan.yaw))
	var ring: Rect2i = rect.grow(AURA)
	side.plan.radius = side.yard.radius
	side.plan.center = side.placement_center(plan.id)
	for y: int in range(ring.position.y, ring.end.y):
		for x: int in range(ring.position.x, ring.end.x):
			var c: Vector2i = Vector2i(x, y)
			var state: String = side.plan.cell_state(c, wet, plan.id)
			out.append({"cell": c, "state": state, "foot": foot.has(c)})
	return out

func paint() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var plan: SMPlacement = side.placement
	var tiles: MultiMeshInstance3D = _host.get_node_or_null("PlacementAura") as MultiMeshInstance3D
	if not plan.active or plan.spot == Vector3.INF:
		if tiles != null:
			tiles.queue_free()
		_show_pill(false, "")
		return
	if tiles == null:
		tiles = _tiles()
	var cells: Array[Dictionary] = aura()
	var grid: SMDomainGrid = side.plan.grid
	var mm: MultiMesh = tiles.multimesh
	mm.instance_count = cells.size()
	var pulse: float = 0.0
	if flash_left > 0.0:
		pulse = 0.5 + 0.5 * sin(flash_left * 28.0)
	for i: int in cells.size():
		var row: Dictionary = cells[i]
		var c: Vector2i = row["cell"] as Vector2i
		var ink: Color = ink_of(str(row["state"]))
		var lift: float = 0.06
		if bool(row["foot"]):
			ink.a = minf(0.85, ink.a + 0.22)
			lift = 0.1
		if str(row["state"]) != "ok" and pulse > 0.0:
			ink = ink.lerp(Color(1.0, 0.95, 0.9, 0.9), pulse * 0.6)
		var at: Vector3 = grid.cell_center(c) + Vector3(0.0, lift, 0.0)
		mm.set_instance_transform(i, Transform3D(Basis(), at))
		mm.set_instance_color(i, ink)
	_show_pill(not plan.valid(), pill_text(plan.reason))

func _process(delta: float) -> void:
	if side == null or not side.placement.active:
		if _pill != null and _pill.visible:
			_show_pill(false, "")
		return
	if flash_left > 0.0:
		flash_left = maxf(0.0, flash_left - delta)
		paint()
	_place_pill()

func _on_refused(reason: String) -> void:
	refusals += 1
	flash_left = FLASH_TIME
	SoundBank.play(_host, "error_buzz")
	VoiceBank.say(_host, VoiceBank.reason_key(reason))
	paint()

func _on_finished(_id: StringName, result: String) -> void:
	if result == "placed" or result == "redeployed":
		VoiceBank.say(_host, "building")

func _tiles() -> MultiMeshInstance3D:
	var tiles: MultiMeshInstance3D = MultiMeshInstance3D.new()
	tiles.name = "PlacementAura"
	tiles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var quad: PlaneMesh = PlaneMesh.new()
	var cell: float = side.plan.grid.cell_size if side.plan.grid != null else 4.0
	quad.size = Vector2(cell * 0.86, cell * 0.86)
	mm.mesh = quad
	tiles.multimesh = mm
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.vertex_color_use_as_albedo = true
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.no_depth_test = true
	ink.render_priority = -1
	tiles.material_override = ink
	_host.add_child(tiles)
	return tiles

func _show_pill(on: bool, text: String) -> void:
	if on and _pill == null:
		_build_pill()
	if _pill == null:
		return
	_pill.visible = on
	if on:
		_pill_line.text = text
		_place_pill()

func _build_pill() -> void:
	var layer: CanvasLayer = _host.get("ui_layer") as CanvasLayer
	if layer == null:
		layer = _host.get_node_or_null("PlacementLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "PlacementLayer"
		layer.layer = 6
		_host.add_child(layer)
	_pill = PanelContainer.new()
	_pill.name = "PlacementPill"
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.z_index = 20
	var plate: StyleBoxFlat = StyleBoxFlat.new()
	plate.bg_color = Color(0.42, 0.02, 0.05, 0.94)
	plate.border_color = Color(1.0, 0.85, 0.8, 0.95)
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(14)
	plate.content_margin_left = 16.0
	plate.content_margin_right = 16.0
	plate.content_margin_top = 6.0
	plate.content_margin_bottom = 6.0
	_pill.add_theme_stylebox_override("panel", plate)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 1)
	_pill.add_child(col)
	_pill_line = Label.new()
	_pill_line.name = "PlacementPillLine"
	_pill_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pill_line.add_theme_font_size_override("font_size", 17)
	_pill_line.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_pill_line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_pill_line.add_theme_constant_override("outline_size", 4)
	col.add_child(_pill_line)
	_legend = Label.new()
	_legend.name = "PlacementLegend"
	_legend.text = "Green: open   Red: blocked   Blue: water"
	_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legend.add_theme_font_size_override("font_size", 13)
	_legend.add_theme_color_override("font_color", Color(1.0, 0.86, 0.82, 0.92))
	col.add_child(_legend)
	_pill.visible = false
	layer.add_child(_pill)

func _place_pill() -> void:
	if _pill == null or not _pill.visible or side == null:
		return
	var cam: Camera3D = _host.get_viewport().get_camera_3d() if _host.is_inside_tree() else null
	var at: Vector3 = side.placement.spot
	if cam == null or at == Vector3.INF or cam.is_position_behind(at):
		return
	var screen: Vector2 = cam.unproject_position(at)
	var view: Vector2 = _host.get_viewport().get_visible_rect().size
	var size: Vector2 = _pill.get_combined_minimum_size()
	var pos: Vector2 = screen + Vector2(-size.x * 0.5, 54.0)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, view.x - size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, view.y - size.y - 8.0))
	_pill.position = pos
