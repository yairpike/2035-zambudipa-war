extends RefCounted
## One session endpoint. The host simulates. The guest is the second player.
## Desktop uses ENet. Browsers attach a WebRTCMultiplayerPeer through the paste path.

const Power = preload("res://addons/rts_advanced/sm_power.gd")
const World = preload("res://game/world_view.gd")
const Paste = preload("res://game/web_paste.gd")

var port: int = 7777
var beacon_port: int = 7778
var role: String = ""
var started: bool = false
var map_path: String = "res://game/phillips_channel.tscn"
var faction: String = "gtfc"
var guest_faction: String = "nmrf"
var peer: MultiplayerPeer
var inbox: Array[String] = []
var host_ready: bool = false
var guest_ready: bool = false
var guest_joined: bool = false
var launched: bool = false
var counting: bool = false
var count_left: float = 0.0
var count_shown: int = 0
var chat_lines: Array[String] = []
var paused: bool = false
var winner: String = ""
var silence_pause: float = 2.0
var drop_after: float = 15.0
var quiet: float = 0.0
var last_note: String = ""
var guest_side: SMSide
var guest_roster: SMRoster
var guest_protocols: SMProtocols
var guest_powers: SMAbilities
var guest_sight: SMSight
var bound: Node
var _hello_sent: bool = false
var _seen: Array[Dictionary] = []
var _beacon: PacketPeerUDP
var _hear: PacketPeerUDP
var _beacon_at: int = 0
var _hi_acc: float = 0.0
var _prev: Dictionary = {}
var _prev_fog: PackedByteArray = PackedByteArray()
var _seq: int = 0
var _web: Paste
var _paste_note: String = ""
var _picked_faction: String = ""

static func faction_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	ids.append("gtfc")
	ids.append("nmrf")
	ids.append("mvd")
	ids.append("black_market")
	return ids

static func map_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	ids.append("res://game/phillips_channel.tscn")
	ids.append("res://game/sop_ruak.tscn")
	ids.append("res://game/burma_road.tscn")
	ids.append("res://game/ten_degree_atolls.tscn")
	ids.append("res://game/mekong_delta.tscn")
	ids.append("res://game/chiang_rai.tscn")
	return ids

static func known_faction(id: String) -> String:
	if faction_ids().has(id):
		return id
	return "gtfc"

static func known_map(path: String) -> String:
	if map_ids().has(path):
		return path
	return "res://game/phillips_channel.tscn"

static func map_title(path: String) -> String:
	var base: String = path.get_file().get_basename()
	if base == "":
		return "skirmish"
	return base.replace("_", " ")

func show_controls() -> bool:
	return not OS.has_feature("web")

func lan_note(web: bool) -> String:
	if web:
		return "Copy the offer into the other browser, then paste its answer back. No account."
	return "Host a 1v1 on this LAN, or join one. Each player brings a faction and a base."

func holding() -> bool:
	return paused

func active_host() -> bool:
	return role == "host" and started and peer != null

func open_host() -> Error:
	if not show_controls():
		return ERR_UNAVAILABLE
	close()
	role = "host"
	started = false
	var enet: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = enet.create_server(port)
	if err != OK:
		role = ""
		enet.close()
		return err
	peer = enet
	_arm_beacon()
	return OK

func open_client(address: String) -> Error:
	if not show_controls():
		return ERR_UNAVAILABLE
	close()
	role = "client"
	started = false
	var dest: String = address.strip_edges()
	if dest == "":
		dest = "127.0.0.1"
	var enet: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = enet.create_client(dest, port)
	if err != OK:
		role = ""
		enet.close()
		return err
	peer = enet
	return OK

func attach_peer(next: MultiplayerPeer, as_host: bool) -> Error:
	if next == null:
		return ERR_INVALID_PARAMETER
	close()
	peer = next
	role = "host" if as_host else "client"
	started = false
	return OK

func paste_host() -> Error:
	close()
	var link: Paste = Paste.new()
	var err: Error = link.open_host()
	_paste_note = link.note
	if err != OK:
		return err
	_adopt_paste(link, true)
	return OK

