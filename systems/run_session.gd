extends Node

const MapState = preload("res://systems/map_state.gd")
const SAVE = "user://map_run_v1.json"
var world
var encounter: Dictionary = {}
var notice = ""

func ensure_world() -> void:
	if world != null: return
	var definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	world = MapState.new(definitions,Time.get_ticks_usec())
	if FileAccess.file_exists(SAVE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if not parsed is Dictionary or not world.restore(parsed): notice = "저장된 맵을 읽지 못해 새 원정을 시작했습니다."

func save_world() -> bool:
	var file = FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
	if file == null:
		notice = "저장에 실패했습니다."
		return false
	file.store_string(JSON.stringify(world.snapshot()))
	file.flush()
	var error = file.get_error()
	file.close()
	if error!=OK: return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE+".tmp"),ProjectSettings.globalize_path(SAVE))==OK

func start_encounter(index: int, selected_ids: Array) -> bool:
	if index<0 or index>=world.tiles.size() or index in world.cleared: return false
	if not world.tiles[index] in ["monster","rare-monster","boss"]: return false
	if selected_ids.is_empty() or selected_ids.size()>4: return false
	var allies: Array = []
	var used: Array = []
	for id in selected_ids:
		if used.has(id): return false
		var unit: Dictionary = {}
		for owned in world.roster:
			if owned.id==id and owned.current_hp>0: unit = owned
		if unit.is_empty(): return false
		used.append(id)
		allies.append(unit.duplicate(true))
	var rules = load("res://systems/battlefield_rules.gd").new(world.definitions,world.rng.randi())
	var type: String = world.tiles[index]
	var slugs = ["goblin-rider"]
	if type=="rare-monster": slugs = ["ghoul","skeleton-spear"]
	elif type=="boss": slugs = ["death-knight","minotaur","orc-warrior","boulder-ogre"]
	elif world.contamination>=40: slugs = ["goblin-rider","orc-warrior"]
	var enemies: Array = []
	for i in range(slugs.size()): enemies.append(rules.individual(slugs[i],"enemy-"+str(i)))
	encounter = {"index":index,"type":type,"allies":allies,"enemies":enemies}
	save_world()

	return true

func finish_encounter(battle) -> void:
	if encounter.is_empty(): return
	var survivors: Array = []
	for owned in world.roster:
		var fought: Dictionary = battle.find_id(owned.id)
		if not fought.is_empty():
			if not fought.alive: continue
			owned.current_hp = mini(owned.max_hp,fought.hp)
		survivors.append(owned)
	world.roster = survivors
	if battle.winner()=="ally":
		if not encounter.index in world.cleared: world.cleared.append(encounter.index)
		notice = "전투 승리 · 마물 타일을 정리했습니다."
	else: notice = "전투 패배 · 생존한 마물과 함께 맵으로 돌아왔습니다."
	encounter = {}
	save_world()
