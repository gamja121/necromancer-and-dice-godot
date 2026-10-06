class_name Expedition
extends RefCounted

const Rules = preload("res://systems/battle_rules.gd")
const STARTERS = ["skeleton-spear","skeleton-archer","skeleton-cavalry","grave-priest","goblin-chief","goblin-soldier","sea-wolf","ghoul"]
const NODES = ["출발","안개 길","전투","버려진 제단","이벤트","갈림길","전투","고요한 숲","이벤트","성문","전투","보스"]
var data: Dictionary
var rng = RandomNumberGenerator.new()
var roster: Array = []
var formation: Array = []
var position = 0
var destination = 0
var phase = "formation"
var souls = 0
var serial = 0
var message = "마물 카드를 눌러 최대 네 마리를 편성하세요."
var last_face = 0
var battle
var reward: Dictionary = {}
var completed: Array = []
var log_lines: Array = []

func _init(definitions: Dictionary = {}, seed_value: int = 1) -> void:
	data = definitions
	rng.seed = seed_value
	battle = Rules.new(data,rng.randi())
	for slug in STARTERS:
		roster.append(battle.individual(slug,next_id()))
	formation = roster.slice(0,4).map(func(u): return u.id)

func next_id() -> String:
	serial += 1
	return "owned_%d" % serial

func selected() -> Array:
	return roster.filter(func(u): return u.id in formation)

func toggle(id: String) -> void:
	if phase != "formation": return
	if id in formation:
		formation.erase(id)
	elif formation.size()<4:
		formation.append(id)

func depart() -> void:
	if phase != "formation" or formation.is_empty(): return
	phase = "board"
	message = "주사위를 굴려 원정을 시작하세요."

func roll_move() -> void:
	if phase != "board": return
	last_face = rng.randi_range(1,6)
	destination = mini(position+last_face,NODES.size()-1)
	# Short prototype route: major encounters crossed on the way also stop movement.
	for index in range(position+1,destination+1):
		if index in [2,4,6,8,10,11] and not index in completed:
			destination = index
			break
	position = destination
	message = "주사위 %d · %s 도착" % [last_face,NODES[position]]
	if position in [2,6,10,11] and not position in completed:
		start_battle()
	elif position in [4,8] and not position in completed:
		phase = "event"
		message = "떠도는 영혼이 도움을 청합니다. 계약을 선택하세요."

func choose_event(growth: bool) -> void:
	if phase != "event": return
	if growth and not selected().is_empty():
		selected()[0].max_hp += 2
		message = "%s 최대 체력 +2 · 원정 동안 유지" % selected()[0].name
	else:
		souls += 3
		message = "영혼 +3 획득"
	completed.append(position)
	phase = "board"

func start_battle() -> void:
	var enemy_slugs = ["goblin-soldier","sea-wolf"]
	if position == 6: enemy_slugs = ["ghoul","skeleton-spear","skeleton-archer"]
	if position == 10: enemy_slugs = ["goblin-chief","goblin-soldier","sea-wolf"]
	if position == 11: enemy_slugs = ["death-knight","grave-priest","skeleton-spear","skeleton-archer"]
	var enemies: Array = []
	for i in range(enemy_slugs.size()):
		enemies.append(battle.individual(enemy_slugs[i],"enemy_%d_%d" % [position,i]))
	battle.start(selected(),enemies)
	log_lines = []
	phase = "battle"
	message = "전투 시작 · 군단은 진입 시 고정됩니다."

func battle_round() -> void:
	if phase != "battle": return
	var result = battle.step()
	last_face = result.face
	message = "%d라운드 · 주사위 %d" % [result.round,result.face]
	log_lines.append(message)
	log_lines.append("행동 순서: " + " → ".join(result.get("order",[])))
	log_lines.append_array(result.events)
	if log_lines.size()>120: log_lines = log_lines.slice(-120)
	if not result.winner.is_empty():
		finish_battle(result.winner)
	elif result.round >= 200:
		phase = "ended"
		message = "판정 제한에 도달했습니다. 원정 종료 (검증용 안전 한도)."

