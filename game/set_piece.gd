extends Node
## Scripted opener for a story mission.
## Most beats are presentation. The jade wagon, the hack hold, the mine line,
## the spray run, the ferry crossing, and the superweapon count are rules.
## Each mission keeps its own order. At most two of the shared beats
## (ambush, bridge, relief, weather) are on a mission, plus the side cache.
## A hero line plays from dialogue/<language>/<mission>/<beat>.ogg
## when that take passes. English falls back to the mission region.
## The subtitle stays on screen either way.

const Clips = preload("res://game/match_audio.gd")
const Cameos = preload("res://game/match_cameos.gd")

var mission_id: String = ""
var stage: int = 0
var line_text: String = ""
var intro_done: bool = false
var outro_started: bool = false
var outro_done: bool = false
var bridge_down: bool = false
var betrayed: bool = false
var ambush_spawned: bool = false
var reinforced: bool = false
var weather_turned: bool = false
var bonus_done: bool = false
var has_bonus: bool = false
var finale_done: bool = false
var bonus_at: Vector3 = Vector3(12.0, 0.0, -8.0)
var home_focus: Vector3 = Vector3.ZERO
var home_distance: float = 18.0
var wide_distance: float = 42.0
var faction: String = "gtfc"
var cameo_id: String = "militia"
var speaker_name: String = "Night commander"
var last_voiced: bool = false
var beat_ids: PackedStringArray = PackedStringArray()
var beat_at: PackedFloat32Array = PackedFloat32Array()
var fired: PackedStringArray = PackedStringArray()
var _voiced_beat: String = ""
var hack_end: float = -1.0
var count_end: float = -1.0

var _host: Node3D
var _clock: float = 0.0
var _armed: bool = false
var _outro_t: float = 0.0
var _outro_from: float = 18.0
var _intro_from: Vector3 = Vector3.ZERO
var _intro_to: Vector3 = Vector3.ZERO
var _plate: ColorRect
var _portrait: TextureRect
var _speaker: Label
var _subtitle: Label
var _bonus: Label
var _hack: Label
var _count: Label
var _bridge: MeshInstance3D

static func attach(host: Node3D, id: String) -> void:
	if host == null:
		return
	if not _covered(id):
		return
	if host.get_node_or_null("SetPiece") != null:
		return
	var piece: Node = Node.new()
	piece.name = "SetPiece"
	piece.set_script(load("res://game/set_piece.gd") as GDScript)
	host.add_child(piece)
	piece.call("open", host, id)

func open(host: Node3D, id: String) -> void:
	_host = host
	mission_id = id
	_cast()
	_arm_plan()
	_chrome()
	if beat_ids.has("bridge"):
		_span()
	_say(_line("open"), "", "open")

func drive(delta: float) -> void:
	if _host == null:
		return
	_clock += maxf(delta, 0.0)
	_sync_portrait()
	_retry_voice()
	if not _armed:
		_arm_camera()
	var story: SMStory = _host.get("story") as SMStory
	if story != null and (story.done or story.lost):
		_outro(delta)
		return
	_intro()
	for i: int in beat_ids.size():
		var beat: String = beat_ids[i]
		if _clock >= beat_at[i] and not fired.has(beat):
			_fire(beat)
	_clocks()
	_bonus_check()
	_press_patani()
	stage = 1 + fired.size()

static func _covered(id: String) -> bool:
	return id == "kokang" or id == "tachileik" or id == "shwe_kokko" or id == "operation_1027" or id == "andaman" or id == "ghosts_of_patani" or id == "kilometer_watch" or id == "black_haze" or id == "archipelago_rising" or id == "wrath_of_the_garuda" or id == "fog_over_pakbeng" or id == "keng_tung" or id == "plain_of_jars" or id == "tonle_sap" or id == "shattered_monsoon"

