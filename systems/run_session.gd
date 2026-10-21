extends Node
const MapGearShift = preload("res://systems/map_gear_shift.gd")

const RoutePlan = preload("res://systems/route_plan.gd")
const EncounterGenerator = preload("res://systems/encounter_generator.gd")
const BrandInheritance = preload("res://systems/brand_inheritance.gd")
const DiceControl = preload("res://systems/dice_control.gd")
const Catalog = preload("res://systems/reward_catalog.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const MapState = preload("res://systems/map_state.gd")
const Discovery = preload("res://systems/location_discoveries.gd")
const Routine = preload("res://systems/routine_event_catalog.gd")
const StoryBattleRegistry = preload("res://systems/story_battle_registry.gd")
const CultistAltarEnemies = preload("res://systems/cultist_altar_enemies.gd")
const RitualPortalEnemies = preload("res://systems/ritual_portal_enemies.gd")
const StoryBattleOutcomes = preload("res://systems/story_battle_outcomes.gd")
const SAVE = "user://map_run_v1.json"
# Tests use a separate user:// path; production keeps the canonical path by default.
var save_file_path: String = SAVE
const RITUAL_EVENT_ID = "ritual_portal_trace_01"
const HUNT_EVENT_ID = "monster_king_hunt_trace_01"
const GRAVEYARD_EVENT_ID = "graveyard_child_ambush_01"
const GRAVEYARD_RESULT_PENDING_FLAG = "story:graveyard_child_ambush_01:result_pending"
var world
var encounter: Dictionary = {}
var notice = ""

func has_save() -> bool:
	return FileAccess.file_exists(save_file_path)

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
	if FileAccess.file_exists(save_file_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_file_path))
		if not parsed is Dictionary or not world.restore(parsed):
			notice = "저장된 맵을 읽지 못해 새 원정을 시작했습니다."
		else:
			# Older saves between contamination 20 and 79 predate the new
			# boss threshold. Upgrade the existing 24th tile in place without
			# rerolling the board or changing other saved progress.
			var before_upgrade: Dictionary = world.snapshot().duplicate(true)
			var boss_upgraded: bool = world.reveal_boss_at_threshold()
			var swamp_upgraded: int = world.reveal_swamps_for_contamination()
			# The 2026-10-14 version saved only card_shown, not a hill.
			# Retrofit one real road for those existing players instead of
			# locking them out permanently from the new event-only award.
			var hill_upgraded: bool = false
			if event_flag_is_set("event:discovery:forest:card_shown") and not event_flag_is_set(MapState.HILL_UNLOCK_FLAG):
				var hill_index: int=world.reveal_discovered_hill()
				if hill_index>=0:
					world.event_flags[MapState.HILL_UNLOCK_FLAG]=true
					world.event_flags[MapState.HILL_HOME_NOTICE]=true
					hill_upgraded=true
			if (boss_upgraded or swamp_upgraded > 0 or hill_upgraded) and not save_world():
				world.restore(before_upgrade)
				notice = "타일 해금 상태 갱신 저장에 실패했습니다. 다시 시도하세요."
	encounter = world.active_encounter.duplicate(true)

func save_world() -> bool:
	var file = FileAccess.open(save_file_path+".tmp",FileAccess.WRITE)
	if file == null:
		notice = "저장에 실패했습니다."
		return false
	file.store_string(JSON.stringify(world.snapshot()))
	file.flush()
	var error = file.get_error()
	file.close()
	if error!=OK: return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(save_file_path+".tmp"),ProjectSettings.globalize_path(save_file_path))==OK

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

## Commit the on-board empty-road change, discovery receipt and pending
## HOME unlock notification atomically. UI must never claim an unlock if
## the durable save fails. No second discovery is allowed in this run.
func discover_hill_on_event(index: int) -> Dictionary:
	# Preserve original public/test API used by the first hill discovery.
	return discover_location_on_event(index,"forest")

func next_discovery_kind() -> String:
	if world == null: return ""
	return Discovery.next_eligible(world)

