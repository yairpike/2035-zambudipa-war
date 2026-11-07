class_name SMPointer
extends RefCounted
## Click controls for a match: left click and drag select friendlies,
## right click ground to move, right click an enemy to attack.

const StatusUnit = preload("res://addons/rts_advanced/sm_status.gd")
const Weather = preload("res://addons/rts_advanced/sm_weather.gd")
const PLAYER: int = 0
const ENEMY: int = 1
const PICK_PX: float = 28.0
const ATTACK_M: float = 2.2
const BUILDING_SIZE: Vector3 = Vector3(2.2, 4.6, 2.2)
const GTFC_KINDS: Array[StringName] = [&"militia", &"slag_hauler", &"ruby_lancer", &"amber_tank", &"monsoon_tube", &"channel_skiff"]
const MVD_KINDS: Array[StringName] = [&"clearance_trooper", &"hub_drone", &"charcoal_apc", &"cyan_ifv", &"relay_van", &"river_drone"]
const NMRF_KINDS: Array[StringName] = [&"river_rifle", &"sampan", &"emerald_gunboat", &"mangrove_tube", &"packer", &"jade_skiff"]

var teams: RTSTeams = RTSTeams.new()
var faction_id: String = "gtfc"
## Set before spawn so one enemy can wear a different faction than the mission default.
var next_look: String = ""
var primary_color: Color = Color(0.72, 0.12, 0.18)
var accent_color: Color = Color(0.88, 0.62, 0.12)
var nav: RTSGridNav
var nav_ground: RTSGridNav
var nav_amphib: RTSGridNav
var nav_naval: RTSGridNav
var nav_air: RTSGridNav
var domain: SMDomainGrid
var selection: RTSSelection = RTSSelection.new()
var units: Array[RTSUnit] = []
var box: RTSSelectionBox
var cam: RTSCamera
var host: Node3D
var ew: SMEwField
var tech: SMTechNet
var on_bridge_ruined: Callable
var on_cue: Callable
var on_line: Callable
var on_bark: Callable
var marks: Array[Node3D] = []
var group_note: String = ""
var group_note_t: float = 0.0
var beacon_at: Vector3 = Vector3.INF
var line_formation: bool = false
var last_pick: int = 0
var last_pick_ms: int = 0
var hover_at: Vector2 = Vector2.INF
var visual_node: Node3D
var side_link: SMSide
const Cast = preload("res://addons/rts_advanced/sm_cast.gd")
const F_COOLDOWN: float = 3.0
signal dressed(host: Node3D)
signal unit_made(u: RTSUnit, team: int, kind: String, role: String, loco: String, tint: Color, label: String)
signal unit_posed(u: RTSUnit, delta: float)
signal status_shown(body: MeshInstance3D, frozen: bool)
signal beacon_moved(host: Node3D, at: Vector3)
signal rally_moved(host: Node3D, at: Vector3)
signal wreck_made(host: Node3D, at: Vector3)
signal ping_made(host: Node3D, at: Vector3, order: String)
signal path_moved(host: Node3D, show: bool, step: Vector3)
signal damage_shown(u: RTSUnit, amount: float)
signal ally_lost
const BEAM_TIME: float = 1.5

func bind(p_host: Node3D, p_cam: RTSCamera) -> void:
	host = p_host
	cam = p_cam
	teams.add_team(PLAYER, Color(0.72, 0.12, 0.18))
	teams.add_team(ENEMY, Color(0.12, 0.62, 0.7))
	teams.set_relation(PLAYER, ENEMY, RTSTeams.Relation.ENEMY)
	selection.team = PLAYER
	dressed.emit(host)

func bind_faction(p_host: Node3D, p_cam: RTSCamera, faction: String) -> void:
	bind(p_host, p_cam)
	faction_id = faction
	var data: Dictionary = SMCatalog.faction(faction)
	var colors: Dictionary = {}
	var raw_colors: Variant = data.get("colors", {})
	if raw_colors is Dictionary:
		colors = raw_colors
	primary_color = SMCatalog.hex_color(str(colors.get("primary_hex", "#B81E2D")))
	accent_color = SMCatalog.hex_color(str(colors.get("accent_hex", "#E0A106")))
	teams.add_team(PLAYER, primary_color)
	if faction == "mvd":
		teams.add_team(ENEMY, Color(0.72, 0.12, 0.18))
	else:
		teams.add_team(ENEMY, Color(0.12, 0.62, 0.7))

func bind_tech(net: SMTechNet, ruined: Callable) -> void:
	tech = net
	on_bridge_ruined = ruined

func use_domain(grid: SMDomainGrid) -> void:
	domain = grid
	nav_ground = _nav_for_loco(grid, SMDomainGrid.Loco.GROUND)
	nav_amphib = _nav_for_loco(grid, SMDomainGrid.Loco.AMPHIBIOUS)
	nav_naval = _nav_for_loco(grid, SMDomainGrid.Loco.NAVAL)
	nav_air = _nav_for_loco(grid, SMDomainGrid.Loco.AIR)
	nav = nav_amphib

func _nav_for_loco(grid: SMDomainGrid, loco: int) -> RTSGridNav:
	var built: RTSGridNav = RTSGridNav.new(grid.cols, grid.rows, grid.cell_size, grid.origin)
	for y: int in range(grid.rows):
		for x: int in range(grid.cols):
			var cell: Vector2i = Vector2i(x, y)
			var blocked: bool = not grid.can_enter(grid.domain_at_cell(cell), loco)
			if not blocked and loco != SMDomainGrid.Loco.AIR and grid.holding(cell):
				blocked = true
			if blocked:
				built.set_blocked(cell, true)
	return built

func nav_for_unit(u: RTSUnit) -> RTSGridNav:
	var loco: String = "ground"
	if is_instance_valid(u):
		loco = str(u.get_meta("locomotion", "ground"))
	if loco == "naval" and nav_naval != null:
		return nav_naval
	if loco == "amphibious" and nav_amphib != null:
		return nav_amphib
	if loco == "air" and nav_air != null:
		return nav_air
	if nav_ground != null:
		return nav_ground
	return nav

func loco_id(u: RTSUnit) -> int:
	var loco: String = "ground"
	if is_instance_valid(u):
		loco = str(u.get_meta("locomotion", "ground"))
	if loco == "amphibious":
		return SMDomainGrid.Loco.AMPHIBIOUS
	if loco == "naval":
		return SMDomainGrid.Loco.NAVAL
	if loco == "air":
		return SMDomainGrid.Loco.AIR
	return SMDomainGrid.Loco.GROUND

