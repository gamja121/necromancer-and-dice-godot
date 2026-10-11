extends SceneTree
## W153/P2-04: real separate Godot-process crash/restart integration test.
## Only uses a dedicated test save, never the production map_run_v1.json.
## Run each phase using the ordered CI shell commands below.
const Session=preload("res://systems/run_session.gd")
const SAVE_PATH="user://w153_crash_boundary_integration_v1.json"
const SEED_FLAG="story:w153_integration:before_crash"
const AFTER_FLAG="story:w153_integration:after_commit"

var passed: int=0
var failed: int=0

func _initialize() -> void: call_deferred("_run")

func check(value: bool, message: String) -> void:
	if value:
		passed+=1
		print("PASS W153: ",message)
	else:
		failed+=1
		printerr("FAIL W153: ",message)

func erase_test_files() -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(SAVE_PATH+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH+suffix))

func session():
	var s=Session.new()
	root.add_child(s)
	s.save_file_path=SAVE_PATH
	return s

func check_primary() -> void:
	check(FileAccess.file_exists(SAVE_PATH),"committed primary save exists")
	var data=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	check(data is Dictionary and data.get("version",-1)==1,"committed primary save is valid JSON")

func seed() -> void:
	erase_test_files()
	var s=session()
	s.start_new_world()
	check_primary()
	check(s.set_event_flag(SEED_FLAG),"source-compatible story flag persisted")
	var move: Dictionary=s.prepare_map_roll()
	check(move.get("ok",false),"real pending movement persisted before crash")
	check(not s.world.pending_move.is_empty(),"new map movement is pending")
	check(s.event_flag_is_set(SEED_FLAG),"durable story flag set")
	check(s.world.move_serial>0,"movement transaction has a durable receipt")
	s.free()

func check_pre_crash_state(s) -> void:
	check(s.event_flag_is_set(SEED_FLAG),"previously committed story progress restored")
	check(not s.event_flag_is_set(AFTER_FLAG),"not-yet-committed future receipt absent")
	check(not s.world.pending_move.is_empty(),"pending movement survives restart")
	check(s.world.move_serial>0,"movement receipt survives process restart")
	check(s.encounter.is_empty(),"no phantom battle created on restart")

func crash_before_replace() -> void:
	var s=session()
	s.ensure_world()
	check_pre_crash_state(s)
	check_primary()
	# Model a process killed after the actual save's FileAccess.WRITE and
	# flush stages, before its final DirAccess.rename_absolute() commit.
	var file=FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
	check(file!=null,"temporary write file created")
	if file==null: quit(1); return
	file.store_string("{\"version\":1,\"pending_move\":")
	file.flush()
	check(file.get_error()==OK,"unfinished temporary save flushes to disk")
	file.close()
	check(FileAccess.file_exists(SAVE_PATH+".tmp"),"interrupted temporary save exists")
	check_primary()
	if failed>0: quit(1); return
	print("W153_CRASH_BEFORE_RENAME: intentional process termination")
	OS.delay_msec(100)
	OS.kill(OS.get_process_id())
	quit(33)

func verify_old_commit() -> void:
	var s=session()
	s.ensure_world()
	check_pre_crash_state(s)
	check_primary()
	check(FileAccess.file_exists(SAVE_PATH+".tmp"),"orphaned partial tmp survives process crash")
	var unreadable=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH+".tmp"))
	check(unreadable==null,"orphaned partial tmp is NOT a valid game save")
	check(not s.prepare_map_roll().get("ok",false),"pending movement cannot be rerolled to duplicate action")
	check(not s.world.pending_move.is_empty(),"rejected duplicate roll preserves original movement")
	s.free()

func crash_after_commit() -> void:
	var s=session()
	s.ensure_world()
	check_pre_crash_state(s)
	check(s.complete_map_move(),"existing pending move committed exactly once")
	check(s.world.pending_move.is_empty(),"map movement has been acknowledged")
	check(s.set_event_flag(AFTER_FLAG),"durable second transaction committed")
	check_primary()
	check(not FileAccess.file_exists(SAVE_PATH+".tmp"),"orphaned tmp overwritten during normal save")
	if failed>0: quit(1); return
	print("W153_CRASH_AFTER_COMMIT: intentional process termination")
	OS.delay_msec(100)
	OS.kill(OS.get_process_id())
	quit(34)

func verify_new_commit() -> void:
	var s=session()
	s.ensure_world()
	check(s.event_flag_is_set(SEED_FLAG),"old committed flag retained")
	check(s.event_flag_is_set(AFTER_FLAG),"successful commit survives process termination")
	check(s.world.pending_move.is_empty(),"completed move does not replay after restart")
	check(s.world.move_serial>0,"movement receipt preserved after completion")
	check_primary()
	var stable: Dictionary=s.world.snapshot().duplicate(true)
	var bytes: String=FileAccess.get_file_as_string(SAVE_PATH)
	check(s.complete_map_move(),"duplicate movement completion is harmless")
	check(s.set_event_flag(AFTER_FLAG),"duplicate flag confirmation is idempotent")
	check(s.world.snapshot()==stable,"duplicate actions cannot mutate run")
	check(FileAccess.get_file_as_string(SAVE_PATH)==bytes,"duplicate acknowledgements do not rewrite save")
	s.reload_world()
	check(s.event_flag_is_set(AFTER_FLAG),"second reload retains final flags")
	check(s.world.pending_move.is_empty(),"second reload still does not repeat move")
	s.free()

func _run() -> void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	var phase: String=args[0] if args.size()>0 else ""
	match phase:
		"seed": seed()
		"crash_before_replace": crash_before_replace()
		"verify_old_commit": verify_old_commit()
		"crash_after_commit": crash_after_commit()
		"verify_new_commit": verify_new_commit()
		"cleanup":
			erase_test_files()
			check(not FileAccess.file_exists(SAVE_PATH),"isolated test save cleaned up")
		_:
			check(false,"unknown phase "+phase)
	print("W153_PROCESS_PHASE_%s: %d passed, %d failed" % [phase,passed,failed])
	quit(0 if failed==0 else 1)
