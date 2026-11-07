extends Node3D
## Guest view of the host's match. Orders go to the guest's own side.

const Lan = preload("res://game/lan_link.gd")
const Seat = preload("res://game/lan_seat.gd")
const Ground = preload("res://game/ground_view.gd")
const Forms = preload("res://game/unit_meshes.gd")
const Models = preload("res://game/model_registry.gd")
const World = preload("res://game/world_view.gd")
const MapArt = preload("res://game/hud_minimap_art.gd")
const Settings = preload("res://game/match_settings.gd")

var grid: SMDomainGrid
var plan: SMMapPlan
var sim: SMMatch = SMMatch.new()
var field: SMPointer = SMPointer.new()
var roster: SMRoster = SMRoster.new()
var side: SMSide = SMSide.new()
var hud: SMHud = SMHud.new()
var outcome: SMOutcome = SMOutcome.new()
var sight: SMSight = SMSight.new()
var status: Label
var ui_layer: CanvasLayer
var map_id: String = "phillips_channel"

var _dots: Dictionary = {}
var _blocks: Dictionary = {}
var _status: Label
var _purse: Label
var _cam: RTSCamera
var _picked: Array[int] = []
var _train: String = ""
var _build: String = ""
var _sell: String = ""
var _proto: String = "cash_bounty"
var _home: Vector3 = Vector3.ZERO
var _home_focused: bool = false
var _fog: PackedByteArray = PackedByteArray()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	preload("res://game/boot.gd").mark_training_seen()
	preload("res://game/sim_presenter.gd").follow(self)
	var seat: Seat = Lan.seat()
	var guest_fac: String = seat.guest_faction if seat.guest_faction != "" else SMFront.current()
	var host_fac: String = seat.faction if seat.faction != "" else "gtfc"
	SMFront.faction_id = guest_fac
	Models.look_faction = host_fac
	map_id = _map_id_of(seat.map_path)
	plan = SMMapPlan.of(map_id)
	grid = _grid_for(map_id)
	if map_id == "phillips_channel":
		sim.setup_phillips(guest_fac)
	else:
		sim.place_sites(map_id, grid)
	roster.setup(guest_fac)
	_world()
	_ui()
	_home = _default_home()
	side.prepare(self, status, grid, _home, roster.economy, guest_fac)
	if side.yard.style != SMBuildYard.Style.INTERNAL:
		side.yard.radius = maxf(side.yard.radius, 44.0)
	field.bind_faction(self, _cam, guest_fac)
	field.use_domain(grid)
	field.attach_box(ui_layer)
	hud.mount(ui_layer, field, roster, side, _map_title(map_id), _home, Callable(self, "fire_ability"), grid, _cam)
	hud.use_goods(sim.goods)
	hud.use_tech(sim.tech)
	outcome.mount(self, ui_layer)
	sight.bind(grid)
	hud.use_sight(sight)
	if hud.minimap != null:
		hud.minimap.backdrop = MapArt.bake(grid, _profile_of(map_id))
	_wire_hud_commands()
	Settings.apply_scene(self)

func _map_id_of(path: String) -> String:
	var stem: String = path.get_file().get_basename()
	if stem == "":
		return "phillips_channel"
	return stem

func _profile_of(id: String) -> String:
	match id:
		"sop_ruak":
			return "sop"
		"burma_road":
			return "burma"
		"ten_degree_atolls":
			return "atolls"
		"mekong_delta":
			return "mekong"
		"chiang_rai":
			return "chiang"
		"showcase":
			return "showcase"
	return "phillips"

func _map_title(id: String) -> String:
	match id:
		"sop_ruak":
			return "Sop Ruak"
		"burma_road":
			return "Burma Road"
		"ten_degree_atolls":
			return "Ten Degree Atolls"
		"mekong_delta":
			return "Mekong Delta"
		"chiang_rai":
			return "Siege of Chiang Rai"
		"showcase":
			return "Golden Confluence"
	return "Phillips Channel"

func _grid_for(id: String) -> SMDomainGrid:
	if plan != null:
		return plan.grid()
	if id == "sop_ruak":
		return SMDomainGrid.sop_ruak_layout()
	if id == "showcase":
		return SMDomainGrid.showcase_layout()
	return SMDomainGrid.phillips_layout()