func use_open(cols: int, rows: int, cell: float, origin: Vector3) -> void:
	nav = RTSGridNav.new(cols, rows, cell, origin)

func attach_box(layer: CanvasLayer) -> void:
	box = RTSSelectionBox.new()
	box.name = "SelectionBox"
	box.count_provider = Callable(self, "preview_count")
	layer.add_child(box)

func preview_count(rect: Rect2) -> int:
	return selection.preview_count(rect, units, Callable(self, "project_point"))

func project_point(p: Vector3) -> Vector2:
	if cam == null:
		return Vector2(p.x, p.z)
	return cam.unproject_position(p)

func spawn(team: int, at: Vector3, kind: StringName, lead: bool = true) -> RTSUnit:
	var u: RTSUnit = StatusUnit.new() as RTSUnit
	u.team = team
	u.unit_type = kind
	u.speed = 8.0
	u.max_hp = 80.0
	u.attack_damage = 12.0
	u.attack_range = 8.0
	u.attack_interval = 0.8
	u.position = at
	if next_look != "":
		u.set_meta("look", next_look)
		next_look = ""
	_apply_catalog(u, kind)
	var row: Dictionary = _unit_row(kind)
	var role: String = "infantry" if row.is_empty() else str(row.get("role", ""))
	var loco: String = "ground" if row.is_empty() else str(row.get("locomotion", "ground"))
	visual_node = null
	unit_made.emit(u, team, str(kind), role, loco, _body_color(team, kind), unit_label(team, kind))
	u.set_meta("jammer", Callable(self, "filter_shot"))
	u.shot_filter = Callable(u, "guard_shot")
	u.fired.connect(_on_shot)
	host.add_child(u)
	u.set_meta("seen_hp", u.hp)
	units.append(u)
	if lead:
		var flight: int = int(_unit_row(kind).get("flight", 1))
		for n: int in range(1, flight):
			spawn(team, at + Vector3(1.3 * float(n), 0.0, 0.4 * float(n)), kind, false)
	return u

func spawn_support(at: Vector3) -> void:
	var have: Array = []
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.team == PLAYER:
			have.append(u.unit_type)
	var n: int = 0
	for id: StringName in SMCatalog.support_ids(faction_id, have):
		spawn(PLAYER, at + Vector3(2.2 * float(n), 0.0, 3.2), id)
		n += 1

func _on_shot(unit: RTSUnit, _target: RTSUnit) -> void:
	if not is_instance_valid(unit):
		return
	unit.set_meta("flash_t", 0.14)
	if str(unit.unit_type) == "mekong_uav":
		var left: int = int(unit.get_meta("missiles", 2)) - 1
		unit.set_meta("missiles", left)
		if left <= 0 and unit.attack_damage > 0.0:
			unit.set_meta("attack_bank", unit.attack_damage)
			unit.attack_damage = 0.0
	var dive: String = str(unit.get_meta("ability", ""))
	if dive == "Shaped Charge" or dive == "Fibre Dive":
		unit.take_damage(unit.hp + 1.0)
	var muzzle: MeshInstance3D = unit.get_node_or_null("Muzzle") as MeshInstance3D
	if muzzle != null:
		muzzle.visible = true

func unit_label(team: int, kind: StringName) -> String:
	if team != PLAYER:
		return "Enemy"
	var row: Dictionary = _unit_row(kind)
	if row.is_empty():
		return faction_id.to_upper()
	return str(row.get("display_name", faction_id.to_upper()))

func name_of(u: RTSUnit) -> String:
	if not is_instance_valid(u):
		return ""
	var tag: Label3D = u.get_node_or_null("NameTag") as Label3D
	if tag == null:
		return ""
	return tag.text

func _apply_catalog(u: RTSUnit, kind: StringName) -> void:
	var unit: Dictionary = _unit_row(kind)
	if unit.is_empty():
		return
	u.max_hp = float(unit.get("hp", u.max_hp))
	u.hp = u.max_hp
	u.speed = float(unit.get("speed", u.speed))
	u.attack_damage = float(unit.get("weapon_damage", u.attack_damage))
	if unit.has("attack_range"):
		u.attack_range = float(unit.get("attack_range"))
	if int(unit.get("missiles", 0)) > 0:
		u.set_meta("missiles", int(unit.get("missiles")))
	u.set_meta("weapon", str(unit.get("weapon", "")))
	u.set_meta("secondary", str(unit.get("secondary", "")))
	u.set_meta("guidance", str(unit.get("guidance", "none")))
	u.set_meta("locomotion", str(unit.get("locomotion", "ground")))
	u.set_meta("role", str(unit.get("role", "")))
	u.set_meta("tags", _tag_list(unit))
	u.set_meta("ability", str(unit.get("ability", "")))
	u.set_meta("f_stat", str(unit.get("f_stat", "damage")))
	SMCatalog.mark_unit(u, unit)

func _body_color(team: int, kind: StringName) -> Color:
	if team != PLAYER:
		return teams.color_of(team)
	if faction_id != "gtfc":
		return accent_color if _accent_kind(kind) else primary_color
	if kind == &"slag_hauler" or kind == &"amber_tank" or kind == &"channel_skiff":
		return Color(0.88, 0.62, 0.12)
	return Color(0.72, 0.12, 0.18)

func _accent_kind(kind: StringName) -> bool:
	var units: Array[Dictionary] = SMCatalog.units_of(SMCatalog.faction(faction_id))
	for i: int in units.size():
		if str(units[i].get("id", "")) == str(kind):
			return i % 2 == 1
	return false

static func building_at(at: Vector3) -> Vector3:
	return at + Vector3(0.0, BUILDING_SIZE.y * 0.5, 0.0)

func category_of(kind: StringName) -> String:
	var unit: Dictionary = _unit_row(kind)
	if unit.is_empty():
		return "infantry"
	var role: String = str(unit.get("role", ""))
	var loco: String = str(unit.get("locomotion", ""))
	if role == "infantry" or _tagged(unit, "infantry"):
		return "infantry"
	if role == "air" or role == "drone" or loco == "air" or _tagged(unit, "air"):
		return "aircraft"
	if role == "boat" or role == "amphibious" or loco == "naval" or _tagged(unit, "naval"):
		return "boat"
	return "vehicle"

