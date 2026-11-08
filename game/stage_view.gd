extends Node
## Shows an SMStages arc on screen: the commander transmission banner, the objectives tracker, minimap pings
## (Space jumps to the newest), and the arrival props (helicopter drop, landing craft, boss compound, bonus site).
## It never moves the camera or takes input; the player keeps control through every beat.

const BANNER_TIME: float = 6.5
const HELI_TIME: float = 5.0
const CRAFT_TIME: float = 4.5

var stages: SMStages
var speaker: String = "Command"
var shown: Array[Dictionary] = []
var banner_text: String = ""

var _host: Node3D
var _banner: Control
var _banner_speaker: Label
var _banner_line: Label
var _banner_t: float = 0.0
var _rows: Array[Label] = []
var _bonus_row: Label
var _props: Array[Dictionary] = []

static func attach(host: Node3D, arc: SMStages, who: String = "Command") -> Node:
	if host == null or arc == null:
		return null
	var have: Node = host.get_node_or_null("StageView")
	if have != null:
		return have
	var view: Node = Node.new()
	view.name = "StageView"
	view.set_script(load("res://game/stage_view.gd") as GDScript)
	host.add_child(view)
	view.call("open", host, arc, who)
	return view

func open(host: Node3D, arc: SMStages, who: String) -> void:
	_host = host
	stages = arc
	speaker = who
	_chrome()
	drive(0.0)

func drive(delta: float) -> void:
	if stages == null or _host == null:
		return
	for e: Dictionary in stages.drain():
		_show(e)
	if _banner_t > 0.0:
		_banner_t = maxf(0.0, _banner_t - delta)
		if _banner_t <= 0.0 and _banner != null:
			_banner.visible = false
	_animate(delta)
	_refresh()

func props_named(prefix: String) -> int:
	var n: int = 0
	for child: Node in _host.get_children():
		if str(child.name).begins_with(prefix):
			n += 1
	return n

func _show(e: Dictionary) -> void:
	shown.append(e)
	var kind: String = str(e.get("kind", ""))
	var at: Vector3 = e.get("at", Vector3.INF) as Vector3
	var field: SMPointer = _host.get("field") as SMPointer
	if field != null and kind != "bonus_site":
		field.ping(at, _ping_color(kind))
	var text: String = str(e.get("text", ""))
	if text != "":
		_say(text, kind)
	if kind == "allies":
		var mode: String = str(e.get("mode", ""))
		var to: Vector3 = e.get("to", at) as Vector3
		if mode == "heli":
			_heli(to)
		elif mode == "landing":
			_craft(at, to)
	elif kind == "boss":
		if bool(e.get("fixed", false)):
			_compound(at)
	elif kind == "bonus_site":
		_site(at, str(e.get("bonus", "")))

func _ping_color(kind: String) -> Color:
	if kind == "allies":
		return Color(0.35, 0.85, 0.45)
	if kind == "bonus":
		return Color(0.95, 0.85, 0.3)
	if kind == "boss" or kind == "ambush" or kind == "swap":
		return Color(0.95, 0.3, 0.25)
	return Color(0.98, 0.7, 0.25)

func _say(text: String, kind: String) -> void:
	banner_text = text
	_banner_t = BANNER_TIME
	if _banner == null:
		return
	_banner.visible = true
	_banner_speaker.text = speaker if kind != "bonus" else "Bonus objective"
	_banner_line.text = text

