extends RefCounted
## Subscribes match scenes to sim signals. The SM scripts do not preload this.

const World = preload("res://game/world_view.gd")
const Forms = preload("res://game/unit_meshes.gd")
const Models = preload("res://game/model_registry.gd")
const FX = preload("res://game/fx_view.gd")
const SettingsPanel = preload("res://game/settings_panel.gd")
const Settings = preload("res://game/match_settings.gd")
const Clips = preload("res://game/match_audio.gd")
const Cameos = preload("res://game/match_cameos.gd")
const Faces = preload("res://game/font_faces.gd")
const Motion = preload("res://game/unit_motion.gd")
const Watch = preload("res://game/building_watch.gd")

## Pins the objective to one line under the top bar, clear of the left rail.
static func seat_status(status: Control) -> void:
	if status == null:
		return
	status.anchor_left = 0.0
	status.anchor_top = 0.0
	status.anchor_right = 0.0
	status.anchor_bottom = 0.0
	status.offset_left = 100.0
	status.offset_top = 36.0
	status.offset_right = 424.0
	status.offset_bottom = 62.0
	status.custom_minimum_size = Vector2(0, 22)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.clip_text = true
	status.max_lines_visible = 1
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func follow(host: Node) -> void:
	if host == null or bool(host.get_meta("view_bound", false)):
		return
	host.set_meta("view_bound", true)
	Faces.pin()
	Models.look_faction = ""
	Models.warm(host)
	var field: SMPointer = host.get("field") as SMPointer
	if field != null:
		follow_pointer(field)
		if not field.ally_lost.is_connected(_announce):
			field.ally_lost.connect(_announce.bind(host, "unit_lost"))
	var sim: SMMatch = host.get("sim") as SMMatch
	if sim != null:
		_follow_match(sim)
		if sim.tech != null and not bool(sim.tech.get_meta("view_bound", false)):
			sim.tech.set_meta("view_bound", true)
			sim.tech.site_captured.connect(_on_capture.bind(host))
	var side: SMSide = host.get("side") as SMSide
	if field != null and side != null:
		field.side_link = side
	if side != null and not bool(side.get_meta("view_bound", false)):
		side.set_meta("view_bound", true)
		side.slab_made.connect(Callable(World, "slab"))
		side.line_voiced.connect(_on_side_line.bind(host, side))
		side.super_launched.connect(_announce.bind(host, "superweapon_launched"))
		if not side.defense_fired.is_connected(_on_defense):
			side.defense_fired.connect(_on_defense.bind(host))
		_bind_yard(host, side.yard, false)
	var raider: SMRaider = host.get("raider") as SMRaider
	if raider != null and not bool(raider.get_meta("view_bound", false)):
		raider.set_meta("view_bound", true)
		raider.marker_made.connect(Callable(World, "slab"))
		raider.banner_made.connect(Callable(World, "billboard"))
		_bind_yard(host, raider.yard, true)
	var story: SMStory = host.get("story") as SMStory
	if story != null and not bool(story.get_meta("view_bound", false)):
		story.set_meta("view_bound", true)
		story.pad_made.connect(Callable(World, "plain_slab"))
	var sight: SMSight = host.get("sight") as SMSight
	if sight != null and not bool(sight.get_meta("view_bound", false)):
		sight.set_meta("view_bound", true)
		sight.match_drawn.connect(Callable(World, "sync"))
	var hud: SMHud = host.get("hud") as SMHud
	if hud != null and not bool(hud.get_meta("view_bound", false)):
		hud.set_meta("view_bound", true)
		hud.chrome = Callable(preload("res://game/match_hud_view.gd"), "install")
		hud.layer_mounted.connect(_on_layer)
		hud.line_voiced.connect(_on_hud_line.bind(host, hud))
	var outcome: SMOutcome = host.get("outcome") as SMOutcome
	if outcome != null and not bool(outcome.get_meta("view_bound", false)):
		outcome.set_meta("view_bound", true)
		outcome.chrome_wanted.connect(_on_chrome)
		outcome.base_struck.connect(_announce.bind(host, "base_under_attack"))
	Clips.arm(host, "match")
	if preload("res://game/lan_link.gd").active_host():
		var guest_raider: SMRaider = host.get("raider") as SMRaider
		if guest_raider != null:
			guest_raider.human = true
	if preload("res://game/lan_link.gd").active_host() and host.get_node_or_null("LanRelay") == null:
		var relay: Node = Node.new()
		relay.name = "LanRelay"
		relay.set_script(preload("res://game/lan_relay.gd"))
		host.add_child(relay)
	if host.get_node_or_null("CameraFit") == null:
		var fitter: Node = Node.new()
		fitter.name = "CameraFit"
		fitter.set_script(preload("res://game/camera_fit.gd"))
		host.add_child(fitter)
	if host.get_node_or_null("MatchExit") == null:
		var exit: Node = Node.new()
		exit.name = "MatchExit"
		exit.set_script(preload("res://game/match_exit.gd"))
		host.add_child(exit)
	if host.get_node_or_null("MatchCoach") == null:
		var coach: Node = Node.new()
		coach.name = "MatchCoach"
		coach.set_script(preload("res://game/match_coach.gd"))
		host.add_child(coach)