func _unit_row(kind: StringName) -> Dictionary:
	var lists: Array[String] = [faction_id]
	for extra: String in ["black_market", "gtfc", "nmrf", "mvd"]:
		if not lists.has(extra):
			lists.append(extra)
	for faction: String in lists:
		var units: Array[Dictionary] = SMCatalog.units_of(SMCatalog.faction(faction))
		for unit: Dictionary in units:
			if str(unit.get("id", "")) == str(kind):
				return unit
	return {}

func _tagged(unit: Dictionary, tag: String) -> bool:
	var raw: Variant = unit.get("tags", [])
	if not (raw is Array):
		return false
	for item: Variant in raw:
		if str(item) == tag:
			return true
	return false

func _open_units() -> Array:
	var out: Array = []
	for u: RTSUnit in units:
		if not bool(u.get_meta("garrisoned", false)):
			out.append(u)
	return out

func _drop_garrisoned() -> void:
	var housed: Array[RTSUnit] = []
	for u: RTSUnit in selection.units:
		if is_instance_valid(u) and bool(u.get_meta("garrisoned", false)):
			housed.append(u)
	for u: RTSUnit in housed:
		u.selected = false
		selection.units.erase(u)

func units_of(team: int) -> Array[RTSUnit]:
	var out: Array[RTSUnit] = []
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive() and u.team == team:
			out.append(u)
	return out

func count_team(team: int) -> int:
	return units_of(team).size()

func select_click(screen: Vector2, project_fn: Callable, add: bool = false, toggle: bool = false) -> RTSUnit:
	var picked: RTSUnit = selection.select_at(screen, _open_units(), project_fn, add, toggle, PICK_PX)
	if picked != null and not add and not toggle and _fresh_double(picked):
		select_kind(picked.unit_type)
	elif picked != null and picked.selected:
		_cue("select")
		announce(picked, "select")
	return picked

func select_drag(rect: Rect2, project_fn: Callable, add: bool = false) -> int:
	return selection.select_box(rect, _open_units(), project_fn, add)

func select_kind(kind: StringName) -> int:
	var found: Array[RTSUnit] = []
	for u: RTSUnit in units_of(PLAYER):
		if u.unit_type == kind and not bool(u.get_meta("garrisoned", false)):
			found.append(u)
	select_only(found)
	if not found.is_empty():
		group_note = "All %s" % name_of(found[0])
		group_note_t = 1.4
	return found.size()

func select_same() -> int:
	if selection.count() <= 0:
		return select_company()
	return select_kind(selection.units[0].unit_type)

func select_company() -> int:
	var company: Array[RTSUnit] = []
	for u: RTSUnit in units_of(PLAYER):
		if not bool(u.get_meta("garrisoned", false)):
			company.append(u)
	select_only(company)
	group_note = "Company"
	group_note_t = 1.2
	return selection.count()

func toggle_line() -> bool:
	line_formation = not line_formation
	group_note = "Line" if line_formation else "Box"
	group_note_t = 1.4
	return line_formation

func _fresh_double(u: RTSUnit) -> bool:
	var now: int = Time.get_ticks_msec()
	var id: int = u.get_instance_id()
	var hit: bool = last_pick == id and now - last_pick_ms < 320
	last_pick = id
	last_pick_ms = now
	return hit

## Right click. Returns "attack", "move", or "none".
func command_at(ground: Vector3, screen: Vector2, project_fn: Callable, queue: bool = false) -> StringName:
	if selection.count() <= 0:
		return &"none"
	var foe: RTSUnit = enemy_near(screen, ground, project_fn)
	if foe != null:
		var hit: int = 0
		for u: RTSUnit in selection.units:
			if is_instance_valid(u) and u.is_alive():
				var one: Array[RTSUnit] = [u]
				hit += RTSOrders.attack(one, foe, nav_for_unit(u), teams)
		if hit > 0:
			_drop_hunt(selection.units)
			_clear_bridges(selection.units)
			_cue("attack")
			announce(_first_player(), "attack")
			_mark(foe.global_position, "attack")
		return &"attack" if hit > 0 else &"none"
	if tech != null and ground != Vector3.INF:
		var span_id: StringName = tech.nearest_bridge(ground, 6.0)
		if span_id != &"":
			return _order_bridge(span_id)
	if ground == Vector3.INF:
		return &"none"
	var housed: int = 0
	if side_link != null:
		housed = SMGuns.try_enter(side_link, self, ground)
	var sent: int = _send(ground, false, queue)
	if sent > 0:
		if queue:
			group_note = "Waypoint"
			group_note_t = 1.2
		_cue("move")
		announce(_first_player(), "move")
		_mark(ground, "move")
	if sent > 0:
		return &"move"
	return &"garrison" if housed > 0 else &"none"

## Walks the selection to formation slots. Hunt keeps them shooting on the way.
func _send(ground: Vector3, hunt: bool, queue: bool = false) -> int:
	var live: Array[RTSUnit] = []
	for u: RTSUnit in selection.units:
		if is_instance_valid(u) and u.is_alive():
			live.append(u)
	if live.is_empty():
		return 0
	var center: Vector3 = Vector3.ZERO
	var positions: Array[Vector3] = []
	for u: RTSUnit in live:
		center += u.global_position
		positions.append(u.global_position)
	center /= float(live.size())
	var slots: Array[Vector3] = RTSFormation.line(center, ground, live.size(), 2.0) if line_formation else RTSFormation.box(center, ground, live.size(), 2.0)
	var pick: Array[int] = RTSFormation.assign(positions, slots)
	var sent: int = 0
	for i: int in live.size():
		var mover: RTSUnit = live[i]
		var slot: Vector3 = slots[pick[i]]
		var route: PackedVector3Array = nav_for_unit(mover).find_path(mover.global_position, slot)
		if route.is_empty():
			continue
		if queue and not mover.path.is_empty():
			var tail: Vector3 = mover.path[mover.path.size() - 1]
			var extra: PackedVector3Array = nav_for_unit(mover).find_path(tail, slot)
			if extra.is_empty():
				continue
			mover.path.append_array(extra)
			sent += 1
			continue
		mover.attack_target = null
		mover.set_meta("bridge_id", "")
		mover.set_meta("hunt", hunt)
		if hunt:
			mover.set_meta("hunt_goal", ground)
		mover.set_path(route)
		sent += 1
	return sent