func _default_home() -> Vector3:
	if plan != null and plan.starts.size() >= 2:
		return grid.cell_center(plan.start(plan.starts.size() / 2))
	if map_id == "sop_ruak":
		return grid.cell_center(SMDomainGrid.at("sop_ruak", Vector2i(26, 22)))
	return grid.cell_center(SMDomainGrid.at("phillips", Vector2i(30, 12)))

func _world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.07, 0.1, 0.13)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 20.0, 0.0)
	add_child(sun)
	var profile: String = _profile_of(map_id)
	var dressing: SMMapPlan = null
	if plan == null:
		dressing = SMMapPlan.dressing(map_id)
	Ground.dress(self, grid, profile, plan, Rect2i(), dressing)
	if map_id == "mekong_delta" and plan != null:
		_deck("BridgeWest", plan.site_span(&"bridge_a").merge(plan.site_span(&"bridge_b")))
		_deck("BridgeEast", plan.site_span(&"bridge_c").merge(plan.site_span(&"bridge_d")))
	sim.paint_sites(self)
	_cam = RTSCamera.new()
	_cam.name = "Camera"
	var span: Vector2 = Vector2(float(grid.cols) * grid.cell_size, float(grid.rows) * grid.cell_size)
	_cam.bounds = Rect2(grid.origin.x - 8.0, grid.origin.z - 8.0, span.x + 16.0, span.y + 16.0)
	_cam.distance = 32.0 if plan == null else (56.0 if map_id == "chiang_rai" else 52.0)
	_cam.zoom_max = 90.0
	_cam.edge_pan_px = 20.0
	_cam.focus = _default_home()
	add_child(_cam)
	_cam.current = true

func _deck(node_name: String, span: Rect2i) -> void:
	if plan == null:
		return
	var size: Vector3 = Vector3(float(span.size.x) * grid.cell_size + 2.0, 0.28, float(span.size.y) * grid.cell_size)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = plan.rect_center(span) + Vector3(0.0, 0.15, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.4, 0.3)
	mi.material_override = mat
	add_child(mi)

func _ui() -> void:
	ui_layer = CanvasLayer.new()
	var layer: CanvasLayer = ui_layer
	add_child(layer)
	sim.protocols.mount_panel(layer, roster.economy, SMPointer.PLAYER, sim.abilities, Callable(self, "_say"))
	var title: Label = Label.new()
	title.name = "LanGuest"
	title.text = "LAN guest. Your company, your base."
	title.visible = false
	layer.add_child(title)
	_status = Label.new()
	_status.name = "Status"
	_status.text = "Waiting for the host."
	_status.position = Vector2(240.0, 608.0)
	_status.size = Vector2(760.0, 40.0)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.clip_text = true
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_color_override("font_color", Color(0.95, 0.9, 0.55))
	layer.add_child(_status)
	status = _status
	preload("res://game/sim_presenter.gd").seat_status(_status)
	_purse = Label.new()
	_purse.name = "LanPurse"
	_purse.text = "Credits 0    Power 0/0"
	_purse.visible = false
	layer.add_child(_purse)
	_orders(layer)
	var back: Button = Button.new()
	back.name = "MissionBoot"
	back.text = "Boot menu"
	back.position = Vector2(48.0, 168.0)
	back.pressed.connect(func() -> void:
		Lan.close()
		get_tree().change_scene_to_file("res://game/boot.tscn")
	)
	layer.add_child(back)

func _orders(layer: CanvasLayer) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "LanOrders"
	row.position = Vector2(220.0, 168.0)
	row.visible = false
	row.add_theme_constant_override("separation", 6)
	layer.add_child(row)
	_order(row, "LanTrain", "Train", _send_train)
	_order(row, "LanBuild", "Build", _send_build)
	_order(row, "LanPlace", "Place", _send_place)
	_order(row, "LanSell", "Sell", _send_sell)
	_order(row, "LanRepair", "Repair", _send_repair)
	_order(row, "LanAbility", "Ability", _send_ability)
	_order(row, "LanProtocol", "Protocol", _send_protocol)

func _order(row: HBoxContainer, node_name: String, caption: String, fn: Callable) -> void:
	var b: Button = Button.new()
	b.name = node_name
	b.text = caption
	b.pressed.connect(fn)
	row.add_child(b)

