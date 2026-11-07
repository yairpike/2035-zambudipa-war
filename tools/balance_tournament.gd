extends SceneTree
## Headless bot-versus-bot matches on Normal.
## Each faction pair, including mirrors, plays every skirmish map
## with all three commanders and five seeds.
## One line of JSON per match is appended to the output path.

const STEP: float = 0.25
const LIMIT: float = 720.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var pilot: bool = OS.get_environment("BALANCE_PILOT") == "1"
	var out_path: String = OS.get_environment("BALANCE_OUT")
	if out_path == "":
		out_path = "/tmp/balance-matches.jsonl"
	var handle: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if handle == null:
		push_error("balance tournament could not open %s" % out_path)
		quit(1)
		return
	var started: int = Time.get_ticks_msec()
	var played: int = 0
	for map_id: String in _maps():
		for home_id: String in _factions():
			for away_id: String in _factions():
				for who: String in _commanders():
					for seed: int in _seed_count():
						var row: Dictionary = await _match(map_id, home_id, away_id, who, seed)
						handle.store_line(JSON.stringify(row))
						handle.flush()
						played += 1
						print("match ", played, " ", map_id, " ", home_id, " vs ", away_id, " ", who, " seed ", seed, " ", row["winner"], " ", row["seconds"])
						if pilot:
							handle.close()
							print("pilot seconds ", snapped(float(Time.get_ticks_msec() - started) / 1000.0, 0.1))
							quit()
							return
	handle.close()
	print("tournament matches ", played, " wall ", snapped(float(Time.get_ticks_msec() - started) / 1000.0, 0.1))
	quit()

func _match(map_id: String, home_id: String, away_id: String, who: String, seed: int) -> Dictionary:
	var host: Node3D = Node3D.new()
	host.name = "BalanceMatch"
	root.add_child(host)
	var cam: RTSCamera = RTSCamera.new()
	host.add_child(cam)
	var grid: SMDomainGrid = _layout(map_id)
	var field: SMPointer = SMPointer.new()
	field.bind_faction(host, cam, home_id)
	field.use_domain(grid)
	var homes: Array[Vector2i] = _homes(map_id)
	var home: SMRaider = SMRaider.new()
	var away: SMRaider = SMRaider.new()
	home.node_id = &"home_ruby"
	away.node_id = &"away_ruby"
	home.attach(field, grid.cell_center(homes[0]), SMPointer.PLAYER)
	away.attach(field, grid.cell_center(homes[1]), SMPointer.ENEMY)
	home.personality_name = who
	away.personality_name = who
	home.bind_faction(home_id)
	away.bind_faction(away_id)
	home.set_seed(seed)
	away.set_seed(seed + 3)
	home.apply_pace(1.0, 1.0, 1.0, 1.0)
	away.apply_pace(1.0, 1.0, 1.0, 1.0)
	var outcome: SMOutcome = SMOutcome.new()
	var clock: float = 0.0
	var winner: String = "draw"
	var side: String = "draw"
	while clock < LIMIT and not outcome.over:
		home.tick(STEP)
		away.tick(STEP)
		home.goods.advance(STEP, home.economy)
		away.goods.advance(STEP, away.economy)
		field.tick(STEP)
		var players: Array[SMBuildYard] = []
		var foes: Array[SMBuildYard] = []
		players.append(home.yard)
		foes.append(away.yard)
		outcome.tick(field, players, foes, STEP)
		clock += STEP
		if int(clock / STEP) % 160 == 0:
			await process_frame
	var home_score: int = field.count_team(SMPointer.PLAYER) * 2 + home.yard.living_count() * 3
	var away_score: int = field.count_team(SMPointer.ENEMY) * 2 + away.yard.living_count() * 3
	if outcome.over:
		side = "home" if outcome.victory else "away"
	elif home_score > away_score:
		side = "home"
	elif away_score > home_score:
		side = "away"
	if side == "home":
		winner = home_id
	elif side == "away":
		winner = away_id
	var row: Dictionary = {
		"map": map_id,
		"home": home_id,
		"away": away_id,
		"commander": who,
		"seed": seed,
		"winner": winner,
		"side": side,
		"seconds": snapped(clock, 0.1),
		"capped": not outcome.over,
		"home_built": home.trained.duplicate(),
		"away_built": away.trained.duplicate(),
	}
	host.free()
	await process_frame
	return row

func _factions() -> PackedStringArray:
	return PackedStringArray(["gtfc", "nmrf", "mvd", "black_market"])

func _commanders() -> PackedStringArray:
	var picked: String = OS.get_environment("BALANCE_COMMANDERS")
	if picked == "":
		return PackedStringArray(["Bo Mya", "Iskandar", "Tran"])
	var out: PackedStringArray = PackedStringArray()
	for part: String in picked.split(",", false):
		var name: String = part.strip_edges()
		if name != "":
			out.append(name)
	return out

func _maps() -> PackedStringArray:
	var picked: String = OS.get_environment("BALANCE_MAPS")
	if picked == "":
		return PackedStringArray(["phillips", "sop_ruak", "burma_road", "ten_degree_atolls", "mekong_delta", "chiang_rai"])
	var out: PackedStringArray = PackedStringArray()
	for part: String in picked.split(",", false):
		var name: String = part.strip_edges()
		if name != "":
			out.append(name)
	return out

func _seed_count() -> int:
	var picked: String = OS.get_environment("BALANCE_SEEDS")
	if picked == "":
		return 5
	return clampi(int(picked), 1, 5)

func _layout(map_id: String) -> SMDomainGrid:
	if map_id == "sop_ruak":
		return SMDomainGrid.sop_ruak_layout()
	if SMMapPlan.exists(map_id):
		return SMMapPlan.of(map_id).grid()
	return SMDomainGrid.phillips_layout()

func _homes(map_id: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if SMMapPlan.exists(map_id):
		var plan: SMMapPlan = SMMapPlan.of(map_id)
		cells = [plan.start(0), plan.start(plan.starts.size() / 2)]
	elif map_id == "sop_ruak":
		cells = [SMDomainGrid.at("sop_ruak", Vector2i(8, 22)), SMDomainGrid.at("sop_ruak", Vector2i(26, 22))]
	else:
		cells = [SMDomainGrid.at("phillips", Vector2i(1, 8)), SMDomainGrid.at("phillips", Vector2i(30, 12))]
	return cells