func _drop_hunt(list: Array[RTSUnit]) -> void:
	for u: RTSUnit in list:
		if is_instance_valid(u):
			u.set_meta("hunt", false)

func _clear_bridges(list: Array[RTSUnit]) -> void:
	for u: RTSUnit in list:
		if is_instance_valid(u):
			u.set_meta("bridge_id", "")

func _order_bridge(id: StringName) -> StringName:
	var at: Vector3 = tech.site_pos(id)
	var hit: int = 0
	for u: RTSUnit in selection.units:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		u.attack_target = null
		u.set_meta("hunt", false)
		u.set_meta("bridge_id", str(id))
		u.set_meta("bridge_cool", 0.0)
		var route: PackedVector3Array = nav_for_unit(u).find_path(u.global_position, at)
		if not route.is_empty():
			u.set_path(route)
		hit += 1
	if hit <= 0:
		return &"none"
	_cue("attack")
	announce(_first_player(), "attack")
	_mark(at, "attack")
	return &"attack"

func _press_bridge(u: RTSUnit, delta: float) -> void:
	var raw: String = str(u.get_meta("bridge_id", ""))
	if raw == "" or tech == null:
		return
	var id: StringName = StringName(raw)
	if not tech.bridge_alive(id):
		u.set_meta("bridge_id", "")
		return
	var at: Vector3 = tech.site_pos(id)
	var dist: float = Vector2(u.global_position.x, u.global_position.z).distance_to(Vector2(at.x, at.z))
	if dist > u.attack_range + 0.4:
		return
	u.path = PackedVector3Array()
	u.attack_target = null
	var cool: float = float(u.get_meta("bridge_cool", 0.0)) - delta
	if cool > 0.0:
		u.set_meta("bridge_cool", cool)
		return
	u.set_meta("bridge_cool", u.attack_interval)
	var dealt: float = u.attack_damage * u.damage_mult
	if tech.harm_bridge(id, dealt) and on_bridge_ruined.is_valid():
		on_bridge_ruined.call(id)

## Ctrl stores the current selection in 1-9. A plain number recalls it.
func bind_group(index: int, store: bool) -> int:
	if index < 1 or index > 9:
		return 0
	if store:
		selection.save_group(index)
		group_note = "Group %d stored" % index
		group_note_t = 1.8
		return selection.count()
	selection.recall_group(index)
	_drop_garrisoned()
	var n: int = selection.count()
	group_note = ("Group %d" % index) if n > 0 else ("Group %d empty" % index)
	group_note_t = 1.8
	return n

func selection_focus() -> Vector3:
	if selection.count() <= 0:
		return Vector3.INF
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0
	for u: RTSUnit in selection.units:
		if is_instance_valid(u) and u.is_alive():
			sum += u.global_position
			n += 1
	if n <= 0:
		return Vector3.INF
	return sum / float(n)

func halt_selected() -> void:
	var live: Array[RTSUnit] = []
	for u: RTSUnit in selection.units:
		if is_instance_valid(u) and u.is_alive():
			live.append(u)
	RTSOrders.stop(live)
	_drop_hunt(live)
	_clear_bridges(live)
	group_note = "Halt"
	group_note_t = 1.4

func set_stance(mode: String) -> void:
	for u: RTSUnit in selection.units:
		if not is_instance_valid(u):
			continue
		u.set_meta("stance", mode)
		if mode == "hold" or mode == "guard":
			u.set_meta("hunt", false)
	group_note = mode.capitalize()
	group_note_t = 1.4

## Move toward `at` and shoot anything that enters range along the way.
func attack_move_at(at: Vector3) -> int:
	if at == Vector3.INF:
		return 0
	var sent: int = _send(at, true)
	if sent <= 0:
		return 0
	_mark(at, "attack")
	group_note = "Attack-move"
	group_note_t = 1.6
	_cue("attack")
	announce(_first_player(), "attack")
	return sent

func enemy_anchor() -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive() and teams.are_enemies(PLAYER, u.team):
			sum += u.global_position
			n += 1
	if n <= 0:
		return Vector3.INF
	return sum / float(n)

func place_beacon(at: Vector3) -> void:
	beacon_at = at
	beacon_moved.emit(host, at)

func place_rally(at: Vector3) -> void:
	rally_moved.emit(host, at)

func _cue(kind: String) -> void:
	if on_cue.is_valid():
		on_cue.call(kind)

func enemy_near(screen: Vector2, ground: Vector3, project_fn: Callable) -> RTSUnit:
	var best: RTSUnit = null
	var best_d: float = PICK_PX
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive() and teams.are_enemies(PLAYER, u.team):
			var d: float = (project_fn.call(u.global_position) as Vector2).distance_to(screen)
			if d <= best_d:
				best_d = d
				best = u
	if best != null:
		return best
	if ground == Vector3.INF:
		return null
	var flat: Vector2 = Vector2(ground.x, ground.z)
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive() and teams.are_enemies(PLAYER, u.team):
			if Vector2(u.global_position.x, u.global_position.z).distance_to(flat) <= ATTACK_M:
				return u
	return null

## Kokang secondary: selected friendlies (or the whole squad) strike the nearest enemy.
func secondary_strike() -> int:
	var squad: Array[RTSUnit] = []
	if selection.count() <= 0:
		squad = units_of(PLAYER)
	else:
		for u: RTSUnit in selection.units:
			if is_instance_valid(u) and u.is_alive():
				squad.append(u)
	var n: int = 0
	for u: RTSUnit in squad:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		var foe: RTSUnit = nearest_enemy(u.global_position, 24.0)
		if foe == null:
			continue
		foe.take_damage(u.attack_damage)
		u.attack_target = foe
		n += 1
	if n > 0 and not squad.is_empty():
		announce(squad[0], "ability")
	return n

func select_only(list: Array[RTSUnit]) -> void:
	selection.clear()
	for u: RTSUnit in list:
		if is_instance_valid(u) and u.is_alive() and u.team == PLAYER:
			if not selection.units.has(u):
				selection.units.append(u)
				u.selected = true
	selection.changed.emit(selection.units)

