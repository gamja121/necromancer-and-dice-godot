extends RefCounted
## TEST-ONLY synthetic save receipt for dedicated map/boss gate unit tests.
## Real main-story integration still uses explicit original event buttons.
## Never import this into production game scripts.
static func seed_completed_final_hunt(world, acknowledged: bool = true) -> void:
	var f: Dictionary = world.event_flags
	world.story_events["ritual_portal_trace_01"] = {"status":"complete","choice":"intervene","battle_result":"won"}
	world.story_events["monster_king_hunt_trace_01"] = {"status":"complete","choice":"","battle_result":""}
	for key in [
		"event:ritual_portal_trace_01:seen",
		"event:ritual_portal_trace_01:choice_intervene",
		"event:ritual_portal_trace_01:complete",
		"story:monster_king:ritual_confirmed",
		"story:ritual_portal:found",
		"story:monster_king:ritual_site_location_known",
		"quest:ritual_site_tracking:complete",
		"story:monster_king:revived",
		"story:monster_king:revival_weakened",
		"battle:ritual_portal_trace_01:won",
		"event:monster_king_hunt_trace_01:seen",
		"event:monster_king_hunt_trace_01:complete",
		"quest:monster_king_hunt:complete",
		"story:monster_king:sealed_ruins_location_known",
		"quest:monster_king_final_battle:active",
	]:
		f[key]=true
	for i in [1,2,3,4]:
		f["event:ritual_portal_trace_01:beat:%d" % i]=true
	for i in [1,2,3]:
		f["event:monster_king_hunt_trace_01:beat:%d" % i]=true
	f["event:monster_king_hunt_trace_01:final_acknowledged"]=acknowledged
	f["quest:monster_king_hunt:active"]=false
	f["quest:ritual_site_tracking:active"]=false
	f["quest:ritual_intervention:active"]=false
	f["story:ritual_portal_trace_01:result_pending"]=false
	f["battle:ritual_portal_trace_01:lost"]=false
	f["story:monster_king:revival_complete"]=false
