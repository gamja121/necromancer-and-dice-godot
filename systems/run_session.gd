extends Node

const RoutePlan = preload("res://systems/route_plan.gd")
const EncounterGenerator = preload("res://systems/encounter_generator.gd")
const BrandInheritance = preload("res://systems/brand_inheritance.gd")
const DiceControl = preload("res://systems/dice_control.gd")
const Catalog = preload("res://systems/reward_catalog.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const MapState = preload("res://systems/map_state.gd")
const SAVE = "user://map_run_v1.json"
const RITUAL_EVENT_ID = "ritual_portal_trace_01"
const HUNT_EVENT_ID = "monster_king_hunt_trace_01"
var world
var encounter: Dictionary = {}
var notice = ""

func has_save() -> bool:
	return FileAccess.file_exists(SAVE)

func start_new_world() -> void:
	var definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	world = MapState.new(definitions,Time.get_ticks_usec())
	encounter = {}
	notice = ""
	save_world()

func reload_world() -> void:
	world = null
	encounter = {}
	notice = ""
	ensure_world()

func ensure_world() -> void:
	if world != null: return
	var definitions = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	world = MapState.new(definitions,Time.get_ticks_usec())
	if FileAccess.file_exists(SAVE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if not parsed is Dictionary or not world.restore(parsed): notice = "저장된 맵을 읽지 못해 새 원정을 시작했습니다."
	encounter = world.active_encounter.duplicate(true)

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

## Story/event flags are transiently edited in world, then saved atomically.
## The caller supplies canonical flag names from the reference story runtime.
func event_flag_is_set(flag: String) -> bool:
	if world == null or flag.is_empty(): return false
	return world.event_flags.get(flag,false) == true

func set_event_flag(flag: String, enabled: bool = true) -> bool:
	if world == null or flag.is_empty(): return false
	# Repeated notifications must not create duplicate writes or state changes.
	if world.event_flags.has(flag) and world.event_flags[flag] == enabled: return true
	var before: Dictionary = world.snapshot().duplicate(true)
	world.event_flags[flag] = enabled
	# persist_change restores the original snapshot on save failure.
	return persist_change(before)

## A missing event has the implicit "unseen" state.
func get_story_event(event_id: String) -> Dictionary:
	var initial: Dictionary = {"status":"unseen","choice":"","battle_result":""}
	if world == null or event_id.is_empty(): return initial
	var entry: Dictionary = world.story_events.get(event_id,initial).duplicate(true)
	# Entries saved before P1-02C did not contain battle_result.
	if not entry.has("battle_result"): entry["battle_result"] = ""
	return entry

## Forward-only transition: unseen -> seen -> active -> complete.
## Repeated requests for the same status are safe and do not rewrite the save.
func advance_story_event(event_id: String, next_status: String) -> bool:
	if world == null or event_id.is_empty(): return false
	const ORDER = {"unseen":0,"seen":1,"active":2,"complete":3}
	if not ORDER.has(next_status) or next_status == "unseen": return false
	# Ritual/hunt completion must persist their linked quest flags atomically.
	if next_status == "complete" and event_id in [RITUAL_EVENT_ID,HUNT_EVENT_ID]: return false
	var current: Dictionary = get_story_event(event_id)
	var step: int = ORDER[next_status] - ORDER[current.status]
	if step == 0: return true
	if step != 1: return false
	var before: Dictionary = world.snapshot().duplicate(true)
	world.story_events[event_id] = {"status":next_status,"choice":current.choice,"battle_result":current.battle_result}
	return persist_change(before)

## Choice can be committed once while active. It cannot be silently overwritten.
func choose_story_event(event_id: String, choice_id: String) -> bool:
	if world == null or event_id.is_empty() or choice_id.is_empty(): return false
	var current: Dictionary = get_story_event(event_id)
	if current.status != "active": return false
	if current.choice == choice_id: return true
	if not current.choice.is_empty(): return false
	var before: Dictionary = world.snapshot().duplicate(true)
	world.story_events[event_id] = {"status":"active","choice":choice_id,"battle_result":current.battle_result}
	return persist_change(before)

## Only active story battles may commit an outcome; a completed result is immutable.
## Battle runtime must pass the actual win/loss when post-battle persistence is ready.
func record_story_battle_result(event_id: String, won: bool) -> bool:
	if world == null or event_id.is_empty(): return false
	var current: Dictionary = get_story_event(event_id)
	if current.status != "active": return false
	var result: String = "won" if won else "lost"
	if current.battle_result == result: return true
	if not current.battle_result.is_empty(): return false
	var before: Dictionary = world.snapshot().duplicate(true)
	world.story_events[event_id] = {"status":"active","choice":current.choice,"battle_result":result}
	return persist_change(before)

## Exactly one of the two canonical revival flags may be true.
func monster_king_revival_state() -> String:
	if world == null: return ""
	var weak: bool = world.event_flags.get("story:monster_king:revival_weakened",false) == true
	var full: bool = world.event_flags.get("story:monster_king:revival_complete",false) == true
	if weak == full: return ""
	return "weakened" if weak else "full"

## Mirrors web hunt preconditions without opening any tile/event by itself.
func monster_king_hunt_eligible() -> bool:
	if world == null or monster_king_revival_state().is_empty(): return false
	var flags: Dictionary = world.event_flags
	return (
		flags.get("event:ritual_portal_trace_01:complete",false) == true
		and flags.get("story:monster_king:revived",false) == true
		and flags.get("quest:monster_king_hunt:active",false) == true
		and flags.get("event:monster_king_hunt_trace_01:complete",false) != true
	)

## Called ONLY after the actual ritual battle result has been durably recorded.
## Finishing the ritual sets all matching web flags in one save transaction.
func finalize_ritual_portal_outcome() -> bool:
	if world == null: return false
	var current: Dictionary = get_story_event(RITUAL_EVENT_ID)
	if current.battle_result not in ["won","lost"]: return false
	var won: bool = current.battle_result == "won"
	if current.status == "complete":
		return (
			world.event_flags.get("event:ritual_portal_trace_01:complete",false) == true
			and world.event_flags.get("story:monster_king:revived",false) == true
			and monster_king_revival_state() == ("weakened" if won else "full")
		)
	if current.status != "active": return false
	if world.event_flags.get("event:ritual_portal_trace_01:complete",false) == true: return false
	if world.event_flags.get("story:monster_king:revived",false) == true: return false
	var before: Dictionary = world.snapshot().duplicate(true)
	world.story_events[RITUAL_EVENT_ID] = {"status":"complete","choice":current.choice,"battle_result":current.battle_result}
	var changes: Dictionary = {
		"event:ritual_portal_trace_01:seen": true,
		"event:ritual_portal_trace_01:complete": true,
		"story:ritual_portal:found": true,
		"story:monster_king:ritual_site_location_known": true,
		"quest:ritual_site_tracking:active": false,
		"quest:ritual_site_tracking:complete": true,
		"quest:ritual_intervention:active": false,
		"battle:ritual_portal_trace_01:won": won,
		"battle:ritual_portal_trace_01:lost": not won,
		"story:monster_king:revived": true,
		"story:monster_king:revival_weakened": won,
		"story:monster_king:revival_complete": not won,
		"quest:monster_king_hunt:active": true
	}
	for flag in changes: world.event_flags[flag] = changes[flag]
	return persist_change(before)

## Later story presentation can use this after the hunt scene is genuinely over.
## It does not start the final battle or alter the pre-existing boss tile.
func complete_monster_king_hunt() -> bool:
	if world == null: return false
	var current: Dictionary = get_story_event(HUNT_EVENT_ID)
	var flags: Dictionary = world.event_flags
	if current.status == "complete":
		return (
			flags.get("event:monster_king_hunt_trace_01:complete",false) == true
			and flags.get("quest:monster_king_hunt:complete",false) == true
			and flags.get("quest:monster_king_hunt:active",false) == false
		)
	if current.status != "active" or not monster_king_hunt_eligible(): return false
	var before: Dictionary = world.snapshot().duplicate(true)
	world.story_events[HUNT_EVENT_ID] = {"status":"complete","choice":current.choice,"battle_result":current.battle_result}
	var changes: Dictionary = {
		"event:monster_king_hunt_trace_01:seen": true,
		"event:monster_king_hunt_trace_01:complete": true,
		"quest:monster_king_hunt:active": false,
		"quest:monster_king_hunt:complete": true,
		"story:monster_king:sealed_ruins_location_known": true,
		"quest:monster_king_final_battle:active": true
	}
	for flag in changes: world.event_flags[flag] = changes[flag]
	return persist_change(before)

func start_encounter(index: int, selected_ids: Array) -> bool:
	var mimic = world.pending_reward.get("kind","")=="mimic" and int(world.pending_reward.get("index",-1))==index
	if (not world.pending_reward.is_empty() and not mimic) or not encounter.is_empty() or not world.pending_move.is_empty(): return false
	if index<0 or index>=world.tiles.size() or (not mimic and index in world.cleared): return false
	if not world.tiles[index] in (["gem"] if mimic else ["monster","rare-monster","boss"]): return false
	if selected_ids.is_empty() or selected_ids.size()>4: return false
	var before: Dictionary = world.snapshot().duplicate(true)
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
	var type: String = "mimic" if mimic else world.tiles[index]
	var slugs: Array = []
	if mimic:
		for i in range(int(world.pending_reward.count)): slugs.append("mimic")
	else:
		var intel: Dictionary = {}
		for entry in active_scout_intel():
			if int(entry.index)==index: intel=entry; break
		slugs = EncounterGenerator.slugs(world.definitions,world.contamination,world.laps+1,world.rng,intel)
	if slugs.is_empty():
		world.restore(before)
		return false
	var enemies: Array = []
	for i in range(slugs.size()): enemies.append(rules.individual(slugs[i],"enemy-"+str(i)))
	rules.start(allies,enemies)
	for unit in rules.units:
		if unit.team=="ally": unit.hp = mini(unit.max_hp,unit.get("current_hp",unit.max_hp)+(unit.max_hp-unit.base_hp))
	var prophecy = world.prophecy.duplicate(true)
	for unit in rules.units:
		if unit.team=="ally":
			unit.max_hp += int(prophecy.get("ally_hp",0))
			unit.hp += int(prophecy.get("ally_hp",0))
			unit.base_attack += int(prophecy.get("ally_attack",0))
			unit.attack += int(prophecy.get("ally_attack",0))
			unit.base_speed += int(prophecy.get("ally_speed",0))
			unit.speed += int(prophecy.get("ally_speed",0))
		else:
			unit.base_attack += int(prophecy.get("enemy_attack",0))
			unit.attack += int(prophecy.get("enemy_attack",0))
	world.prophecy = {"rolls":[]}
	encounter = {"id":world.next_id("encounter"),"index":index,"type":type,"allies":allies,"enemies":enemies,"checkpoint":rules.snapshot(),"phase":"ready","prophecy":prophecy,"previous_roll":0,"previous_card":""}
	if mimic:
		world.reward_receipts.append(world.pending_reward.id)
		world.pending_reward = {}
	world.active_encounter = encounter.duplicate(true)
	if not persist_change(before):
		encounter = {}
		return false
	return true

func finish_encounter(battle) -> bool:
	if encounter.is_empty(): return true
	if battle.winner().is_empty(): return false
	var before: Dictionary = world.snapshot().duplicate(true)
	var survivors: Array = []
	for owned in world.roster:
		var fought: Dictionary = battle.find_id(owned.id)
		if not fought.is_empty():
			if not fought.alive:
				world.graveyard_corpses.append(owned.duplicate(true))
				continue
			var temporary_bonus: int = maxi(0,fought.max_hp-owned.max_hp)
			owned.current_hp = clampi(fought.hp-temporary_bonus,1,owned.max_hp)
		survivors.append(owned)
	world.roster = survivors
	if battle.winner()=="ally":
		if encounter.type in ["monster","rare-monster","boss"] and not encounter.index in world.cleared: world.cleared.append(encounter.index)
		world.contamination = maxi(0,world.contamination-1)
		var corpses: Array = []
		for unit in battle.units:
			if unit.team=="enemy" and not unit.alive and not unit.is_summon:
				corpses.append({"id":unit.id,"slug":unit.slug,"name":unit.name,"target":world.rng.randi_range(2,6)})
		if not corpses.is_empty():
			world.pending_reward = {"id":"capture-"+encounter.id,"kind":"capture","corpses":corpses,"selected":0,"locked":false,"max_attempts":2 if battle.active("ally","corpse") else 1,"attempts":2 if battle.active("ally","corpse") else 1,"phase":"choose","battle":battle.snapshot(),"face":battle.face}
		notice = "미믹 격퇴 · 오염도 -1" if encounter.type=="mimic" else "전투 승리 · 오염도 -1 · 마물 타일을 정리했습니다."
	else: notice = "전투 패배 · 생존한 마물과 함께 맵으로 돌아왔습니다."
	world.active_encounter = {}
	if not persist_change(before): return false
	encounter = {}
	return true

func persist_change(before: Dictionary) -> bool:
	if save_world(): return true
	world.restore(before)
	encounter = world.active_encounter.duplicate(true)
	notice = "저장에 실패했습니다. 다시 시도하세요."
	return false

func create_item(kind: String, source: Dictionary) -> Dictionary:
	if kind=="unit":
		var rules = Rules.new(world.definitions,world.rng.randi())
		var item: Dictionary = rules.individual(source.slug,world.next_id("unit"))
		item.current_hp = item.max_hp
		return item
	if kind=="dice":
		var item = source.duplicate(true)
		item.id = world.next_id("dice-card")
		return item
	var rules = Rules.new(world.definitions,world.rng.randi())
	var keys: Array = rules.COUNTS.keys()
	var brand: Dictionary = rules.make_brand(keys[world.rng.randi_range(0,keys.size()-1)])
	brand.curse = []
	return {"id":world.next_id("brand-card"),"brand":brand}

func open_treasure(index: int = -1) -> bool:
	if not encounter.is_empty() or not world.pending_move.is_empty(): return false
	if not world.pending_reward.is_empty(): return world.pending_reward.get("kind","") in ["treasure","mimic"]
	if index<0: index = world.position
	if index<0 or index>=world.tiles.size() or world.tiles[index]!="gem": return false
	var visit_id = "treasure-visit:%d:%d:%d" % [world.laps,world.move_serial,index]
	if visit_id in world.reward_receipts:
		notice = "이번 방문의 보물상자 보상은 이미 받았습니다."
		return false
	var before: Dictionary = world.snapshot().duplicate(true)
	if world.rng.randf()<0.10:
		world.pending_reward = {"id":visit_id,"kind":"mimic","index":index,"count":EncounterGenerator.mimic_count(world.contamination,world.laps+1)}
		return persist_change(before)
	var pool: Array = []
	for slug in world.definitions:
		if world.definitions[slug].grade!="special": pool.append({"kind":"unit","source":{"slug":slug,"name":world.definitions[slug].name}})
	for card in Catalog.dice_cards(): pool.append({"kind":"dice","source":card})
	for i in range(3): pool.append({"kind":"brand","source":create_item("brand",{})})
	for i in range(pool.size()-1,0,-1):
		var j = world.rng.randi_range(0,i)
		var swap = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	world.pending_reward = {"id":visit_id,"kind":"treasure","offers":pool.slice(0,3),"selected":-1}
	return persist_change(before)

func select_treasure(index: int) -> bool:
	if world.pending_reward.get("kind","")!="treasure" or world.pending_reward.has("reward"): return false
	if index<0 or index>=world.pending_reward.offers.size(): return false
	var before: Dictionary = world.snapshot().duplicate(true)
	world.pending_reward.selected = index
	return persist_change(before)

func prepare_treasure_reward(index: int) -> bool:
	if world.pending_reward.get("kind","")!="treasure": return false
	if world.pending_reward.has("reward"): return int(world.pending_reward.selected)==index
	if int(world.pending_reward.selected)!=index: return false
	var before: Dictionary = world.snapshot().duplicate(true)
	var offer: Dictionary = world.pending_reward.offers[index]
	world.pending_reward.reward = {"kind":offer.kind,"item":offer.source.duplicate(true) if offer.kind=="brand" else create_item(offer.kind,offer.source)}
	return persist_change(before)

func select_capture(index: int) -> bool:
	if world.pending_reward.get("kind","")!="capture" or world.pending_reward.locked: return false
	if index<0 or index>=world.pending_reward.corpses.size(): return false
	var before: Dictionary = world.snapshot().duplicate(true)
	world.pending_reward.selected = index
	world.pending_reward.attempts = world.pending_reward.max_attempts
	return persist_change(before)

func roll_capture() -> Dictionary:
	if world.pending_reward.get("kind","")!="capture": return {"ok":false}
	var pending: Dictionary = world.pending_reward
	if not pending.phase in ["choose","retry"] or int(pending.attempts)<=0: return {"ok":false}
	var before: Dictionary = world.snapshot().duplicate(true)
	pending.locked = true
	pending.attempts = int(pending.attempts)-1
	pending.roll = world.rng.randi_range(1,6)
	var corpse: Dictionary = pending.corpses[int(pending.selected)]
	if pending.roll>=int(corpse.target):
		pending.phase = "success"
		pending.reward = {"kind":"unit","item":create_item("unit",corpse)}
	else: pending.phase = "retry" if pending.attempts>0 else "failed"
	if not persist_change(before): return {"ok":false}
	return {"ok":true,"face":pending.roll,"success":pending.phase=="success"}

func claim_reward(discard_id: String = "") -> Dictionary:
	var pending: Dictionary = world.pending_reward
	if pending.is_empty() or not pending.has("reward"): return {"ok":false}
	if pending.id in world.reward_receipts: return {"ok":false}
	var reward: Dictionary = pending.reward
	var items: Array = world.roster if reward.kind=="unit" else (world.dice_cards if reward.kind=="dice" else world.brand_cards)
	var capacity = Catalog.UNIT_CAPACITY if reward.kind=="unit" else (Catalog.DICE_CAPACITY if reward.kind=="dice" else 0)
	if capacity>0 and items.size()>=capacity:
		if discard_id.is_empty(): return {"ok":false,"overflow":true}
		if discard_id!="__new__" and not items.any(func(item): return item.id==discard_id): return {"ok":false}
	elif not discard_id.is_empty(): return {"ok":false}
	var before: Dictionary = world.snapshot().duplicate(true)
	var kept = discard_id!="__new__"
	if kept:
		if not discard_id.is_empty():
			for i in range(items.size()-1,-1,-1):
				if items[i].id==discard_id: items.remove_at(i)
		items.append(reward.item.duplicate(true))
	world.reward_receipts.append(pending.id)
	world.pending_reward = {}
	if not persist_change(before): return {"ok":false}
	return {"ok":true,"kept":kept}

func dismiss_failed_capture() -> bool:
	if world.pending_reward.get("phase","")!="failed": return false
	var before: Dictionary = world.snapshot().duplicate(true)
	world.reward_receipts.append(world.pending_reward.id)
	world.pending_reward = {}
	return persist_change(before)

func dice_context(battle: bool = false) -> Dictionary:
	return {"previous_roll":int(encounter.get("previous_roll",0)),"previous_card":str(encounter.get("previous_card",""))} if battle else {"previous_roll":world.previous_map_roll,"previous_card":world.previous_map_card}

func resolve_owned_card(instance_id: String, context: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var index = -1
	for i in range(world.dice_cards.size()):
		if str(world.dice_cards[i].id)==instance_id: index = i; break
	if index<0: return {"ok":false,"reason":"이 카드를 보유하고 있지 않습니다."}
	var resolved = DiceControl.resolve(str(world.dice_cards[index].card_id),context,rng)
	if resolved.ok: world.dice_cards.remove_at(index)
	return resolved

func prepare_map_roll(instance_id: String = "") -> Dictionary:
	if not encounter.is_empty() or not world.pending_reward.is_empty(): return {"ok":false,"reason":"지금은 이동할 수 없습니다."}
	if not world.pending_move.is_empty(): return {"ok":false,"reason":"이전 이동을 먼저 완료하세요."}
	var before: Dictionary = world.snapshot().duplicate(true)
	var result: Dictionary = {"ok":true,"face":0,"label":""}
	if not instance_id.is_empty():
		result = resolve_owned_card(instance_id,dice_context(),world.rng)
		if not result.ok: return result
	else: result.face = world.rng.randi_range(1,6)
	var origin = world.position
	var path = world.move_path(int(result.face))
	world.previous_map_roll = int(result.face)
	if result.has("effective_card"): world.previous_map_card = str(result.effective_card)
	var landed = world.position
	if world.tiles[landed]=="warp": world.position = world.warp_destination()
	elif world.tiles[landed]=="swamp":
		for unit in world.roster: unit.current_hp = maxi(1,unit.current_hp-1)
	world.pending_move = {"face":int(result.face),"label":str(result.label),"origin":origin,"path":path,"landed":landed}
	if not persist_change(before): return {"ok":false,"reason":notice}
	return world.pending_move.merged({"ok":true})

func complete_map_move() -> bool:
	if world.pending_move.is_empty(): return true
	var before: Dictionary = world.snapshot().duplicate(true)
	world.pending_move = {}
	return persist_change(before)

func prepare_battle_roll(battle, instance_id: String = "") -> Dictionary:
	if encounter.is_empty() or encounter.get("phase","ready")!="ready" or not battle.winner().is_empty(): return {"ok":false,"reason":"지금은 카드를 사용할 수 없습니다."}
	var before: Dictionary = world.snapshot().duplicate(true)
	var rules_before: Dictionary = battle.snapshot()
	var result: Dictionary = {"ok":true,"face":0,"label":""}
	if not instance_id.is_empty():
		result = resolve_owned_card(instance_id,dice_context(true),battle.rng)
		if not result.ok: return result
	else: result.face = battle.rng.randi_range(1,6)
	encounter.previous_roll = int(result.face)
	if result.has("effective_card"): encounter.previous_card = str(result.effective_card)
	encounter.roll = {"face":int(result.face),"label":str(result.label)}
	encounter.phase = "rolled"
	encounter.checkpoint = battle.snapshot()
	world.active_encounter = encounter.duplicate(true)
	if not persist_change(before):
		battle.restore(rules_before)
		return {"ok":false,"reason":notice}
	return result

func checkpoint_battle(battle, phase: String) -> bool:
	if encounter.is_empty(): return false
	var before: Dictionary = world.snapshot().duplicate(true)
	encounter.phase = phase
	encounter.checkpoint = battle.snapshot()
	world.active_encounter = encounter.duplicate(true)
	if persist_change(before): return true
	battle.restore(encounter.checkpoint)
	return false

func home_visit_id() -> String:
	return place_visit_id("inheritance",MapState.HOME)

func home_action_allowed() -> Dictionary:
	if not encounter.is_empty() or not world.active_encounter.is_empty() or not world.pending_reward.is_empty() or not world.pending_move.is_empty():
		return {"ok":false,"reason":"이동·전투·보상을 먼저 완료하세요."}
	if home_visit_id() in world.reward_receipts: return {"ok":false,"reason":"이번 방문의 계승은 완료했습니다."}
	return {"ok":true}

func enter_home() -> bool:
	if not encounter.is_empty() or not world.pending_reward.is_empty() or not world.pending_move.is_empty(): return false
	var before: Dictionary = world.snapshot().duplicate(true)
	for unit in world.roster: unit.current_hp = unit.max_hp
	return persist_change(before)

func owned_unit(instance_id: String) -> Dictionary:
	for unit in world.roster:
		if str(unit.id)==instance_id: return unit
	return {}

func inherit_at_home(receiver_id: String, donor_id: String = "", brand_card_id: String = "") -> Dictionary:
	var allowed = home_action_allowed()
	if not allowed.ok: return allowed
	var receiver = owned_unit(receiver_id)
	if receiver.is_empty(): return {"ok":false,"reason":"낙인을 받을 마물을 선택하세요."}
	if receiver.brands.size()>=3: return {"ok":false,"reason":"낙인 3칸이 찬 마물에는 계승할 수 없습니다."}
	if donor_id.is_empty()==brand_card_id.is_empty(): return {"ok":false,"reason":"재료 마물 또는 낙인 카드 하나를 선택하세요."}
	var before: Dictionary = world.snapshot().duplicate(true)
	var source: Dictionary = {}
	var donor: Dictionary = {}
	var card_index = -1
	if not brand_card_id.is_empty():
		for i in range(world.brand_cards.size()):
			if str(world.brand_cards[i].id)==brand_card_id: card_index = i; break
		if card_index<0: return {"ok":false,"reason":"이 낙인 카드를 보유하고 있지 않습니다."}
		source = world.brand_cards[card_index].brand
		if not BrandInheritance.validate(source) or source.bless.is_empty(): return {"ok":false,"reason":"적용할 수 없는 낙인 카드입니다."}
	else:
		if donor_id==receiver_id: return {"ok":false,"reason":"재료와 받는 마물은 달라야 합니다."}
		donor = owned_unit(donor_id)
		if donor.is_empty(): return {"ok":false,"reason":"재료 마물을 보유하고 있지 않습니다."}
		var brands = BrandInheritance.normalize(donor,world.definitions)
		if brands.is_empty(): return {"ok":false,"reason":"낙인이 없는 마물은 재료로 사용할 수 없습니다."}
		source = brands[world.rng.randi_range(0,brands.size()-1)]
	var applied = BrandInheritance.blessing(receiver,source,world.definitions)
	if applied.is_empty():
		# A failed random selection must not consume a material, but remains a new attempt.
		if not persist_change(before): return {"ok":false,"reason":notice}
		return {"ok":false,"reason":"기본 저주와 겹쳐 계승 가능한 축복 눈금이 없습니다."}
	receiver.brands = BrandInheritance.normalize(receiver,world.definitions)
	receiver.brands.append(applied)
	if card_index>=0: world.brand_cards.remove_at(card_index)
	else:
		for i in range(world.roster.size()-1,-1,-1):
			if str(world.roster[i].id)==donor_id: world.roster.remove_at(i); break
	world.reward_receipts.append(home_visit_id())
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"receiver":receiver.duplicate(true),"brand":applied.duplicate(true),"donor_id":donor_id,"card_id":brand_card_id}

func place_visit_id(kind: String, index: int) -> String:
	var legacy = "%s-visit:%d:%d:%d" % [kind,world.laps,world.move_serial,index]
	return legacy+(":map:%d" % world.map_serial if world.map_serial>0 else "")

func place_allowed(index: int, type: String) -> Dictionary:
	if index<0 or index>=world.tiles.size() or world.tiles[index]!=type:
		return {"ok":false,"reason":"이 장소에서는 사용할 수 없습니다."}
	if not encounter.is_empty() or not world.pending_reward.is_empty() or not world.pending_move.is_empty():
		return {"ok":false,"reason":"이동·전투·보상을 먼저 완료하세요."}
	return {"ok":true}

func altar_ritual(index: int, donor_id: String, receiver_id: String) -> Dictionary:
	var allowed = place_allowed(index,"altar")
	if not allowed.ok: return allowed
	var receipt = place_visit_id("ritual",index)
	if receipt in world.reward_receipts: return {"ok":false,"reason":"이번 방문의 의식은 완료했습니다."}
	var donor = owned_unit(donor_id)
	var receiver = owned_unit(receiver_id)
	if donor.is_empty() or receiver.is_empty() or donor_id==receiver_id:
		return {"ok":false,"reason":"서로 다른 재물과 강화 대상을 선택하세요."}
	if int(receiver.get("altar_enhancements",0))>=3:
		return {"ok":false,"reason":"이 마물은 강화 한도 3회에 도달했습니다."}
	var before: Dictionary = world.snapshot().duplicate(true)
	receiver.attack = int(receiver.attack)+1
	receiver.max_hp = int(receiver.max_hp)+2
	receiver.current_hp = mini(receiver.max_hp,int(receiver.current_hp)+2)
	receiver.altar_enhancements = int(receiver.get("altar_enhancements",0))+1
	world.roster = world.roster.filter(func(u): return str(u.id)!=donor_id)
	world.reward_receipts.append(receipt)
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"reason":"%s 강화 완료 · 공격력 +1 · 최대 체력 +2 · 강화 %d/3" % [receiver.name,receiver.altar_enhancements]}

func shop_offers(index: int, unit_id: String) -> Dictionary:
	var allowed = place_allowed(index,"village")
	if not allowed.ok: return allowed
	var unit = owned_unit(unit_id)
	if unit.is_empty() or world.roster.size()<=1:
		return {"ok":false,"reason":"마지막 마물은 교환할 수 없습니다."}
	var visit = place_visit_id("shop",index)
	if world.shop_trade.get("visit","")==visit and world.shop_trade.offers.has(unit_id):
		return {"ok":true,"offers":world.shop_trade.offers[unit_id].duplicate(true)}
	var before: Dictionary = world.snapshot().duplicate(true)
	if world.shop_trade.get("visit","")!=visit: world.shop_trade={"visit":visit,"offers":{}}
	var grade = str(unit.grade)
	var count = 5 if grade=="hero" else (4 if grade=="advanced" else 3)
	var pool = Catalog.dice_cards().filter(func(c): return grade=="hero" or (c.card_id!="echo" and (grade=="advanced" or c.card_id!="repeat")))
	var offers: Array = []
	for i in range(count):
		var brand = i%2==(0 if grade=="hero" else 1)
		if brand:
			offers.append({"kind":"brand","item":create_item("brand",{})})
		else:
			var choice = world.rng.randi_range(0,pool.size()-1)
			offers.append({"kind":"dice","item":create_item("dice",pool[choice])})
			pool.remove_at(choice)
	world.shop_trade.offers[unit_id] = offers
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"offers":offers.duplicate(true)}