func _chrome() -> void:
	var layer: CanvasLayer = _host.get("ui_layer") as CanvasLayer
	if layer == null:
		return
	var view: Vector2 = Vector2(1280.0, 720.0)
	if _host.is_inside_tree():
		view = _host.get_viewport().get_visible_rect().size
	_banner = PanelContainer.new()
	_banner.name = "StageBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.position = Vector2(maxf(12.0, view.x * 0.5 - 300.0), view.y * 0.41)
	_banner.custom_minimum_size = Vector2(600.0, 0.0)
	var plate: StyleBoxFlat = StyleBoxFlat.new()
	plate.bg_color = Color(0.05, 0.06, 0.08, 0.86)
	plate.border_color = Color(0.95, 0.72, 0.25, 0.9)
	plate.border_width_left = 4
	plate.content_margin_left = 14.0
	plate.content_margin_right = 14.0
	plate.content_margin_top = 8.0
	plate.content_margin_bottom = 8.0
	_banner.add_theme_stylebox_override("panel", plate)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_banner_speaker = Label.new()
	_banner_speaker.name = "StageSpeaker"
	_banner_speaker.add_theme_font_size_override("font_size", 17)
	_banner_speaker.add_theme_color_override("font_color", Color(0.98, 0.78, 0.3))
	_banner_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_banner_speaker)
	var hint: Label = Label.new()
	hint.name = "StageJumpHint"
	hint.text = "Space: jump to the event"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	head.add_child(hint)
	_banner_line = Label.new()
	_banner_line.name = "StageLine"
	_banner_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_line.custom_minimum_size = Vector2(572.0, 0.0)
	_banner_line.add_theme_font_size_override("font_size", 18)
	col.add_child(_banner_line)
	_banner.visible = false
	layer.add_child(_banner)
	var tracker: PanelContainer = PanelContainer.new()
	tracker.name = "StageTracker"
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.position = Vector2(72.0, 172.0)
	tracker.custom_minimum_size = Vector2(300.0, 0.0)
	var tplate: StyleBoxFlat = StyleBoxFlat.new()
	tplate.bg_color = Color(0.05, 0.06, 0.08, 0.82)
	tplate.content_margin_left = 10.0
	tplate.content_margin_right = 10.0
	tplate.content_margin_top = 6.0
	tplate.content_margin_bottom = 6.0
	tracker.add_theme_stylebox_override("panel", tplate)
	var list: VBoxContainer = VBoxContainer.new()
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_child(list)
	var title: Label = Label.new()
	title.name = "StageTrackerTitle"
	title.text = "Objectives"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.98, 0.78, 0.3))
	list.add_child(title)
	for n: int in 3:
		var row: Label = Label.new()
		row.name = "StageRow%d" % (n + 1)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(300.0, 0.0)
		row.add_theme_font_size_override("font_size", 15)
		list.add_child(row)
		_rows.append(row)
	_bonus_row = Label.new()
	_bonus_row.name = "StageBonusRow"
	_bonus_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bonus_row.custom_minimum_size = Vector2(300.0, 0.0)
	_bonus_row.add_theme_font_size_override("font_size", 15)
	list.add_child(_bonus_row)
	layer.add_child(tracker)

func _refresh() -> void:
	if _rows.is_empty():
		return
	var layer: CanvasLayer = _host.get("ui_layer") as CanvasLayer if _host != null else null
	if layer != null:
		var tracker: Control = layer.get_node_or_null("StageTracker") as Control
		var dialogue: Control = layer.find_child("SetDialogue", true, false) as Control
		var brief: Control = layer.find_child("Briefing", true, false) as Control
		if tracker != null:
			var top_y: float = 160.0
			if brief != null and brief.visible:
				top_y = maxf(top_y, brief.position.y + brief.size.y + 38.0)
			if dialogue != null and dialogue.visible:
				top_y = maxf(top_y, dialogue.position.y + dialogue.size.y + 8.0)
			tracker.position = Vector2(72.0, top_y)
	for n: int in 3:
		var stage: int = n + 1
		var row: Label = _rows[n]
		var title: String = SMStages.stage_title(stage)
		if stage < stages.stage:
			row.text = "Stage %d done: %s" % [stage, title]
			row.add_theme_color_override("font_color", Color(0.55, 0.8, 0.55, 0.8))
		elif stage == stages.stage:
			row.text = "Stage %d now: %s" % [stage, stages.goal_line()]
			row.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		else:
			row.text = "Stage %d: %s" % [stage, title]
			row.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	_bonus_row.text = stages.bonus_line()
	var ink: Color = Color(0.95, 0.85, 0.3)
	if stages.bonus_state == "done":
		ink = Color(0.55, 0.8, 0.55)
	elif stages.bonus_state == "failed":
		ink = Color(0.85, 0.4, 0.35)
	_bonus_row.add_theme_color_override("font_color", ink)

func _heli(to: Vector3) -> void:
	var body: Node3D = Node3D.new()
	body.name = "DropHeli%d" % _props.size()
	body.add_child(_box(Vector3(1.4, 1.1, 3.6), Color(0.22, 0.28, 0.22), Vector3.ZERO))
	body.add_child(_box(Vector3(0.4, 0.4, 2.6), Color(0.22, 0.28, 0.22), Vector3(0.0, 0.2, 2.8)))
	var rotor: MeshInstance3D = _box(Vector3(7.0, 0.08, 0.35), Color(0.1, 0.1, 0.1), Vector3(0.0, 0.75, 0.0))
	rotor.name = "Rotor"
	body.add_child(rotor)
	_host.add_child(body)
	_props.append({"node": body, "kind": "heli", "to": to, "t": 0.0, "life": HELI_TIME})
	_place_heli(_props[_props.size() - 1])

