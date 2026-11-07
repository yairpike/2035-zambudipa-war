extends SceneTree
## Windowed map screenshots: a top-down plan and a gameplay view with both bases raised. Not part of the test suite.
## godot --path . --resolution 1280x720 -s res://tools/map_shot.gd -- --scene res://game/burma_road.tscn --out /tmp/burma [--faction gtfc] [--sim 120] [--mission id] [--town x,y]
## --town adds a third close view over that cell, saved as <out>-town.png.

var _args: Dictionary = {}
var _clock: float = 0.0
var _stage: int = 0

func _initialize() -> void:
	var raw: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < raw.size():
		_args[raw[i].trim_prefix("--")] = raw[i + 1] if i + 1 < raw.size() else ""
		i += 2
	SMFront.faction_id = str(_args.get("faction", "gtfc"))
	if _args.has("mission"):
		SMCampaign.selected = str(_args["mission"])
	change_scene_to_file(str(_args.get("scene", "res://game/burma_road.tscn")))

func _process(delta: float) -> bool:
	_clock += delta
	var scene: Node3D = current_scene as Node3D
	if scene == null:
		return false
	if _stage == 0 and _clock > 1.0:
		_stage = 1
		_raise_bases(scene)
	elif _stage == 1 and _clock > 4.0:
		_stage = 2
		_top_down(scene)
	elif _stage == 2 and _clock > 5.5:
		_stage = 3
		_save("%s-top.png" % str(_args.get("out", "/tmp/map")))
		_gameplay(scene)
	elif _stage == 3 and _clock > 7.0:
		_stage = 4
		_save("%s-play.png" % str(_args.get("out", "/tmp/map")))
		if not _args.has("town"):
			quit()
		_town(scene)
	elif _stage == 4 and _clock > 8.5:
		_save("%s-town.png" % str(_args.get("out", "/tmp/map")))
		quit()
	return false

func _raise_bases(scene: Node3D) -> void:
	var side: SMSide = scene.get("side") as SMSide
	var roster: SMRoster = scene.get("roster") as SMRoster
	if roster != null:
		roster.economy.set_credits(SMPointer.PLAYER, 99999)
	if side != null:
		for id: StringName in side.yard.tech_order:
			if side.yard.building_optional.get(id, false):
				continue
			side.order_building(id)
	var steps: int = int(_args.get("sim", "120"))
	var raider: SMRaider = scene.get("raider") as SMRaider
	for n: int in steps:
		if raider != null:
			raider.tick(0.5)
			raider.show_markers(scene)
	var hud: SMHud = scene.get("hud") as SMHud
	if hud != null:
		hud.layout_for(root.get_visible_rect().size)

func _top_down(scene: Node3D) -> void:
	var grid: SMDomainGrid = _grid_of(scene)
	if grid == null:
		return
	for layer: Node in scene.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var veil: Node3D = scene.get_node_or_null("FogVeil") as Node3D
	if veil != null:
		veil.visible = false
	var cam := Camera3D.new()
	cam.name = "PlanCamera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var w: float = float(grid.cols) * grid.cell_size
	var h: float = float(grid.rows) * grid.cell_size
	var aspect: float = root.get_visible_rect().size.x / root.get_visible_rect().size.y
	cam.size = maxf(h, w / aspect) * 1.02
	cam.far = 800.0
	scene.add_child(cam)
	cam.global_position = grid.origin + Vector3(w * 0.5, 300.0, h * 0.5)
	cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	cam.current = true

func _gameplay(scene: Node3D) -> void:
	for layer: Node in scene.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = true
	var veil: Node3D = scene.get_node_or_null("FogVeil") as Node3D
	if veil != null:
		veil.visible = true
	var plan: Node = scene.get_node_or_null("PlanCamera")
	if plan != null:
		plan.free()
	var cam: RTSCamera = scene.find_child("Camera", true, false) as RTSCamera
	if cam != null:
		cam.current = true
		cam.apply()

func _town(scene: Node3D) -> void:
	var grid: SMDomainGrid = _grid_of(scene)
	var cam: RTSCamera = scene.find_child("Camera", true, false) as RTSCamera
	var at: PackedStringArray = str(_args["town"]).split(",")
	if grid == null or cam == null or at.size() < 2:
		return
	var veil: Node3D = scene.get_node_or_null("FogVeil") as Node3D
	if veil != null:
		veil.visible = false
	cam.focus = grid.cell_center(Vector2i(int(at[0]), int(at[1])))
	cam.distance = 34.0
	cam.apply()

func _grid_of(scene: Node3D) -> SMDomainGrid:
	var grid: SMDomainGrid = scene.get("grid") as SMDomainGrid
	if grid == null and scene.get("sim") is SMMatch:
		grid = (scene.get("sim") as SMMatch).grid
	return grid

func _save(path: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(path)
	print("saved ", path)