func aim_from_camera(camera: RTSCamera, screen: Vector2) -> Vector3:
	if camera != null:
		var ground: Vector3 = camera.ground_at(screen)
		if ground != Vector3.INF:
			return ground
	if selection.count() > 0:
		return selection.units[0].global_position
	return Vector3.ZERO

## Selected-unit F. Toggles the whole group, smart-casts only the closest ready unit,
## and starts a beam on the closest ready tube. Returns which kinds fired.
func cast_f(aim: Vector3) -> String:
	var toggled: int = 0
	var smart: RTSUnit = null
	var smart_d: float = 1.0e20
	var beam: RTSUnit = null
	var beam_d: float = 1.0e20
	for u: RTSUnit in selection.units:
		if not is_instance_valid(u) or not u.is_alive() or bool(u.get_meta("frozen", false)):
			continue
		var kind: String = str(u.get_meta("secondary", ""))
		var flat: float = Vector2(u.global_position.x, u.global_position.z).distance_to(Vector2(aim.x, aim.z))
		if kind == "group_toggle":
			var on: bool = not bool(u.get_meta("toggled", false))
			u.set_meta("toggled", on)
			var guidance: String = str(u.get_meta("guidance", "none"))
			if guidance == "fiber":
				u.set_meta("fiber_on", on)
			elif guidance == "hop":
				u.set_meta("hop_on", on)
			apply_named_f(u)
			toggled += 1
		elif kind == "smart_cast" and float(u.get_meta("f_ready", 0.0)) <= 0.0 and flat < smart_d:
			smart_d = flat
			smart = u
		elif kind == "channeled_beam" and not bool(u.get_meta("channeling", false)) and float(u.get_meta("f_ready", 0.0)) <= 0.0 and flat < beam_d:
			beam_d = flat
			beam = u
	var fired: String = ""
	if toggled > 0:
		fired = "toggle"
	if smart != null:
		smart.set_meta("fired_f", int(smart.get_meta("fired_f", 0)) + 1)
		smart.set_meta("f_ready", F_COOLDOWN)
		smart.set_meta("f_aim", aim)
		apply_named_f(smart)
		var strike: RTSUnit = nearest_enemy(aim, 240.0)
		if strike != null:
			strike.take_damage(smart.attack_damage * smart.damage_mult)
		fired = "smart" if fired == "" else fired + "+smart"
	if beam != null:
		beam.set_meta("channeling", true)
		beam.set_meta("channel_t", BEAM_TIME)
		beam.set_meta("f_ready", F_COOLDOWN)
		apply_named_f(beam)
		fired = "beam" if fired == "" else fired + "+beam"
	if fired != "":
		announce(_first_player(), "ability")
	return fired

func apply_named_f(u: RTSUnit) -> bool:
	if not is_instance_valid(u):
		return false
	var ability: String = str(u.get_meta("ability", ""))
	if ability == "Bench Seat":
		_bench(u)
	if ability == "Bomblet Carpet":
		var aim: Vector3 = u.get_meta("f_aim", u.global_position)
		for other: RTSUnit in units:
			if not is_instance_valid(other) or not other.is_alive() or not teams.are_enemies(u.team, other.team):
				continue
			var flat: float = Vector2(other.global_position.x, other.global_position.z).distance_to(Vector2(aim.x, aim.z))
			if flat <= 7.0:
				other.take_damage(u.attack_damage)
	var diving: bool = ability == "Shaped Charge" or ability == "Fibre Dive"
	if diving:
		var foe: RTSUnit = _armor_near(u)
		if foe == null:
			foe = nearest_enemy(u.global_position, maxf(u.attack_range, 8.0))
		if foe != null:
			foe.take_damage(u.attack_damage * 3.0)
	Cast.apply(self, u)
	var stat: String = str(u.get_meta("f_stat", "damage"))
	if stat == "speed":
		u.speed_scale += 0.4
	elif stat == "hp":
		u.max_hp += 8.0
		u.hp += 8.0
	elif stat == "incoming":
		u.incoming_mult = maxf(0.2, u.incoming_mult - 0.2)
	else:
		u.damage_mult += 0.25
	u.set_meta("f_stat_changed", stat)
	if str(u.get_meta("f_effect", "")) == "":
		u.set_meta("f_effect", str(u.get_meta("ability", "")))
	if str(u.get_meta("ability", "")) == "Shaped Charge" or str(u.get_meta("ability", "")) == "Fibre Dive":
		u.take_damage(u.hp + 1.0)
	return true

func apply_status(u: RTSUnit, status: String, duration: float) -> void:
	if not is_instance_valid(u):
		return
	var body: MeshInstance3D = u.get_node_or_null("Body") as MeshInstance3D
	if body != null:
		body.scale = Vector3.ONE
	status_shown.emit(body, false)
	u.speed_scale = 1.0
	u.incoming_mult = 1.0
	u.set_meta("frozen", false)
	u.set_meta("status", status)
	u.set_meta("status_t", duration)
	if status == "frozen":
		u.set_meta("frozen", true)
		u.speed_scale = 0.0
		u.stop()
		status_shown.emit(body, true)
	elif status == "shrunk":
		u.speed_scale = 2.0
		u.incoming_mult = 0.5
		if body != null:
			body.scale = Vector3(0.5, 0.5, 0.5)
	elif status == "black_hole":
		u.incoming_mult = 0.2

func filter_shot(u: RTSUnit, _target: RTSUnit, amount: float) -> float:
	if ew == null or not is_instance_valid(u):
		return amount
	var guidance: int = SMEwField.guidance_of(str(u.get_meta("guidance", "none")))
	var scale: float = ew.accuracy(u.global_position, guidance, bool(u.get_meta("fiber_on", false)), bool(u.get_meta("hop_on", false)))
	return amount * scale

func _crush_under(u: RTSUnit, before: Vector3) -> void:
	if not is_instance_valid(u) or not u.is_alive():
		return
	if not bool(u.get_meta("crusher", false)):
		return
	if u.global_position.distance_squared_to(before) <= 0.0001:
		return
	for other: RTSUnit in units:
		if other == u or not is_instance_valid(other) or not other.is_alive():
			continue
		if str(other.get_meta("status", "")) != "shrunk":
			continue
		if not teams.are_enemies(u.team, other.team):
			continue
		var flat: float = Vector2(u.global_position.x, u.global_position.z).distance_to(Vector2(other.global_position.x, other.global_position.z))
		if flat <= 1.35:
			other.set_meta("crushed", true)
			var scale: float = maxf(other.incoming_mult, 0.05)
			other.take_damage((other.hp + 1.0) / scale)