## Triggered only by real story-free event arrival in map.gd.
## One safe road, unique card receipt and HOME NEW alert commit atomically.
func discover_location_on_event(index: int,kind: String) -> Dictionary:
	if world == null or not world.run_result.is_empty(): return {"ok":false}
	if world.tiles.size()!=24 or index!=world.position or world.tiles[index]!="event":
		return {"ok":false,"reason":"발견 조건을 확인할 수 없습니다."}
	if not Discovery.eligible(world,kind) or event_flag_is_set(Discovery.receipt_flag(kind)):
		return {"ok":false,"reason":"아직 발견할 수 없거나 이미 해금한 장소입니다."}
	if not encounter.is_empty() or not world.active_encounter.is_empty() or not world.pending_reward.is_empty() or not world.pending_move.is_empty():
		return {"ok":false,"reason":"이동·전투·보상을 먼저 완료하세요."}
	var before: Dictionary = world.snapshot().duplicate(true)
	var converted: int = world.reveal_discovered_location(kind)
	if converted<0:
		return {"ok":false,"reason":"보호 길을 제외한 빈 칸이 없어 해금을 보류합니다."}
	_apply_discovery_flags(kind)
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"index":converted,"kind":kind}

## Reuse the same original unlock transaction for the optional
## discovery path, without paying another RNG roll after selecting the event.
func _apply_discovery_flags(kind: String) -> void:
	world.event_flags[Discovery.unlock_flag(kind)] = true
	world.event_flags[Discovery.receipt_flag(kind)] = true
	world.event_flags[Discovery.home_flag(kind)] = true
	world.event_flags["ui:unlock:%s:tile_pending" % kind] = true
	world.event_flags["ui:unlock:%s:action_pending" % kind] = true
	if kind=="rest":
		if not RoutePlan.is_new(world.patrol_plan):
			world.patrol_plan = RoutePlan.default_plan()
		world.patrol_plan["rest_unlocked"] = true
		world.patrol_plan["rest_discovered"] = true

func _event_visit_id(index: int) -> String:
	return "routine-visit:%d:%d:%d" % [world.map_serial,world.move_serial,index]

## This method MUST only be called after map.gd's complete story priority
## dispatch has found nothing playable/resumable. One transaction covers
## selection, optional discovery, random card source and the visit receipt.
func begin_story_free_event(index: int) -> Dictionary:
	if world == null or not world.run_result.is_empty(): return {"ok":false,"reason":"원정을 진행할 수 없습니다."}
	if index!=world.position or index<0 or index>=world.tiles.size() or world.tiles[index]!="event":
		return {"ok":false,"reason":"실제 사건 타일 도착만 유효합니다."}
	if not world.pending_move.is_empty() or not world.pending_reward.is_empty() or not encounter.is_empty() or not world.active_encounter.is_empty():
		return {"ok":false,"reason":"기존 이동·전투·보상을 먼저 완료하세요."}
	var receipt: String = _event_visit_id(index)
	if receipt in world.reward_receipts: return {"ok":false,"reason":"이번 방문은 이미 완료했습니다."}
	var before: Dictionary = world.snapshot().duplicate(true)
	var possible: String = Discovery.next_eligible(world)
	# One balanced draw only when a real undiscovered, qualified location
	# exists. Without such a location, all six routine events stay reachable.
	if not possible.is_empty() and world.rng.randf()>=0.60:
		var converted: int = world.reveal_discovered_location(possible)
		if converted>=0:
			_apply_discovery_flags(possible)
			# A discovery consumes this one real event visit too. Without its
			# visit receipt, a second dispatcher call could grant a routine card
			# on the very same landing after the unlock was already saved.
			world.reward_receipts.append(receipt)
			if not persist_change(before): return {"ok":false,"reason":notice}
			return {"ok":true,"type":"discovery","location":possible,"index":converted}
		# No free road: safely fall back to a routine instead of awarding a
		# phantom place or overwriting a boss/story/protected swamp slot.
	var event_id: String = Routine.choose(world.rng)
	var definition: Dictionary = Routine.details(event_id)
	var offered: Dictionary = {}
	if str(definition.effect)=="dice":
		var pool: Array = Catalog.dice_cards()
		offered = pool[world.rng.randi_range(0,pool.size()-1)].duplicate(true)
	world.pending_reward = {
		"kind":"routine","id":receipt,"index":index,
		"event_id":event_id,"phase":"choice","offer":offered
	}
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"type":"routine","event_id":event_id}