func _wire_hud_commands() -> void:
	if ui_layer == null:
		return
	var containers: Array[Node] = [hud.icon_grid, hud.sidebar]
	for host_node: Node in containers:
		if host_node == null:
			continue
		for child: Node in host_node.get_children():
			var btn: Button = child as Button
			if btn == null:
				continue
			var prod_id: String = str(btn.get_meta("prod_id", ""))
			var prod_kind: String = str(btn.get_meta("prod_kind", ""))
			if prod_id == "":
				continue
			if prod_kind == "unit":
				btn.pressed.connect(_cmd_train.bind(prod_id))
			elif prod_kind == "building":
				btn.pressed.connect(_cmd_building.bind(prod_id))
	var protos: Node = ui_layer.find_child("Protocols", true, false)
	if protos != null and protos.get_child_count() > 0:
		for child: Node in protos.get_child(0).get_children():
			var pbtn: Button = child as Button
			if pbtn != null and str(pbtn.name).begins_with("Proto_"):
				var pid: String = str(pbtn.name).trim_prefix("Proto_")
				pbtn.pressed.connect(func() -> void:
					_proto = pid
					_send_protocol()
				)

func _cmd_train(id: String) -> void:
	_train = id
	_send_train()

func _cmd_building(id: String) -> void:
	if side != null and side.sell_armed:
		_sell = id
		_send_sell()
		return
	if side != null and side.repair_armed:
		_sell = id
		_send_repair()
		return
	_build = id
	_send_build()

func fire_ability() -> bool:
	_send_ability()
	return true

func _say(text: String) -> void:
	if _status != null:
		_status.text = text

func _process(delta: float) -> void:
	if _cam != null and not hud.blocks_edge():
		var vp: Viewport = get_viewport()
		if vp != null:
			_cam.edge_scroll(vp.get_mouse_position(), vp.get_visible_rect().size, delta)
	var seat: Seat = Lan.seat()
	Lan.pump()
	Lan.pulse(delta)
	var raw: String = Lan.take()
	while raw != "":
		var kind: String = seat.ingest(raw)
		if kind == "state":
			_apply(raw)
		raw = Lan.take()
	Lan.watch(delta)
	field.tick(delta)
	sight.advance_weather(delta)
	World.sync(self, sight, _cam)
	hud.refresh()
	if seat.winner == "guest":
		if not outcome.over:
			outcome.finish(true, "The other player left the match.")
		_status.text = "The other player left the match. Opponent left. Victory."
		hud.show_line("The other player left the match.")
	elif seat.winner == "host":
		if not outcome.over:
			outcome.finish(false, "The other player left the match.")
		_status.text = "The other player left the match. Opponent left. Defeat."
		hud.show_line("The other player left the match.")
	elif seat.paused:
		_status.text = "Paused. Waiting for the other player."