func shop_trade(index: int, unit_id: String, offer_index: int) -> Dictionary:
	var allowed = place_allowed(index,"village")
	if not allowed.ok: return allowed
	if world.shop_trade.get("visit","")!=place_visit_id("shop",index) or not world.shop_trade.get("offers",{}).has(unit_id):
		return {"ok":false,"reason":"교환할 마물을 다시 선택하세요."}
	var offers: Array = world.shop_trade.offers[unit_id]
	if world.roster.size()<=1 or owned_unit(unit_id).is_empty() or offer_index<0 or offer_index>=offers.size():
		return {"ok":false,"reason":"거래할 수 없는 편성입니다."}
	var offer: Dictionary = offers[offer_index]
	if offer.kind=="dice" and world.dice_cards.size()>=Catalog.DICE_CAPACITY:
		return {"ok":false,"reason":"주사위 카드 보관함이 가득 찼습니다."}
	var before: Dictionary = world.snapshot().duplicate(true)
	var unit_name = owned_unit(unit_id).name
	world.roster = world.roster.filter(func(u): return str(u.id)!=unit_id)
	if offer.kind=="dice": world.dice_cards.append(offer.item.duplicate(true))
	else: world.brand_cards.append(offer.item.duplicate(true))
	world.shop_trade.offers.erase(unit_id)
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"reason":"%s ↔ %s 거래 완료" % [unit_name,Catalog.label(offer.kind,offer.item)]}