## One explicit routine choice resolves atomically; 5/5 dice uses the
## ORIGINAL RewardOverflow and claim_reward replace/decline flow.
func complete_routine_choice(choice: String) -> Dictionary:
	if world==null or not world.run_result.is_empty(): return {"ok":false}
	var pending: Dictionary = world.pending_reward
	if pending.get("kind","")!="routine" or pending.get("phase","")!="choice" or not choice in ["take","skip"]:
		return {"ok":false,"reason":"선택 가능한 사건이 없습니다."}
	if not Routine.valid(str(pending.get("event_id",""))): return {"ok":false}
	if str(pending.id) in world.reward_receipts: return {"ok":false}
	var definition: Dictionary = Routine.details(str(pending.event_id))
	var before: Dictionary = world.snapshot().duplicate(true)
	var message: String = "사건을 지나쳤습니다."
	if choice=="take":
		match str(definition.effect):
			"dice":
				var item: Dictionary = create_item("dice",pending.offer)
				if world.dice_cards.size()>=Catalog.DICE_CAPACITY:
					world.pending_reward["phase"] = "overflow"
					world.pending_reward["reward"] = {"kind":"dice","item":item}
					if not persist_change(before): return {"ok":false,"reason":notice}
					return {"ok":true,"overflow":true,"message":"카드 보관함이 가득 찼습니다."}
				world.dice_cards.append(item)
				message = "%s 획득 · 주사위 카드 %d/5" % [str(item.label),world.dice_cards.size()]
			"heal":
				for unit in world.roster:
					unit.current_hp = mini(int(unit.max_hp),int(unit.current_hp)+1)
				message = "아군 마물 체력이 1씩 회복됐습니다."
			"cleanse":
				world.contamination = maxi(0,int(world.contamination)-1)
				message = "오염도가 1 감소했습니다."
			_:
				return {"ok":false,"reason":"알 수 없는 사건 효과입니다."}
	world.reward_receipts.append(str(pending.id))
	world.pending_reward = {}
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"overflow":false,"message":message}

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

## Persisted, single-use story presentation receipt. A crash after combat
## resolution must not skip the result scene when the map is reopened.
func graveyard_battle_result_pending() -> bool:
	return story_battle_result_pending(GRAVEYARD_EVENT_ID)

## Generic result receipt gate; only supported result handlers may show a scene.
func story_battle_result_pending(event_id: String) -> bool:
	var spec: Dictionary = StoryBattleRegistry.definition(event_id)
	if world == null or spec.is_empty(): return false
	if not encounter.is_empty() or not world.active_encounter.is_empty(): return false
	if not world.pending_move.is_empty() or not world.pending_reward.is_empty(): return false
	return StoryBattleOutcomes.valid_result(world,event_id,spec)

## Reusable result scene data; returns nothing for unregistered or invalid outcomes.
func story_battle_presentation(event_id: String) -> Dictionary:
	if not story_battle_result_pending(event_id): return {}
	return StoryBattleOutcomes.presentation(StoryBattleRegistry.definition(event_id),get_story_event(event_id))

func pending_story_battle_event_id() -> String:
	for event_id in StoryBattleRegistry.registered_ids():
		if story_battle_result_pending(str(event_id)): return str(event_id)
	return ""

## Acknowledge the visual result only after the player presses a close/retry
## button; do not consume it on display or on map startup.
func acknowledge_graveyard_battle_result() -> bool:
	return acknowledge_story_battle_result(GRAVEYARD_EVENT_ID)

func acknowledge_story_battle_result(event_id: String) -> bool:
	if not story_battle_result_pending(event_id): return false
	var spec: Dictionary = StoryBattleRegistry.definition(event_id)
	var before: Dictionary = world.snapshot().duplicate(true)
	world.event_flags[spec.pending_flag] = false
	return persist_change(before)

## Story fights must pass through the existing 1-4 owned-monster deck picker.
## A lost rescue attempt may be retried; the previous loss stays in its flag.
func start_story_encounter(event_id: String, index: int, selected_ids: Array) -> bool:
	if world == null: return false
	var spec: Dictionary = StoryBattleRegistry.definition(event_id)
	if not StoryBattleRegistry.can_start(world,get_story_event(event_id),index,spec): return false
	return _start_encounter(index,selected_ids,event_id)

func start_encounter(index: int, selected_ids: Array) -> bool:
	return _start_encounter(index,selected_ids)