func _keep_domain(u: RTSUnit, before: Vector3) -> void:
	if domain == null or not is_instance_valid(u):
		return
	var loco: int = loco_id(u)
	var from_ok: bool = domain.can_enter(domain.domain_at(before), loco)
	var to_ok: bool = domain.can_enter(domain.domain_at(u.global_position), loco)
	if from_ok and not to_ok:
		u.global_position = before
		u.path = PackedVector3Array()

func is_infantry(u: RTSUnit) -> bool:
	if not is_instance_valid(u):
		return false
	if str(u.get_meta("role", "")) == "infantry":
		return true
	var raw: Variant = u.get_meta("tags", PackedStringArray())
	if raw is PackedStringArray:
		return (raw as PackedStringArray).has("infantry")
	return false

func _tag_list(unit: Dictionary) -> PackedStringArray:
	var tags: PackedStringArray = PackedStringArray()
	var raw: Variant = unit.get("tags", [])
	if raw is Array:
		for item: Variant in raw:
			tags.append(str(item))
	return tags

func _armor_near(u: RTSUnit) -> RTSUnit:
	var best: RTSUnit = null
	var best_d: float = 12.0
	for other: RTSUnit in units:
		if not is_instance_valid(other) or not other.is_alive() or not teams.are_enemies(u.team, other.team):
			continue
		var role: String = str(other.get_meta("role", ""))
		if role != "armor" and role != "vehicle" and role != "hauler":
			continue
		var d: float = u.global_position.distance_to(other.global_position)
		if d <= best_d:
			best_d = d
			best = other
	return best

func _bench(truck: RTSUnit) -> void:
	var riding: Array[RTSUnit] = []
	var raw: Variant = truck.get_meta("passengers", [])
	if raw is Array:
		for item: Variant in raw:
			var who: RTSUnit = instance_from_id(int(item)) as RTSUnit
			if is_instance_valid(who) and who.is_alive() and bool(who.get_meta("garrisoned", false)):
				riding.append(who)
	if not riding.is_empty():
		for i: int in riding.size():
			var who: RTSUnit = riding[i]
			who.visible = true
			who.set_meta("garrisoned", false)
			who.global_position = truck.global_position + Vector3(1.6 * float(i + 1), 0.0, 1.2)
		truck.set_meta("passengers", [])
		return
	var taken: Array = []
	for other: RTSUnit in units:
		if taken.size() >= 2:
			break
		if other == truck or not is_instance_valid(other) or not other.is_alive():
			continue
		if other.team != truck.team or str(other.get_meta("role", "")) != "infantry":
			continue
		if bool(other.get_meta("garrisoned", false)):
			continue
		if other.global_position.distance_to(truck.global_position) > 4.5:
			continue
		other.stop()
		other.selected = false
		other.visible = false
		other.set_meta("garrisoned", true)
		selection.units.erase(other)
		taken.append(other.get_instance_id())
	truck.set_meta("passengers", taken)

func _ride_bench(truck: RTSUnit) -> void:
	var raw: Variant = truck.get_meta("passengers", [])
	if not raw is Array:
		return
	for item: Variant in raw:
		var who: RTSUnit = instance_from_id(int(item)) as RTSUnit
		if is_instance_valid(who) and who.is_alive():
			who.global_position = truck.global_position

func _dump_bench(truck: RTSUnit) -> void:
	var raw: Variant = truck.get_meta("passengers", [])
	if not raw is Array:
		return
	var i: int = 0
	for item: Variant in raw:
		var who: RTSUnit = instance_from_id(int(item)) as RTSUnit
		if is_instance_valid(who) and who.is_alive():
			who.visible = true
			who.set_meta("garrisoned", false)
			who.global_position = truck.global_position + Vector3(1.4 * float(i + 1), 0.0, 0.0)
		i += 1
	truck.set_meta("passengers", [])

func _park_hides() -> void:
	if side_link == null or side_link.yard == null:
		return
	var spots: Array[Vector3] = []
	for id: StringName in side_link.yard.finished:
		if str(side_link.yard.building_role.get(id, "")) != "conceal" or not side_link.yard.structure_alive(id):
			continue
		spots.append(side_link.yard.position_of(id))
	var used: Array[int] = []
	used.resize(spots.size())
	for u: RTSUnit in units:
		if not is_instance_valid(u) or not u.is_alive():
			continue
		var role: String = str(u.get_meta("role", ""))
		var vehicle: bool = role == "vehicle" or role == "armor" or role == "hauler"
		var hidden: bool = false
		if vehicle and float(u.get_meta("flash_t", 0.0)) <= 0.0 and u.attack_target == null:
			for i: int in spots.size():
				if used[i] >= 2:
					continue
				if u.global_position.distance_to(spots[i]) <= 8.0:
					used[i] += 1
					hidden = true
					break
		u.set_meta("concealed", hidden)
	for shooter: RTSUnit in units:
		if not is_instance_valid(shooter) or shooter.attack_target == null or not is_instance_valid(shooter.attack_target):
			continue
		if bool(shooter.attack_target.get_meta("concealed", false)):
			shooter.attack_target = null

