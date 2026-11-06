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
	var enemies = encounter.get("enemies",[])
	return enemies is Array and enemies.size()==1 and enemies[0] is Dictionary and enemies[0].get("slug","")=="dragon" and enemies[0].get("final_boss",false)==true

## Builds before the ending stored a final win in the waiting harvest.
static func legacy_harvest_encounter_id(reward: Dictionary) -> String:
	var receipt: String = str(reward.get("id",""))
	if reward.get("kind","")!="capture" or not receipt.begins_with("capture-encounter-"): return ""
	var corpses = reward.get("corpses",[])
	var battle = reward.get("battle",{})
	if not corpses is Array or corpses.size()!=1 or not corpses[0] is Dictionary or not battle is Dictionary: return ""
	var corpse: Dictionary = corpses[0]
	var corpse_id: String = str(corpse.get("id",""))
	var units = battle.get("units",[])
	if corpse_id.is_empty() or not units is Array: return ""
	for unit in units:
		if not unit is Dictionary or unit.get("id","")!=corpse_id or unit.get("team","")!="enemy": continue
		if unit.get("slug","")=="dragon" and unit.get("final_boss",false)==true and unit.get("alive",true)==false and not unit.get("is_summon",false):
			return receipt.trim_prefix("capture-")
	return ""

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
