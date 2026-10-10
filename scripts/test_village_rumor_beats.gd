extends SceneTree
## P1-05B: whole rescued/abandoned village rumor beats and atomic completion.
const SessionScript=preload("res://systems/run_session.gd")
const Child=preload("res://systems/story_event_entry.gd")
const Rumor=preload("res://systems/village_rumor_entry.gd")
const Beats=preload("res://systems/village_rumor_beats.gd")

class Result:
	extends RefCounted
	var outcome: String
	var units: Array=[]
	func _init(value: String) -> void: outcome=value
	func winner() -> String: return outcome
	func find_id(_id: String) -> Dictionary: return {}

var passed: int=0
var failed: int=0
var files: Array[String]=[]

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, what: String) -> void:
	if ok:
		passed+=1
		print("PASS village-beats: ",what)
	else:
		failed+=1
		printerr("FAIL village-beats: ",what)

func remove_file(path: String) -> void:
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func make(suffix: String, rescued: bool):
	var s=SessionScript.new()
	root.add_child(s)
	var path: String="user://village_beats_%d_%s.json" % [OS.get_process_id(),suffix]
	files.append(path)
	remove_file(path)
	s.save_file_path=path
	s.start_new_world()
	var graveyard: int=s.world.tiles.find("graveyard")
	check(graveyard>=0,"graveyard found "+suffix)
	s.world.position=graveyard
	check(Child.begin(s,graveyard),"child discovered "+suffix)
	if rescued:
		check(Child.choose(s,graveyard,"protect_child"),"rescue selected")
		check(s.start_story_encounter(Child.EVENT_ID,graveyard,[s.world.roster[0].id]),"ghoul checkpoint started")
		check(s.finish_encounter(Result.new("ally")),"real rescue won")
		check(s.acknowledge_graveyard_battle_result(),"rescue outcome acknowledged")
	else:
		check(Child.choose(s,graveyard,"leave"),"abandon chosen")
	var village: int=s.world.tiles.find("village")
	s.world.position=village
	var event_id: String=Rumor.RESCUED_ID if rescued else Rumor.ABANDONED_ID
	check(Rumor.begin(s,village)==event_id,"matching village rumor discovered")
	return s

func verify_beats() -> void:
	check(Beats.count(Rumor.RESCUED_ID)==5,"rescued branch has five exact source beats")
	check(Beats.count(Rumor.ABANDONED_ID)==6,"abandoned branch has six exact source beats")
	check(Beats.count("unregistered")==0,"unknown branch has no beats")
	check(Beats.beat("unregistered",0).is_empty(),"unknown branch cannot render")
	check(Beats.beat(Rumor.RESCUED_ID,-1).is_empty(),"negative beat is invalid")
	check(Beats.beat(Rumor.RESCUED_ID,5).is_empty(),"out-of-bounds beat is invalid")
	check(Beats.is_final(Rumor.RESCUED_ID,4),"rescue last scene index")
	check(Beats.is_final(Rumor.ABANDONED_ID,5),"abandon last scene index")
	check(not Beats.is_final(Rumor.ABANDONED_ID,4),"abandon has additional scene")
	check(not Beats.is_final("unknown",0),"unknown event cannot complete")
	check(Beats.beat(Rumor.RESCUED_ID,0).effect==Rumor.INTRO[Rumor.RESCUED_ID],"saved intro matches old first scene")
	check(Beats.beat(Rumor.ABANDONED_ID,0).effect==Rumor.INTRO[Rumor.ABANDONED_ID],"abandon intro matches old first scene")
	check(Beats.beat(Rumor.RESCUED_ID,1).dialogue=="공동묘지에서 봤다더군. 아이를 덮치던 구울을… 다른 괴물이 죽였대.","canonical rescued gossip exact")
	check(Beats.beat(Rumor.RESCUED_ID,2).dialogue=="죽은 것들을 거느리고 있었다고 해. 사람은 아니었어.","canonical rescued detail exact")
	check(Beats.beat(Rumor.RESCUED_ID,3).dialogue=="…쉿. 저기.","canonical rescued noticed exact")
	check(Beats.beat(Rumor.RESCUED_ID,4).effect.contains("‘괴물이 아이를 구했다’"),"rescue final silence exact")
	check(Beats.beat(Rumor.ABANDONED_ID,1).dialogue.contains("아이 울음소리가 들렸다더군…"),"abandoned missing child gossip")
	check(Beats.beat(Rumor.ABANDONED_ID,2).dialogue=="그 자리에 이상한 괴물이 있었다고 했어. 보고도 그냥 두고 갔다더군.","abandoned detail exact")
	check(Beats.beat(Rumor.ABANDONED_ID,3).dialogue=="산 자를 구하지 않는 괴물이라면… 그건 더 위험한 거 아냐?","abandoned extra fear exact")
	check(Beats.beat(Rumor.ABANDONED_ID,4).dialogue=="…쉿. 저자야.","abandoned noticed exact")
	check(Beats.beat(Rumor.ABANDONED_ID,5).effect=="마을에는 아이를 버리고 지나간 괴물에 대한 소문만 남았다.","abandoned final exact")
	check(Beats.beat(Rumor.RESCUED_ID,0).layers.is_empty(),"arriving has no overlay")
	check(Beats.beat(Rumor.RESCUED_ID,1).layers==[Beats.WHISPER],"gossip reveals whispers")
	check(Beats.beat(Rumor.RESCUED_ID,2).layers==[Beats.WHISPER,Beats.TURN],"detail overlays turn on whisper")
	check(Beats.beat(Rumor.RESCUED_ID,3).layers==[Beats.TURN,Beats.NECROMANCER],"noticing reveals necromancer")
	check(Beats.beat(Rumor.ABANDONED_ID,3).layers==[Beats.TURN,Beats.NECROMANCER],"abandoned fear reveals necromancer")
	for art in [Beats.BASE,Beats.WHISPER,Beats.TURN,Beats.NECROMANCER]:
		check(ResourceLoader.exists(art),"original art resource exists: "+art)
	var changed: Dictionary=Beats.beat(Rumor.RESCUED_ID,1)
	changed.layers.clear()
	changed.dialogue="tampered"
	check(Beats.beat(Rumor.RESCUED_ID,1).layers.size()==1,"returned layers cannot mutate original")
	check(Beats.beat(Rumor.RESCUED_ID,1).dialogue.begins_with("공동묘지"),"returned beat cannot mutate original")

