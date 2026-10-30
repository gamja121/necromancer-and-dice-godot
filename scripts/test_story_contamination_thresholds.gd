extends SceneTree
## First-discovery contamination gates: all 10 story IDs, true runtime
## child/village entry, branch parity, lower-contamination continuation,
## and durable save/reload. No quest reward or unrelated rules changed.
const Session = preload("res://systems/run_session.gd")
const Gate = preload("res://systems/story_contamination_gate.gd")
const Child = preload("res://systems/story_event_entry.gd")
const Rumor = preload("res://systems/village_rumor_entry.gd")
var passed := 0
var failed := 0
var save_path := ""

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS contamination-story: ",label)
	else:
		failed += 1
		printerr("FAIL contamination-story: ",label)

func clean() -> void:
	for suffix in ["",".tmp"]:
		var path: String = save_path+str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
	var session = Session.new()
	root.add_child(session)
	save_path = "user://story_contamination_%d.json" % OS.get_process_id()
	clean()
	session.save_file_path = save_path
	session.start_new_world()
	check(Gate.MINIMUMS.size()==10,"ten story branch IDs including alternate prophet clue")
	check(not Gate.allows(session,"missing_event"),"unknown event id fails closed")
	check(not Gate.allows(null,Child.EVENT_ID),"missing session fails closed")
	for id in Gate.MINIMUMS:
		var minimum: int = int(Gate.MINIMUMS[id])
		session.world.story_events.erase(id)
		session.world.contamination = minimum-1
		check(not Gate.allows(session,str(id)),str(id)+" is blocked at "+str(minimum-1))
		session.world.contamination = minimum
		check(Gate.allows(session,str(id)),str(id)+" opens at exact threshold "+str(minimum))
		session.world.contamination = 0
		check(not Gate.allows(session,str(id)),str(id)+" is still unseen at zero")
		session.world.story_events[id] = {"status":"seen","choice":"","battle_result":""}
		check(Gate.allows(session,str(id)),str(id)+" seen story reopens below threshold")
		session.world.story_events[id] = {"status":"active","choice":"","battle_result":""}
		check(Gate.allows(session,str(id)),str(id)+" active story not relocked")
		session.world.story_events.erase(id)
	# Actual first appearance, revisit and restart of the child story.
	var child_tile: int = session.world.tiles.find("event")
	check(child_tile>=0,"first-lap wildcard event exists without a graveyard")
	session.world.position = child_tile
	session.world.contamination = 9
	check(not Child.can_enter(session,child_tile),"child cannot appear at contamination 9")
	check(not Child.begin(session,child_tile),"child cannot be first-saved below 10")
	check(session.get_story_event(Child.EVENT_ID).status=="unseen","below-gate child never wrote seen")
	session.world.contamination = 10
	check(Child.can_enter(session,child_tile),"child can appear at exactly 10")
	check(Child.begin(session,child_tile),"child first discovery saved")
	session.world.contamination = 0
	check(Child.can_enter(session,child_tile),"already seen child stays playable after prayer decrease")
	check(session.save_world(),"seen child below threshold is saved")
	session.reload_world()
	check(session.get_story_event(Child.EVENT_ID).status=="seen","seen child reload succeeds")
	check(Child.can_enter(session,child_tile),"seen child reopens after reload at zero")
	# Resolve abandonment in the test world through the actual source choice.
	check(Child.choose(session,child_tile,"leave"),"abandon branch resolves via original choice")
	var village: int = session.world.tiles.find("village")
	check(village>=0,"village source tile exists")
	session.world.position = village
	session.world.contamination = 14
	check(Rumor.eligible_event_id(session,village).is_empty(),"abandoned rumor blocked at 14")
	session.world.contamination = 15
	check(Rumor.eligible_event_id(session,village)==Rumor.ABANDONED_ID,"abandoned rumor opens exactly at 15")
	check(Rumor.begin(session,village)==Rumor.ABANDONED_ID,"abandoned rumor saves first encounter")
	session.world.contamination = 0
	check(Rumor.eligible_event_id(session,village)==Rumor.ABANDONED_ID,"seen abandoned rumor resumes at zero")
	check(session.save_world(),"abandoned rumor progression persists")
	session.reload_world()
	check(session.get_story_event(Rumor.ABANDONED_ID).status=="seen","abandoned rumor reloads")
	check(Rumor.eligible_event_id(session,village)==Rumor.ABANDONED_ID,"abandoned rumor resumes after restart")
	# Separate rescue branch should use the same limit rather than inherit an
	# already-seen abandoned rumor, with no extra reward or story conclusion.
	session.world.story_events[Child.EVENT_ID]={"status":"complete","choice":"protect_child","battle_result":"won"}
	session.world.event_flags["event:graveyard_child_ambush_01:rescued"]=true
	session.world.event_flags["event:graveyard_child_ambush_01:abandoned"]=false
	session.world.contamination = 14
	check(Rumor.eligible_event_id(session,village).is_empty(),"rescued rumor blocked at 14")
	session.world.contamination = 15
	check(Rumor.eligible_event_id(session,village)==Rumor.RESCUED_ID,"rescued rumor opens exactly at 15")
	session.world.contamination = 0
	check(not Gate.allows(session,Rumor.RESCUED_ID),"rescued rumor unseen at zero despite abandoned rumor already seen")
	# All nine entry modules must actually consume the common gate.
	var modules: Array[String] = [
		"story_event_entry.gd","village_rumor_entry.gd","knight_commander_entry.gd",
		"monster_hunter_entry.gd","cultist_rumor_entry.gd","cultist_altar_entry.gd",
		"ritual_portal_entry.gd","monster_king_hunt_entry.gd","prophet_story_entry.gd"
	]
	for path in modules:
		var file = FileAccess.open("res://systems/"+path,FileAccess.READ)
		var source: String = file.get_as_text() if file != null else ""
		check(source.contains("ContaminationGate.allows(session,"),path+" enforces gate at runtime")
	session.free()
	clean()
	print("STORY_CONTAMINATION_THRESHOLDS: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
