extends Node
## Portrait framing for an RTSCamera, using only its existing distance and apply().
## Play distances come from the scale chart so campaign, skirmish and LAN share one isometric view.

static func _cam_chart() -> Dictionary:
	return SMBasePlan.chart().get("camera", {}) as Dictionary

static func play_distance(kind: String) -> float:
	var cam: Dictionary = _cam_chart()
	if kind == "skirmish_large":
		return float(cam.get("skirmish_large", 72.0))
	if kind == "skirmish":
		return float(cam.get("skirmish", 64.0))
	if kind == "yard":
		return float(cam.get("yard", 42.0))
	return float(cam.get("company", 48.0))

static func apply_play(cam: RTSCamera, kind: String) -> void:
	if cam == null:
		return
	var chart: Dictionary = _cam_chart()
	cam.distance = play_distance(kind)
	cam.zoom_max = maxf(cam.zoom_max, float(chart.get("zoom_max", 96.0)))
	cam.pitch_near = float(chart.get("pitch_near", 50.0))
	cam.pitch_far = float(chart.get("pitch_far", 58.0))
	if cam.is_inside_tree():
		cam.apply()

static func fit(cam: RTSCamera, viewport_size: Vector2) -> void:
	if cam == null:
		return
	var authored: float = cam.distance
	if cam.has_meta(&"fit_authored"):
		authored = float(cam.get_meta(&"fit_authored"))
	else:
		cam.set_meta(&"fit_authored", cam.distance)
	var tall: bool = viewport_size.y > viewport_size.x + 4.0
	var key: int = 1 if tall else 0
	var prev: int = int(cam.get_meta(&"fit_key", -1))
	if key == prev:
		return
	cam.set_meta(&"fit_key", key)
	var next: float = authored
	if tall and viewport_size.x > 1.0:
		var pull: float = clampf(viewport_size.y / viewport_size.x, 1.0, 2.5)
		next = clampf(authored * pull, cam.zoom_min, cam.zoom_max)
	cam.distance = next
	cam.apply()

## How much to shrink a world-space span so it stays within `cap_px` on screen.
## Returns 1 when the span already fits.
static func span(viewport: Vector2, fov_deg: float, dist: float, world_span: float, cap_px: float) -> float:
	if viewport.y < 64.0 or dist < 0.25 or world_span <= 0.0 or cap_px < 1.0:
		return 1.0
	var fov: float = fov_deg if fov_deg > 1.0 else 75.0
	var half: float = tan(deg_to_rad(fov) * 0.5)
	if half < 0.001:
		return 1.0
	var px: float = world_span * viewport.y / (2.0 * half * dist)
	if px <= cap_px:
		return 1.0
	return cap_px / px

func _process(_delta: float) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var cam: RTSCamera = host.get_node_or_null("Camera") as RTSCamera
	var vp: Viewport = get_viewport()
	if cam == null or vp == null:
		return
	fit(cam, vp.get_visible_rect().size)