func run_branch(rescued: bool) -> void:
	var name: String="rescued" if rescued else "abandoned"
	var s=make(name,rescued)
	var event_id: String=Rumor.RESCUED_ID if rescued else Rumor.ABANDONED_ID
	var other: String=Rumor.ABANDONED_ID if rescued else Rumor.RESCUED_ID
	var idx: int=s.world.position
	var count: int=Beats.count(event_id)
	check(Rumor.current_beat(s,event_id)==0,"initial displayed beat is arrival: "+name)
	check(Rumor.current_beat(s,other)==-1,"opposite rumor inaccessible: "+name)
	check(Rumor.progress_flag(event_id,0).is_empty(),"arrival has no separate flag")
	check(Rumor.progress_flag(event_id,count).is_empty(),"past-final index has no flag")
	check(Rumor.progress_flag("bogus",1).is_empty(),"unknown progress flag denied")
	check(not Rumor.advance(s,idx,event_id,1),"cannot skip arrival: "+name)
	check(not Rumor.advance(s,idx,other,0),"cannot switch branches: "+name)
	check(not Rumor.advance(s,idx+1,event_id,0),"preview cannot advance rumor: "+name)
	for step in range(count-1):
		var before: Dictionary=s.world.snapshot().duplicate(true)
		check(Rumor.current_beat(s,event_id)==step,"beat index before explicit advance %s %d" % [name,step])
		check(not s.event_flag_is_set(Rumor.complete_flag(event_id)),"not complete before final %s %d" % [name,step])
		check(s.get_story_event(event_id).status=="seen","status stays seen %s %d" % [name,step])
		check(Rumor.advance(s,idx,event_id,step),"explicit beat advance persisted %s %d" % [name,step])
		check(Rumor.current_beat(s,event_id)==step+1,"next beat now shown %s %d" % [name,step])
		check(s.event_flag_is_set(Rumor.progress_flag(event_id,step+1)),"beat flag saved %s %d" % [name,step+1])
		var written: Dictionary=s.world.snapshot().duplicate(true)
		check(not Rumor.advance(s,idx,event_id,step),"stale UI click rejected %s %d" % [name,step])
		check(s.world.snapshot()==written,"stale click cannot write %s %d" % [name,step])
		s.reload_world()
		check(Rumor.current_beat(s,event_id)==step+1,"reload keeps exact beat %s %d" % [name,step+1])
		check(s.world.position==idx,"reload preserves story tile %s %d" % [name,step+1])
		check(Rumor.begin(s,idx)==event_id,"reopening unfinished scene resumes: "+name)
	check(Beats.is_final(event_id,Rumor.current_beat(s,event_id)),"last beat reached: "+name)
	check(not s.event_flag_is_set(Rumor.complete_flag(event_id)),"last beat appearance does not complete: "+name)
	check(s.get_story_event(event_id).status=="seen","last beat still seen before finish: "+name)
	s.reload_world()
	check(Rumor.current_beat(s,event_id)==count-1,"reloaded last beat still needs acknowledgement: "+name)
	check(Rumor.advance(s,idx,event_id,count-1),"final scene finished by explicit click: "+name)
	check(s.get_story_event(event_id).status=="complete","rumor completed only at final click: "+name)
	check(s.event_flag_is_set(Rumor.complete_flag(event_id)),"canonical complete flag set: "+name)
	check(s.event_flag_is_set(Rumor.seen_flag(event_id)),"seen flag retained after completion: "+name)
	check(s.get_story_event(other).status=="unseen","opposite branch untouched after completion: "+name)
	check(not s.event_flag_is_set(Rumor.complete_flag(other)),"opposite completion flag absent: "+name)
	check(Rumor.current_beat(s,event_id)==-1,"completed rumor has no current scene: "+name)
	check(Rumor.eligible_event_id(s,idx).is_empty(),"completed rumor cannot auto-trigger: "+name)
	check(not Rumor.advance(s,idx,event_id,count-1),"completed rumor cannot repeat: "+name)
	s.reload_world()
	check(s.get_story_event(event_id).status=="complete","completion reloads: "+name)
	check(s.event_flag_is_set(Rumor.complete_flag(event_id)),"completed flag reloads: "+name)
	check(Rumor.begin(s,idx).is_empty(),"revisit does not replay completed rumor: "+name)
	s.free()