func paste_join(blob: String) -> Error:
	var row: Dictionary = Paste.unpack(blob)
	if row.is_empty() or str(row.get("t", "")) != "offer":
		_paste_note = "That paste is not an offer."
		return ERR_INVALID_DATA
	close()
	var link: Paste = Paste.new()
	var err: Error = link.join(blob)
	_paste_note = link.note
	if err != OK:
		return err
	_adopt_paste(link, false)
	return OK

func paste_seal(blob: String) -> Error:
	if _web == null or _web.phase != "offer":
		_paste_note = "Start an offer before pasting an answer."
		return ERR_UNCONFIGURED
	var err: Error = _web.seal(blob)
	_paste_note = _web.note
	return err

func paste_text() -> String:
	if _web == null:
		return ""
	return _web.text

func paste_note() -> String:
	if _web != null and _web.note != "":
		return _web.note
	return _paste_note

func close() -> void:
	if started:
		send({"k": "bye"})
		if peer != null:
			peer.poll()
	var web_peer: MultiplayerPeer = null
	if _web != null:
		web_peer = _web.peer
		_web.shutdown()
	_web = null
	_paste_note = ""
	if peer != null and peer != web_peer:
		peer.close()
	peer = null
	role = ""
	started = false
	launched = false
	counting = false
	host_ready = false
	guest_ready = false
	guest_joined = false
	paused = false
	winner = ""
	quiet = 0.0
	inbox.clear()
	chat_lines.clear()
	_hello_sent = false
	_picked_faction = ""
	_prev.clear()
	_prev_fog = PackedByteArray()
	_seq = 0
	guest_side = null
	guest_roster = null
	guest_protocols = null
	guest_powers = null
	guest_sight = null
	bound = null
	_stop_beacon()
	hush_listen()

func pump() -> void:
	_send_beacon()
	if _web != null:
		_web.poll()
		if _web.note != "":
			_paste_note = _web.note
	if peer == null:
		return
	peer.poll()
	while peer.get_available_packet_count() > 0:
		inbox.append(peer.get_packet().get_string_from_utf8())
	if role == "client" and not _hello_sent and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		send({"k": "hello", "faction": _wish_faction()})
		_hello_sent = true

func pulse(delta: float) -> void:
	if role != "client" or not started:
		return
	_hi_acc += delta
	if _hi_acc < 0.5:
		return
	_hi_acc = 0.0
	send({"k": "hi"})

func listen() -> Error:
	if not show_controls():
		return ERR_UNAVAILABLE
	if _hear != null:
		return OK
	var udp: PacketPeerUDP = PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	var err: Error = udp.bind(beacon_port)
	if err != OK:
		return err
	_hear = udp
	return OK

func gather() -> void:
	if _hear == null:
		return
	while _hear.get_available_packet_count() > 0:
		var raw: PackedByteArray = _hear.get_packet()
		var ip: String = _hear.get_packet_ip()
		note_beacon(ip, raw)

func hush_listen() -> void:
	if _hear != null:
		_hear.close()
	_hear = null

func note_beacon(ip: String, raw: PackedByteArray) -> void:
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var row: Dictionary = parsed
	if str(row.get("k", "")) != "here":
		return
	var host_ip: String = ip
	if host_ip.begins_with("::ffff:"):
		host_ip = host_ip.substr(7)
	if host_ip == "":
		return
	var game_port: int = int(row.get("port", port))
	var label: String = map_title(str(row.get("map", "")))
	var fresh: Dictionary = {
		"ip": host_ip,
		"port": game_port,
		"label": label,
		"at": Time.get_ticks_msec(),
	}
	for i: int in _seen.size():
		if str(_seen[i].get("ip", "")) == host_ip:
			_seen[i] = fresh
			return
	_seen.append(fresh)

func forget_hosts() -> void:
	_seen.clear()

func hosts() -> PackedStringArray:
	var now: int = Time.get_ticks_msec()
	var keep: Array[Dictionary] = []
	var out: PackedStringArray = PackedStringArray()
	for row: Dictionary in _seen:
		if now - int(row.get("at", 0)) > 4000:
			continue
		keep.append(row)
		out.append("%s:%d  %s" % [str(row.get("ip", "")), int(row.get("port", 0)), str(row.get("label", ""))])
	_seen = keep
	return out

func host_address(index: int) -> String:
	if index < 0 or index >= _seen.size():
		return ""
	return str(_seen[index].get("ip", ""))

