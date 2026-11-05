class_name SMOutcome
extends RefCounted
## Ends a skirmish when one side has no units and no production left.
## Killing the army does not raze the base. Structures fall only to fire in range.

var saw_player: bool = false
var saw_enemy: bool = false
var over: bool = false
var victory: bool = false
var host: Node
var panel: Control
var banner: Label
var reason: Label
var reason_plate: PanelContainer
var back: Button
var _cool: Dictionary[int, float] = {}

signal chrome_wanted(outcome: SMOutcome, panel: Control, faction: String)
signal base_struck

func mount(p_host: Node, layer: CanvasLayer) -> void:
	host = p_host
	panel = Control.new()
	panel.name = "MatchEnd"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 20
	layer.add_child(panel)
	var faction: String = "gtfc"
	var field: Variant = p_host.get("field")
	if field != null:
		faction = str(field.get("faction_id"))
	banner = Label.new()
	banner.name = "MatchBanner"
	banner.theme_type_variation = "Header"
	banner.anchor_left = 0.0
	banner.anchor_top = 0.5
	banner.anchor_right = 1.0
	banner.anchor_bottom = 0.5
	banner.offset_top = -64.0
	banner.offset_bottom = 8.0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.offset_left = 64.0
	banner.offset_right = -64.0
	banner.add_theme_font_size_override("font_size", 48)
	banner.add_theme_color_override("font_color", Color(1, 1, 1))
	panel.add_child(banner)
	reason_plate = PanelContainer.new()
	reason_plate.name = "MatchReasonPlate"
	reason_plate.visible = false
	reason_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reason_plate.anchor_left = 0.0
	reason_plate.anchor_top = 0.5
	reason_plate.anchor_right = 0.0
	reason_plate.anchor_bottom = 0.5
	reason_plate.offset_left = 64.0
	reason_plate.offset_right = 468.0
	reason_plate.offset_top = 44.0
	reason_plate.offset_bottom = 88.0
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.02, 0.025, 0.035, 0.94)
	pill.border_color = Color(0.93, 0.78, 0.38, 0.85)
	pill.set_border_width_all(1)
	pill.set_corner_radius_all(6)
	pill.content_margin_left = 14
	pill.content_margin_right = 14
	pill.content_margin_top = 6
	pill.content_margin_bottom = 6
	reason_plate.add_theme_stylebox_override("panel", pill)
	panel.add_child(reason_plate)
	reason = Label.new()
	reason.name = "MatchReason"
	reason.visible = false
	reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	reason.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reason.add_theme_font_size_override("font_size", 22)
	reason.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	reason.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	reason.add_theme_constant_override("outline_size", 4)
	reason_plate.add_child(reason)
	chrome_wanted.emit(self, panel, faction)

func consider(player_units: int, player_buildings: int, enemy_units: int, enemy_buildings: int) -> void:
	if over:
		return
	var player_alive: bool = player_units > 0 or player_buildings > 0
	var enemy_alive: bool = enemy_units > 0 or enemy_buildings > 0
	if player_alive:
		saw_player = true
	if enemy_alive:
		saw_enemy = true
	if not saw_player or not saw_enemy:
		return
	if not player_alive:
		_finish(false)
	elif not enemy_alive:
		_finish(true)

func tick(field: SMPointer, player_yards: Array[SMBuildYard], enemy_yards: Array[SMBuildYard], delta: float) -> void:
	if over or field == null:
		return
	var friends: Array[RTSUnit] = _side_units(field, true)
	var hostiles: Array[RTSUnit] = _side_units(field, false)
	var player_units: int = friends.size()
	var enemy_units: int = hostiles.size()
	var player_buildings: int = _living(player_yards)
	var enemy_buildings: int = _living(enemy_yards)
	if (player_units > 0 or player_buildings > 0) and (enemy_units > 0 or enemy_buildings > 0):
		saw_player = true
		saw_enemy = true
	elif player_units > 0 or player_buildings > 0:
		saw_player = true
	elif enemy_units > 0 or enemy_buildings > 0:
		saw_enemy = true
	if saw_player and saw_enemy:
		_press(field, friends, enemy_yards, delta, false)
		_press(field, hostiles, player_yards, delta, true)
		player_buildings = _living(player_yards)
		enemy_buildings = _living(enemy_yards)
	consider(player_units, player_buildings, enemy_units, enemy_buildings)

