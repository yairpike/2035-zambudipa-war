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