func loopback_beacon(listen_port: int) -> bool:
	var recv: PacketPeerUDP = PacketPeerUDP.new()
	if recv.bind(listen_port) != OK:
		return false
	var udp: PacketPeerUDP = PacketPeerUDP.new()
	if udp.bind(listen_port + 1) != OK:
		recv.close()
		return false
	udp.set_dest_address("127.0.0.1", listen_port)
	var body: String = JSON.stringify({"k": "here", "port": port, "map": map_path, "name": "ASEAN 2031"})
	udp.put_packet(body.to_utf8_buffer())
	var ok: bool = false
	for _i: int in 20:
		if recv.get_available_packet_count() > 0:
			var raw: PackedByteArray = recv.get_packet()
			var ip: String = recv.get_packet_ip()
			note_beacon(ip, raw)
			ok = true
			break
		OS.delay_msec(10)
	udp.close()
	recv.close()
	return ok

func take() -> String:
	if inbox.is_empty():
		return ""
	var line: String = inbox[0]
	inbox.remove_at(0)
	return line

func send(payload: Dictionary) -> void:
	if peer == null:
		return
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	peer.set_target_peer(0 if role == "host" else 1)
	peer.put_packet(JSON.stringify(payload).to_utf8_buffer())

func send_start(path: String, host_faction: String, guest: String) -> void:
	map_path = known_map(path)
	faction = known_faction(host_faction)
	guest_faction = known_faction(guest)
	started = true
	send({"k": "start", "map": map_path, "faction": faction, "guest": guest_faction})

func pick_faction(id: String) -> void:
	var known: String = known_faction(id)
	if role == "client":
		_picked_faction = known
		guest_faction = known
		send({"k": "wish", "faction": known, "ready": guest_ready})
		return
	faction = known
	if role == "host":
		announce_room()

func lobby_line() -> String:
	var guest_name: String = guest_faction if guest_joined else "waiting"
	var host_state: String = "ready" if host_ready else "open"
	var guest_state: String = "ready" if guest_ready else "open"
	return "Host %s %s    Guest %s %s" % [faction, host_state, guest_name, guest_state]

func _wish_faction() -> String:
	if _picked_faction != "":
		return _picked_faction
	if role == "client" and guest_joined and guest_faction != "":
		return guest_faction
	return faction

func pick_map(path: String) -> void:
	if role != "host":
		return
	map_path = known_map(path)
	announce_room()

func set_ready(on: bool) -> void:
	if role == "host":
		host_ready = on
		if not on:
			counting = false
		announce_room()
	elif role == "client":
		guest_ready = on
		send({"k": "wish", "faction": _wish_faction(), "ready": guest_ready})

func say(text: String) -> void:
	var line: String = text.strip_edges()
	if line.length() > 80:
		line = line.substr(0, 80)
	if line == "":
		return
	var who: String = "host" if role == "host" else "guest"
	_push_chat(who, line)
	send({"k": "chat", "who": who, "text": line})
	if role == "host":
		announce_room()

func announce_room() -> void:
	if role != "host":
		return
	send({
		"k": "room",
		"map": map_path,
		"faction": faction,
		"guest": guest_faction,
		"host_ready": host_ready,
		"guest_ready": guest_ready,
		"chat": _chat_tail(),
	})

func tick_lobby(delta: float) -> String:
	if role != "host" or launched or not guest_joined:
		return ""
	if not host_ready or not guest_ready:
		counting = false
		return ""
	if not counting:
		counting = true
		count_left = 3.0
		count_shown = 3
		send({"k": "count", "n": 3})
	count_left -= delta
	var show: int = maxi(1, int(ceil(count_left)))
	if count_left <= 0.0:
		show = 0
	if show != count_shown and show > 0:
		count_shown = show
		send({"k": "count", "n": show})
	if count_left > 0.0:
		return ""
	launched = true
	counting = false
	send_start(map_path, faction, guest_faction)
	return "start"

