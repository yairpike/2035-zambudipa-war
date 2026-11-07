extends Node
## Browser limits, plus a portrait layout that follows the window and the screen scale.

var _applied_phys: Vector2i = Vector2i(-1, -1)
var _applied_dpi: float = -1.0
var _applied_factor: float = 1.0
var _tracked: SMHud

func _ready() -> void:
	if not OS.has_feature("web"):
		return
	Engine.max_fps = 60
	get_tree().node_added.connect(_on_node)
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	vp.msaa_2d = Viewport.MSAA_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	_fit_display()
	_fit_view()

func _on_node(node: Node) -> void:
	quiet_node(node)

static func quiet_node(node: Node) -> void:
	var light: DirectionalLight3D = node as DirectionalLight3D
	if light != null:
		light.shadow_enabled = false
		return
	var world: WorldEnvironment = node as WorldEnvironment
	if world != null and world.environment != null:
		world.environment.glow_enabled = false
		world.environment.ssao_enabled = false
		world.environment.ssil_enabled = false
		world.environment.sdfgi_enabled = false

func _fit_display() -> void:
	var reported: Vector2i = DisplayServer.window_get_size()
	var dpi: float = DisplayServer.screen_get_scale()
	if dpi < 1.0:
		dpi = 1.0
	var phys: Vector2i = reported
	if _applied_factor > 1.01 and _applied_phys.x > 0:
		var grown: Vector2i = Vector2i(int(round(float(reported.x) * _applied_factor)), int(round(float(reported.y) * _applied_factor)))
		if grown == _applied_phys:
			phys = _applied_phys
	if phys == _applied_phys and is_equal_approx(dpi, _applied_dpi):
		return
	var factor: float = 1.0
	if phys.y > phys.x:
		factor = dpi
	elif float(phys.y) > 720.0:
		factor = minf(float(phys.y) / 720.0, dpi)
	if factor < 1.0:
		factor = 1.0
	_applied_phys = phys
	_applied_dpi = dpi
	_applied_factor = factor
	var win: Window = get_window()
	if win != null and not is_equal_approx(win.content_scale_factor, factor):
		win.content_scale_factor = factor

func _fit_view() -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var size: Vector2 = vp.get_visible_rect().size
	var scene: Node = get_tree().current_scene
	_confine(scene)
	if scene != null and scene.has_method("layout_for"):
		scene.call("layout_for", size)
	if _tracked != null and (_tracked.layer_node == null or not is_instance_valid(_tracked.layer_node)):
		_tracked = null
	if _tracked == null:
		_tracked = _seek_hud(scene)
	if _tracked != null:
		_tracked.layout_for(size)

static func pointer_mode(in_match: bool) -> int:
	## The browser rejects MOUSE_MODE_CONFINED on every frame and spams the console.
	if OS.has_feature("web"):
		return Input.MOUSE_MODE_VISIBLE
	if in_match:
		return Input.MOUSE_MODE_CONFINED
	return Input.MOUSE_MODE_VISIBLE

func _confine(scene: Node) -> void:
	var in_match: bool = scene is Node3D
	var mode: int = pointer_mode(in_match)
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode

func _seek_hud(scene: Node) -> SMHud:
	if scene == null:
		return null
	var layers: Array[Node] = scene.find_children("", "CanvasLayer", true, false)
	for node: Node in layers:
		if not node.has_meta("hud"):
			continue
		var hud: SMHud = node.get_meta("hud") as SMHud
		if hud != null:
			return hud
	return null
