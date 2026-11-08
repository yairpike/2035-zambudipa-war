extends SceneTree
## Prints a map plan or campaign dressing as text: lots, streets, sites and terrain.
## Usage: godot --headless --path . -s res://tools/plan_ascii.gd -- <map_id or missions/<id>> ...

func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var t0: int = Time.get_ticks_msec()
		var plan: SMMapPlan = SMMapPlan.dressing(arg.trim_prefix("missions/")) if arg.begins_with("missions/") else SMMapPlan.of(arg)
		if plan == null:
			print("no plan ", arg)
			continue
		print("%s %dx%d lots=%d paved=%d avenues=%d ms=%d" % [arg, plan.cols, plan.rows, plan.lots.size(), plan.paved.size(), plan.avenues.size(), Time.get_ticks_msec() - t0])
		for y: int in plan.rows:
			var line: String = ""
			for x: int in plan.cols:
				line += _glyph(plan, Vector2i(x, y))
			print(line)
	quit()

func _glyph(plan: SMMapPlan, c: Vector2i) -> String:
	for row: Dictionary in plan.sites:
		if row["cell"] == c:
			return "T"
	for row: Dictionary in plan.nodes:
		if row["cell"] == c:
			return "N"
	if plan.starts.has(c):
		return "@"
	var lot: Dictionary = plan.lot_at(c)
	if not lot.is_empty():
		if str(lot["kind"]) == "landmark":
			return "M"
		if str(lot["kind"]) == "building" or str(lot["kind"]) == "civic":
			return "B"
		return "h"
	if plan.paved.has(c):
		return "="
	var d: int = plan.ground.domain_at_cell(c)
	if d == SMDomainGrid.Domain.DEEP:
		return "~"
	if d == SMDomainGrid.Domain.SHALLOW:
		return "-"
	if d == SMDomainGrid.Domain.CLIFF:
		return "#"
	for r: Rect2i in plan.plateaus:
		if r.has_point(c):
			return ":"
	for r: Rect2i in plan.opens:
		if r.has_point(c):
			return ","
	for r: Rect2i in plan.holds:
		if r.has_point(c):
			return "X"
	for r: Rect2i in plan.orchards:
		if r.has_point(c):
			return "o"
	return "."