func _cast() -> void:
	faction = "gtfc"
	cameo_id = "militia"
	speaker_name = "Night commander"
	bonus_at = Vector3(12.0, 0.0, -8.0)
	if mission_id == "tachileik":
		cameo_id = "slag_hauler"
		speaker_name = "Caravan master"
		bonus_at = Vector3(-16.0, 0.0, 8.0)
	elif mission_id == "shwe_kokko":
		cameo_id = "bullion_truck"
		speaker_name = "Compound runner"
		bonus_at = Vector3(16.0, 0.0, -10.0)
	elif mission_id == "operation_1027":
		cameo_id = "orlan10"
		speaker_name = "Strip lead"
		bonus_at = Vector3(-16.0, 0.0, 10.0)
	elif mission_id == "andaman":
		cameo_id = "channel_skiff"
		speaker_name = "Beach master"
		bonus_at = Vector3(-16.0, 0.0, 8.0)
	elif mission_id == "ghosts_of_patani":
		faction = "nmrf"
		cameo_id = "river_rifle"
		speaker_name = "River commander"
		bonus_at = Vector3(-14.0, 0.0, 8.0)
	elif mission_id == "kilometer_watch":
		faction = "nmrf"
		cameo_id = "olive_ranger"
		speaker_name = "Watch captain"
		bonus_at = Vector3(-16.0, 0.0, 10.0)
	elif mission_id == "black_haze":
		faction = "nmrf"
		cameo_id = "mangrove_skiff"
		speaker_name = "Haze coxswain"
		bonus_at = Vector3(16.0, 0.0, 10.0)
	elif mission_id == "archipelago_rising":
		faction = "nmrf"
		cameo_id = "packer"
		speaker_name = "Packer captain"
		bonus_at = Vector3(-18.0, 0.0, -10.0)
	elif mission_id == "wrath_of_the_garuda":
		faction = "nmrf"
		cameo_id = "emerald_gunboat"
		speaker_name = "Fleet captain"
		bonus_at = Vector3(18.0, 0.0, 8.0)
	elif mission_id == "fog_over_pakbeng":
		faction = "mvd"
		cameo_id = "clearance_trooper"
		speaker_name = "Clearance commander"
		bonus_at = Vector3(-14.0, 0.0, 8.0)
	elif mission_id == "keng_tung":
		faction = "mvd"
		cameo_id = "charcoal_mortar"
		speaker_name = "Defoliation lead"
		bonus_at = Vector3(-16.0, 0.0, 12.0)
	elif mission_id == "plain_of_jars":
		faction = "mvd"
		cameo_id = "spectrum_prism"
		speaker_name = "Beam officer"
		bonus_at = Vector3(16.0, 0.0, -12.0)
	elif mission_id == "tonle_sap":
		faction = "mvd"
		cameo_id = "cyan_skiff"
		speaker_name = "Ferry warden"
		bonus_at = Vector3(-18.0, 0.0, 6.0)
	elif mission_id == "shattered_monsoon":
		faction = "mvd"
		cameo_id = "hub_drone"
		speaker_name = "Citadel officer"
		bonus_at = Vector3(18.0, 0.0, -8.0)

func _plan(id: String, at: float) -> void:
	beat_ids.append(id)
	beat_at.append(at)

func _arm_plan() -> void:
	has_bonus = false
	if mission_id == "kokang":
		has_bonus = true
		_plan("weather", 6.0)
		_plan("orlans", 14.0)
		_plan("night_shift", 22.0)
	elif mission_id == "tachileik":
		has_bonus = true
		_plan("escort", 5.0)
		_plan("drones", 13.0)
		_plan("ambush", 21.0)
	elif mission_id == "shwe_kokko":
		has_bonus = true
		_plan("hack", 4.0)
		_plan("ambush", 12.0)
		_plan("siphon", 20.0)
	elif mission_id == "operation_1027":
		_plan("scramble", 6.0)
		_plan("swarm", 14.0)
		_plan("relief", 22.0)
	elif mission_id == "andaman":
		has_bonus = true
		_plan("mines", 5.0)
		_plan("landing", 15.0)
		_plan("weather", 23.0)
	elif mission_id == "ghosts_of_patani":
		has_bonus = true
		_plan("blackout", 5.0)
		_plan("ghosts", 14.0)
		_plan("bridge", 22.0)
	elif mission_id == "kilometer_watch":
		_plan("ping", 5.0)
		_plan("relief", 13.0)
		_plan("bridge", 21.0)
	elif mission_id == "black_haze":
		_plan("haze", 6.0)
		_plan("second_wave", 15.0)
		_plan("hold", 23.0)
	elif mission_id == "archipelago_rising":
		_plan("packer", 6.0)
		_plan("wharf", 14.0)
		_plan("weather", 22.0)
	elif mission_id == "wrath_of_the_garuda":
		_plan("napalm", 5.0)
		_plan("pickets", 13.0)
		_plan("relief", 21.0)
	elif mission_id == "fog_over_pakbeng":
		has_bonus = true
		_plan("bridge", 5.0)
		_plan("haze", 13.0)
		_plan("radar", 21.0)
	elif mission_id == "keng_tung":
		has_bonus = true
		_plan("screen", 5.0)
		_plan("spray", 12.0)
		_plan("intercept", 20.0)
	elif mission_id == "plain_of_jars":
		_plan("beam", 6.0)
		_plan("freeze", 14.0)
		_plan("batteries", 22.0)
	elif mission_id == "tonle_sap":
		_plan("crossing", 5.0)
		_plan("under_fire", 13.0)
		_plan("weather", 21.0)
	elif mission_id == "shattered_monsoon":
		_plan("garrison", 4.0)
		_plan("countdown", 11.0)
		_plan("finale", 22.0)