func prophecy_label() -> String:
	var parts: Array = []
	for pair in [["ally_attack","아군 공격"],["ally_hp","아군 체력"],["ally_speed","아군 속도"],["enemy_attack","적 공격"]]:
		var value = int(world.prophecy.get(pair[0],0))
		if value>0: parts.append("%s +%d" % [pair[1],value])
	return " · ".join(parts) if not parts.is_empty() else "누적 없음"

func fortune_prophecy(index: int) -> Dictionary:
	var allowed = place_allowed(index,"fortune-teller-camp")
	if not allowed.ok: return allowed
	var visit = place_visit_id("prophecy",index)
	if visit in world.reward_receipts:
		return {"ok":false,"reason":"이번 방문의 예언은 완료했습니다."}
	var before: Dictionary = world.snapshot().duplicate(true)
	var face = world.rng.randi_range(1,6)
	var descriptions = ["저주 · 다음 전투 적 공격 +1","축복 · 아군 전체 완전 회복","축복 · 다음 전투 아군 속도 +1","축복 · 다음 전투 아군 체력 +2","축복 · 다음 전투 아군 공격 +1","대축복 · 다음 전투 아군 공격 +1 · 체력 +2"]
	if face==2:
		for u in world.roster: u.current_hp=u.max_hp
	else:
		for pair in [["enemy_attack",1 if face==1 else 0],["ally_speed",1 if face==3 else 0],["ally_hp",2 if face in [4,6] else 0],["ally_attack",1 if face in [5,6] else 0]]:
			world.prophecy[pair[0]]=int(world.prophecy.get(pair[0],0))+pair[1]
		world.prophecy.rolls.append(face)
		if world.prophecy.rolls.size()>24: world.prophecy.rolls.pop_front()
	world.reward_receipts.append(visit)
	world.last_prophecy = {"visit":visit,"face":face,"detail":descriptions[face-1]}
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"face":face,"reason":descriptions[face-1]+" · 누적: "+prophecy_label()}