func finish_battle(winner_team: String) -> void:
	if phase != "battle": return
	var dead_ids: Array = []
	for u in battle.units:
		if u.team == "ally" and not u.is_summon and not u.alive:
			dead_ids.append(u.id)
	roster = roster.filter(func(u): return not u.id in dead_ids)
	formation = formation.filter(func(id): return not id in dead_ids)
	completed.append(position)
	if winner_team != "ally":
		phase = "ended"
		message = "군단이 전멸했습니다. 원정 실패."
		return
	souls += 2
	var corpses = battle.units.filter(func(u): return u.team == "enemy" and not u.is_summon)
	reward = {"target":corpses[0].slug,"threshold":rng.randi_range(2,6),"attempts":2 if battle.active("ally","corpse") else 1,"done":false,"claimed":false}
	phase = "reward"
	message = "전투 승리 · 영혼 +2 · 전사 마물 %d마리 영구 손실" % dead_ids.size()

func harvest() -> void:
	if phase != "reward" or reward.done: return
	last_face = rng.randi_range(1,6)
	reward.attempts -= 1
	if last_face >= reward.threshold:
		var u = battle.individual(reward.target,next_id())
		roster.append(u)
		if formation.size()<4: formation.append(u.id)
		reward.done = true
		reward.claimed = true
		message = "주사위 %d · %s 영입 성공" % [last_face,u.name]
	else:
		reward.done = reward.attempts<=0
		message = "주사위 %d · 영입 실패 · 남은 기회 %d" % [last_face,reward.attempts]

func leave_reward() -> void:
	if phase != "reward": return
	reward.done = true
	phase = "ended" if position == 11 else "board"
	if phase == "ended": message = "보스 격파 · 첫 원정 완료! 영혼 %d" % souls

func edit_formation() -> void:
	if phase != "board": return
	phase = "formation"
	message = "다음 전투에 참가할 마물을 편성하세요."

func snapshot() -> Dictionary:
	return {"version":1,"roster":roster.duplicate(true),"formation":formation.duplicate(),"position":position,"destination":destination,"phase":phase,"souls":souls,"serial":serial,"message":message,"last_face":last_face,"reward":reward.duplicate(true),"completed":completed.duplicate(),"log":log_lines.duplicate(),"rng_seed":str(rng.seed),"rng_state":str(rng.state),"battle":battle.snapshot()}

func restore(saved: Dictionary) -> bool:
	if saved.get("version",0)!=1 or not saved.get("roster") is Array or not saved.get("formation") is Array:
		return false
	if not saved.get("phase","") in ["formation","board","battle","reward","event","ended"]:
		return false
	for key in ["destination","souls","serial","message","last_face","reward","completed","log","rng_seed","rng_state","battle"]:
		if not saved.has(key): return false
	if not saved.reward is Dictionary or not saved.completed is Array or not saved.log is Array: return false
	if saved.formation.size()>4: return false
	if saved.phase=="reward":
		for key in ["target","threshold","attempts","done","claimed"]:
			if not saved.reward.has(key): return false
	if int(saved.get("position",-1))<0 or int(saved.position)>=NODES.size(): return false
	for u in saved.roster:
		if not u is Dictionary or not data.has(u.get("slug","")): return false
		for key in ["id","name","max_hp","attack","speed","passive","legions","brands","is_summon"]:
			if not u.has(key): return false
		if not u.brands is Array: return false
		for b in u.brands:
			if not b is Dictionary or not b.get("bless") is Array or not b.get("curse") is Array: return false
	if not battle.restore(saved.get("battle",{})): return false
	roster = saved.roster.duplicate(true)
	for u in roster:
		for field in ["max_hp","attack","speed"]: u[field] = int(u[field])
		for b in u.brands:
			b.bless = b.bless.map(func(face): return int(face))
			b.curse = b.curse.map(func(face): return int(face))
	formation = saved.formation.duplicate()
	position = int(saved.position)
	destination = int(saved.destination)
	phase = saved.phase
	souls = int(saved.souls)
	serial = int(saved.serial)
	message = saved.message
	last_face = int(saved.last_face)
	reward = saved.reward.duplicate(true)
	completed = saved.completed.map(func(index): return int(index))
	log_lines = saved.log.duplicate()
	rng.seed = int(saved.rng_seed)
	rng.state = int(saved.rng_state)
	return true

func save_to(path: String) -> Error:
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(snapshot()))
	file.close()
	return DirAccess.rename_absolute(path+".tmp",path)

func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed is Dictionary and restore(parsed)