func _tick_ability(u: RTSUnit, delta: float) -> void:
	u.set_meta("f_ready", maxf(0.0, float(u.get_meta("f_ready", 0.0)) - delta))
	var status: String = str(u.get_meta("status", "none"))
	if status != "none":
		var left: float = float(u.get_meta("status_t", 0.0)) - delta
		u.set_meta("status_t", left)
		if left <= 0.0:
			apply_status(u, "none", 0.0)
	if str(u.get_meta("ability", "")) == "Swarm Cloud" and bool(u.get_meta("toggled", false)):
		if bool(u.get_meta("frozen", false)):
			u.set_meta("toggled", false)
		else:
			for other: RTSUnit in units:
				if not is_instance_valid(other) or not other.is_alive() or not teams.are_enemies(u.team, other.team):
					continue
				var flat: float = Vector2(u.global_position.x, u.global_position.z).distance_to(Vector2(other.global_position.x, other.global_position.z))
				if flat > 8.0:
					continue
				other.take_damage(3.0 * delta)
				if other.damage_mult > 0.75:
					other.damage_mult = 0.75
	if str(u.unit_type) == "mekong_uav" and int(u.get_meta("missiles", 2)) <= 0 and side_link != null and side_link.yard != null:
		if u.global_position.distance_to(side_link.yard.center) <= 14.0:
			u.set_meta("missiles", 2)
			var bank: float = float(u.get_meta("attack_bank", u.attack_damage))
			if bank > 0.0:
				u.attack_damage = bank
	_ride_bench(u)
	if not bool(u.get_meta("channeling", false)):
		return
	if bool(u.get_meta("frozen", false)):
		u.set_meta("channeling", false)
		u.set_meta("channel_t", 0.0)
		return
	var channel: float = float(u.get_meta("channel_t", 0.0)) - delta
	u.set_meta("channel_t", channel)
	if channel > 0.0:
		return
	u.set_meta("channeling", false)
	u.set_meta("beam_done", int(u.get_meta("beam_done", 0)) + 1)
	var foe: RTSUnit = nearest_enemy(u.global_position, 240.0)
	if foe != null:
		apply_status(foe, "frozen", 3.0)

func nearest_enemy(from: Vector3, reach: float) -> RTSUnit:
	var best: RTSUnit = null
	var best_d2: float = reach * reach
	var fx: float = from.x
	var fz: float = from.z
	for u: RTSUnit in units:
		if is_instance_valid(u) and u.is_alive() and not bool(u.get_meta("garrisoned", false)) and teams.are_enemies(PLAYER, u.team):
			var p: Vector3 = u.position
			var dx: float = fx - p.x
			var dz: float = fz - p.z
			var d2: float = dx * dx + dz * dz
			if d2 <= best_d2:
				best_d2 = d2
				best = u
	return best

func handle_button(mb: InputEventMouseButton) -> bool:
	if box == null or cam == null:
		return false
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if _touch_blocks_select(mb.pressed):
			if not mb.pressed:
				box.end()
			return true
		if mb.pressed:
			box.begin(mb.position)
		else:
			var project_fn: Callable = Callable(self, "project_point")
			var add: bool = mb.shift_pressed
			var toggle: bool = mb.ctrl_pressed and not add
			if box.is_box():
				select_drag(box.rect(), project_fn, add)
			else:
				select_click(mb.position, project_fn, add, toggle)
			box.end()
		return true
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		command_at(cam.ground_at(mb.position), mb.position, Callable(self, "project_point"), mb.shift_pressed)
		return true
	return false

func _touch_blocks_select(pressed: bool) -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var touch: Node = tree.root.get_node_or_null("SMTouch")
	if touch == null:
		return false
	if bool(touch.get("moved")):
		return true
	if not pressed:
		return false
	var raw: Variant = touch.get("points")
	if raw is Dictionary:
		return not (raw as Dictionary).is_empty()
	return false

func handle_motion(motion: InputEventMouseMotion) -> void:
	hover_at = motion.position
	if box != null and box.active:
		box.update_drag(motion.position)

func tick(delta: float) -> void:
	_fade_marks(delta)
	if group_note_t > 0.0:
		group_note_t = maxf(0.0, group_note_t - delta)
	var alive: Array[RTSUnit] = []
	var hover_unit: RTSUnit = _hovered(units)
	for u: RTSUnit in units:
		if not is_instance_valid(u):
			continue
		if not u.is_alive():
			_dump_bench(u)
			for hunter: RTSUnit in units:
				if hunter != u and is_instance_valid(hunter) and hunter.attack_target == u and hunter.team != u.team:
					hunter.set_meta("kills", int(hunter.get_meta("kills", 0)) + 1)
					hunter.attack_target = null
			if u.team == PLAYER:
				ally_lost.emit()
			_drop_wreck(u.global_position)
			u.queue_free()
			continue
		_tick_ability(u, delta)
		_press_hunt(u)
		_return_fire(u)
		_press_bridge(u, delta)
		var before: Vector3 = u.global_position
		Weather.step(u, delta)
		_crush_under(u, before)
		_keep_domain(u, before)
		unit_posed.emit(u, delta)
		var ring: Node3D = u.get_node_or_null("Ring") as Node3D
		if ring != null:
			ring.visible = u.selected
			var girth: float = _ring_girth(u)
			ring.scale = Vector3(girth, 1.0, girth)
		var reach: MeshInstance3D = u.get_node_or_null("RangeRing") as MeshInstance3D
		if reach != null:
			reach.visible = (u.selected and u.team == PLAYER) or u == hover_unit
			var span: float = maxf(u.attack_range, 0.2)
			reach.scale = Vector3(span, 1.0, span)
		_paint_vitals(u, delta)
		alive.append(u)
	units = alive
	_park_hides()
	_paint_names(alive, hover_unit)
	_paint_path()

func _drop_wreck(at: Vector3) -> void:
	if host == null:
		return
	visual_node = null
	wreck_made.emit(host, at)
	var body: MeshInstance3D = visual_node as MeshInstance3D
	if body == null:
		return
	body.set_meta("order", "wreck")
	body.set_meta("life", 0.9)
	marks.append(body)

func _mark(at: Vector3, order: String) -> void:
	if host == null:
		return
	visual_node = null
	ping_made.emit(host, at, order)
	var ping: MeshInstance3D = visual_node as MeshInstance3D
	if ping == null:
		return
	ping.set_meta("order", order)
	ping.set_meta("life", 1.15)
	marks.append(ping)

func _fade_marks(delta: float) -> void:
	var kept: Array[Node3D] = []
	for ping: Node3D in marks:
		if not is_instance_valid(ping):
			continue
		var life: float = float(ping.get_meta("life", 0.0)) - delta
		if life <= 0.0:
			ping.queue_free()
			continue
		ping.set_meta("life", life)
		kept.append(ping)
	marks = kept

func announce(u: RTSUnit, cue: String) -> void:
	if not is_instance_valid(u) or u.team != PLAYER:
		return
	var text: String = SMBark.line(u.unit_type, cue)
	if on_line.is_valid():
		on_line.call(text)
	if on_bark.is_valid():
		var pitch: float = 1.6 if str(u.get_meta("status", "")) == "shrunk" else 1.0
		on_bark.call(pitch, str(u.unit_type), cue)

func _first_player() -> RTSUnit:
	for u: RTSUnit in selection.units:
		if is_instance_valid(u) and u.is_alive() and u.team == PLAYER:
			return u
	return null