func ingest(raw: String) -> String:
	if raw != "":
		quiet = 0.0
		if winner == "":
			paused = false
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	var row: Dictionary = parsed
	var kind: String = str(row.get("k", ""))
	if kind == "hello" and role == "host" and not launched:
		guest_joined = true
		guest_faction = known_faction(str(row.get("faction", "nmrf")))
		announce_room()
	elif kind == "wish" and role == "host" and not launched:
		guest_joined = true
		guest_faction = known_faction(str(row.get("faction", guest_faction)))
		guest_ready = bool(row.get("ready", false))
		if not guest_ready:
			counting = false
		announce_room()
	elif kind == "chat":
		_push_chat(str(row.get("who", "guest")), str(row.get("text", "")))
		if role == "host":
			announce_room()
	elif kind == "room" and role == "client":
		map_path = known_map(str(row.get("map", map_path)))
		guest_joined = true
		var echoed: String = str(row.get("guest", ""))
		if echoed != "":
			guest_faction = known_faction(echoed)
		elif _picked_faction != "":
			guest_faction = _picked_faction
		faction = known_faction(str(row.get("faction", "gtfc")))
		host_ready = bool(row.get("host_ready", false))
		guest_ready = bool(row.get("guest_ready", false))
		_take_chat(row.get("chat", []))
	elif kind == "count":
		count_shown = int(row.get("n", 0))
		counting = count_shown > 0
	elif kind == "start":
		started = true
		map_path = known_map(str(row.get("map", map_path)))
		faction = known_faction(str(row.get("faction", faction)))
		guest_faction = known_faction(str(row.get("guest", guest_faction)))
	elif kind == "ack":
		last_note = str(row.get("note", ""))
	elif kind == "bye":
		paused = true
		winner = "host" if role == "host" else "guest"
	return kind

func watch(delta: float) -> void:
	if not started or winner != "":
		return
	var peer_gone: bool = peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED or (_web != null and _web.is_disconnected())
	if peer_gone and quiet >= silence_pause:
		paused = true
		winner = "host" if role == "host" else "guest"
		return
	quiet += delta
	if quiet < silence_pause:
		return
	paused = true
	var timeout: float = 4.0 if role == "client" and drop_after >= 10.0 else drop_after
	if peer_gone or quiet >= silence_pause + timeout:
		winner = "host" if role == "host" else "guest"

func try_seat(host: Node) -> bool:
	if guest_side != null:
		return true
	if host == null or role != "host":
		return false
	var raider: SMRaider = host.get("raider") as SMRaider
	var field: SMPointer = host.get("field") as SMPointer
	if raider == null or field == null or raider.yard == null:
		return false
	raider.human = true
	var grid: SMDomainGrid = _grid(host)
	var world: Node3D = host as Node3D
	if grid == null or world == null:
		return false
	var center: Vector3 = raider.yard.center
	var status: Label = host.find_child("Status", true, false) as Label
	guest_roster = SMRoster.new()
	guest_roster.setup(guest_faction)
	var purse: RTSEconomy = guest_roster.economy
	var bank: int = purse.credits(0)
	purse.set_credits(0, 0)
	purse.set_credits(SMPointer.ENEMY, bank)
	if guest_roster.queue != null:
		guest_roster.queue.team = SMPointer.ENEMY
		guest_roster.queue.rally = center + Vector3(6.0, 0.0, 2.0)
		if not guest_roster.queue.produced.is_connected(_on_trained):
			guest_roster.queue.produced.connect(_on_trained)
	guest_side = SMSide.new()
	guest_side.prepare(world, status, grid, center, purse, guest_faction)
	guest_side.yard.team = SMPointer.ENEMY
	guest_side.yard.economy = purse
	guest_side.slab_made.connect(Callable(World, "slab"))
	guest_protocols = SMProtocols.new()
	guest_powers = SMAbilities.new()
	raider.yard = guest_side.yard
	raider.economy = purse
	bound = host
	_raise_base()
	return true

func tick_guest(delta: float) -> void:
	if guest_side == null or guest_side.yard == null:
		return
	guest_side.yard.tick_repair(delta)
	guest_side.yard.cool_super(delta)
	if guest_protocols != null:
		guest_protocols.cool(delta)
	if guest_roster != null and guest_roster.queue != null:
		guest_roster.queue.advance(delta)

func apply_line(host: Node, raw: String) -> int:
	last_note = ""
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var row: Dictionary = parsed
	var kind: String = str(row.get("k", ""))
	if kind == "go":
		last_note = "rejected"
		return 0
	if kind != "cmd":
		return 0
	last_note = apply_cmd(host, row)
	return 0 if _failed(last_note) else 1