static func follow_pointer(field: SMPointer) -> void:
	if field == null or bool(field.get_meta("view_bound", false)):
		return
	field.set_meta("view_bound", true)
	field.dressed.connect(Callable(FX, "dress"))
	field.unit_made.connect(_on_unit.bind(field))
	field.unit_posed.connect(Callable(Forms, "animate"))
	field.status_shown.connect(_on_status)
	field.beacon_moved.connect(Callable(World, "place_beacon"))
	field.rally_moved.connect(Callable(World, "place_rally"))
	field.wreck_made.connect(_on_wreck.bind(field))
	field.ping_made.connect(_on_ping.bind(field))
	field.path_moved.connect(Callable(World, "path_mark"))
	field.damage_shown.connect(Callable(World, "damage_pop"))
	field.damage_shown.connect(_on_damage.bind(field))

static func _follow_match(sim: SMMatch) -> void:
	if bool(sim.get_meta("view_bound", false)):
		return
	sim.set_meta("view_bound", true)
	sim.site_made.connect(Callable(World, "place_site"))
	sim.plate_sunk.connect(Callable(World, "sink_named"))
	sim.deck_fit.connect(Callable(World, "fit_deck"))

static func _on_unit(u: RTSUnit, team: int, kind: String, role: String, loco: String, tint: Color, label: String, field: SMPointer) -> void:
	var primary: Color = tint
	var trim: Color = tint
	if team == SMPointer.PLAYER:
		primary = field.primary_color
		trim = field.accent_color
	var paint: String = field.faction_id
	if team != SMPointer.PLAYER:
		paint = Models.enemy_look(field.faction_id)
	var marked: String = str(u.get_meta("look", ""))
	if marked != "":
		paint = marked
	var body: MeshInstance3D = Forms.dress_unit(kind, role, loco, tint, primary, trim, paint)
	u.add_child(body)
	Motion.attach(u, body)
	World.dress_spawn(u, team, label)
	field.visual_node = body
	if not u.fired.is_connected(_on_fired):
		u.fired.connect(_on_fired.bind(field))
	if not u.died.is_connected(_on_died):
		u.died.connect(_on_died.bind(field))
	if team == SMPointer.PLAYER:
		Clips.on_spawn(field.host, u)

static func _on_died(unit: RTSUnit, field: SMPointer) -> void:
	if field == null or field.host == null:
		return
	Clips.on_death(field.host, unit)

static func _on_defense(building_id: StringName, at: Vector3, host: Node) -> void:
	Clips.on_defense(host, str(building_id), at)

static func _on_fired(unit: RTSUnit, target: RTSUnit, field: SMPointer) -> void:
	if field == null or field.host == null:
		return
	var kind: String = Clips.weapon_kind(str(unit.get_meta("weapon", "")))
	if kind != "" and Clips.cue_clip(kind) != null:
		Clips.on_shot(field.host, unit, target)
	elif field.on_cue.is_valid():
		field.on_cue.call("attack")

static func _on_damage(unit: RTSUnit, amount: float, field: SMPointer) -> void:
	if field == null or field.host == null:
		return
	Clips.on_hit(field.host, unit, amount)

static func play_selected_ability(host: Node) -> void:
	if host == null:
		return
	var field: SMPointer = host.get("field") as SMPointer
	var label: String = ""
	if field != null and field.selection.count() > 0:
		var unit: RTSUnit = field.selection.units[0]
		if is_instance_valid(unit):
			label = str(unit.get_meta("ability", ""))
	Clips.play_kind(host, Clips.ability_kind(label))

static func _cue_stream(kind: String, hud: SMHud) -> AudioStream:
	var resolved: String = kind
	if kind == "ability_cast":
		resolved = _ability_cue(hud)
	return Clips.cue_clip(resolved)