func _craft(from: Vector3, to: Vector3) -> void:
	var hull: Node3D = Node3D.new()
	hull.name = "LandingCraft%d" % _props.size()
	hull.add_child(_box(Vector3(3.2, 0.8, 5.2), Color(0.3, 0.34, 0.3), Vector3(0.0, 0.3, 0.0)))
	hull.add_child(_box(Vector3(3.2, 1.2, 0.3), Color(0.36, 0.4, 0.34), Vector3(0.0, 0.7, -2.5)))
	_host.add_child(hull)
	hull.position = from
	hull.look_at_from_position(from, Vector3(to.x, from.y, to.z) + Vector3(0.001, 0.0, 0.0), Vector3.UP)
	_props.append({"node": hull, "kind": "craft", "from": from, "to": to, "t": 0.0, "life": CRAFT_TIME})

func _compound(at: Vector3) -> void:
	var base: Node3D = Node3D.new()
	base.name = "BossCompound"
	base.position = at
	var wall: Color = Color(0.36, 0.33, 0.3)
	base.add_child(_box(Vector3(7.0, 1.2, 0.5), wall, Vector3(0.0, 0.6, 3.3)))
	base.add_child(_box(Vector3(7.0, 1.2, 0.5), wall, Vector3(0.0, 0.6, -3.3)))
	base.add_child(_box(Vector3(0.5, 1.2, 7.0), wall, Vector3(3.3, 0.6, 0.0)))
	base.add_child(_box(Vector3(2.4, 2.6, 2.4), Color(0.28, 0.22, 0.2), Vector3(-1.6, 1.3, -1.4)))
	base.add_child(_box(Vector3(0.2, 3.6, 0.2), Color(0.8, 0.2, 0.15), Vector3(-1.6, 4.4, -1.4)))
	_host.add_child(base)

func _site(at: Vector3, kind: String) -> void:
	if at == Vector3.INF:
		return
	var mark: Node3D = Node3D.new()
	mark.name = "BonusSite"
	mark.position = at
	if kind == "jammer":
		mark.add_child(_box(Vector3(0.5, 5.0, 0.5), Color(0.2, 0.22, 0.28), Vector3(0.0, 2.5, 0.0)))
		mark.add_child(_box(Vector3(2.2, 0.12, 0.12), Color(0.85, 0.2, 0.2), Vector3(0.0, 4.6, 0.0)))
	elif kind == "rescue":
		mark.add_child(_box(Vector3(0.25, 3.0, 0.25), Color(1.0, 0.45, 0.15), Vector3(0.0, 1.5, 0.0), true))
	elif kind == "capture":
		mark.add_child(_box(Vector3(3.6, 0.1, 3.6), Color(0.95, 0.8, 0.25), Vector3(0.0, 0.06, 0.0)))
		mark.add_child(_box(Vector3(0.12, 2.6, 0.12), Color(0.9, 0.9, 0.9), Vector3(1.6, 1.3, 1.6)))
		mark.add_child(_box(Vector3(0.9, 0.55, 0.05), Color(0.95, 0.8, 0.25), Vector3(1.15, 2.3, 1.6)))
	else:
		return
	_host.add_child(mark)

func _animate(delta: float) -> void:
	for i: int in range(_props.size() - 1, -1, -1):
		var p: Dictionary = _props[i]
		var node: Node3D = p["node"] as Node3D
		if not is_instance_valid(node):
			_props.remove_at(i)
			continue
		p["t"] = float(p["t"]) + delta
		if str(p["kind"]) == "heli":
			_place_heli(p)
		else:
			var k: float = clampf(float(p["t"]) / float(p["life"]), 0.0, 1.0)
			node.position = (p["from"] as Vector3).lerp(p["to"] as Vector3, k * 0.85)
		if float(p["t"]) >= float(p["life"]) + 1.0:
			node.queue_free()
			_props.remove_at(i)

## Comes in high, settles to a hover over the drop, then climbs away.
func _place_heli(p: Dictionary) -> void:
	var node: Node3D = p["node"] as Node3D
	var t: float = float(p["t"])
	var life: float = float(p["life"])
	var to: Vector3 = p["to"] as Vector3
	var h: float = 4.0
	if t < 1.5:
		h = lerpf(16.0, 4.0, t / 1.5)
	elif t > life - 1.5:
		h = lerpf(4.0, 18.0, (t - (life - 1.5)) / 1.5)
	node.position = Vector3(to.x, h, to.z)
	var rotor: Node3D = node.get_node_or_null("Rotor") as Node3D
	if rotor != null:
		rotor.rotation.y = t * 18.0

func _box(size: Vector3, color: Color, at: Vector3, glow: bool = false) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = at
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	return mi