func _start_encounter(index: int, selected_ids: Array, event_id: String = "") -> bool:
	if world == null or not world.run_result.is_empty(): return false
	var story_spec: Dictionary = StoryBattleRegistry.definition(event_id)
	var story: bool = not story_spec.is_empty()
	if not event_id.is_empty() and not story: return false
	var mimic: bool = not story and world.pending_reward.get("kind","")=="mimic" and int(world.pending_reward.get("index",-1))==index
	if (not world.pending_reward.is_empty() and not mimic) or not encounter.is_empty() or not world.active_encounter.is_empty() or not world.pending_move.is_empty(): return false
	if index<0 or index>=world.tiles.size() or (not mimic and not story and index in world.cleared): return false
	if story:
		if not StoryBattleRegistry.can_start(world,get_story_event(event_id),index,story_spec): return false
	elif not world.tiles[index] in (["gem"] if mimic else ["monster","rare-monster","boss"]): return false
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
	var type: String = str(story_spec.encounter_type) if story else ("mimic" if mimic else world.tiles[index])
	var slugs: Array = []
	if story:
		# The altar fight rolls its 4 unique enemies only when an actual
		# owned-monster deck has been confirmed. Encounter + RNG save together.
		if event_id==StoryBattleRegistry.CULTIST_ALTAR_ID:
			slugs = CultistAltarEnemies.select(world.definitions,world.rng)
			if not CultistAltarEnemies.valid(world.definitions,slugs):
				world.restore(before)
				return false
		elif event_id==StoryBattleRegistry.RITUAL_PORTAL_ID:
			slugs = RitualPortalEnemies.select(world.definitions,world.rng)
			if not RitualPortalEnemies.valid(world.definitions,slugs):
				world.restore(before)
				return false
		else:
			slugs = story_spec.enemies.duplicate()
	elif mimic:
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
	# A retry is a new combat attempt; the prior loss is still journaled.
	if story and get_story_event(event_id).battle_result == "lost":
		world.story_events[event_id] = {"status":"active","choice":str(story_spec.choice),"battle_result":""}
	encounter = {"id":world.next_id("encounter"),"index":index,"type":type,"allies":allies,"enemies":enemies,"checkpoint":rules.snapshot(),"phase":"ready","prophecy":prophecy,"previous_roll":0,"previous_card":""}
	if story: encounter["event_id"] = event_id
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
	var event_id: String = str(encounter.get("event_id",""))
	var story_spec: Dictionary = StoryBattleRegistry.definition(event_id)
	# Unknown event IDs or mismatched encounter types must not fall into the
	# ordinary tile reward branch or consume owned monsters.
	if not event_id.is_empty() and story_spec.is_empty(): return false
	if not story_spec.is_empty():
		if not StoryBattleRegistry.valid_definition(story_spec): return false
		if str(encounter.get("type","")) != str(story_spec.encounter_type): return false
		if not get_story_event(event_id).status == "active" or get_story_event(event_id).choice != story_spec.choice: return false
	elif str(encounter.get("type","")).begins_with("event-"): return false
	var before: Dictionary = world.snapshot().duplicate(true)
	for combatant in battle.units:
		if combatant.team=="enemy" and not combatant.alive and not combatant.get("is_summon",false):
			world.enemies_defeated += 1
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
	var story: bool = not story_spec.is_empty()
	if story:
		# Policy-specific flags and the unacknowledged result are one save.
		notice = StoryBattleOutcomes.apply(world,event_id,story_spec,battle.winner()=="ally")
		if notice.is_empty():
			world.restore(before)
			encounter = world.active_encounter.duplicate(true)
			return false
	elif battle.winner()=="ally":
		if encounter.type in ["monster","rare-monster","boss"] and not encounter.index in world.cleared: world.cleared.append(encounter.index)
		world.contamination = maxi(0,world.contamination-1)
		var corpses: Array = []
		for unit in battle.units:
			if unit.team=="enemy" and not unit.alive and not unit.is_summon:
				# Capture must preserve the exact enemy that entered this battle.
				# Battle rounds can normalize/transiently modify a combatant, so
				# prefer its original encounter snapshot for permanent identity.
				var original: Dictionary = unit
				for generated in encounter.get("enemies",[]):
					if str(generated.get("id",""))==str(unit.id):
						original=generated
						break
				corpses.append({"id":unit.id,"slug":unit.slug,"name":unit.name,"target":world.rng.randi_range(2,6),"unit":original.duplicate(true)})
		if not corpses.is_empty():
			world.pending_reward = {"id":"capture-"+encounter.id,"kind":"capture","corpses":corpses,"selected":0,"locked":false,"max_attempts":2 if battle.active("ally","corpse") else 1,"attempts":2 if battle.active("ally","corpse") else 1,"phase":"choose","battle":battle.snapshot(),"face":battle.face}
		notice = "미믹 격퇴 · 오염도 -1" if encounter.type=="mimic" else "전투 승리 · 오염도 -1 · 마물 타일을 정리했습니다."
	else: notice = "전투 패배 · 원정 종료"
	# All defeated battles end the expedition, even if owned monsters
	# remain. The battle record, permanent losses, and game-over are saved
	# atomically so reload cannot revive the run or duplicate rewards.
	if battle.winner()=="enemy":
		world.run_result = {
			"ended":true,
			"reason":"battle_defeat",
			"encounter_id":str(encounter.get("id","")),
			"laps":world.laps,
			"contamination":world.contamination,
			"enemies_defeated":world.enemies_defeated,
			"lost_monsters":world.graveyard_corpses.size(),
			"surviving_monsters":world.roster.size()
		}
		notice = "원정 종료 · 망자의 계약이 끊어졌습니다."
	world.active_encounter = {}
	if not persist_change(before): return false
	encounter = {}
	return true