func _line(beat: String) -> String:
	var key: String = "%s:%s" % [mission_id, beat]
	match key:
		"kokang:open":
			return "Raise the yard before the Orlans find the pits."
		"kokang:weather":
			return "Rain on the pits. Keep the company moving."
		"kokang:orlans":
			return "Orlans over the ruby pits. They have not marked the yard."
		"kokang:night_shift":
			return "The night shift is on the road. Bring one stock home."
		"tachileik:open":
			return "The jade wagon is on the road. Walk it through."
		"tachileik:escort":
			return "Stay with the wagon. The bazaar is the drop."
		"tachileik:drones":
			return "Drones on the jade wagon. Keep it under the trees."
		"tachileik:ambush":
			return "Contact behind the wagon."
		"shwe_kokko:open":
			return "Both server blocks are live. Start the hack."
		"shwe_kokko:hack":
			return "The hack is running. Twenty seconds on the blocks."
		"shwe_kokko:ambush":
			return "Garrison in the trees."
		"shwe_kokko:siphon":
			return "Siphon is up. Stay on the blocks until it pays."
		"operation_1027:open":
			return "The jammers are up. The hangars are still parked."
		"operation_1027:scramble":
			return "The strip scrambles. The Su-30 and the CH-4 are still on the ground."
		"operation_1027:swarm":
			return "The swarm is in the air. It does not finish the towers."
		"operation_1027:relief":
			return "Two rifles for the strip."
		"andaman:open":
			return "The channel is mined. Break out and land the far shore."
		"andaman:mines":
			return "Mines in the cut. Take the boats wide of the line."
		"andaman:landing":
			return "The far shore is open. Put a boat on it."
		"andaman:weather":
			return "The squall is on. Cross while it lasts."
		"ghosts_of_patani:open":
			return "The jammer is live. Fiber holds. GPS does not."
		"ghosts_of_patani:blackout":
			return "GPS drops in the mist. Fiber shots still land."
		"ghosts_of_patani:ghosts":
			return "Ghosts in the jammer. Every one of them has to fall."
		"ghosts_of_patani:bridge":
			return "The guide turns on us. The span is down."
		"kilometer_watch:open":
			return "The hydro radar is dark. Light the water."
		"kilometer_watch:ping":
			return "The radar pings. Water shows along the road."
		"kilometer_watch:relief":
			return "Two rifles from the watch are in."
		"kilometer_watch:bridge":
			return "The span is cut. The guide has sold the watch."
		"black_haze:open":
			return "The haze is thick. Take the radar and stay on it."
		"black_haze:haze":
			return "The haze closes over the radar. Do not walk off it."
		"black_haze:second_wave":
			return "A second wave is in the black haze."
		"black_haze:hold":
			return "Hold the radar. The haze is the clock."
		"archipelago_rising:open":
			return "The atoll is held by boats. Sail the packer in."
		"archipelago_rising:packer":
			return "The packer is in the shallows. Unpack it."
		"archipelago_rising:wharf":
			return "The wharf is up. Take it to the second level."
		"archipelago_rising:weather":
			return "The squall is on the shallows. Finish the wharf."
		"wrath_of_the_garuda:open":
			return "The joint fleet is in the channel. Sink it."
		"wrath_of_the_garuda:napalm":
			return "Napalm is armed. Calling it does not sink the fleet."
		"wrath_of_the_garuda:pickets":
			return "Pickets across the bow. They are not the fleet."
		"wrath_of_the_garuda:relief":
			return "Two gunboats from the river are in."
		"fog_over_pakbeng:open":
			return "The haze is the weapon. Hold the radar."
		"fog_over_pakbeng:bridge":
			return "An ally breaks. The span is down."
		"fog_over_pakbeng:haze":
			return "The haze has closed in. Do not leave the radar."
		"fog_over_pakbeng:radar":
			return "Stay on the radar until the murk thins."
		"keng_tung:open":
			return "The tank column is on the road. Freeze it, then break it."
		"keng_tung:screen":
			return "Infantry screen the tanks. They are not the column."
		"keng_tung:spray":
			return "A spray run is coming down the road. Cut it off."
		"keng_tung:intercept":
			return "Stop the sprayer before it reaches the tanks."
		"plain_of_jars:open":
			return "The phantom is on the plain. Hold the beam until it freezes."
		"plain_of_jars:beam":
			return "Keep the beam on the phantom. It is not frozen yet."
		"plain_of_jars:freeze":
			return "The phantom stutters in the beam. Do not let go."
		"plain_of_jars:batteries":
			return "Both batteries are still up, and the screen is with them."
		"tonle_sap:open":
			return "The ferry has to live. Hold it through the channel."
		"tonle_sap:crossing":
			return "The ferry is in the channel. Keep guns on the water."
		"tonle_sap:under_fire":
			return "Trimarans on the ferry. Hold the crossing."
		"tonle_sap:weather":
			return "The squall is on. Keep the ferry afloat."
		"shattered_monsoon:open":
			return "Both superweapons are live. Break the screen and drop them."
		"shattered_monsoon:garrison":
			return "The citadel garrison is out. They screen the weapons."
		"shattered_monsoon:countdown":
			return "Both weapons are armed. The count is running."
		"shattered_monsoon:finale":
			return "The monsoon breaks over the citadel. Drop both weapons."
	return ""

