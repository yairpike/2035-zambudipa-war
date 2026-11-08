extends Node
## Registers render-side hooks that every scene shares. See match_settings.gd for the quality levels.
## On the web at Medium it also governs the frame budget: frames that average past STRAIN_MS for
## HOLD_UP seconds raise Settings.strain one step (smaller 3D buffer, then lean crowds and props,
## then fewer particles); frames under EASE_MS for HOLD_DOWN seconds give a step back.
## Picking High or Low in Settings opts out, and native builds never strain.

const ModelTextures = preload("res://game/model_textures.gd")
const Settings = preload("res://game/match_settings.gd")

const STRAIN_MS: float = 22.0
const EASE_MS: float = 14.0
const HOLD_UP: float = 2.0
const HOLD_DOWN: float = 8.0
## Seconds after a match loads (or a step lands) before frames count.
const SETTLE: float = 3.0

## Tests and the perf probe: 1 governs on any platform, 0 never, -1 web Medium only.
static var governs: int = -1

static var _textures: GLTFDocumentExtension

var _scene: Node
var _settle: float = 0.0
var _avg_ms: float = 0.0
var _over: float = 0.0
var _under: float = 0.0
var _win_phys: Vector2i = Vector2i(-1, -1)
var _win_pref: String = ""
var _win_factor: float = 1.0
var _tracked_hud: SMHud

static func window_scale_for(phys: Vector2i, dpi: float, user_mult: float) -> float:
	var factor: float = user_mult
	if phys.y > phys.x:
		factor = maxf(dpi, user_mult)
	elif float(phys.y) > 720.0:
		factor = maxf((float(phys.y) / 960.0) * user_mult, user_mult)
	if phys.x >= phys.y and phys.y > 0:
		factor = minf(factor, float(phys.y) / 720.0)
	return clampf(factor, 1.0, 4.0)

func _fit_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win: Window = get_window()
	if win == null:
		return
	if win.content_scale_mode != Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if win.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND:
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var reported: Vector2i = DisplayServer.window_get_size()
	if win.content_scale_size != reported:
		win.content_scale_size = reported
	var dpi: float = maxf(1.0, DisplayServer.screen_get_scale())
	var pref: String = Settings.ui_scale
	var phys: Vector2i = reported
	if _win_factor > 1.01 and _win_phys.x > 0:
		var grown: Vector2i = Vector2i(int(round(float(reported.x) * _win_factor)), int(round(float(reported.y) * _win_factor)))
		if grown == _win_phys:
			phys = _win_phys
	var factor: float = window_scale_for(phys, dpi, Settings.ui_scale_factor())
	if phys != _win_phys or pref != _win_pref or not is_equal_approx(win.content_scale_factor, factor):
		_win_phys = phys
		_win_pref = pref
		_win_factor = factor
		win.content_scale_factor = factor
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var view_size: Vector2 = vp.get_visible_rect().size
	var cur: Node = get_tree().current_scene
	if cur != null and cur.has_method("layout_for"):
		cur.call("layout_for", view_size)
	if _tracked_hud != null and (_tracked_hud.layer_node == null or not is_instance_valid(_tracked_hud.layer_node)):
		_tracked_hud = null
	if _tracked_hud == null and cur != null:
		var raw_hud: Variant = cur.get("hud")
		if raw_hud is SMHud:
			_tracked_hud = raw_hud as SMHud
	if _tracked_hud != null:
		_tracked_hud.layout_for(view_size)

static func install() -> void:
	if _textures != null:
		return
	_textures = ModelTextures.new()
	GLTFDocument.register_gltf_document_extension(_textures)

static func shutdown(tree: SceneTree = null) -> void:
	if _textures != null:
		GLTFDocument.unregister_gltf_document_extension(_textures)
		_textures = null
	preload("res://game/model_registry.gd").clear_templates()
	preload("res://game/env_dress.gd").clear_cache()
	preload("res://game/mission_kokang.gd").clear_cache()
	SMLang.uninstall()
	if tree != null and tree.current_scene != null and is_instance_valid(tree.current_scene):
		var scene: Node = tree.current_scene
		tree.current_scene = null
		if scene.get_parent() != null:
			scene.get_parent().remove_child(scene)
		scene.free()

static func governing() -> bool:
	if governs >= 0:
		return governs == 1
	return OS.has_feature("web") and Settings.effective() == "medium"

func _ready() -> void:
	install()

func _process(delta: float) -> void:
	_fit_window()
	if not governing():
		if Settings.strain != 0:
			_set_strain(0)
		return
	var scene: Node = get_tree().current_scene
	if scene == null or scene.get("field") == null:
		_scene = null
		return
	if scene != _scene:
		_scene = scene
		_restart()
		_apply_view()
	feed(delta)

## One frame of `delta` seconds. Returns the strain step after it.
func feed(delta: float) -> int:
	if _settle > 0.0:
		_settle -= delta
		return Settings.strain
	var ms: float = minf(delta * 1000.0, 100.0)
	_avg_ms = ms if _avg_ms <= 0.0 else lerpf(_avg_ms, ms, 0.1)
	if _avg_ms > STRAIN_MS:
		_over += delta
		_under = 0.0
	elif _avg_ms < EASE_MS:
		_under += delta
		_over = 0.0
	else:
		_over = 0.0
		_under = 0.0
	if _over >= HOLD_UP and Settings.strain < Settings.STRAIN_MAX:
		_set_strain(Settings.strain + 1)
	elif _under >= HOLD_DOWN and Settings.strain > 0:
		_set_strain(Settings.strain - 1)
	return Settings.strain

func _set_strain(step: int) -> void:
	Settings.strain = clampi(step, 0, Settings.STRAIN_MAX)
	_restart()
	_apply_view()

func _restart() -> void:
	_settle = SETTLE
	_avg_ms = 0.0
	_over = 0.0
	_under = 0.0

func _apply_view() -> void:
	var view: Viewport = get_viewport()
	if view != null and _scene != null:
		view.scaling_3d_scale = Settings.render_scale()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		shutdown(get_tree())
		if get_tree() != null:
			get_tree().quit()
	elif what == NOTIFICATION_PREDELETE:
		shutdown()
