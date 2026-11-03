extends RefCounted
const Source=preload("res://scripts/cultist_mistrust_fixture.gd")
const Inquiry=preload("res://systems/commander_inquiry_entry.gd")
const InquiryBeats=preload("res://systems/commander_inquiry_beats.gd")
const Hunt=preload("res://systems/witch_hunt_entry.gd")
const Beats=preload("res://systems/witch_hunt_beats.gd")
const State=preload("res://systems/map_state.gd")
static func prepare(session, explained: bool=true) -> bool:
	if not Source.prepare_mistrust(session): return false
	var at: int=session.world.position
	session.world.move_serial+=1
	if not Inquiry.begin(session,at): return false
	for index in range(2):
		if not Inquiry.advance(session,at,index): return false
	if not Inquiry.choose(session,at,2,"explain" if explained else "withhold"): return false
	for index in range(3,InquiryBeats.count()):
		if not Inquiry.advance(session,at,index): return false
	return Inquiry.completed(session)
static func arrive(session, stage: int) -> bool:
	session.world.position=State.HOME if stage==2 else session.world.tiles.find("village")
	session.world.move_serial+=1
	if stage==2: session.world.lap_ready=true
	return session.save_world()
static func finish_stage(session, stage: int, decision: String) -> bool:
	var at: int=session.world.position
	if not Hunt.begin(session,stage,at): return false
	for index in range(Beats.CHOICE_INDEX):
		if not Hunt.advance(session,stage,at,index): return false
	if not Hunt.choose(session,stage,at,Beats.CHOICE_INDEX,decision): return false
	for index in range(Beats.CHOICE_INDEX+1,Beats.count()):
		if not Hunt.advance(session,stage,at,index): return false
	return Hunt.completed(session,stage)