func _fire(beat: String) -> void:
	fired.append(beat)
	match beat:
		"ambush":
			_ambush()
		"bridge":
			_blow()
		"relief":
			_reinforce()
		"weather":
			_monsoon()
		"orlans":
			_quiet(SMPointer.ENEMY, Vector3(14.0, 0.0, 7.0), "spectacle", &"orlan10")
			_quiet(SMPointer.ENEMY, Vector3(12.0, 0.0, 9.0), "spectacle", &"orlan10")
			_say(_line(beat), "", beat)
		"night_shift":
			_quiet(SMPointer.PLAYER, Vector3(-2.0, 0.0, 6.0), "night", &"slag_hauler")
			_say(_line(beat), "", beat)
		"escort":
			var wagon: RTSUnit = _wagon()
			if wagon != null:
				wagon.set_meta("duty", "escort")
				wagon.set_meta("escorted", true)
				wagon.speed = 4.5
				if wagon.path.is_empty():
					wagon.set_path(PackedVector3Array([Vector3(-2.0, 0.0, -6.0)]))
			_say(_line(beat), "", beat)
		"drones":
			_quiet(SMPointer.ENEMY, Vector3(8.0, 0.0, 6.0), "spectacle", &"orlan10")
			_quiet(SMPointer.ENEMY, Vector3(6.0, 0.0, 8.0), "spectacle", &"orlan10")
			_say(_line(beat), "", beat)
		"hack":
			_hack = _timer("HackTimer", "Hack: 20s")
			hack_end = _clock + 20.0
			_say(_line(beat), "", beat)
		"siphon":
			_say(_line(beat), "", beat)
		"scramble":
			_quiet(SMPointer.ENEMY, Vector3(14.0, 0.0, 3.0), "spectacle", &"su30")
			_quiet(SMPointer.ENEMY, Vector3(14.0, 0.0, -3.0), "spectacle", &"ch4")
			_say(_line(beat), "", beat)
		"swarm":
			_quiet(SMPointer.ENEMY, Vector3(4.0, 0.0, 6.0), "spectacle", &"orlan10")
			_say(_line(beat), "", beat)
		"mines":
			_mines()
		"landing":
			_say(_line(beat), "", beat)
		"blackout":
			_say(_line(beat), "", beat)
		"ghosts":
			_quiet(SMPointer.ENEMY, Vector3(10.0, 0.0, 6.0), "ambush", &"militia")
			_quiet(SMPointer.ENEMY, Vector3(8.0, 0.0, 8.0), "ambush", &"militia")
			_say(_line(beat), "", beat)
		"ping":
			_marker("SetPing", Vector3(10.0, 1.6, -6.0), Vector3(0.35, 3.2, 0.35), Color(0.45, 0.75, 0.95), true)
			_say(_line(beat), "", beat)
		"haze":
			_haze()
		"second_wave":
			_quiet(SMPointer.ENEMY, Vector3(6.0, 0.0, 5.0), "spectacle", &"militia")
			_quiet(SMPointer.ENEMY, Vector3(4.0, 0.0, 7.0), "spectacle", &"militia")
			_say(_line(beat), "", beat)
		"hold":
			_say(_line(beat), "", beat)
		"packer":
			_quiet(SMPointer.PLAYER, Vector3(-14.0, 0.0, -6.0), "packer", &"sampan")
			_say(_line(beat), "", beat)
		"wharf":
			_marker("SetWharf", Vector3(8.0, 0.5, 5.0), Vector3(3.2, 0.4, 1.4), Color(0.35, 0.48, 0.42), false)
			_say(_line(beat), "", beat)
		"napalm":
			_marker("SetNapalm", Vector3(8.0, 2.4, 1.0), Vector3(8.0, 0.15, 0.6), Color(0.85, 0.28, 0.08), true)
			_say(_line(beat), "", beat)
		"pickets":
			_quiet(SMPointer.ENEMY, Vector3(11.0, 0.0, 6.0), "spectacle", &"channel_skiff")
			_quiet(SMPointer.ENEMY, Vector3(9.0, 0.0, 8.0), "spectacle", &"channel_skiff")
			_say(_line(beat), "", beat)
		"radar":
			_marker("SetRadar", Vector3(10.0, 1.6, -6.0), Vector3(0.4, 2.8, 0.4), Color(0.55, 0.78, 0.72), true)
			_say(_line(beat), "", beat)
		"screen":
			_quiet(SMPointer.ENEMY, Vector3(8.0, 0.0, 6.0), "spectacle", &"militia")
			_quiet(SMPointer.ENEMY, Vector3(7.0, 0.0, 4.0), "spectacle", &"militia")
			_say(_line(beat), "", beat)
		"spray":
			var sprayer: RTSUnit = _quiet(SMPointer.ENEMY, Vector3(16.0, 0.0, 10.0), "spray", &"monsoon_tube")
			if sprayer != null:
				sprayer.speed = 4.5
				sprayer.set_path(PackedVector3Array([Vector3(6.0, 0.0, 2.0)]))
			_say(_line(beat), "", beat)
		"intercept":
			_say(_line(beat), "", beat)
		"beam":
			_say(_line(beat), "", beat)
		"freeze":
			_marker("SetFrost", Vector3(6.0, 0.9, 3.0), Vector3(1.4, 1.8, 1.4), Color(0.7, 0.86, 0.92), false)
			_say(_line(beat), "", beat)
		"batteries":
			_say(_line(beat), "", beat)
		"crossing":
			_say(_line(beat), "", beat)
		"under_fire":
			_quiet(SMPointer.ENEMY, Vector3(11.0, 0.0, 7.0), "spectacle", &"sampan")
			_quiet(SMPointer.ENEMY, Vector3(9.0, 0.0, 8.0), "spectacle", &"sampan")
			_say(_line(beat), "", beat)
		"garrison":
			_quiet(SMPointer.ENEMY, Vector3(8.0, 0.0, 5.0), "spectacle", &"militia")
			_quiet(SMPointer.ENEMY, Vector3(7.0, 0.0, -4.0), "spectacle", &"militia")
			_say(_line(beat), "", beat)
		"countdown":
			_count = _timer("CountTimer", "Count: 16s")
			count_end = _clock + 16.0
			_say(_line(beat), "", beat)
		"finale":
			finale_done = true
			_say(_line(beat), "", beat)
		_:
			_say(_line(beat), "", beat)