func persist_change(before: Dictionary) -> bool:
	# Historical discovery gates survive pollution purification and healing.
	world.max_contamination_reached = maxi(int(world.max_contamination_reached),int(world.contamination))
	if world.roster.any(func(unit): return int(unit.current_hp)<int(unit.max_hp)):
		world.event_flags["discovery:ever_injured"] = true
	# Any system that raises contamination across 20 (not only leaving
	# home) must persist the first boss tile in the SAME save transaction.
	# A failed write rolls the boss/swamp reveal back with everything else.
	if int(before.get("contamination",0)) < MapState.BOSS_CONTAMINATION and world.contamination >= MapState.BOSS_CONTAMINATION:
		world.reveal_boss_at_threshold()
	# At 15/30, automatically change ordinary road tiles into swamps even
	# before the next home shuffle. No RNG/encounter/story state is modified.
	if world.contamination > int(before.get("contamination",0)) and world.contamination >= MapState.FIRST_SWAMP_CONTAMINATION:
		world.reveal_swamps_for_contamination()
	if save_world(): return true
	world.restore(before)
	encounter = world.active_encounter.duplicate(true)
	notice = "저장에 실패했습니다. 다시 시도하세요."
	return false

func create_item(kind: String, source: Dictionary) -> Dictionary:
	if kind=="unit":
		# Soul harvest is NOT a reroll. Copy the dead enemy's exact passive,
		# brand types, blessing faces and curse faces into the owned card.
		var captured: Dictionary = source.get("unit",{})
		if captured.is_empty() and world.pending_reward.get("kind","")=="capture":
			# Pre-fix saved captures only stored the slain enemy's ID. Recover
			# its actual brands from the persisted battle checkpoint if possible.
			for combatant in world.pending_reward.get("battle",{}).get("units",[]):
				if str(combatant.get("id",""))==str(source.get("id","")):
					captured=combatant
					break
		if not captured.is_empty():
			var item: Dictionary=captured.duplicate(true)
			# Battle-local effects (HP, curses this turn, slot, team, etc.)
			# must not become persistent roster attributes.
			for key in item.keys():
				if not key in ["id","slug","name","grade","legions","max_hp","attack","speed","passive","brands","is_summon","altar_enhancements"]:
					item.erase(key)
			item.id=world.next_id("unit")
			item.current_hp=int(item.max_hp)
			for brand in item.brands:
				brand.bless=brand.bless.map(func(face): return int(face))
				brand.curse=brand.curse.map(func(face): return int(face))
			return item
		# Fallback only for legacy capture data without a battle snapshot;
		# normal rewards may still explicitly request a newly generated unit.
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
	var unit_pool: Array = []
	# New treasure rewards are strictly monster or dice cards; older pending
	# transactions remain stored unchanged until claimed or discarded.
	for slug in EncounterGenerator.eligible_roster(world.definitions):
		var candidate: Dictionary = {"kind":"unit","source":{"slug":slug,"name":world.definitions[slug].name}}
		unit_pool.append(candidate)
		pool.append(candidate)
	for card in Catalog.dice_cards(): pool.append({"kind":"dice","source":card})
	for i in range(pool.size()-1,0,-1):
		var j = world.rng.randi_range(0,i)
		var swap = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var offers: Array = pool.slice(0,3)
	# Monster cards are the new growth material: every chest must offer one.
	if not unit_pool.is_empty() and not offers.any(func(offer): return offer.kind=="unit"):
		offers[world.rng.randi_range(0,offers.size()-1)] = unit_pool[world.rng.randi_range(0,unit_pool.size()-1)]
	world.pending_reward = {"id":visit_id,"kind":"treasure","offers":offers,"selected":-1}
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
	# First full circuit unlocks the cemetery; announce it at HOME once.
	if landed == MapState.HOME and world.lap_ready and world.laps == 0:
		world.event_flags["ui:unlock:graveyard:home_pending"] = true
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
	if encounter.is_empty() or world == null: return false
	# Only the two actual combat checkpoints are accepted. Failed or out-of-order
	# writes must not strand a resumed story encounter in an impossible phase.
	var current_phase: String = str(encounter.get("phase",""))
	if phase == "actions":
		if current_phase not in ["rolled","actions"]: return false
	elif phase == "ready":
		if current_phase != "actions": return false
	else:
		return false
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