func apply_cmd(host: Node, row: Dictionary) -> String:
	if guest_side == null and not try_seat(host):
		return "rejected"
	var op: String = str(row.get("op", ""))
	if op == "move":
		return _move(host, row)
	if op == "attack":
		return _attack(host, row)
	if op == "build":
		return _build(str(row.get("id", "")))
	if op == "place":
		return _place(str(row.get("id", "")), float(row.get("x", 0.0)), float(row.get("z", 0.0)))
	if op == "train":
		return _train(str(row.get("id", "")))
	if op == "sell":
		return _sell(str(row.get("id", "")))
	if op == "repair":
		return _repair(str(row.get("id", "")))
	if op == "ability":
		return _ability(host, row)
	if op == "protocol":
		return _protocol(str(row.get("id", "")))
	return "rejected"

func state_of(host: Node, force: bool = false) -> Dictionary:
	var field: SMPointer = host.get("field") as SMPointer
	var full: bool = force or _prev.is_empty() or _seq % 20 == 0
	var now: Dictionary = {}
	var fog: PackedByteArray = _fog(host)
	if field != null:
		for u: RTSUnit in field.units:
			if not is_instance_valid(u) or not u.is_alive():
				continue
			if not _guest_sees(host, u, fog):
				continue
			var uid: int = u.get_instance_id()
			var sx: float = snappedf(u.global_position.x, 0.1)
			var sz: float = snappedf(u.global_position.z, 0.1)
			now[uid] = "%s|%s|%s|%s|%s" % [sx, sz, int(round(u.hp)), u.team, str(u.unit_type)]
	var changed: Array = []
	var gone: Array = []
	for key: Variant in now.keys():
		var uid_now: int = int(key)
		if full or str(_prev.get(uid_now, "")) != str(now[uid_now]):
			var bits: PackedStringArray = str(now[uid_now]).split("|")
			changed.append([uid_now, float(bits[0]), float(bits[1]), int(bits[2]), int(bits[3]), bits[4]])
	if not full:
		for key_old: Variant in _prev.keys():
			var uid_old: int = int(key_old)
			if not now.has(uid_old):
				gone.append(uid_old)
	_prev = now
	_seq += 1
	var packet: Dictionary = {
		"k": "state",
		"seq": _seq,
		"n": now.size(),
		"full": full,
		"u": changed,
		"gone": gone,
		"pause": paused,
		"winner": winner,
	}
	_put_economy(packet)
	_put_structures(host, packet, fog)
	_put_fog(packet, fog, full)
	if full:
		packet["train"] = _train_offer()
		packet["build"] = _build_offer()
		packet["sell"] = _sell_offer()
		packet["proto"] = "cash_bounty"
		if guest_side != null:
			packet["home"] = [guest_side.yard.center.x, guest_side.yard.center.z]
	return packet

func broadcast_state(host: Node) -> void:
	send(state_of(host))

func probe(listen_port: int) -> bool:
	if not show_controls():
		return false
	var server: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	if server.create_server(listen_port) != OK:
		return false
	var client: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	if client.create_client("127.0.0.1", listen_port) != OK:
		server.close()
		return false
	var ok: bool = false
	for _i: int in 25:
		server.poll()
		client.poll()
		if client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			client.set_target_peer(1)
			client.put_packet("hello".to_utf8_buffer())
			server.poll()
			if server.get_available_packet_count() > 0:
				ok = server.get_packet().get_string_from_utf8() == "hello"
				break
		OS.delay_msec(20)
	client.close()
	server.close()
	return ok

func _raise_base() -> void:
	if guest_side == null or guest_side.yard == null:
		return
	var guard: int = 0
	while guard < 8:
		guard += 1
		var nxt: StringName = _next_build()
		if nxt == &"":
			return
		var note: String = guest_side.order_building(nxt)
		if note != "built" and note != "placed" and not guest_side.yard.finished.has(nxt):
			return
		if _has_role("power") and _has_role("barracks"):
			return

func _next_build() -> StringName:
	if guest_side == null:
		return &""
	for id: StringName in guest_side.yard.tech_order:
		if not guest_side.yard.finished.has(id):
			return id
	return &""

