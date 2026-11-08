extends SceneTree
## Contact sheet for calibrating building fronts. One row per model. Columns show the model's local
## +Z, +X, -Z and -X sides turned toward the camera, so the column with the door or shopfront is its front.
## The result goes into "fronts" in data/model_scale.json. Not part of the test suite.
## godot --path . --resolution 1600x1000 -s res://tools/front_sheet.gd -- --out /tmp/fronts.png --ids a,b,c

const Env = preload("res://game/env_dress.gd")
const SIDES: Array[String] = ["+Z", "+X", "-Z", "-X"]
const CELL: float = 14.0

var _args: Dictionary = {}
var _clock: float = 0.0

func _initialize() -> void:
	var raw: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < raw.size():
		_args[raw[i].trim_prefix("--")] = raw[i + 1] if i + 1 < raw.size() else ""
		i += 2
	var ids: PackedStringArray = str(_args.get("ids", "")).split(",", false)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.33, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 20, 0)
	stage.add_child(sun)
	for row: int in ids.size():
		var label := Label3D.new()
		label.text = ids[row]
		label.font_size = 96
		label.pixel_size = 0.02
		label.position = Vector3(-CELL * 1.1, -float(row) * CELL + 4.0, 0)
		stage.add_child(label)
		for col: int in SIDES.size():
			var model: Node3D = Env._load(ids[row])
			if model == null:
				continue
			var box: AABB = Env._bounds(model)
			var fit: float = 10.0 / maxf(0.01, maxf(box.size.x, maxf(box.size.y, box.size.z)))
			var pivot := Node3D.new()
			pivot.position = Vector3(float(col) * CELL, -float(row) * CELL, 0)
			pivot.rotation_degrees.y = -float(col) * 90.0
			stage.add_child(pivot)
			model.scale = Vector3.ONE * fit
			model.position = -(box.position + box.size * 0.5) * fit
			pivot.add_child(model)
			if row == 0:
				var head := Label3D.new()
				head.text = SIDES[col]
				head.font_size = 128
				head.pixel_size = 0.02
				head.position = Vector3(float(col) * CELL, CELL * 0.55, 0)
				stage.add_child(head)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(ids.size()) * CELL + 6.0
	stage.add_child(cam)
	cam.position = Vector3(CELL * 1.25, -float(ids.size() - 1) * CELL * 0.5 + CELL * 0.25, 80.0)
	cam.current = true

func _process(delta: float) -> bool:
	_clock += delta
	if _clock > 1.5:
		root.get_texture().get_image().save_png(str(_args.get("out", "/tmp/fronts.png")))
		print("saved ", _args.get("out", "/tmp/fronts.png"))
		quit()
	return false
