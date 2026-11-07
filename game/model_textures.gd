extends GLTFDocumentExtension
## Runtime glTF loads keep raw images with no mip chain, so distant units sample full-size textures.
## This builds the chain right after parsing, before any material or mesh uses it, and halves textures on Low.

const Settings = preload("res://game/match_settings.gd")
const LOW_EDGE: int = 256

func _import_post_parse(state: GLTFState) -> Error:
	var low: bool = Settings.low()
	for tex: Texture2D in state.get_images():
		var image_tex: ImageTexture = tex as ImageTexture
		if image_tex == null:
			continue
		var img: Image = image_tex.get_image()
		if img == null or img.is_empty() or img.is_compressed():
			continue
		var changed: bool = false
		while low and maxi(img.get_width(), img.get_height()) > LOW_EDGE:
			img.shrink_x2()
			changed = true
		if not img.has_mipmaps():
			img.generate_mipmaps()
			changed = true
		if changed:
			image_tex.set_image(img)
	return OK