func _has_role(role_name: String) -> bool:
	if guest_side == null:
		return false
	for id: StringName in guest_side.yard.building_role.keys():
		if str(guest_side.yard.building_role[id]) == role_name and guest_side.yard.structure_alive(id):
			return true
	return false

func _move(host: Node, row: Dictionary) -> String:
	var live: Array[RTSUnit] = _own(host, row.get("ids", []))
	if live.is_empty():
		return "rejected"
	var at: Vector3 = Vector3(float(row.get("x", 0.0)), 0.0, float(row.get("z", 0.0)))
	var field: SMPointer = host.get("field") as SMPointer
	RTSOrders.move(live, at, field.nav_for_unit(live[0]))
	return "moved"

func _attack(host: Node, row: Dictionary) -> String:
	var live: Array[RTSUnit] = _own(host, row.get("ids", []))
	if live.is_empty():
		return "rejected"
	var field: SMPointer = host.get("field") as SMPointer
	var foe: RTSUnit = _find(field, int(row.get("tid", -1)))
	if foe == null or not foe.is_alive() or foe.team == SMPointer.ENEMY:
		return "rejected"
	if not field.teams.are_enemies(SMPointer.ENEMY, foe.team):
		return "rejected"
	if RTSOrders.attack(live, foe, field.nav_for_unit(live[0]), field.teams) <= 0:
		return "rejected"
	return "attack"

func _build(id: String) -> String:
	if guest_side == null or id == "":
		return "rejected"
	var idn: StringName = StringName(id)
	if not guest_side.yard.can_build(idn):
		return "rejected"
	var note: String = guest_side.order_building(idn)
	if guest_side.yard.finished.has(idn) or note == "built" or note == "placed":
		return "built"
	return "rejected" if note == "" else note

func _place(id: String, x: float, z: float) -> String:
	if guest_side == null or guest_side.yard == null:
		return "rejected"
	var idn: StringName = StringName(id)
	if guest_side.yard.style != SMBuildYard.Style.INTERNAL or not guest_side.yard.ready.has(idn):
		return "not ready"
	var pos: Vector3 = Vector3(x, 0.0, z)
	if not guest_side.yard.inside(pos):
		return "outside"
	if not guest_side.yard.place_finished(idn, pos):
		return "rejected"
	guest_side.slab_made.emit(guest_side.host, "Built_%s" % id, SMPointer.building_at(pos), SMPointer.BUILDING_SIZE, SMFront.accent())
	return "placed"

func _train(id: String) -> String:
	if guest_roster == null or guest_side == null or id == "":
		return "rejected"
	if not Power.online(guest_side.yard):
		return "low power"
	var row: Dictionary = _unit_row(id)
	var need: String = SMCatalog.producer(row)
	if need != "" and not _has_role(need):
		return "rejected"
	if not guest_roster.train(StringName(id)):
		return "rejected"
	return "queued"

func _sell(id: String) -> String:
	if guest_side == null:
		return "rejected"
	if guest_side.sell_structure(StringName(id)) <= 0:
		return "rejected"
	return "sold"

func _repair(id: String) -> String:
	if guest_side == null or guest_side.yard == null:
		return "rejected"
	if not guest_side.yard.begin_repair(StringName(id)):
		return "rejected"
	return "repairing"

func _ability(host: Node, row: Dictionary) -> String:
	var live: Array[RTSUnit] = _own(host, row.get("ids", []))
	if live.is_empty():
		return "rejected"
	var field: SMPointer = host.get("field") as SMPointer
	var saved: Array[RTSUnit] = []
	for u: RTSUnit in field.selection.units:
		saved.append(u)
	field.selection.clear()
	for u_live: RTSUnit in live:
		u_live.selected = true
		field.selection.units.append(u_live)
	var aim: Vector3 = Vector3(float(row.get("x", live[0].global_position.x)), 0.0, float(row.get("z", live[0].global_position.z)))
	var fired: String = field.cast_f(aim)
	field.selection.clear()
	for u_back: RTSUnit in saved:
		if is_instance_valid(u_back):
			u_back.selected = true
			field.selection.units.append(u_back)
	if fired == "":
		return "rejected"
	return "ability"