func _chrome() -> void:
	var layer: CanvasLayer = _host.get("ui_layer") as CanvasLayer
	if layer == null:
		return
	var panel: Control = Control.new()
	panel.name = "SetDialogue"
	var view_h: float = 720.0
	var view: Viewport = _host.get_viewport()
	if view != null:
		view_h = view.get_visible_rect().size.y
	var lane_top: float = view_h - 196.0
	var panel_y: float = lane_top - 136.0
	if panel_y < 200.0:
		panel_y = 200.0
	var panel_h: float = minf(128.0, lane_top - panel_y - 8.0)
	if panel_h < 64.0:
		panel_h = 64.0
	panel.position = Vector2(220.0, panel_y)
	panel.size = Vector2(720.0, panel_h)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
	layer.add_child(panel)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.07, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	_plate = ColorRect.new()
	_plate.name = "SetPortraitPlate"
	_plate.position = Vector2(0.0, 8.0)
	_plate.size = Vector2(84.0, 84.0)
	_plate.color = Color(0.07, 0.08, 0.1, 0.92)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_plate)
	_portrait = TextureRect.new()
	_portrait.name = "SetPortrait"
	_portrait.position = Vector2(0.0, 8.0)
	_portrait.size = Vector2(84.0, 84.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.texture = Cameos.texture(faction, cameo_id)
	panel.add_child(_portrait)
	_sync_portrait()
	_speaker = Label.new()
	_speaker.name = "SetSpeaker"
	_speaker.position = Vector2(96.0, 4.0)
	_speaker.size = Vector2(600.0, 22.0)
	_speaker.text = speaker_name
	_speaker.add_theme_font_size_override("font_size", 16)
	_speaker.add_theme_color_override("font_color", _tint())
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_speaker)
	_subtitle = Label.new()
	_subtitle.name = "SetSubtitle"
	_subtitle.position = Vector2(96.0, 28.0)
	_subtitle.size = Vector2(600.0, 48.0)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.clip_text = true
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_theme_font_size_override("font_size", 16)
	_subtitle.max_lines_visible = 2
	_subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	panel.add_child(_subtitle)
	_bonus = Label.new()
	_bonus.name = "SetBonus"
	_bonus.position = Vector2(96.0, 80.0)
	_bonus.size = Vector2(600.0, 24.0)
	_bonus.text = "Bonus: reach the side cache" if has_bonus else ""
	_bonus.visible = has_bonus
	_bonus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bonus.add_theme_font_size_override("font_size", 16)
	_bonus.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	panel.add_child(_bonus)

