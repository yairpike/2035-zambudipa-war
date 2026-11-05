extends Node
## Host match: seat the guest, apply their orders, and stream a delta snapshot.

const Lan = preload("res://game/lan_link.gd")
const Seat = preload("res://game/lan_seat.gd")

var _acc: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not Lan.active_host():
		return
	var host: Node = get_parent()
	if host == null:
		return
	var seat: Seat = Lan.seat()
	seat.try_seat(host)
	Lan.pump()
	var raw: String = Lan.take()
	while raw != "":
		var kind: String = seat.ingest(raw)
		if kind == "cmd":
			seat.apply_line(host, raw)
			Lan.send({"k": "ack", "note": seat.last_note})
		raw = Lan.take()
	Lan.watch(delta)
	if not Lan.holding():
		seat.tick_guest(delta)
	_acc += delta
	if _acc >= 0.1:
		_acc = 0.0
		Lan.broadcast_state(host)
	_banner(host)

func _banner(host: Node) -> void:
	var seat: Seat = Lan.seat()
	if seat.winner == "" and not seat.paused:
		return
	var status: Label = host.find_child("Status", true, false) as Label
	if status == null:
		return
	if seat.winner == "host":
		var outcome: SMOutcome = host.get("outcome") as SMOutcome
		if outcome != null and not outcome.over:
			outcome.finish(true, "The other player left the match.")
		status.text = "Opponent left. Victory."
	elif seat.winner == "guest":
		var lost: SMOutcome = host.get("outcome") as SMOutcome
		if lost != null and not lost.over:
			lost.finish(false, "The other player left the match.")
		status.text = "Opponent left. Defeat."
	elif seat.paused:
		status.text = "Paused. Waiting for the other player."