func storage_failures(rescued: bool) -> void:
	var name: String="win" if rescued else "leave"
	var s=make("rollback_"+name,rescued)
	var event_id: String=Rumor.RESCUED_ID if rescued else Rumor.ABANDONED_ID
	var idx: int=s.world.position
	var path: String=s.save_file_path
	var missing: String="user://village_beats_uncreated_%d/x.json" % OS.get_process_id()
	var before: Dictionary=s.world.snapshot().duplicate(true)
	s.save_file_path=missing
	check(not Rumor.advance(s,idx,event_id,0),"intermediate save failure detected "+name)
	check(s.world.snapshot()==before,"failed intermediate step rolls back "+name)
	check(Rumor.current_beat(s,event_id)==0,"failed intermediate step remains visible "+name)
	s.save_file_path=path
	check(Rumor.advance(s,idx,event_id,0),"intermediate step saves after recovery "+name)
	var count: int=Beats.count(event_id)
	for step in range(1,count-1):
		check(Rumor.advance(s,idx,event_id,step),"advance for final failure fixture %s %d" % [name,step])
	check(Rumor.current_beat(s,event_id)==count-1,"final scene waits for click "+name)
	before=s.world.snapshot().duplicate(true)
	s.save_file_path=missing
	check(not Rumor.advance(s,idx,event_id,count-1),"final completion save failure detected "+name)
	check(s.world.snapshot()==before,"final write rolled back entire stage "+name)
	check(s.get_story_event(event_id).status=="seen","save failure does not complete "+name)
	check(not s.event_flag_is_set(Rumor.complete_flag(event_id)),"save failure leaves complete flag false "+name)
	s.save_file_path=path
	s.reload_world()
	check(Rumor.current_beat(s,event_id)==count-1,"restart resumes failed final scene "+name)
	check(Rumor.advance(s,idx,event_id,count-1),"final completion succeeds on retry "+name)
	s.reload_world()
	check(s.get_story_event(event_id).status=="complete","retried completion survives reload "+name)
	s.free()

func invalid_progress() -> void:
	var s=make("corrupted",false)
	var event_id: String=Rumor.ABANDONED_ID
	var idx: int=s.world.position
	s.world.event_flags[Rumor.progress_flag(event_id,2)]=true
	check(Rumor.current_beat(s,event_id)==-1,"non-contiguous future stage is rejected")
	check(not Rumor.advance(s,idx,event_id,0),"cannot skip over missing stage")
	s.world.event_flags.erase(Rumor.progress_flag(event_id,2))
	check(Rumor.current_beat(s,event_id)==0,"repairing flags restores valid intro")
	s.world.pending_reward={"kind":"test"}
	check(not Rumor.advance(s,idx,event_id,0),"cannot progress with pending reward")
	s.world.pending_reward={}
	check(Rumor.advance(s,idx,event_id,0),"normal progress after blockers cleared")
	s.free()

func verify_ui() -> void:
	var text: String=FileAccess.get_file_as_string("res://map.gd")
	check(text.contains('func show_village_rumor_beat(index: int, event_id: String) -> void:'),"village event renders each beat")
	check(text.contains('call_deferred("resume_village_rumor_if_unfinished")'),"save startup resumes discovered village rumor")
	check(text.contains('func resume_village_rumor_if_unfinished() -> void:'),"resume callback available")
	check(text.contains('session.get_story_event(event_id).status=="seen"'),"startup reopens only a previously seen rumor")
	check(text.contains('VillageRumorEntry.current_beat(session,event_id)'),"UI resolves durable scene index")
	check(text.contains('for layer in beat.layers:'),"scene overlays use authored layer stack")
	check(text.contains('str(beat.dialogue)'),"UI shows original speaker dialogue")
	check(text.contains('VillageRumorEntry.advance(session,index,event_id,shown_beat)'),"UI uses guarded stage advancement")
	check(text.contains('VillageRumorBeats.is_final(event_id,shown_beat)'),"UI checks last beat before exit")
	check(text.contains('"마치기"'),"final confirmation UI provided")
	check(text.contains('"마을 기능"'),"base village actions preserved")
	check(text.contains('"돌아가기"'),"unfinished rumor may be dismissed")
	check(text.contains('if finishing:'),"only finish closes rumor automatically")

func _run() -> void:
	verify_beats()
	run_branch(true)
	run_branch(false)
	storage_failures(true)
	storage_failures(false)
	invalid_progress()
	verify_ui()
	for path in files: remove_file(path)
	print("VILLAGE_RUMOR_BEATS_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
