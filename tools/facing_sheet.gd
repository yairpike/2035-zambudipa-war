extends Node3D
## Renders unit models in a grid with an arrow on the ground pointing at the game's forward (-Z),
## after the registry's per-model yaw correction. Used to verify model facing by eye.
## godot --path . --rendering-driver opengl3 res://tools/facing_sheet.tscn -- --out=/tmp/sheet.png --ids=a,b,c [--clip=walk] [--raw]

const Catalog = preload("res://game/model_catalog.gd")

var out: String = "/tmp/facing.png"
var ids: PackedStringArray = []
var dir: String = ""
var clip: String = ""
var raw: bool = false
var top: bool = false
var frames: int = 0

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--ids="):
			ids = arg.trim_prefix("--ids=").split(",", false)
		elif arg.begins_with("--dir="):
			dir = arg.trim_prefix("--dir=")
		elif arg.begins_with("--clip="):
			clip = arg.trim_prefix("--clip=")
		elif arg == "--raw":
			raw = true
		elif arg == "--top":
			top = true

func _build() -> void:
	get_window().size = Vector2i(1600, 1000)
	var stage: Node3D = self
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -30, 0)
	stage.add_child(sun)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.36, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	stage.add_child(env)
	var cols: int = maxi(1, ceili(sqrt(float(ids.size()) * 1.6)))
	var rows: int = ceili(float(ids.size()) / float(cols))
	var cell: float = 6.0
	for i: int in ids.size():
		var at: Vector3 = Vector3(0, -float(i / cols) * cell, -float(i % cols) * cell)
		if top:
			at = Vector3(float(i % cols) * cell, 0, float(i / cols) * cell)
		_place(stage, ids[i], at)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(float(cols) * cell / 1.6, float(rows) * cell) * 1.15
	var mid: Vector3 = Vector3(0, -(rows - 1) * cell * 0.5 + 1.2, -(cols - 1) * cell * 0.5)
	stage.add_child(cam)
	if top:
		mid = Vector3((cols - 1) * cell * 0.5, 0, (rows - 1) * cell * 0.5)
		cam.global_position = mid + Vector3(0, 40, 0)
		cam.look_at(mid, Vector3.FORWARD)
	else:
		cam.global_position = mid + Vector3(40, 6, 0)
		cam.look_at(mid, Vector3.UP)
	cam.current = true

func _place(stage: Node3D, id: String, at: Vector3) -> void:
	var arrow: MeshInstance3D = MeshInstance3D.new()
	var shaft: BoxMesh = BoxMesh.new()
	shaft.size = Vector3(0.18, 0.04, 2.0)
	arrow.mesh = shaft
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.85, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow.material_override = mat
	arrow.position = at + (Vector3(-2.0, 0.02, 0.0) if top else Vector3(0, -0.3, -0.2))
	stage.add_child(arrow)
	var head: MeshInstance3D = MeshInstance3D.new()
	var tip: PrismMesh = PrismMesh.new()
	tip.size = Vector3(0.7, 0.6, 0.05)
	head.mesh = tip
	head.material_override = mat
	head.rotation_degrees = Vector3(-90, 0, 0)
	head.position = at + (Vector3(-2.0, 0.03, -1.25) if top else Vector3(0, -0.3, -1.45))
	stage.add_child(head)
	var label: Label3D = Label3D.new()
	label.text = id
	label.font_size = 64
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at + Vector3(0, -0.9, 0)
	stage.add_child(label)
	var path: String = id if id.ends_with(".glb") else (dir.path_join(id + ".glb") if dir != "" else "")
	if path == "":
		return
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return
	var model: Node3D = doc.generate_scene(state) as Node3D
	if model == null:
		return
	var holder: Node3D = Node3D.new()
	stage.add_child(holder)
	holder.position = at
	holder.add_child(model)
	var key: String = id.get_file().get_basename()
	label.text = "%s %+d" % [key, int(Catalog.forward_yaw_deg(key, path))]
	if not raw:
		model.rotation.y = deg_to_rad(Catalog.forward_yaw_deg(key, path))
	var box: AABB = _bounds(model)
	var span: float = maxf(box.size.x, maxf(box.size.z, box.size.y * 0.8))
	if span > 0.001:
		model.scale *= 3.2 / span
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and clip != "" and player.has_animation(clip):
		player.play(clip)
		player.seek(0.3, true)

func _bounds(n: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for c: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func _process(_delta: float) -> void:
	frames += 1
	if frames == 1:
		_build()
	if frames == 10:
		get_viewport().get_texture().get_image().save_png(out)
		print("SHEET ", out)
		get_tree().quit()