func _sync_portrait() -> void:
	if _portrait == null:
		return
	if _portrait.texture == null:
		_portrait.texture = Cameos.texture(faction, cameo_id)
	var ready: bool = _portrait.texture != null
	_portrait.visible = ready
	if _plate != null:
		_plate.visible = ready
	var text_x: float = 96.0 if ready else 12.0
	var text_w: float = 600.0 if ready else 684.0
	if _speaker != null:
		_speaker.position.x = text_x
		_speaker.size.x = text_w
	if _subtitle != null:
		_subtitle.position.x = text_x
		_subtitle.size.x = text_w
	if _bonus != null:
		_bonus.position.x = text_x
		_bonus.size.x = text_w

func _tint() -> Color:
	if faction == "nmrf":
		return Color(0.35, 0.62, 0.28)
	if faction == "mvd":
		return Color(0.15, 0.75, 0.82)
	return Color(0.72, 0.12, 0.18)

func _span() -> void:
	_bridge = MeshInstance3D.new()
	_bridge.name = "SetBridge"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(6.0, 0.35, 1.2)
	_bridge.mesh = mesh
	_bridge.position = Vector3(0.0, 0.7, 11.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.38, 0.28)
	_bridge.material_override = mat
	_host.add_child(_bridge)

func _arm_camera() -> void:
	_armed = true
	var cam: RTSCamera = _host.get_node_or_null("Camera") as RTSCamera
	if cam == null:
		return
	home_focus = cam.focus
	home_distance = cam.distance
	_intro_to = home_focus
	_intro_from = home_focus + Vector3(0.0, 0.0, 12.0)
	wide_distance = minf(cam.zoom_max, home_distance + 24.0)