func pray_world_tree(index: int) -> Dictionary:
	var allowed = place_allowed(index,"unknown")
	if not allowed.ok: return allowed
	var visit = place_visit_id("purify",index)
	if visit in world.reward_receipts: return {"ok":false,"reason":"이번 방문의 기도는 완료했습니다."}
	var before: Dictionary = world.snapshot().duplicate(true)
	var face = world.rng.randi_range(1,6)
	var delta = -5 if face==6 else (-3 if face>=4 else 1)
	world.contamination = clampi(world.contamination+delta,0,100)
	world.reward_receipts.append(visit)
	world.prayer_result = {"visit":visit,"face":face,"delta":delta}
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"face":face,"reason":"%s · 오염도 %+d · 현재 %d/100" % ["대축복" if face==6 else ("축복" if face>=4 else "실패"),delta,world.contamination]}

func graveyard_choices(corpse_id: String) -> Array:
	var choices: Array = []
	for corpse in world.graveyard_corpses:
		if str(corpse.id)!=corpse_id: continue
		for i in range(corpse.brands.size()):
			var brand: Dictionary = corpse.brands[i]
			if BrandInheritance.validate(brand) and not brand.bless.is_empty():
				choices.append({"index":i,"item":{"brand":{"type":brand.type,"bless":brand.bless.map(func(n): return int(n)),"curse":[]}}})
	return choices

