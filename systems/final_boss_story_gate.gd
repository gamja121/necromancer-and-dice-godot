extends RefCounted
## The final dragon may appear only after the real five-scene king-hunt
## conclusion was explicitly acknowledged. Contamination is checked by
## MapState separately. No invented story or combat is introduced here.
##
## Do not use only quest:monster_king_final_battle:active: that bit is set
## before the user actually closes the last story scene.
const HUNT_ID = "monster_king_hunt_trace_01"
const PORTAL_ID = "ritual_portal_trace_01"

static func ready(world) -> bool:
	if world == null: return false
	var f: Dictionary = world.event_flags
	var hunt: Dictionary = world.story_events.get(HUNT_ID,{})
	if hunt.get("status","")!="complete" or hunt.get("choice","")!="" or hunt.get("battle_result","")!="": return false
	for key in [
		"event:monster_king_hunt_trace_01:seen",
		"event:monster_king_hunt_trace_01:complete",
		"event:monster_king_hunt_trace_01:final_acknowledged",
		"quest:monster_king_hunt:complete",
		"story:monster_king:sealed_ruins_location_known",
		"quest:monster_king_final_battle:active",
		"story:monster_king:revived",
	]:
		if f.get(key,false)!=true: return false
	if f.get("quest:monster_king_hunt:active",false)!=false: return false
	for i in [1,2,3]:
		if f.get("event:monster_king_hunt_trace_01:beat:%d" % i,false)!=true: return false
	# Require a coherent pre-existing portal ending: a lone hand-written
	# final-quest flag cannot open the dragon fight.
	var portal: Dictionary = world.story_events.get(PORTAL_ID,{})
	if portal.get("status","")!="complete" or portal.get("choice","")!="intervene": return false
	if portal.get("battle_result","") not in ["won","lost"]: return false
	var won: bool = portal.battle_result=="won"
	for key in [
		"event:ritual_portal_trace_01:complete",
		"story:monster_king:ritual_confirmed",
		"story:ritual_portal:found",
		"story:monster_king:ritual_site_location_known",
	]:
		if f.get(key,false)!=true: return false
	if f.get("battle:ritual_portal_trace_01:won",false)!=won: return false
	if f.get("battle:ritual_portal_trace_01:lost",false)==won: return false
	if f.get("story:monster_king:revival_weakened",false)!=won: return false
	if f.get("story:monster_king:revival_complete",false)==won: return false
	return true
