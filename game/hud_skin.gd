extends RefCounted
## Faction skins for the match HUD, from docs/art-direction.md.
## GTFC teak and brass, NMRF naval grey and songket gold, MVD charcoal and cyan,
## Black Market black, chrome and tarnished amber.

const PLATE_SHADER: Shader = preload("res://game/shaders/hud_plate.gdshader")

const SKINS: Dictionary = {
	"gtfc": {
		"name": "GTFC",
		"metal": Color(0.23, 0.14, 0.085),
		"metal_hi": Color(0.42, 0.26, 0.15),
		"trim": Color(0.79, 0.63, 0.29),
		"trim_hi": Color(0.98, 0.86, 0.52),
		"accent": Color(0.72, 0.12, 0.18),
		"glow": Color(0.88, 0.63, 0.02),
		"ink": Color(0.98, 0.93, 0.8),
		"pattern": 0,
	},
	"nmrf": {
		"name": "NMRF",
		"metal": Color(0.2, 0.23, 0.24),
		"metal_hi": Color(0.38, 0.42, 0.44),
		"trim": Color(0.83, 0.69, 0.22),
		"trim_hi": Color(0.98, 0.9, 0.55),
		"accent": Color(0.12, 0.62, 0.4),
		"glow": Color(0.35, 0.86, 0.55),
		"ink": Color(0.92, 0.97, 0.92),
		"pattern": 1,
	},
	"mvd": {
		"name": "MVD",
		"metal": Color(0.13, 0.145, 0.16),
		"metal_hi": Color(0.27, 0.3, 0.33),
		"trim": Color(0.6, 0.64, 0.67),
		"trim_hi": Color(0.88, 0.92, 0.95),
		"accent": Color(0.15, 0.75, 0.82),
		"glow": Color(0.35, 0.92, 1.0),
		"ink": Color(0.9, 0.98, 1.0),
		"pattern": 2,
	},
	"black_market": {
		"name": "Black Market",
		"metal": Color(0.09, 0.09, 0.09),
		"metal_hi": Color(0.24, 0.23, 0.22),
		"trim": Color(0.78, 0.8, 0.82),
		"trim_hi": Color(1.0, 1.0, 1.0),
		"accent": Color(0.77, 0.57, 0.16),
		"glow": Color(0.98, 0.74, 0.25),
		"ink": Color(1.0, 0.95, 0.86),
		"pattern": 3,
	},
}

static var _plates: Dictionary = {}

## The skin id for a match. A root meta "hud_skin" overrides it for previews.
static func id_for(node: Node, faction: String) -> String:
	if node != null and node.is_inside_tree():
		var forced: String = str(node.get_tree().root.get_meta("hud_skin", ""))
		if SKINS.has(forced):
			return forced
	if SKINS.has(faction):
		return faction
	return "gtfc"

static func skin(id: String) -> Dictionary:
	return SKINS.get(id, SKINS["gtfc"]) as Dictionary

static func color(id: String, key: String) -> Color:
	return skin(id).get(key, Color.WHITE) as Color

## Metal, teak, songket or primer plate. Shared per skin.
static func plate_material(id: String) -> ShaderMaterial:
	if _plates.has(id):
		return _plates[id] as ShaderMaterial
	var s: Dictionary = skin(id)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = PLATE_SHADER
	mat.set_shader_parameter("metal", s["metal"])
	mat.set_shader_parameter("metal_hi", s["metal_hi"])
	mat.set_shader_parameter("trim", s["trim"])
	mat.set_shader_parameter("accent", s["accent"])
	mat.set_shader_parameter("glow", s["glow"])
	mat.set_shader_parameter("pattern", int(s["pattern"]))
	_plates[id] = mat
	return mat

## A framed plate for the sidebar, the top bar and the unit panel.
## The StyleBoxFlat draws the bevel and trim. The shader adds the surface.
static func plate_style(id: String, corner: int = 4, border: int = 2, margin: int = 6) -> StyleBoxFlat:
	var s: Dictionary = skin(id)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = s["metal"]
	box.border_color = s["trim"]
	box.set_border_width_all(border)
	box.set_corner_radius_all(corner)
	box.corner_detail = 4
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 4
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box

## A dark recessed well for the minimap, portrait and cameo grid.
static func well_style(id: String, corner: int = 3) -> StyleBoxFlat:
	var s: Dictionary = skin(id)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.025, 0.03, 0.96)
	box.border_color = (s["trim"] as Color).darkened(0.35)
	box.border_width_top = 2
	box.border_width_left = 2
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.set_corner_radius_all(corner)
	box.content_margin_left = 3
	box.content_margin_right = 3
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box

## Bevelled button faces: normal, hover, pressed, and the lit tab.
static func button_style(id: String, state: String) -> StyleBoxFlat:
	var s: Dictionary = skin(id)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	var metal: Color = s["metal_hi"]
	var trim: Color = s["trim"]
	box.set_corner_radius_all(3)
	box.set_border_width_all(1)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	match state:
		"hover":
			box.bg_color = metal.lightened(0.12)
			box.border_color = s["trim_hi"]
		"pressed":
			box.bg_color = (s["metal"] as Color).darkened(0.2)
			box.border_color = trim
		"lit":
			box.bg_color = (s["accent"] as Color).darkened(0.25)
			box.border_color = s["glow"]
			box.set_border_width_all(2)
		"disabled":
			box.bg_color = (s["metal"] as Color).darkened(0.3)
			box.border_color = trim.darkened(0.5)
		_:
			box.bg_color = metal.darkened(0.15)
			box.border_color = trim.darkened(0.2)
	return box

static func dress_button(b: Button, id: String) -> void:
	if b == null:
		return
	b.add_theme_stylebox_override("normal", button_style(id, "normal"))
	b.add_theme_stylebox_override("hover", button_style(id, "hover"))
	b.add_theme_stylebox_override("pressed", button_style(id, "pressed"))
	b.add_theme_stylebox_override("disabled", button_style(id, "disabled"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", skin(id)["ink"] as Color)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))

## The cameo tile: a thin trim frame so the art fills the tile.
static func cameo_style(id: String, state: String) -> StyleBoxFlat:
	var s: Dictionary = skin(id)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.035, 0.04, 1.0)
	box.set_corner_radius_all(2)
	box.set_border_width_all(2)
	box.content_margin_left = 2
	box.content_margin_right = 2
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	match state:
		"hover":
			box.border_color = s["trim_hi"]
		"pressed":
			box.border_color = s["glow"]
		_:
			box.border_color = (s["trim"] as Color).darkened(0.25)
	return box

static func dress_cameo(b: Button, id: String) -> void:
	if b == null:
		return
	b.add_theme_stylebox_override("normal", cameo_style(id, "normal"))
	b.add_theme_stylebox_override("hover", cameo_style(id, "hover"))
	b.add_theme_stylebox_override("pressed", cameo_style(id, "pressed"))
	b.add_theme_stylebox_override("disabled", cameo_style(id, "normal"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
