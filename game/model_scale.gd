extends RefCounted
## Real-world sizes from res://data/model_scale.json for units and scenery. Building footprints come from SMBasePlan.
## A target is {"height": m}, {"length": m} (longest horizontal side), or {"scale": s}; "height_max" caps either.

static func unit_target(id: String) -> Dictionary:
	var chart: Dictionary = SMBasePlan.chart()
	var cls: String = str((chart.get("units", {}) as Dictionary).get(id, ""))
	return (chart.get("unit_classes", {}) as Dictionary).get(cls, {}) as Dictionary

static func unit_class(id: String) -> String:
	return str((SMBasePlan.chart().get("units", {}) as Dictionary).get(id, ""))

static func scenery_target(id: String) -> Dictionary:
	var chart: Dictionary = SMBasePlan.chart()
	var cls: String = str((chart.get("scenery", {}) as Dictionary).get(id, ""))
	return (chart.get("scenery_classes", {}) as Dictionary).get(cls, {}) as Dictionary

static func scenery_class(id: String) -> String:
	return str((SMBasePlan.chart().get("scenery", {}) as Dictionary).get(id, ""))

static func fill() -> float:
	return float(SMBasePlan.chart().get("building_fill", 0.88))

static func height_ratio_max() -> float:
	return float(SMBasePlan.chart().get("building_height_ratio_max", 1.35))

## Uniform scale that brings an authored box to `target`. 1.0 when the target is empty.
static func scale_for(size: Vector3, target: Dictionary) -> float:
	if target.is_empty():
		return 1.0
	var s: float = 1.0
	if target.has("scale"):
		s = float(target["scale"])
	elif target.has("height") and size.y > 0.001:
		s = float(target["height"]) / size.y
	elif target.has("length"):
		s = float(target["length"]) / maxf(maxf(size.x, size.z), 0.001)
	if target.has("height_max") and size.y * s > float(target["height_max"]):
		s = float(target["height_max"]) / maxf(size.y, 0.001)
	return s

## Uniform scale that fits an authored box inside a footprint (metres) with the chart's margin and height cap.
static func footprint_scale(size: Vector3, footprint: Vector2) -> float:
	var f: float = fill()
	var s: float = minf(footprint.x * f / maxf(size.x, 0.001), footprint.y * f / maxf(size.z, 0.001))
	var cap: float = maxf(footprint.x, footprint.y) * height_ratio_max()
	if size.y * s > cap:
		s = cap / maxf(size.y, 0.001)
	return s

## Footprint in metres for a structure node name (Built_<id>, PlayerYard, EnemyYard, HubShell, PackerCore).
static func structure_footprint(node_name: String, role: String) -> Vector2:
	var n: String = node_name.to_lower()
	if n == "hubshell" or n == "packercore" or n == "playeryard" or n == "enemyyard" or n == "enemybase":
		return SMBasePlan.footprint_m("", "yard")
	return SMBasePlan.footprint_m(n.trim_prefix("built_").trim_prefix("foebuilt_"), role)
