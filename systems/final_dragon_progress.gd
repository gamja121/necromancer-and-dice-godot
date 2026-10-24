extends RefCounted
## One durable final victory; unrelated tile clears never imply a completed run.
const REASON = "final_dragon_defeated"
const ACTIVE = "quest:monster_king_final_battle:active"
const COMPLETE = "quest:monster_king_final_battle:complete"
const DEFEATED = "story:final_dragon:defeated"
const INTRO_SEEN = "presentation:final_dragon:acknowledged"

static func cleared(world) -> bool:
	return world != null and (world.event_flags.get(DEFEATED,false)==true or world.run_result.get("reason","")==REASON)

static func quest_reached(flags: Dictionary) -> bool:
	return flags.get(ACTIVE,false)==true or (flags.get(COMPLETE,false)==true and flags.get(DEFEATED,false)==true)

static func is_final_encounter(encounter: Dictionary) -> bool:
	if encounter.get("type","")!="boss" or not str(encounter.get("event_id","")).is_empty(): return false
	var enemies: Array = encounter.get("enemies",[])
	return enemies.size()==1 and enemies[0].get("slug","")=="dragon" and enemies[0].get("final_boss",false)==true

static func record_victory(world, encounter: Dictionary) -> void:
	world.event_flags[ACTIVE] = false
	world.event_flags[COMPLETE] = true
	world.event_flags[DEFEATED] = true
	world.run_result = {
		"ended":true,"reason":REASON,"encounter_id":str(encounter.id),
		"laps":world.laps,"contamination":world.contamination,
		"enemies_defeated":world.enemies_defeated,
		"lost_monsters":world.graveyard_corpses.size(),
		"surviving_monsters":world.roster.size()
	}

static func valid_record(saved: Dictionary) -> bool:
	var record: Dictionary = saved.get("run_result",{})
	if record.get("reason","")!=REASON: return true
	var flags: Dictionary = saved.get("event_flags",{})
	if flags.get(ACTIVE,false)!=false or flags.get(COMPLETE,false)!=true or flags.get(DEFEATED,false)!=true: return false
	if str(record.get("encounter_id","")).is_empty(): return false
	if not saved.get("active_encounter",{}).is_empty() or not saved.get("pending_move",{}).is_empty(): return false
	var pending: Dictionary = saved.get("pending_reward",{})
	return pending.is_empty() or (pending.get("kind","")=="capture" and pending.get("id","")=="capture-"+str(record.encounter_id))