func _protocol(id: String) -> String:
	if guest_protocols == null or guest_roster == null or id == "":
		return "rejected"
	if not guest_protocols.cast_power(StringName(id), guest_roster.economy, SMPointer.ENEMY, guest_powers, -1):
		return "rejected"
	return "cast"

func _own(host: Node, raw: Variant) -> Array[RTSUnit]:
	var live: Array[RTSUnit] = []
	if typeof(raw) != TYPE_ARRAY:
		return live
	var field: SMPointer = host.get("field") as SMPointer
	if field == null:
		return live
	var ids: Array = raw
	for item: Variant in ids:
		var u: RTSUnit = _find(field, int(item))
		if u == null or not u.is_alive() or u.team != SMPointer.ENEMY:
			live.clear()
			return live
		live.append(u)
	return live

func _find(field: SMPointer, uid: int) -> RTSUnit:
	if field == null:
		return null
	for u: RTSUnit in field.units:
		if is_instance_valid(u) and u.get_instance_id() == uid:
			return u
	return null

func _unit_row(id: String) -> Dictionary:
	for unit: Dictionary in SMCatalog.units_of(SMCatalog.faction(guest_faction)):
		if str(unit.get("id", "")) == id:
			return unit
	return {}

func _on_trained(unit_type: StringName, rally: Vector3) -> void:
	if bound == null:
		return
	var field: SMPointer = bound.get("field") as SMPointer
	if field == null:
		return
	field.spawn(SMPointer.ENEMY, rally, unit_type)

func _grid(host: Node) -> SMDomainGrid:
	var grid: SMDomainGrid = host.get("grid") as SMDomainGrid
	if grid != null:
		return grid
	var sim: SMMatch = host.get("sim") as SMMatch
	if sim != null:
		return sim.grid
	return null

func _fog(host: Node) -> PackedByteArray:
	var grid: SMDomainGrid = _grid(host)
	var empty: PackedByteArray = PackedByteArray()
	if grid == null:
		return empty
	if guest_sight == null or guest_sight.grid != grid:
		guest_sight = SMSight.new()
		guest_sight.bind(grid)
	guest_sight.begin()
	var field: SMPointer = host.get("field") as SMPointer
	var reach: float = guest_sight.unit_radius(false)
	if field != null:
		for u: RTSUnit in field.units:
			if is_instance_valid(u) and u.is_alive() and field.teams.are_allies(SMPointer.ENEMY, u.team):
				guest_sight.add_seer(u.global_position, reach)
	guest_sight.commit()
	var out: PackedByteArray = PackedByteArray()
	out.resize(grid.cols * grid.rows)
	var i: int = 0
	for y: int in grid.rows:
		for x: int in grid.cols:
			out[i] = guest_sight.cell_state(Vector2i(x, y))
			i += 1
	return out

func _guest_sees(host: Node, u: RTSUnit, fog: PackedByteArray) -> bool:
	var field: SMPointer = host.get("field") as SMPointer
	if field != null and field.teams.are_allies(SMPointer.ENEMY, u.team):
		return true
	if guest_sight == null or guest_sight.grid == null or fog.is_empty():
		return false
	var cell: Vector2i = guest_sight.grid.cell_at(u.global_position)
	if not guest_sight.grid.in_bounds(cell):
		return false
	var idx: int = cell.y * guest_sight.grid.cols + cell.x
	if idx < 0 or idx >= fog.size():
		return false
	return fog[idx] != SMSight.HIDDEN

func _put_fog(packet: Dictionary, fog: PackedByteArray, full: bool) -> void:
	if fog.is_empty():
		return
	if full or _prev_fog.is_empty() or fog.size() != _prev_fog.size():
		packet["fog"] = _fog_text(fog)
		_prev_fog = fog
		return
	var fi: Array = []
	var fv: Array = []
	for i: int in fog.size():
		if fog[i] != _prev_fog[i]:
			fi.append(i)
			fv.append(fog[i])
	if not fi.is_empty():
		packet["fi"] = fi
		packet["fv"] = fv
	_prev_fog = fog

func _fog_text(fog: PackedByteArray) -> String:
	var chars: PackedByteArray = PackedByteArray()
	chars.resize(fog.size())
	for i: int in fog.size():
		chars[i] = 48 + int(fog[i])
	return chars.get_string_from_ascii()