## Rename only a living owned instance. The species catalog and all combat
## attributes remain unchanged. The optional nickname field protects custom
## names from legacy monster-name normalization on future reloads.
func rename_owned_unit(instance_id: String, proposed_name: String) -> Dictionary:
	if world == null or not world.run_result.is_empty():
		return {"ok":false,"reason":"종료된 원정에서는 이름을 변경할 수 없습니다."}
	var unit: Dictionary = owned_unit(instance_id)
	if unit.is_empty() or bool(unit.get("is_summon",false)):
		return {"ok":false,"reason":"보유 중인 마물만 이름을 변경할 수 있습니다."}
	# Validate the raw candidate before trimming: otherwise a leading tab
	# or trailing newline would silently disappear and become a legal name.
	for i in range(proposed_name.length()):
		if proposed_name.unicode_at(i)<32 or proposed_name.unicode_at(i)==127:
			return {"ok":false,"reason":"줄바꿈이나 제어 문자는 이름에 사용할 수 없습니다."}
	var chosen: String = proposed_name.strip_edges()
	if chosen.is_empty() or chosen.length()>12:
		return {"ok":false,"reason":"이름은 1~12자로 입력하세요."}
	if chosen==str(unit.name):
		return {"ok":true,"name":chosen}
	var before: Dictionary = world.snapshot().duplicate(true)
	unit.name = chosen
	unit["nickname"] = chosen
	# The same owned unit may already have an on-disk battle checkpoint.
	# Keep the restored combat name consistent without altering stats/RNG.
	if not world.active_encounter.is_empty():
		for ally in world.active_encounter.get("allies",[]):
			if str(ally.get("id",""))==instance_id:
				ally["name"]=chosen
				ally["nickname"]=chosen
		var snapshot: Dictionary = world.active_encounter.get("checkpoint",{})
		for fighter in snapshot.get("units",[]):
			if str(fighter.get("id",""))==instance_id and str(fighter.get("team",""))=="ally":
				fighter["name"]=chosen
				fighter["nickname"]=chosen
	if not persist_change(before):
		return {"ok":false,"reason":"이름 저장에 실패했습니다. 다시 시도하세요."}
	encounter = world.active_encounter.duplicate(true)
	return {"ok":true,"name":chosen}

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

## Offer a different species of the donor's grade. Offering a monster is a
## one-for-one trade, not a free new card or a change to its inherited brands.
func shop_monster_offer(donor: Dictionary, used_slugs: Array) -> Dictionary:
	var candidates: Array = EncounterGenerator.eligible_roster(world.definitions).filter(
		func(slug): return str(slug)!=str(donor.slug) and str(world.definitions[slug].grade)==str(donor.grade) and not slug in used_slugs
	)
	if candidates.is_empty(): return {}
	var choice: String = str(candidates[world.rng.randi_range(0,candidates.size()-1)])
	used_slugs.append(choice)
	return {"kind":"unit","item":create_item("unit",{"slug":choice})}