static func _ability_cue(hud: SMHud) -> String:
	if hud == null or hud.field == null or hud.field.selection.count() <= 0:
		return "ability_generic"
	var unit: RTSUnit = hud.field.selection.units[0]
	if not is_instance_valid(unit):
		return "ability_generic"
	return Clips.ability_kind(str(unit.get_meta("ability", "")))

static func _on_status(body: MeshInstance3D, frozen: bool) -> void:
	if body == null:
		return
	var mat: Material = null
	if frozen:
		mat = FX.ice_material()
	Forms.paint_status(body, mat)

static func _on_wreck(host: Node3D, at: Vector3, field: SMPointer) -> void:
	field.visual_node = World.wreck(host, at)

static func _on_ping(host: Node3D, at: Vector3, order: String, field: SMPointer) -> void:
	field.visual_node = World.order_ping(host, at, order)

static func _on_layer(who: SMHud, layer: CanvasLayer) -> void:
	SettingsPanel.attach(layer)
	if who == null:
		return
	who.cameo_for = Callable(Cameos, "texture")
	who.apply_cameos()
	Cameos.arm(layer, who)
	if who.sfx == null:
		return
	who.sfx.cue_level = Callable(Settings, "cue_db")
	who.sfx.clip_for = Callable(Clips, "clip_for")
	who.sfx.cue_for = _cue_stream.bind(who)
	Clips.color_voice(who.sfx)
	who.sfx.apply_levels()

static func _bind_yard(host: Node, yard: SMBuildYard, enemy: bool) -> void:
	if yard == null or bool(yard.get_meta("view_bound", false)):
		return
	yard.set_meta("view_bound", true)
	Watch.watch(host as Node3D, yard)
	if enemy:
		yard.super_ready.connect(_announce.bind(host, "enemy_superweapon_detected"))
		yard.super_fired.connect(_announce.bind(host, "enemy_superweapon_detected"))
	else:
		yard.super_ready.connect(_announce.bind(host, "superweapon_ready"))

static func _announce(host: Node, key: String) -> void:
	Clips.on_super(host, key)
	Clips.announce_key(host, _faction_of(host), key)

static func _on_capture(team: int, host: Node) -> void:
	if team == SMPointer.PLAYER:
		_announce(host, "building_captured")

static func _on_hud_line(text: String, key: String, host: Node, hud: SMHud) -> void:
	Clips.on_line(host, text)
	var faction: String = hud._faction_id() if hud != null else _faction_of(host)
	if key != "":
		Clips.announce_key(host, faction, key)
	else:
		Clips.announce_line(host, faction, text)

static func _on_side_line(text: String, host: Node, side: SMSide) -> void:
	Clips.on_line(host, text)
	var faction: String = side.faction_id if side != null else _faction_of(host)
	Clips.announce_line(host, faction, text)

static func _faction_of(host: Node) -> String:
	if host == null:
		return "gtfc"
	var field: SMPointer = host.get("field") as SMPointer
	if field != null and str(field.get("faction_id")) != "":
		return str(field.get("faction_id"))
	var side: SMSide = host.get("side") as SMSide
	if side != null and side.faction_id != "":
		return side.faction_id
	return SMFront.current()

static func _on_chrome(outcome: SMOutcome, panel: Control, faction: String) -> void:
	if outcome == null or panel == null:
		return
	var art: Control = (load("res://game/menu_backdrop.gd") as GDScript).new() as Control
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.call("set_screen", "faction")
	art.call("set_faction", faction)
	panel.add_child(art)
	panel.move_child(art, 0)
	var back: Button = (load("res://game/menu_plate.gd") as GDScript).new() as Button
	back.name = "BootMenuButton"
	back.text = "Boot menu"
	back.anchor_left = 0.0
	back.anchor_top = 0.5
	back.anchor_right = 0.0
	back.anchor_bottom = 0.5
	back.offset_left = 64.0
	back.offset_top = 56.0
	back.offset_right = 360.0
	back.offset_bottom = 108.0
	back.custom_minimum_size = Vector2(320, 52)
	back.pressed.connect(_boot.bind(outcome))
	panel.add_child(back)
	outcome.back = back
	var layer: Node = panel.get_parent()
	if layer != null:
		var boot_chip: CanvasItem = layer.find_child("MissionBoot", true, false) as CanvasItem
		if boot_chip != null and panel.visible:
			boot_chip.visible = false

static func _boot(outcome: SMOutcome) -> void:
	preload("res://game/boot.gd").mark_training_seen()
	preload("res://game/lan_link.gd").close()
	if outcome == null or outcome.host == null:
		return
	outcome.host.get_tree().change_scene_to_file("res://game/boot.tscn")
