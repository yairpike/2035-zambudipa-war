extends RefCounted
## Warheed falls back to Operation Napalm. Neither face uses the system font.
## Napalm falls back to the Noto subsets for Burmese, Thai, and Chinese,
## because the web build has no system fonts.

const SCRIPT_FACES: PackedStringArray = [
	"res://localization/fonts/NotoSansMyanmar-Subset.ttf",
	"res://localization/fonts/NotoSansThai-Subset.ttf",
	"res://localization/fonts/NotoSansSC-Subset.otf",
]

static var _pinned: bool = false

static func pin() -> void:
	if _pinned:
		return
	var warheed: FontFile = load("res://assets/fonts/Warheed.otf") as FontFile
	var napalm: FontFile = load("res://assets/fonts/OperationNapalm-Regular.ttf") as FontFile
	if warheed == null or napalm == null:
		return
	_pinned = true
	warheed.allow_system_fallback = false
	napalm.allow_system_fallback = false
	var faces: Array[Font] = []
	faces.append(napalm)
	warheed.fallbacks = faces
	var napalm_faces: Array[Font] = script_faces()
	if ThemeDB.fallback_font != null:
		napalm_faces.append(ThemeDB.fallback_font)
	napalm.fallbacks = napalm_faces

static func script_faces() -> Array[Font]:
	var out: Array[Font] = []
	for path: String in SCRIPT_FACES:
		var face: FontFile = load(path) as FontFile if ResourceLoader.exists(path) else null
		if face != null:
			face.allow_system_fallback = false
			out.append(face)
	return out