func extract_graveyard(index: int, corpse_id: String, brand_index: int) -> Dictionary:
	var allowed = place_allowed(index,"graveyard")
	if not allowed.ok: return allowed
	var visit = place_visit_id("grave-extract",index)
	if visit in world.reward_receipts: return {"ok":false,"reason":"이번 방문의 추출은 완료했습니다."}
	var choices = graveyard_choices(corpse_id)
	var selected: Dictionary = {}
	for choice in choices:
		if choice.index==brand_index: selected=choice.item.duplicate(true)
	if selected.is_empty(): return {"ok":false,"reason":"추출 가능한 시체와 낙인을 선택하세요."}
	var before: Dictionary = world.snapshot().duplicate(true)
	selected.id = world.next_id("brand-card")
	world.graveyard_corpses = world.graveyard_corpses.filter(func(c): return str(c.id)!=corpse_id)
	world.brand_cards.append(selected)
	world.reward_receipts.append(visit)
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"reason":Catalog.label("brand",selected)+" 낙인을 추출했습니다 · 시체 소모"}

func scout_hill(index: int) -> Dictionary:
	var allowed = place_allowed(index,"forest")
	if not allowed.ok: return allowed
	if world.scout.scouted: return {"ok":true,"intel":active_scout_intel()}
	var before: Dictionary = world.snapshot().duplicate(true)
	var intel: Array = []
	for i in range(world.tiles.size()):
		if world.tiles[i] in ["monster","rare-monster","boss"] and not i in world.cleared:
			intel.append(EncounterGenerator.scout_intel(world.definitions,world.contamination,world.laps+1,world.rng,i,world.tiles[i]))
	world.scout = {"scouted":true,"intel":intel}
	world.reward_receipts.append(place_visit_id("scout",index))
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"intel":active_scout_intel()}

