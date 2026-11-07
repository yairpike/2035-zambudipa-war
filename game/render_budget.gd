extends Node
## Registers render-side hooks that every scene shares. See match_settings.gd for the quality levels.

const ModelTextures = preload("res://game/model_textures.gd")

static var _textures: GLTFDocumentExtension

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

func _ready() -> void:
	install()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		shutdown(get_tree())
		if get_tree() != null:
			get_tree().quit()
	elif what == NOTIFICATION_PREDELETE:
		shutdown()
