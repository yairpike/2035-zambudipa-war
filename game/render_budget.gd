extends Node
## Registers render-side hooks that every scene shares. See match_settings.gd for the quality levels.

const ModelTextures = preload("res://game/model_textures.gd")

static var _textures: GLTFDocumentExtension

static func install() -> void:
	if _textures != null:
		return
	_textures = ModelTextures.new()
	GLTFDocument.register_gltf_document_extension(_textures)

func _ready() -> void:
	install()