func active_scout_intel() -> Array:
	return world.scout.intel.filter(func(entry): return not int(entry.index) in world.cleared)

func confirm_patrol(plan: Dictionary) -> Dictionary:
	var allowed = place_allowed(MapState.HOME,"home")
	if not allowed.ok: return allowed
	var visit = place_visit_id("patrol",MapState.HOME)
	if visit in world.reward_receipts: return {"ok":false,"reason":"이번 방문의 순찰경로는 확정했습니다."}
	if not RoutePlan.valid(plan): return {"ok":false,"reason":"현재 경로 6칸과 교체판 5칸의 타일 구성을 유지하세요."}
	var before: Dictionary = world.snapshot().duplicate(true)
	world.patrol_plan = plan.duplicate(true)
	world.reward_receipts.append(visit)
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"reason":"순찰경로 저장 완료 · 다음 타일 배치에 적용"}

func rest_allowed(index: int) -> Dictionary:
	var allowed = place_allowed(index,"rest")
	if not allowed.ok: return allowed
	if place_visit_id("heal",index) in world.reward_receipts: return {"ok":false,"reason":"이번 방문의 회복은 완료했습니다."}
	if not world.roster.any(func(u): return u.current_hp<u.max_hp): return {"ok":false,"reason":"모든 마물의 체력이 가득 찼습니다."}
	return {"ok":true}

func heal_at_rest(index: int) -> Dictionary:
	var allowed = rest_allowed(index)
	if not allowed.ok: return allowed
	var before: Dictionary = world.snapshot().duplicate(true)
	for unit in world.roster: unit.current_hp = unit.max_hp
	world.reward_receipts.append(place_visit_id("heal",index))
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"reason":"숙영 · 모든 마물 체력 완전 회복"}

func warp_from(index: int) -> Dictionary:
	var allowed = place_allowed(index,"warp")
	if not allowed.ok: return allowed
	var before: Dictionary = world.snapshot().duplicate(true)
	world.position = index
	var destination = world.warp_destination()
	if destination==index:
		world.restore(before)
		return {"ok":false,"reason":"연결된 워프가 없습니다."}
	world.position = destination
	world.move_serial += 1
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"origin":index,"destination":destination}

func leave_home() -> bool:
	if not place_allowed(MapState.HOME,"home").ok: return false
	var before: Dictionary = world.snapshot().duplicate(true)
	world.position = MapState.HOME
	world.leave_home()
	return persist_change(before)