func _ring_girth(u: RTSUnit) -> float:
	var category: String = category_of(u.unit_type)
	if category == "vehicle":
		return 1.85
	if category == "boat" or category == "aircraft":
		return 1.55
	return 0.72

func _hovered(alive: Array[RTSUnit]) -> RTSUnit:
	if hover_at == Vector2.INF or cam == null:
		return null
	var hover_unit: RTSUnit = null
	var hover_d: float = PICK_PX
	for u: RTSUnit in alive:
		if not is_instance_valid(u) or not u.is_alive() or not u.visible:
			continue
		var screen: Vector2 = project_point(u.position)
		var d: float = screen.distance_to(hover_at)
		if d <= hover_d:
			hover_d = d
			hover_unit = u
	return hover_unit

func _paint_names(alive: Array[RTSUnit], hover_unit: RTSUnit = null) -> void:
	var lead: RTSUnit = null
	var chosen: int = 0
	for u: RTSUnit in alive:
		if u.selected:
			chosen += 1
			if lead == null:
				lead = u
	for u: RTSUnit in alive:
		var tag: Label3D = u.get_node_or_null("NameTag") as Label3D
		if tag == null:
			continue
		var show_name: bool = u == hover_unit
		if u.selected and (chosen <= 1 or u == lead):
			show_name = true
		tag.visible = show_name

func _bar_fit(u: RTSUnit) -> float:
	if cam == null or u == null:
		return 1.0
	var vp: Viewport = cam.get_viewport()
	if vp == null:
		return 1.0
	var view: Vector2 = vp.get_visible_rect().size
	var dist: float = cam.global_position.distance_to(u.position)
	var cap: float = minf(view.x * 0.16, 120.0)
	return _screen_span(view, cam.fov, dist, 2.0, cap)

func _screen_span(viewport: Vector2, fov_deg: float, dist: float, world_span: float, cap_px: float) -> float:
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

func _paint_vitals(u: RTSUnit, delta: float) -> void:
	var bar: MeshInstance3D = u.get_node_or_null("HealthBar") as MeshInstance3D
	if bar != null and bar.visible:
		var ratio: float = clampf(u.hp / maxf(u.max_hp, 1.0), 0.0, 1.0)
		var fit: float = _bar_fit(u)
		bar.scale = Vector3(maxf(0.04, ratio), 1.0, 1.0)
		var slab: BoxMesh = bar.mesh as BoxMesh
		if slab != null:
			var want: Vector3 = Vector3(2.0 * fit, 0.16 * fit, 0.1)
			if slab.size.distance_to(want) > 0.01:
				slab.size = want
		var ink: StandardMaterial3D = bar.material_override as StandardMaterial3D
		if ink != null and u.team == PLAYER and ratio < 0.35:
			ink.albedo_color = Color(0.92, 0.55, 0.18)
	var flash: float = float(u.get_meta("flash_t", 0.0))
	if flash > 0.0:
		flash = maxf(0.0, flash - delta)
		u.set_meta("flash_t", flash)
		var muzzle: MeshInstance3D = u.get_node_or_null("Muzzle") as MeshInstance3D
		if muzzle != null:
			muzzle.visible = flash > 0.0
	var seen: float = float(u.get_meta("seen_hp", u.hp))
	var drop: float = seen - u.hp
	if drop > 0.4:
		_pop_damage(u, drop)
		if u.team == PLAYER:
			var now: int = Time.get_ticks_msec()
			if now >= int(u.get_meta("hurt_until", 0)):
				announce(u, "hurt")
				u.set_meta("hurt_until", now + 1600)
	u.set_meta("seen_hp", u.hp)
	_rise_pop(u, delta)

func _return_fire(u: RTSUnit) -> void:
	if u.team != PLAYER or u.attack_damage <= 0.0 or bool(u.get_meta("garrisoned", false)):
		return
	if str(u.get_meta("stance", "aggressive")) == "hold":
		return
	if bool(u.get_meta("hunt", false)) or not u.path.is_empty():
		return
	if u.attack_target != null and is_instance_valid(u.attack_target) and u.attack_target.is_alive():
		return
	var foe: RTSUnit = nearest_enemy(u.global_position, u.attack_range)
	if foe != null:
		u.attack_target = foe

func _press_hunt(u: RTSUnit) -> void:
	if not bool(u.get_meta("hunt", false)) or bool(u.get_meta("frozen", false)) or bool(u.get_meta("garrisoned", false)):
		return
	var stance: String = str(u.get_meta("stance", "aggressive"))
	if stance == "hold" or stance == "guard":
		return
	if u.attack_target != null and is_instance_valid(u.attack_target) and u.attack_target.is_alive():
		return
	u.attack_target = null
	var foe: RTSUnit = nearest_enemy(u.global_position, u.attack_range)
	if foe != null:
		u.attack_target = foe
		return
	var goal: Variant = u.get_meta("hunt_goal", Vector3.INF)
	if not (goal is Vector3):
		return
	var at: Vector3 = goal as Vector3
	if at == Vector3.INF:
		return
	var flat: float = Vector2(u.global_position.x, u.global_position.z).distance_to(Vector2(at.x, at.z))
	if flat <= 1.4:
		u.set_meta("hunt", false)
		return
	if u.path.is_empty():
		var route: PackedVector3Array = nav_for_unit(u).find_path(u.global_position, at)
		if not route.is_empty():
			u.set_path(route)

func _paint_path() -> void:
	var lead: RTSUnit = _first_player()
	var show: bool = lead != null and not lead.path.is_empty()
	var step: Vector3 = lead.path[0] if show else Vector3.ZERO
	path_moved.emit(host, show, step)

func _pop_damage(u: RTSUnit, amount: float) -> void:
	damage_shown.emit(u, amount)
	u.set_meta("pop_t", 0.75)

func _rise_pop(u: RTSUnit, delta: float) -> void:
	var pop: Label3D = u.get_node_or_null("DamagePop") as Label3D
	if pop == null or not pop.visible:
		return
	var left: float = float(u.get_meta("pop_t", 0.0)) - delta
	u.set_meta("pop_t", left)
	if left <= 0.0:
		pop.visible = false
		return
	pop.position.y += delta * 1.6
	pop.modulate.a = clampf(left / 0.75, 0.0, 1.0)