func shop_offers(index: int, unit_id: String) -> Dictionary:
	var allowed = place_allowed(index,"village")
	if not allowed.ok: return allowed
	var unit = owned_unit(unit_id)
	if unit.is_empty() or world.roster.size()<=1:
		return {"ok":false,"reason":"마지막 마물은 교환할 수 없습니다."}
	var visit = place_visit_id("shop",index)
	if world.shop_trade.get("visit","")==visit and world.shop_trade.offers.has(unit_id):
		var cached: Array = world.shop_trade.offers[unit_id]
		if not cached.any(func(offer): return str(offer.get("kind",""))=="brand"):
			return {"ok":true,"offers":cached.duplicate(true)}
		# A saved, not-yet-used shop offer from the former rules may include
		# brand cards. Convert only those slots; keep dice offers and IDs intact.
		var previous: Dictionary = world.snapshot().duplicate(true)
		var revised: Array = cached.duplicate(true)
		var used: Array = []
		for offer in revised:
			if str(offer.get("kind",""))=="unit": used.append(str(offer.item.slug))
		for i in range(revised.size()):
			if str(revised[i].get("kind",""))!="brand": continue
			var replacement: Dictionary = shop_monster_offer(unit,used)
			if replacement.is_empty():
				world.restore(previous)
				return {"ok":false,"reason":"교환할 마물 후보가 없습니다."}
			revised[i] = replacement
		world.shop_trade.offers[unit_id] = revised
		if not persist_change(previous): return {"ok":false,"reason":notice}
		return {"ok":true,"offers":revised.duplicate(true)}
	var before: Dictionary = world.snapshot().duplicate(true)
	if world.shop_trade.get("visit","")!=visit: world.shop_trade={"visit":visit,"offers":{}}
	var grade = str(unit.grade)
	var count = 5 if grade=="hero" else (4 if grade=="advanced" else 3)
	var pool = Catalog.dice_cards().filter(func(c): return grade=="hero" or (c.card_id!="echo" and (grade=="advanced" or c.card_id!="repeat")))
	var offers: Array = []
	var offered_slugs: Array = []
	for i in range(count):
		var monster_slot: bool = i%2==(0 if grade=="hero" else 1)
		if monster_slot:
			var option: Dictionary = shop_monster_offer(unit,offered_slugs)
			if option.is_empty():
				world.restore(before)
				return {"ok":false,"reason":"교환할 마물 후보가 없습니다."}
			offers.append(option)
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
	if not offer.kind in ["dice","unit"]: return {"ok":false,"reason":"현재 교환할 수 없는 카드입니다. 상품을 다시 선택하세요."}
	if offer.kind=="dice" and world.dice_cards.size()>=Catalog.DICE_CAPACITY:
		return {"ok":false,"reason":"주사위 카드 보관함이 가득 찼습니다."}
	var before: Dictionary = world.snapshot().duplicate(true)
	var unit_name = owned_unit(unit_id).name
	world.roster = world.roster.filter(func(u): return str(u.id)!=unit_id)
	if offer.kind=="dice": world.dice_cards.append(offer.item.duplicate(true))
	else: world.roster.append(offer.item.duplicate(true))
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
	var boss_appeared: bool = before.contamination < MapState.BOSS_CONTAMINATION and world.contamination >= MapState.BOSS_CONTAMINATION
	world.reward_receipts.append(visit)
	world.prayer_result = {"visit":visit,"face":face,"delta":delta}
	if not persist_change(before): return {"ok":false,"reason":notice}
	return {"ok":true,"face":face,"boss_appeared":boss_appeared,"reason":"%s · 오염도 %+d · 현재 %d/100" % ["대축복" if face==6 else ( "축복" if face>=4 else "실패"),delta,world.contamination]}

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

## Hill replaces monster scouting with an explicitly chosen *forward* move.
## The regular die/card history and RNG must not change. The normal board
## contract stops at HOME, even when the player requested more steps.
## Legacy scout intel remains readable for old saves, but no hill UI issues it.
func prepare_hill_move(index: int, steps: int) -> Dictionary:
	var allowed: Dictionary = place_allowed(index,"forest")
	if not allowed.ok: return allowed
	if world.position != index:
		return {"ok":false,"reason":"현재 언덕에 있을 때만 이동을 선택할 수 있습니다."}
	if steps < 1 or steps > 6:
		return {"ok":false,"reason":"앞으로 1~6칸 중 선택하세요."}
	var receipt: String = place_visit_id("hill-route",index)
	if receipt in world.reward_receipts:
		return {"ok":false,"reason":"이번 언덕 방문의 이동은 이미 사용했습니다."}
	var before: Dictionary = world.snapshot().duplicate(true)
	var path: Array = world.move_path(steps)
	if path.size() != steps:
		world.restore(before)
		return {"ok":false,"reason":"집을 지나서는 이동할 수 없습니다."}
	# A chosen stride is not a rolled face or a dice-control-card use.
	world.last_face = int(before.last_face)
	var landed: int = world.position
	if world.tiles[landed] == "warp":
		world.position = world.warp_destination()
	elif world.tiles[landed] == "swamp":
		for unit in world.roster:
			unit.current_hp = maxi(1,int(unit.current_hp)-1)
	world.reward_receipts.append(receipt)
	world.pending_move = {
		"source":"hill","face":steps,"label":"언덕 지정 이동",
		"origin":index,"path":path,"landed":landed
	}
	if not persist_change(before):
		return {"ok":false,"reason":notice}
	return world.pending_move.merged({"ok":true})

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

