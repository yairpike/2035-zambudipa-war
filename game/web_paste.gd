extends RefCounted
## Two browsers connect by copying an offer and an answer.
## STUN only. There is no account, no signalling server, and no TURN relay.

const STUN_URL: String = "stun:stun.l.google.com:19302"
const MARK: String = "ASEAN2031."
const GUEST_ID: int = 2
const DESKTOP_NOTE: String = "Web play uses a copied offer and answer in the browser. This desktop build has no WebRTC addon."

var peer: WebRTCMultiplayerPeer
var note: String = ""
var text: String = ""
var phase: String = ""

var _pc: WebRTCPeerConnection
var _sdp: String = ""
var _ice: Array = []
var _sealed: bool = false
var _opened_at: int = 0
var _sdp_at: int = 0

static func ready() -> bool:
	if OS.has_feature("web"):
		return true
	return not ClassDB.get_inheriters_from_class(&"WebRTCPeerConnectionExtension").is_empty()

static func _b64_ok(body: String) -> bool:
	if body == "":
		return false
	var alphabet: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
	for i: int in body.length():
		if not alphabet.contains(body[i]):
			return false
	return true

static func pack(kind: String, sdp: String, ice: Array) -> String:
	return MARK + Marshalls.utf8_to_base64(JSON.stringify({"t": kind, "s": sdp, "c": ice}))

static func unpack(blob: String) -> Dictionary:
	var text: String = blob.strip_edges()
	if not text.begins_with(MARK):
		return {}
	var body: String = text.substr(MARK.length()).replace("\n", "").replace("\r", "").replace(" ", "")
	if not _b64_ok(body):
		return {}
	var decoded: String = Marshalls.base64_to_utf8(body)
	if decoded == "":
		return {}
	var parsed: Variant = JSON.parse_string(decoded)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var row: Dictionary = parsed
	var kind: String = str(row.get("t", ""))
	if kind != "offer" and kind != "answer":
		return {}
	var sdp: String = str(row.get("s", ""))
	if sdp == "":
		return {}
	var ice_in: Variant = row.get("c", [])
	var ice: Array = []
	if typeof(ice_in) != TYPE_ARRAY:
		return {}
	var rows: Array = ice_in
	for item: Variant in rows:
		if typeof(item) != TYPE_ARRAY:
			return {}
		var triple: Array = item
		if triple.size() != 3:
			return {}
		ice.append([str(triple[0]), int(triple[1]), str(triple[2])])
	return {"t": kind, "s": sdp, "c": ice}

func open_host() -> Error:
	shutdown()
	if not ready():
		note = DESKTOP_NOTE
		return ERR_UNAVAILABLE
	var err: Error = _open(true)
	if err != OK:
		return err
	err = _pc.create_offer()
	if err != OK:
		note = "The offer did not start."
		shutdown()
		return err
	phase = "offer"
	_opened_at = Time.get_ticks_msec()
	note = "Copy the offer once it appears, then paste the guest's answer."
	return OK

func join(blob: String) -> Error:
	var row: Dictionary = unpack(blob)
	if row.is_empty() or str(row.get("t", "")) != "offer":
		note = "That paste is not an offer."
		return ERR_INVALID_DATA
	if not ready():
		note = DESKTOP_NOTE
		return ERR_UNAVAILABLE
	var err: Error = _open(false)
	if err != OK:
		return err
	err = _pc.set_remote_description("offer", str(row.get("s", "")))
	if err != OK:
		note = "The offer was rejected."
		shutdown()
		return err
	_add_ice(row.get("c", []))
	err = _pc.create_answer()
	if err != OK:
		note = "The answer did not start."
		shutdown()
		return err
	phase = "answer"
	_opened_at = Time.get_ticks_msec()
	note = "Copy the answer once it appears and send it back to the host."
	return OK

func seal(blob: String) -> Error:
	if _pc == null or phase != "offer":
		note = "Start an offer before pasting an answer."
		return ERR_UNCONFIGURED
	var row: Dictionary = unpack(blob)
	if row.is_empty() or str(row.get("t", "")) != "answer":
		note = "That paste is not an answer."
		return ERR_INVALID_DATA
	var err: Error = _pc.set_remote_description("answer", str(row.get("s", "")))
	if err != OK:
		note = "The answer was rejected."
		return err
	_add_ice(row.get("c", []))
	note = "Answer applied. Waiting for the guest."
	return OK

func poll() -> void:
	if _pc == null:
		return
	_pc.poll()
	if _sealed or phase == "":
		return
	var now: int = Time.get_ticks_msec()
	if _sdp == "":
		if now - _opened_at > 8000:
			note = "The browser did not produce a session description."
		return
	var gathered: bool = _pc.get_gathering_state() == WebRTCPeerConnection.GATHERING_STATE_COMPLETE
	var waited: int = now - _sdp_at
	if gathered or (waited > 4000 and not _ice.is_empty()) or waited > 12000:
		text = pack(phase, _sdp, _ice)
		_sealed = true
		if phase == "offer":
			note = "Copy this offer and send it to the guest."
		else:
			note = "Copy this answer and send it to the host."

func is_disconnected() -> bool:
	if _pc == null:
		return false
	var st: int = _pc.get_connection_state()
	if st == WebRTCPeerConnection.STATE_DISCONNECTED or st == WebRTCPeerConnection.STATE_FAILED or st == WebRTCPeerConnection.STATE_CLOSED:
		return true
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return true
	return false

func shutdown() -> void:
	if _pc != null:
		if _pc.session_description_created.is_connected(_on_sdp):
			_pc.session_description_created.disconnect(_on_sdp)
		if _pc.ice_candidate_created.is_connected(_on_ice):
			_pc.ice_candidate_created.disconnect(_on_ice)
		_pc.close()
	_pc = null
	if peer != null:
		peer.close()
	peer = null
	text = ""
	phase = ""
	_sdp = ""
	_ice = []
	_sealed = false
	_opened_at = 0
	_sdp_at = 0

func _open(as_host: bool) -> Error:
	_pc = WebRTCPeerConnection.new()
	var err: Error = _pc.initialize(_config())
	if err != OK:
		note = "WebRTC did not start."
		shutdown()
		return err
	var mp: WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()
	if as_host:
		err = mp.create_server()
	else:
		err = mp.create_client(GUEST_ID)
	if err != OK:
		note = "The session did not open."
		shutdown()
		return err
	var remote_id: int = GUEST_ID if as_host else 1
	err = mp.add_peer(_pc, remote_id, 1)
	if err != OK:
		note = "The data channel did not open."
		shutdown()
		return err
	_pc.session_description_created.connect(_on_sdp)
	_pc.ice_candidate_created.connect(_on_ice)
	peer = mp
	return OK

func _config() -> Dictionary:
	var server: Dictionary = {"urls": [STUN_URL]}
	return {"iceServers": [server]}

func _on_sdp(type: String, sdp: String) -> void:
	if type != "offer" and type != "answer":
		return
	_sdp = sdp
	_sdp_at = Time.get_ticks_msec()
	if _pc.set_local_description(type, sdp) != OK:
		note = "The local description was rejected."

func _on_ice(media: String, index: int, name: String) -> void:
	if name == "":
		return
	_ice.append([media, index, name])

func _add_ice(raw: Variant) -> void:
	if _pc == null or typeof(raw) != TYPE_ARRAY:
		return
	var rows: Array = raw
	for item: Variant in rows:
		if typeof(item) != TYPE_ARRAY:
			continue
		var triple: Array = item
		if triple.size() != 3:
			continue
		_pc.add_ice_candidate(str(triple[0]), int(triple[1]), str(triple[2]))