func _put_economy(packet: Dictionary) -> void:
	if guest_roster == null or guest_side == null:
		return
	var pair: Vector2i = Power.tally(guest_side.yard)
	var names: Array = []
	var progress: float = 0.0
	if guest_roster.queue != null:
		for item: StringName in guest_roster.queue.items:
			names.append(str(item))
		progress = guest_roster.queue.head_ratio()
	packet["credits"] = guest_roster.economy.credits(SMPointer.ENEMY)
	packet["gen"] = pair.x
	packet["use"] = pair.y
	packet["q"] = names
	packet["qp"] = progress

func _put_structures(host: Node, packet: Dictionary, fog: PackedByteArray) -> void:
	var rows: Array = []
	if guest_side != null:
		_yards(rows, guest_side.yard, SMPointer.ENEMY, host, fog, true)
	var side: SMSide = host.get("side") as SMSide
	if side != null:
		_yards(rows, side.yard, SMPointer.PLAYER, host, fog, false)
	packet["b"] = rows

func _yards(rows: Array, yard: SMBuildYard, team: int, host: Node, fog: PackedByteArray, own: bool) -> void:
	if yard == null:
		return
	for id: StringName in yard.finished:
		var pos: Vector3 = yard.position_of(id)
		if not own and not _point_seen(host, pos, fog):
			continue
		rows.append([str(id), pos.x, pos.z, yard.structure_hp.get(id, 1.0), team])

func _point_seen(host: Node, pos: Vector3, fog: PackedByteArray) -> bool:
	if guest_sight == null or guest_sight.grid == null or fog.is_empty():
		return false
	var cell: Vector2i = guest_sight.grid.cell_at(pos)
	if not guest_sight.grid.in_bounds(cell):
		return false
	var idx: int = cell.y * guest_sight.grid.cols + cell.x
	if idx < 0 or idx >= fog.size():
		return false
	return fog[idx] != SMSight.HIDDEN

func _train_offer() -> String:
	for unit: Dictionary in SMCatalog.units_of(SMCatalog.faction(guest_faction)):
		if str(unit.get("role", "")) == "infantry":
			return str(unit.get("id", ""))
	return ""

func _build_offer() -> String:
	var nxt: StringName = _next_build()
	return str(nxt)

func _sell_offer() -> String:
	if guest_side == null or guest_side.yard.finished.is_empty():
		return ""
	return str(guest_side.yard.finished[0])

func _failed(note: String) -> bool:
	return note == "" or note == "rejected" or note == "not ready" or note == "outside" or note == "low power"

func _push_chat(who: String, text: String) -> void:
	var line: String = text.strip_edges()
	if line == "":
		return
	if line.length() > 80:
		line = line.substr(0, 80)
	chat_lines.append("%s: %s" % [who, line])
	while chat_lines.size() > 8:
		chat_lines.remove_at(0)

func _chat_tail() -> Array:
	var out: Array = []
	for line: String in chat_lines:
		out.append(line)
	return out

func _take_chat(raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	chat_lines.clear()
	var rows: Array = raw
	for item: Variant in rows:
		var line: String = str(item)
		if line != "":
			chat_lines.append(line)
	while chat_lines.size() > 8:
		chat_lines.remove_at(0)

func _arm_beacon() -> void:
	_stop_beacon()
	if not show_controls():
		return
	var udp: PacketPeerUDP = PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	if udp.bind(0) != OK:
		return
	if udp.set_dest_address("255.255.255.255", beacon_port) != OK:
		udp.close()
		return
	_beacon = udp
	_beacon_at = 0

func _stop_beacon() -> void:
	if _beacon != null:
		_beacon.close()
	_beacon = null

func _adopt_paste(link: Paste, as_host: bool) -> void:
	_web = link
	peer = link.peer
	role = "host" if as_host else "client"
	started = false

func _send_beacon() -> void:
	if role != "host" or _beacon == null:
		return
	var now: int = Time.get_ticks_msec()
	if _beacon_at != 0 and now - _beacon_at < 1000:
		return
	_beacon_at = now
	var body: String = JSON.stringify({
		"k": "here",
		"port": port,
		"map": map_path,
		"name": "ASEAN 2031",
	})
	_beacon.put_packet(body.to_utf8_buffer())