func _intro() -> void:
	if intro_done:
		return
	var cam: RTSCamera = _host.get_node_or_null("Camera") as RTSCamera
	if cam == null:
		intro_done = true
		return
	var t: float = clampf(_clock / 3.0, 0.0, 1.0)
	cam.focus = _intro_from.lerp(_intro_to, t)
	cam.distance = lerpf(wide_distance, home_distance, t)
	cam.apply()
	if t >= 1.0:
		intro_done = true

func _outro(delta: float) -> void:
	var cam: RTSCamera = _host.get_node_or_null("Camera") as RTSCamera
	if not outro_started:
		outro_started = true
		_outro_from = cam.distance if cam != null else home_distance
	_outro_t += maxf(delta, 0.0)
	if cam == null:
		return
	var t: float = clampf(_outro_t / 3.0, 0.0, 1.0)
	cam.distance = lerpf(_outro_from, minf(cam.zoom_max, _outro_from + 16.0), t)
	cam.apply()
	if t >= 1.0:
		outro_done = true

func _ambush() -> void:
	_quiet(SMPointer.ENEMY, Vector3(14.0, 0.0, 7.0), "ambush", &"militia")
	_quiet(SMPointer.ENEMY, Vector3(12.0, 0.0, 9.0), "ambush", &"militia")
	ambush_spawned = true
	_say(_line("ambush"), "base_under_attack", "ambush")

func _blow() -> void:
	if _bridge != null:
		_bridge.position.y = -2.4
		var mat: StandardMaterial3D = _bridge.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(0.22, 0.18, 0.16)
	var turncoat: RTSUnit = _quiet(SMPointer.PLAYER, Vector3(2.0, 0.0, 11.0), "guide", &"militia")
	if turncoat != null:
		turncoat.team = SMPointer.ENEMY
		turncoat.set_meta("duty", "betray")
		turncoat.set_meta("was_ally", true)
		turncoat.set_meta("objective", false)
		turncoat.attack_damage = 0.0
	betrayed = true
	bridge_down = true
	_say(_line("bridge"), "unit_lost", "bridge")

func _reinforce() -> void:
	var left: RTSUnit = _quiet(SMPointer.PLAYER, Vector3(-11.0, 0.0, -7.0), "relief", &"militia")
	var right: RTSUnit = _quiet(SMPointer.PLAYER, Vector3(-9.0, 0.0, -8.0), "relief", &"militia")
	var dest: Vector3 = Vector3(-6.0, 0.0, -3.0)
	if left != null:
		left.speed = 5.0
		left.set_path(PackedVector3Array([dest]))
	if right != null:
		right.speed = 5.0
		right.set_path(PackedVector3Array([dest + Vector3(1.6, 0.0, 0.4)]))
	reinforced = true
	_say(_line("relief"), "", "relief")

func _monsoon() -> void:
	weather_turned = true
	var sky: SMSight = SMSight.new()
	sky.force_monsoon(true)
	var hud: SMHud = _host.get("hud") as SMHud
	if hud != null:
		hud.use_sight(sky)
		hud.refresh()
	_say(_line("weather"), "", "weather")

func _haze() -> void:
	weather_turned = true
	var sky: SMSight = SMSight.new()
	sky.force_weather(true)
	var hud: SMHud = _host.get("hud") as SMHud
	if hud != null:
		hud.use_sight(sky)
		hud.refresh()
	_say(_line("haze"), "", "haze")

func _wagon() -> RTSUnit:
	var story: SMStory = _host.get("story") as SMStory
	if story == null:
		return null
	return story.wagon()

func _bonus_check() -> void:
	if not has_bonus or bonus_done:
		return
	var story: SMStory = _host.get("story") as SMStory
	if story != null and story.bonus_failed:
		if _bonus != null:
			_bonus.text = "Bonus failed: the spray landed"
		return
	var field: SMPointer = _host.get("field") as SMPointer
	if field == null:
		return
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if not is_instance_valid(u) or not u.is_alive():
			continue
		if bool(u.get_meta("objective", false)):
			continue
		if u.global_position.distance_to(bonus_at) > 2.4:
			continue
		bonus_done = true
		if _bonus != null:
			_bonus.text = "Bonus complete: side cache"
		return