## First new tile: available after returning home from the first FULL
## patrol. Unlock remains the player's explicit action (not a free auto
## reward); once saved it cannot be lost through reset, reroll or reload.
## A fresh game at home cannot skip an entire lap to unlock this reward.
func rest_unlock_allowed() -> Dictionary:
	var allowed: Dictionary=place_allowed(MapState.HOME,"home")
	if not allowed.ok: return allowed
	if RoutePlan.is_new(world.patrol_plan) and bool(world.patrol_plan.get("rest_unlocked",false)):
		return {"ok":false,"reason":"숙영은 이미 해금됐습니다."}
	if world.laps<1 and not world.lap_ready:
		return {"ok":false,"reason":"첫 바퀴를 완주해 집에 돌아오면 숙영을 해금할 수 있습니다."}
	return {"ok":true}

func unlock_rest_tile() -> Dictionary:
	var allowed: Dictionary=rest_unlock_allowed()
	if not allowed.ok: return allowed
	var before: Dictionary=world.snapshot().duplicate(true)
	if not RoutePlan.is_new(world.patrol_plan):
		# Existing saves retain their legacy board until the next home exit;
		# convert only the optional route inventory on explicit unlock.
		world.patrol_plan=RoutePlan.default_plan()
	world.patrol_plan["rest_unlocked"]=true
	# Only a real, successful unlock creates a NEW marker. Older saves and
	# a new expedition must not display an invented notification.
	world.event_flags["ui:unlock:rest:tile_pending"] = true
	world.event_flags["ui:unlock:rest:action_pending"] = true
	if not persist_change(before):
		return {"ok":false,"reason":notice}
	return {"ok":true,"reason":"숙영 해금 완료! 숙영은 최대 3칸까지 추가할 수 있습니다."}

func confirm_patrol(plan: Dictionary) -> Dictionary:
	var allowed = place_allowed(MapState.HOME,"home")
	if not allowed.ok: return allowed
	var visit = place_visit_id("patrol",MapState.HOME)
	if visit in world.reward_receipts: return {"ok":false,"reason":"이번 방문의 순찰경로는 확정했습니다."}
	if not RoutePlan.valid(plan): return {"ok":false,"reason":"추가 6칸 제한과 타일별 해금·수량 제한을 확인하세요."}
	# Being drawn in the route editor is not authority to unlock a tile.
	# Never let a forged payload place hill stones before their real event.
	if RoutePlan.is_new(plan) and int(plan.selection.get("forest",0))>0 and not Discovery.is_unlocked(world,"forest"):
		return {"ok":false,"reason":"언덕은 사건에서 발견한 뒤에만 편성할 수 있습니다."}
	# The active unlock is owned by the persisted world, not by a crafted
	# UI payload. Prevent forging an unlock or silently re-locking a tile.
	if RoutePlan.is_new(plan) and (bool(plan.get("rest_unlocked",false)) != bool(world.patrol_plan.get("rest_unlocked",false)) or bool(plan.get("rest_discovered",false)) != bool(world.patrol_plan.get("rest_discovered",false))):
		return {"ok":false,"reason":"숙영 해금 상태가 변경됐습니다. 편성 화면을 다시 열어주세요."}
	var before: Dictionary = world.snapshot().duplicate(true)
	world.patrol_plan = plan.duplicate(true)
	if RoutePlan.is_new(world.patrol_plan) and not world.patrol_plan.selection.has("forest"):
		world.patrol_plan.selection["forest"]=0
	world.reward_receipts.append(visit)
	# The unlock remains permanent; acknowledging its NEW home highlight is
	# part of the same successful patrol-confirm transaction.
	for kind in Discovery.ORDER:
		if world.event_flags.get(Discovery.home_flag(kind),false)==true:
			world.event_flags[Discovery.home_flag(kind)]=false
	world.event_flags["ui:unlock:graveyard:home_pending"] = false
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
	# First actual use acknowledges the previously unlocked button.
	if world.event_flags.get("ui:unlock:rest:action_pending",false) == true:
		world.event_flags["ui:unlock:rest:action_pending"] = false
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
	# Generate the EXACT manifest of two real rings, one cog-notch, and
	# two disjoint tile-pair exchanges. Conserve generated type counts and
	# commit once; the animation reuses the identical manifest.
	world.tiles = MapGearShift.compose_board(before["tiles"],world.tiles,world.map_serial)
	return persist_change(before)