func _apply(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var row: Dictionary = parsed
	if str(row.get("k", "")) != "state":
		return
	if bool(row.get("full", false)):
		_train = str(row.get("train", _train))
		_build = str(row.get("build", _build))
		_sell = str(row.get("sell", _sell))
		_proto = str(row.get("proto", _proto))
		var home: Variant = row.get("home", [])
		if typeof(home) == TYPE_ARRAY and (home as Array).size() >= 2:
			var pair: Array = home
			_home = Vector3(float(pair[0]), 0.0, float(pair[1]))
			if side != null and side.yard != null:
				side.yard.center = _home
		var fog: Variant = row.get("fog", "")
		if typeof(fog) == TYPE_STRING and str(fog) != "":
			_fog = str(fog).to_ascii_buffer()
			for i: int in _fog.size():
				_fog[i] = maxi(0, int(_fog[i]) - 48)
	_merge_fog(row)
	_sync_sight()
	var gone: Variant = row.get("gone", [])
	if typeof(gone) == TYPE_ARRAY:
		for item: Variant in gone:
			_drop_dot(int(item))
	var units: Variant = row.get("u", [])
	if typeof(units) == TYPE_ARRAY:
		for item_u: Variant in units:
			if typeof(item_u) != TYPE_ARRAY:
				continue
			var bits: Array = item_u
			if bits.size() < 6:
				continue
			_move_dot(int(bits[0]), float(bits[1]), float(bits[2]), float(bits[3]), int(bits[4]), str(bits[5]))
	_sync_blocks(row.get("b", []))
	if row.has("credits"):
		var bank: int = int(row.get("credits", 0))
		if roster != null and roster.economy != null:
			roster.economy.set_credits(0, bank)
		var names: String = ""
		var q: Variant = row.get("q", [])
		if typeof(q) == TYPE_ARRAY and not (q as Array).is_empty():
			names = "    " + str((q as Array)[0])
		if _purse != null:
			_purse.text = "Credits %d    Power %d/%d%s" % [bank, int(row.get("gen", 0)), int(row.get("use", 0)), names]
	if _status != null and str(row.get("winner", "")) == "" and not bool(row.get("pause", false)):
		_status.text = "Linked. %d units." % int(row.get("n", 0))
	if _cam != null and _home != Vector3.ZERO and not _home_focused:
		_home_focused = true
		_cam.focus = _home
		_cam.apply()

func _sync_sight() -> void:
	if sight == null or grid == null or _fog.size() != grid.cols * grid.rows:
		return
	sight.begin()
	for i: int in _fog.size():
		var st: int = int(_fog[i])
		if st >= SMSight.DIM:
			sight.explored[i] = 1
		if st == SMSight.CLEAR:
			var cx: int = i % grid.cols
			var cy: int = int(i / grid.cols)
			sight.add_seer(grid.cell_center(Vector2i(cx, cy)), grid.cell_size * 0.75)

func _send_train() -> void:
	if _train != "":
		Lan.send({"k": "cmd", "op": "train", "id": _train})

func _send_build() -> void:
	if _build != "":
		Lan.send({"k": "cmd", "op": "build", "id": _build})

func _send_place() -> void:
	if _build != "":
		Lan.send({"k": "cmd", "op": "place", "id": _build, "x": _home.x, "z": _home.z})

func _send_sell() -> void:
	if _sell != "":
		Lan.send({"k": "cmd", "op": "sell", "id": _sell})

func _send_repair() -> void:
	if _sell != "":
		Lan.send({"k": "cmd", "op": "repair", "id": _sell})

func _send_ability() -> void:
	var aim: Vector3 = _home + Vector3(4.0, 0.0, 0.0)
	if _cam != null and get_viewport() != null:
		var ground: Vector3 = _cam.ground_at(get_viewport().get_mouse_position())
		if ground != Vector3.INF:
			aim = ground
	Lan.send({"k": "cmd", "op": "ability", "ids": _picked_or_own(), "x": aim.x, "z": aim.z})

func _send_protocol() -> void:
	Lan.send({"k": "cmd", "op": "protocol", "id": _proto})

func _picked_or_own() -> Array:
	var ids: Array = []
	if field != null and field.selection.count() > 0:
		for u: RTSUnit in field.selection.units:
			if is_instance_valid(u) and u.has_meta("host_uid"):
				ids.append(int(u.get_meta("host_uid")))
		if not ids.is_empty():
			return ids
	if not _picked.is_empty():
		for uid: int in _picked:
			ids.append(uid)
		return ids
	for key: Variant in _dots.keys():
		var dot: RTSUnit = _dots[key] as RTSUnit
		if dot != null and is_instance_valid(dot) and dot.team == SMPointer.PLAYER:
			ids.append(int(key))
	if ids.is_empty():
		for key_any: Variant in _dots.keys():
			ids.append(int(key_any))
	return ids

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F:
		_send_ability()
		return
	if _cam == null:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			field.handle_button(mb)
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var ground: Vector3 = _cam.ground_at(mb.position)
			if ground == Vector3.INF:
				return
			var ids: Array = _picked_or_own()
			if ids.is_empty():
				return
			var foe: RTSUnit = field.enemy_near(mb.position, ground, Callable(field, "project_point"))
			if foe != null and foe.has_meta("host_uid"):
				Lan.send({"k": "cmd", "op": "attack", "ids": ids, "tid": int(foe.get_meta("host_uid"))})
				field._mark(foe.global_position, "attack")
				return
			Lan.send({"k": "cmd", "op": "move", "ids": ids, "x": ground.x, "z": ground.z})
			field._mark(ground, "move")
			return
		if hud.column_hovered() and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam.zoom_toward(1.0, _cam.ground_at(mb.position))
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.zoom_toward(-1.0, _cam.ground_at(mb.position))
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	field.handle_motion(motion)
	if (motion.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		_cam.orbit(motion.relative.x * 0.25)

func _move_dot(uid: int, x: float, z: float, hp: float, host_team: int, kind: String = "militia") -> void:
	var local_team: int = SMPointer.PLAYER if host_team == SMPointer.ENEMY else SMPointer.ENEMY
	var resolved_kind: String = kind if kind != "" else "militia"
	if resolved_kind == "raider" or resolved_kind == "wave":
		var side_fac: String = field.faction_id if local_team == SMPointer.PLAYER else (Lan.seat().faction if Lan.seat().faction != "" else "gtfc")
		resolved_kind = Models.fallback_unit("infantry", "ground", side_fac)
	var unit_kind: StringName = StringName(resolved_kind)
	var u: RTSUnit = _dots.get(uid, null) as RTSUnit
	var target: Vector3 = Vector3(x, 0.0, z)
	if u == null or not is_instance_valid(u):
		if local_team != SMPointer.PLAYER:
			field.next_look = Lan.seat().faction if Lan.seat().faction != "" else "gtfc"
		u = field.spawn(local_team, target, unit_kind, false)
		u.set_meta("host_uid", uid)
		_dots[uid] = u
		if local_team == SMPointer.PLAYER and field.selection.count() == 0:
			field.select_only([u])
	else:
		u.team = local_team
		if u.global_position.distance_to(target) > 0.25 and u.global_position.distance_to(target) < 28.0:
			u.set_path(PackedVector3Array([target]))
		else:
			u.global_position = target
			u.path = PackedVector3Array()
	if hp > 0.0:
		if hp > u.max_hp:
			u.max_hp = hp
		u.hp = hp
		u.set_meta("seen_hp", hp)

func _drop_dot(uid: int) -> void:
	var u: RTSUnit = _dots.get(uid, null) as RTSUnit
	if u != null and is_instance_valid(u):
		field.selection.units.erase(u)
		field.units.erase(u)
		u.queue_free()
	_dots.erase(uid)

func _clear_dots() -> void:
	for key: Variant in _dots.keys():
		var u: RTSUnit = _dots[key] as RTSUnit
		if u != null and is_instance_valid(u):
			field.selection.units.erase(u)
			field.units.erase(u)
			u.queue_free()
	_dots.clear()

func _sync_blocks(raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	var rows: Array = raw
	var seen: Dictionary = {}
	if side != null and side.yard != null:
		side.yard.finished.clear()
		side.yard.structure_pos.clear()
		side.yard.structure_hp.clear()
	for item: Variant in rows:
		if typeof(item) != TYPE_ARRAY:
			continue
		var bits: Array = item
		if bits.size() < 5:
			continue
		var id: String = str(bits[0])
		var bx: float = float(bits[1])
		var bz: float = float(bits[2])
		var bhp: float = float(bits[3])
		var host_team: int = int(bits[4])
		var key: String = "%d_%s" % [host_team, id]
		seen[key] = true
		var own: bool = host_team == SMPointer.ENEMY
		var at: Vector3 = Vector3(bx, 0.0, bz)
		if own and side != null and side.yard != null:
			var idn: StringName = StringName(id)
			if not side.yard.finished.has(idn):
				side.yard.finished.append(idn)
			side.yard.structure_pos[idn] = at
			side.yard.structure_hp[idn] = maxf(1.0, bhp)
			if not side.yard.structure_max.has(idn):
				side.yard.structure_max[idn] = maxf(200.0, bhp)
		var block: MeshInstance3D = _blocks.get(key, null) as MeshInstance3D
		if block == null or not is_instance_valid(block):
			var node_name: String = "Built_%s" % id if own else "FoeBuilt_%s" % id
			var saved_front: String = SMFront.faction_id
			if not own:
				SMFront.faction_id = Lan.seat().faction if Lan.seat().faction != "" else "gtfc"
			var color: Color = SMFront.primary() if own else Color(0.55, 0.16, 0.18)
			block = World.slab(self, node_name, SMPointer.building_at(at), SMPointer.BUILDING_SIZE, color)
			SMFront.faction_id = saved_front
			_blocks[key] = block
		else:
			block.position = SMPointer.building_at(at)
	var drop: Array = []
	for key_old: Variant in _blocks.keys():
		if not seen.has(key_old):
			drop.append(key_old)
	for key_drop: Variant in drop:
		var old: MeshInstance3D = _blocks[key_drop] as MeshInstance3D
		if old != null and is_instance_valid(old):
			old.queue_free()
		_blocks.erase(key_drop)

func _merge_fog(row: Dictionary) -> void:
	var fi: Variant = row.get("fi", [])
	var fv: Variant = row.get("fv", [])
	if typeof(fi) != TYPE_ARRAY or typeof(fv) != TYPE_ARRAY:
		return
	var idx: Array = fi
	var vals: Array = fv
	var n: int = mini(idx.size(), vals.size())
	for i: int in n:
		var at: int = int(idx[i])
		if at >= 0 and at < _fog.size():
			_fog[at] = int(vals[i])