func _side_units(field: SMPointer, friendly: bool) -> Array[RTSUnit]:
	var out: Array[RTSUnit] = []
	for u: RTSUnit in field.units:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		var with_player: bool = field.teams.are_allies(SMPointer.PLAYER, u.team)
		if with_player == friendly:
			out.append(u)
	return out

func _living(yards: Array[SMBuildYard]) -> int:
	var total: int = 0
	for yard: SMBuildYard in yards:
		if yard != null:
			total += yard.living_count()
	return total

func _press(field: SMPointer, units: Array[RTSUnit], yards: Array[SMBuildYard], delta: float, player_base: bool) -> void:
	for u: RTSUnit in units:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		var best_yard: SMBuildYard = null
		var best_id: StringName = &""
		var best_d: float = INF
		for yard: SMBuildYard in yards:
			if yard == null:
				continue
			var id: StringName = yard.nearest_living(u.global_position)
			if id == &"":
				continue
			var pos: Vector3 = yard.position_of(id)
			var dist: float = Vector2(u.global_position.x, u.global_position.z).distance_to(Vector2(pos.x, pos.z)) - yard.reach_of(id)
			if dist < best_d:
				best_d = dist
				best_yard = yard
				best_id = id
		if best_yard == null or best_d > u.attack_range:
			continue
		if _fire(u, delta):
			best_yard.damage_structure(best_id, u.attack_damage)
			if player_base:
				base_struck.emit()
			if not best_yard.structure_alive(best_id):
				_hide(best_id)

func _fire(u: RTSUnit, delta: float) -> bool:
	var id: int = u.get_instance_id()
	var left: float = 0.0
	if _cool.has(id):
		left = _cool[id]
	if left > 0.0:
		_cool[id] = maxf(0.0, left - delta)
		return false
	_cool[id] = u.attack_interval
	return true

func _hide(id: StringName) -> void:
	if host == null:
		return
	var node_name: String = "Built_%s" % str(id)
	if id == &"enemy_yard":
		node_name = "EnemyYard"
	elif id == &"packer":
		node_name = "PackerCore"
	elif id == &"command_hub":
		node_name = "HubShell"
	var node: Node = host.get_node_or_null(node_name)
	if node is Node3D:
		node.set_meta("destroyed", true)
		(node as Node3D).visible = false
	var built: Node = host.get_node_or_null("Built_%s" % str(id))
	if built is Node3D:
		built.set_meta("destroyed", true)
		(built as Node3D).visible = false

func finish(win: bool, note: String = "") -> void:
	_finish(win, note)

func _finish(win: bool, note: String = "") -> void:
	if over:
		return
	over = true
	victory = win
	if panel != null:
		panel.visible = true
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var layer: Node = panel.get_parent()
		if layer != null:
			var boot_chip: CanvasItem = layer.find_child("MissionBoot", true, false) as CanvasItem
			if boot_chip != null:
				boot_chip.visible = false
	if banner != null:
		banner.text = "Victory" if win else "Defeat"
		banner.add_theme_color_override("font_color", Color(1, 1, 1))
	if reason != null:
		reason.text = note
		reason.visible = note != ""
	if reason_plate != null:
		reason_plate.visible = note != ""
	if back != null:
		back.offset_top = 104.0 if note != "" else 56.0
		back.offset_bottom = 156.0 if note != "" else 108.0
	var status: Label = null
	if host != null:
		status = host.find_child("Status", true, false) as Label
	if status != null:
		status.text = "Objective complete" if win else "Objective failed"