func _press_patani() -> void:
	if mission_id != "ghosts_of_patani" or not _only_spectacle():
		return
	var field: SMPointer = _host.get("field") as SMPointer
	if field == null:
		return
	var prey: RTSUnit = null
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if is_instance_valid(u) and u.is_alive():
			prey = u
			break
	if prey == null:
		return
	var live: Array[RTSUnit] = []
	for u: RTSUnit in field.units_of(SMPointer.PLAYER):
		if is_instance_valid(u) and u.is_alive() and not bool(u.get_meta("objective", false)) and u.attack_damage > 0.0:
			live.append(u)
	if live.is_empty():
		return
	RTSOrders.attack(live, prey, field.nav_for_unit(live[0]), field.teams)

func _only_spectacle() -> bool:
	var field: SMPointer = _host.get("field") as SMPointer
	if field == null:
		return false
	var any: bool = false
	for u: RTSUnit in field.units_of(SMPointer.ENEMY):
		if not is_instance_valid(u) or not u.is_alive():
			continue
		any = true
		var duty: String = str(u.get_meta("duty", ""))
		if duty != "ambush" and duty != "betray":
			return false
	return any

func _quiet(team: int, at: Vector3, duty: String, kind: StringName) -> RTSUnit:
	var field: SMPointer = _host.get("field") as SMPointer
	if field == null:
		return null
	var u: RTSUnit = field.spawn(team, at, kind)
	u.max_hp = 16.0
	u.hp = 16.0
	u.attack_damage = 0.0
	u.speed = 0.0
	u.attack_range = 2.0
	u.set_meta("duty", duty)
	u.set_meta("set_piece", true)
	if team == SMPointer.PLAYER:
		u.set_meta("objective", true)
	return u

func _say(text: String, key: String, beat: String) -> void:
	line_text = text
	if _subtitle != null:
		_subtitle.text = text
	if _speaker != null:
		_speaker.text = speaker_name
	_voiced_beat = ""
	_offer_voice(beat)
	if key != "":
		Clips.announce_key(_host, faction, key)

func _retry_voice() -> void:
	var beat: String = "open"
	if not fired.is_empty():
		beat = str(fired[fired.size() - 1])
	if _voiced_beat == beat:
		return
	_offer_voice(beat)

func _offer_voice(beat: String) -> void:
	var played: bool = Clips.dialogue(_host, mission_id, beat)
	if played or Clips.dialogue_settled(mission_id):
		last_voiced = played
		_voiced_beat = beat
	else:
		last_voiced = false

func _timer(node_name: String, text: String) -> Label:
	var layer: CanvasLayer = _host.get("ui_layer") as CanvasLayer
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.position = Vector2(220.0, 472.0)
	label.size = Vector2(280.0, 22.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.42))
	if layer != null:
		layer.add_child(label)
	return label

func _clocks() -> void:
	var story: SMStory = _host.get("story") as SMStory
	if _hack != null and hack_end >= 0.0:
		var hack_show: float = maxf(hack_end - _clock, 0.0)
		if story != null and story.mission_id == "shwe_kokko":
			hack_show = maxf(story.hack_left, 0.0)
		_hack.text = "Hack: %ds" % int(ceil(hack_show))
	if _count != null and count_end >= 0.0:
		var count_show: float = maxf(count_end - _clock, 0.0)
		if story != null and story.mission_id == "shattered_monsoon":
			count_show = maxf(story.count_left, 0.0)
		_count.text = "Count: %ds" % int(ceil(count_show))

func _mines() -> void:
	var line: Node3D = Node3D.new()
	line.name = "SetMines"
	_host.add_child(line)
	for i: int in 5:
		var rock: MeshInstance3D = MeshInstance3D.new()
		var ball: SphereMesh = SphereMesh.new()
		ball.radius = 0.28
		ball.height = 0.56
		rock.mesh = ball
		rock.position = Vector3(0.4, 0.2, -8.0 + float(i) * 4.0)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.08, 0.09)
		rock.material_override = mat
		line.add_child(rock)
	_say(_line("mines"), "", "mines")

func _marker(node_name: String, at: Vector3, size: Vector3, color: Color, glow: bool) -> void:
	var prop: MeshInstance3D = MeshInstance3D.new()
	prop.name = node_name
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	prop.mesh = box
	prop.position = at
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	if glow:
		mat.emission_enabled = true
		mat.emission = color
	prop.material_override = mat
	_host.add_child(prop)
