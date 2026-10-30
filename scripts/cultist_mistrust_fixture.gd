extends RefCounted
## Test-only genuine source-API chain; never imported by production gameplay.
const Child=preload("res://systems/story_event_entry.gd")
const Rumor=preload("res://systems/village_rumor_entry.gd")
const RumorBeats=preload("res://systems/village_rumor_beats.gd")
const Commander=preload("res://systems/knight_commander_entry.gd")
const CommanderBeats=preload("res://systems/knight_commander_beats.gd")
const Prophet=preload("res://systems/prophet_story_entry.gd")
const ProphetBeats=preload("res://systems/prophet_story_beats.gd")
const Cultist=preload("res://systems/cultist_rumor_entry.gd")
const CultistBeats=preload("res://systems/cultist_rumor_beats.gd")
const Altar=preload("res://systems/cultist_altar_entry.gd")

static func prepare(s) -> bool:
	s.start_new_world()
	s.world.contamination=93
	s.world.lap_ready=true
	s.world.leave_home()
	var grave: int=s.world.tiles.find("graveyard")
	var village: int=s.world.tiles.find("village")
	var camp: int=s.world.tiles.find("fortune-teller-camp")
	var altar: int=s.world.tiles.find("event")
	if mini(mini(grave,village),mini(camp,altar))<0: return false
	s.world.position=grave
	if not Child.begin(s,grave) or not Child.choose(s,grave,"leave"): return false
	s.world.position=village
	if Rumor.begin(s,village)!=Rumor.ABANDONED_ID: return false
	for beat in range(RumorBeats.count(Rumor.ABANDONED_ID)):
		if not Rumor.advance(s,village,Rumor.ABANDONED_ID,beat): return false
	if not Commander.begin(s,village) or Commander.route(s)!="prophet": return false
	for beat in range(CommanderBeats.count("prophet")):
		if not Commander.advance(s,village,beat): return false
	s.world.position=camp
	if not Prophet.begin(s,camp): return false
	for beat in range(ProphetBeats.count()):
		if not Prophet.advance(s,camp,beat): return false
	s.world.position=village
	if not Cultist.begin(s,village) or Cultist.route(s)!="prophet": return false
	for beat in range(CultistBeats.count()):
		if not Cultist.advance(s,village,beat): return false
	s.world.position=altar
	s.world.contamination=50
	return s.save_world() and Altar.begin(s,altar) and Altar.advance(s,altar,0) and Altar.advance(s,altar,1)
