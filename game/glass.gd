extends RefCounted
## Frosted-glass backdrop for menus, dialogs and HUD cards.
## The blur reads the screen behind the item, so it needs a real renderer.
## Headless runs get a flat translucent fill of the same tint.

const SHADER: Shader = preload("res://game/shaders/glass_blur.gdshader")
const TINT: Color = Color(0.05, 0.06, 0.08, 0.46)
const EDGE: Color = Color(1.0, 1.0, 1.0, 0.26)

static var _materials: Dictionary = {}

static func live() -> bool:
	return DisplayServer.get_name() != "headless"

## A ShaderMaterial for one tint. Shared, so many cards cost one shader.
static func material(tint: Color = TINT, edge: Color = EDGE, lod: float = 3.6) -> ShaderMaterial:
	var key: String = "%s|%s|%.2f" % [tint.to_html(), edge.to_html(), lod]
	if _materials.has(key):
		return _materials[key] as ShaderMaterial
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("edge", edge)
	mat.set_shader_parameter("lod", lod)
	mat.set_shader_parameter("spread", 6.0 * lod)
	_materials[key] = mat
	return mat

## The shape. Black fill, white border: the shader reads COLOR.r as the rim mask.
static func style(corner: int = 12, border: int = 1, margin: int = 12, tint: Color = TINT) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.set_corner_radius_all(corner)
	box.set_border_width_all(border)
	box.anti_aliasing = true
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin * 0.75
	box.content_margin_bottom = margin * 0.75
	if live():
		box.bg_color = Color(0, 0, 0, 1)
		box.border_color = Color(1, 1, 1, 1)
	else:
		box.bg_color = Color(tint.r, tint.g, tint.b, maxf(tint.a, 0.86))
		box.border_color = Color(1, 1, 1, EDGE.a)
	return box

## Puts the glass on a Panel or PanelContainer itself. Children keep their own material.
static func dress(item: Control, corner: int = 12, tint: Color = TINT, margin: int = 12, edge: Color = EDGE) -> void:
	if item == null:
		return
	item.add_theme_stylebox_override("panel", style(corner, 1, margin, tint))
	item.material = material(tint, edge) if live() else null
	item.set_meta("glass", true)

## A full-rect glass Panel behind the other children of parent.
static func sheet(parent: Control, node_name: String, tint: Color = TINT, corner: int = 0) -> Panel:
	var pane: Panel = Panel.new()
	pane.name = node_name
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pane.set_anchors_preset(Control.PRESET_FULL_RECT)
	dress(pane, corner, tint, 0, Color(1, 1, 1, 0.0) if corner == 0 else EDGE)
	parent.add_child(pane)
	parent.move_child(pane, 0)
	return pane
