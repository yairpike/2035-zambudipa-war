extends RefCounted
## Live session. Desktop hosts are authoritative for a two-player match.
## ENet is the desktop LAN path. Browsers use paste_host(), paste_join(), and paste_seal().
## That path is a copied WebRTC offer and answer. There is no account and no relay.

const Seat = preload("res://game/lan_seat.gd")

static var _live: Seat

static func seat() -> Seat:
	if _live == null:
		_live = Seat.new()
	return _live

static var port: int:
	get:
		return seat().port
	set(value):
		seat().port = value

static var beacon_port: int:
	get:
		return seat().beacon_port
	set(value):
		seat().beacon_port = value

static var role: String:
	get:
		return seat().role
	set(value):
		seat().role = value

static var started: bool:
	get:
		return seat().started
	set(value):
		seat().started = value

static var map_path: String:
	get:
		return seat().map_path
	set(value):
		seat().map_path = value

static var faction: String:
	get:
		return seat().faction
	set(value):
		seat().faction = value

static var guest_faction: String:
	get:
		return seat().guest_faction
	set(value):
		seat().guest_faction = value

static var peer: MultiplayerPeer:
	get:
		return seat().peer
	set(value):
		seat().peer = value

static var silence_pause: float:
	get:
		return seat().silence_pause
	set(value):
		seat().silence_pause = value

static var drop_after: float:
	get:
		return seat().drop_after
	set(value):
		seat().drop_after = value

static func show_controls() -> bool:
	return seat().show_controls()

static func lan_note(web: bool) -> String:
	return seat().lan_note(web)

static func holding() -> bool:
	return seat().holding()

static func active_host() -> bool:
	return seat().active_host()

static func open_host() -> Error:
	return seat().open_host()

static func open_client(address: String) -> Error:
	return seat().open_client(address)

static func attach_peer(next: MultiplayerPeer, as_host: bool) -> Error:
	return seat().attach_peer(next, as_host)

static func paste_host() -> Error:
	return seat().paste_host()

static func paste_join(blob: String) -> Error:
	return seat().paste_join(blob)

static func paste_seal(blob: String) -> Error:
	return seat().paste_seal(blob)

static func paste_text() -> String:
	return seat().paste_text()

static func paste_note() -> String:
	return seat().paste_note()

static func close() -> void:
	seat().close()

static func pump() -> void:
	seat().pump()

static func pulse(delta: float) -> void:
	seat().pulse(delta)

static func listen() -> Error:
	return seat().listen()

static func gather() -> void:
	seat().gather()

static func hush_listen() -> void:
	seat().hush_listen()

static func note_beacon(ip: String, raw: PackedByteArray) -> void:
	seat().note_beacon(ip, raw)

static func forget_hosts() -> void:
	seat().forget_hosts()

static func hosts() -> PackedStringArray:
	return seat().hosts()

static func host_address(index: int) -> String:
	return seat().host_address(index)

static func loopback_beacon(listen_port: int) -> bool:
	return seat().loopback_beacon(listen_port)

static func take() -> String:
	return seat().take()

static func send(payload: Dictionary) -> void:
	seat().send(payload)

static func send_start(path: String, host_faction: String, guest: String) -> void:
	seat().send_start(path, host_faction, guest)

static func apply_line(host: Node, raw: String) -> int:
	return seat().apply_line(host, raw)

static func state_of(host: Node, force: bool = false) -> Dictionary:
	return seat().state_of(host, force)

static func broadcast_state(host: Node) -> void:
	seat().broadcast_state(host)

static func probe(listen_port: int) -> bool:
	return seat().probe(listen_port)

static func ingest(raw: String) -> String:
	return seat().ingest(raw)

static func tick_lobby(delta: float) -> String:
	return seat().tick_lobby(delta)

static func watch(delta: float) -> void:
	seat().watch(delta)
