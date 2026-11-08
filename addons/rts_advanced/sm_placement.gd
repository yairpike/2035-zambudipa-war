class_name SMPlacement
extends RefCounted
## Interactive building placement: a ghost follows the cursor, snaps to the grid and checks the terrain rules.
## R or the mouse wheel turns it a quarter. Pressing on a cell and dragging aims the exit bay; releasing places it.
## No meshes: the view reads `spot`, `yaw`, `cells()` and `exit_cells()` on `changed`.

signal changed
signal finished(id: StringName, result: String)
## A click tried to place the ghost where it cannot stand; `reason` is the rule it broke.
signal refused(reason: String)

const DRAG_MIN: float = 1.6
const DONE: PackedStringArray = ["built", "placed", "unpacked", "redeployed"]

var side: SMSide
var active: bool = false
var id: StringName = &""
var redeploy: bool = false
var cursor: Vector3 = Vector3.INF
var anchor: Vector3 = Vector3.INF
var spot: Vector3 = Vector3.INF
var yaw: float = 0.0
var reason: String = ""
var pressed: bool = false
var dragged: bool = false
var last_result: String = ""

## Starts placing `p_id`. The ghost opens on the plan's suggested plot and facing.
func begin(p_side: SMSide, p_id: StringName, p_redeploy: bool = false) -> bool:
	if p_side == null or p_id == &"":
		return false
	side = p_side
	id = p_id
	redeploy = p_redeploy
	pressed = false
	dragged = false
	yaw = 0.0
	cursor = side.placement_center(id)
	if not redeploy and not side.plan.plots.has(id):
		var hint: Vector3 = side.plot_of(id, side.placement_center(id))
		if hint != Vector3.INF:
			cursor = hint
			yaw = side.plan.yaw_of(id)
		side.plan.release(id)
	elif redeploy:
		cursor = side.yard.center + Vector3(SMBasePlan.cell_m() * 3.0, 0.0, 0.0)
		yaw = side.front_of(id)
	active = true
	_refresh()
	return true

func cancel() -> void:
	if not active:
		return
	active = false
	pressed = false
	last_result = "cancelled"
	changed.emit()
	finished.emit(id, "cancelled")

func hover(ground: Vector3) -> void:
	if not active or ground == Vector3.INF:
		return
	if pressed:
		drag(ground)
		return
	cursor = ground
	_refresh()

## Quarter turn: +1 clockwise seen from above, -1 back.
func rotate(dir: int) -> void:
	if not active:
		return
	yaw = fposmod(yaw - 90.0 * float(signi(dir)), 360.0)
	_refresh()

func face(p_yaw: float) -> void:
	if not active:
		return
	yaw = fposmod(roundf(p_yaw / 90.0) * 90.0, 360.0)
	_refresh()

func press(ground: Vector3) -> void:
	if not active or ground == Vector3.INF:
		return
	pressed = true
	dragged = false
	cursor = ground
	_refresh()

## While pressed, the drag from the pressed cell sets the facing in 90-degree steps.
func drag(ground: Vector3) -> void:
	if not active or not pressed or ground == Vector3.INF:
		return
	var pull: Vector3 = ground - cursor
	if Vector2(pull.x, pull.z).length() < DRAG_MIN:
		return
	dragged = true
	yaw = SMBasePlan.yaw_toward(pull, 90.0)
	_refresh()

## Ends a press. Places the building and returns the side's result, or "" when nothing was pressed.
func release(ground: Vector3) -> String:
	if not active or not pressed:
		return ""
	drag(ground)
	pressed = false
	return confirm()

## Places at the current ghost. Stays active on a refusal so the player can move it.
func confirm() -> String:
	if not active or side == null:
		return ""
	_refresh()
	if reason != "":
		last_result = reason
		side._say(reason)
		refused.emit(reason)
		changed.emit()
		return reason
	var out: String = side.redeploy_yard(anchor, yaw) if redeploy else side.place_building(id, anchor, yaw)
	last_result = out
	if DONE.has(out):
		active = false
		finished.emit(id, out)
	changed.emit()
	return out

## Footprint cells under the ghost.
func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not active or side == null or side.plan.grid == null or spot == Vector3.INF:
		return out
	var rect: Rect2i = side.plan.rect_at(spot, side.footprint_at(id, yaw))
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	return out

## Cells the exit bay rolls units onto.
func exit_cells() -> Array[Vector2i]:
	if not active or side == null or side.plan.grid == null or spot == Vector3.INF:
		return []
	var rect: Rect2i = side.plan.rect_at(spot, side.footprint_at(id, yaw))
	return side.plan.exit_cells(rect, yaw, side.floats(id) and not redeploy)

func valid() -> bool:
	return active and reason == ""

## Footprint size in metres once turned.
func size_m() -> Vector2:
	if side == null:
		return Vector2(8.0, 8.0)
	return Vector2(side.footprint_at(id, yaw)) * SMBasePlan.cell_m()

func front() -> Vector3:
	return SMBasePlan.front_dir(yaw)

func _refresh() -> void:
	anchor = cursor
	spot = side.snap_spot(id, anchor, yaw) if side != null else anchor
	reason = side.placement_reason(id, anchor, yaw) if side != null else "no side"
	changed.emit()
