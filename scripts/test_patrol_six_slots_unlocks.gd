extends SceneTree
## New map counts, six *optional* patrol slots, automatic five monster
## tiles, locked first rest reward (max 3), and two reserved future swamp
## roads, through real generation and legacy save validation.
const Plan=preload("res://systems/route_plan.gd")
const State=preload("res://systems/map_state.gd")
const Session=preload("res://systems/run_session.gd")
var passed: int=0
var failed: int=0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, reason: String) -> void:
	if ok:
		passed+=1
		print("PASS patrol-six-slots: ",reason)
	else:
		failed+=1
		printerr("FAIL patrol-six-slots: ",reason)

func verify_fixed(board: Array, name: String) -> void:
	check(board.size()==24,name+": exactly 24 tiles")
	check(board[0]=="fortune-teller-camp" and board[8]=="village" and board[15]=="home",name+": permanent town/fortune/home anchors unchanged")

func _run() -> void:
	var defs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var plan: Dictionary=Plan.default_plan()
	check(Plan.valid(plan) and Plan.OPTIONAL_CAPACITY==6 and Plan.RESERVED_SWAMP_ROADS==2,"six optional slots and two protected future-swamp roads")
	check(Plan.AUTO_MONSTERS==5 and plan.selection.monster==0 and plan.selection.rest==0,"five monsters are automatic, zero extra tiles preselected")
	check(not plan.rest_unlocked and Plan.REST_LIMIT==3,"first unlockable rest tile is initially locked, cap three")
	for seed in range(10):
		var world=State.new(defs,1000+seed)
		var board: Array=world.tiles
		verify_fixed(board,"start seed %d" % seed)
		check(board.count("monster")==5 and board.count("event")==1,"start %d automatically includes exactly 5 monsters and 1 event" % seed)
		check(board.count("rest")==0 and board.count("swamp")==0 and board.count("basic")==11,"start %d has no rests/swamps and 11 empty roads" % seed)
		check(board.count("graveyard")==0 and board.count("unknown")==0 and board.count("altar")==0 and board.count("rare-monster")==0,"start %d advanced tiles absent" % seed)
	check(Plan.available(plan)==6,"start six slots available and none counted for automatic monsters")
	var rejected: Dictionary=plan.duplicate(true)
	rejected.selection["rest"]=1
	check(not Plan.valid(rejected) and Plan.adjust(plan,"rest",1)==plan,"rest cannot be selected before unlock")
	for i in range(6):
		plan=Plan.adjust(plan,"monster",1)
	check(Plan.valid(plan) and Plan.total_selected(plan)==6 and Plan.available(plan)==0,"six + clicks fill six optional slots with monsters")
	check(Plan.adjust(plan,"monster",1)==plan,"additional monster refuses seventh optional position")
	plan=Plan.adjust(plan,"monster",-1)
	check(Plan.total_selected(plan)==5 and Plan.available(plan)==1,"minus click restores exactly one free road")
	var chosen: Dictionary=Plan.default_plan()
	chosen.selection["monster"]=6
	for stage in [0,1,20,40,80,100]:
		var state=State.new(defs,642+stage,chosen)
		state.laps=0 if stage==0 else 12
		state.contamination=stage
		state.generate()
		verify_fixed(state.tiles,"full six-choice contamination %d" % stage)
		check(state.tiles.count("basic")>=2,"six optional monsters never consume two protected swamp roads at contamination %d" % stage)
		check(state.tiles.count("monster")>=5 if stage<20 else state.tiles.count("monster")>=4,"automatic monsters retained even after boss reservation at %d" % stage)
		check(state.tiles.count("rest")==0 and state.tiles.count("swamp")==0,"no unapproved rest or premature swamp at contamination %d" % stage)
		if stage>=20: check(state.tiles[23]=="boss","boss remains on 24th board slot at %d" % stage)
		if stage>=1: check(state.tiles.count("graveyard")==1,"first complete lap keeps mandatory cemetery at %d" % stage)
	var unlocked: Dictionary=Plan.default_plan()
	unlocked.rest_unlocked=true
	unlocked.selection["rest"]=3
	unlocked.selection["monster"]=3
	check(Plan.valid(unlocked) and Plan.available(unlocked)==0,"future rest unlock permits max three rests alongside three optional monsters")
	var invalid: Dictionary=unlocked.duplicate(true)
	invalid.selection["rest"]=4
	invalid.selection["monster"]=2
	check(not Plan.valid(invalid) and Plan.adjust(unlocked,"rest",1)==unlocked,"fourth rest rejected after unlock, even with free slots")
	var state2=State.new(defs,31415,unlocked)
	check(state2.tiles.count("rest")==3 and state2.tiles.count("monster")==8 and state2.tiles.count("basic")==5,"future unlocked choices replace exactly 6 roads, preserve five auto monsters")
	state2.laps=12
	state2.contamination=80
	state2.generate()
	check(state2.tiles.count("basic")>=2 and state2.tiles.count("swamp")==0,"two roads protected through cemetery and late corruption")
	var session: Node=root.get_node_or_null("RunSession")
	var own: bool=session==null
	if own:
		session=Session.new()
		session.name="RunSession"
		root.add_child(session)
	var old_path: String=session.save_file_path
	var scratch: String="user://six_slot_plan_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	session.start_new_world()
	var forged: Dictionary=Plan.default_plan()
	forged.rest_unlocked=true
	forged.selection["rest"]=1
	var first: Dictionary=session.confirm_patrol(forged)
	check(not bool(first.get("ok",false)) and not session.world.patrol_plan.rest_unlocked,"cannot forge rest unlock through saved route confirmation")
	var valid_plan: Dictionary=Plan.default_plan()
	valid_plan.selection["monster"]=2
	var done: Dictionary=session.confirm_patrol(valid_plan)
	check(bool(done.get("ok",false)) and int(session.world.patrol_plan.selection.monster)==2,"confirmed two added monsters persist independently of the five automatic")
	check(session.reload_world() and int(session.world.patrol_plan.selection.monster)==2,"new patrol plan survives JSON reload")
	# Legacy saves keep their original counts and unmodified route inventory.
	var old_style: Dictionary={"current":Plan.CURRENT.duplicate(),"reserve":Plan.RESERVE.duplicate()}
	check(Plan.valid(old_style),"legacy 6+5 route inventory remains accepted in old saves")
	var state3=State.new(defs,2000,old_style)
	check(state3.tiles.count("basic")==6 and state3.tiles.count("rest")==2 and state3.tiles.count("event")==2 and state3.tiles.count("swamp")==2,"legacy load retains its previous baseline tile quantities")
	var saved: Dictionary=state3.snapshot().duplicate(true)
	var restored=State.new(defs,10)
	check(restored.restore(saved) and restored.patrol_plan==old_style,"legacy patrol saved snapshot can be restored without changing save version")
	session.save_file_path=old_path
	if own: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("PATROL_SIX_SLOTS: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
