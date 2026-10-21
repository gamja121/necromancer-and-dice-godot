extends RefCounted

const RoutePlan = preload("res://systems/route_plan.gd")
const Routine = preload("res://systems/routine_event_catalog.gd")
const Discovery = preload("res://systems/location_discoveries.gd")
const HILL_UNLOCK_FLAG = "event:discovery:forest:unlocked"
const HILL_HOME_NOTICE = "ui:unlock:forest:home_pending"
const Rules = preload("res://systems/battlefield_rules.gd")
const HOME = 15
const BOSS_CONTAMINATION = 20
const LAP_CONTAMINATION_GAIN = 7
# Swamp growth: 15 -> 1 tile, 30 -> 2 tiles (maximum).
# Boss stages and the separate 40/80 extra-monster conversions are unchanged.
const FIRST_SWAMP_CONTAMINATION = 15
const SECOND_SWAMP_CONTAMINATION = 30
# Preserve the existing boss art and encounter path at the 24th slot.
const BOSS_TILE_INDEX = 23
## First expedition: five guaranteed monster tiles; TWO events; no
## rests, swamps or hills. One ordinary road is traded for the second event,
## preserving 24 slots and both future-swamp reservations.
## Two ordinary roads are reserved for contamination swamps (one at 15,
## another at 30); optional patrol picks and monster conversions cannot take them.
const COUNTS = {"basic":11,"graveyard":0,"altar":0,"unknown":0,"forest":0,"rest":0,"monster":5,"rare-monster":0,"gem":1,"event":2,"swamp":0,"warp":2}
const NAMES = {"basic":"길","graveyard":"공동묘지","altar":"제단","unknown":"세계수","forest":"언덕","rest":"숙영","monster":"일반 마물","rare-monster":"희귀 마물","gem":"보물상자","event":"사건","swamp":"오염된 늪지대","warp":"워프","home":"우리집","village":"마을","fortune-teller-camp":"점술가의 막사","boss":"보스"}
var definitions: Dictionary
var rng = RandomNumberGenerator.new()
var tiles: Array = []
var roster: Array = []
var position = HOME
var cleared: Array = []
var contamination = 0
# Historical gate for world-tree discovery, never reset by purification.
var max_contamination_reached: int = 0
var laps = 0
var lap_ready = false
var last_face = 1
# Purely visual stage-space rest pose for the ONE shared die. Optional in
# existing v1 saves; no gameplay roll probabilities or RNG state change.
var dice_visual_position: Array = [602,308]
var dice_visual_face: int = 1
var dice_visual_rotation: int = 0
var region = "default"
var dice_cards: Array = []
var brand_cards: Array = []
var graveyard_corpses: Array = []
var reward_receipts: Array = []
# Run records survive reload. Existing version:1 saves default to a live run.
var enemies_defeated: int = 0
var run_result: Dictionary = {}
var pending_reward: Dictionary = {}
var next_serial = 2
var move_serial = 0
var map_serial = 0
var previous_map_roll = 0
var previous_map_card = ""
var pending_move: Dictionary = {}
var active_encounter: Dictionary = {}
var prophecy: Dictionary = {"rolls":[]}
var last_prophecy: Dictionary = {}
var shop_trade: Dictionary = {}
var patrol_plan: Dictionary = RoutePlan.default_plan()
var scout: Dictionary = {"scouted":false,"intel":[]}
var prayer_result: Dictionary = {}
var event_flags: Dictionary = {}
# Event stages/choices are separate from canonical web-compatible boolean flags.
var story_events: Dictionary = {}

func next_id(prefix: String) -> String:
	var value = "%s-%d" % [prefix,next_serial]
	next_serial += 1
	return value

func _init(data: Dictionary = {}, seed_value: int = 1, initial_plan: Dictionary = {}) -> void:
	definitions = data
	if RoutePlan.valid(initial_plan): patrol_plan=initial_plan.duplicate(true)
	rng.seed = seed_value
	var rules = Rules.new(data,rng.randi())
	for slug in ["skeleton-spear","skeleton-archer"]:
		var u = rules.individual(slug,"owned-"+str(roster.size()))
		u.current_hp = u.max_hp
		roster.append(u)
	generate()

static func centers() -> Array:
	var result: Array = []
	for i in range(8): result.append(Vector2(20+i*10,12))
	for i in range(4): result.append(Vector2(94,29+i*14))
	for i in range(7): result.append(Vector2(79-i*58.0/6.0,85))
	for i in range(5): result.append(Vector2(6,69-i*13.5))
	return result

static func required_swamp_count(level: int) -> int:
	return 2 if level >= SECOND_SWAMP_CONTAMINATION else (1 if level >= FIRST_SWAMP_CONTAMINATION else 0)

func generate() -> void:
	map_serial += 1
	var counts = COUNTS.duplicate()
	var deltas = RoutePlan.deltas(patrol_plan)
	for type in deltas: counts[type] += int(deltas[type])
	# The cemetery is guaranteed to arrive ONLY on the newly shuffled map
	# after the first completed lap (leave_home increments laps before generate).
	# Normalize legacy patrol plans too; tombs never reappear on lap zero.
	var unlocked_graveyards: int = 1 if laps>=1 else 0
	counts.basic += int(counts.graveyard)-unlocked_graveyards
	counts.graveyard = unlocked_graveyards
	var requested_conversion = 2 if contamination>=80 else (1 if contamination>=40 else 0)
	# Two roads belong to 15/30 swamp corruption; never use those slots for
	# patrol monsters/rests or higher-contamination extra monster stones.
	var conversion = mini(requested_conversion,maxi(0,int(counts.basic)-RoutePlan.RESERVED_SWAMP_ROADS))
	counts.basic -= conversion
	counts.monster += conversion
	# Use only the two protected roads for the new automatically corrupted
	# marsh tiles. Legacy route plans already contain two swamps; never add
	# duplicates, and keep the total number of board slots unchanged.
	var added_swamps: int = mini(maxi(0,required_swamp_count(contamination)-int(counts.swamp)),maxi(0,int(counts.basic)))
	counts.basic -= added_swamps
	counts.swamp += added_swamps
	# Every genuinely discovered EXTRA place (including the hill)
	# persists through HOME reshuffles without consuming reserved swamp roads.
	# Optional places, including the hill, appear only after their discovery flags.
	for kind in Discovery.ORDER:
		if event_flags.get(Discovery.unlock_flag(kind),false)==true and int(counts.basic)>maxi(0,RoutePlan.RESERVED_SWAMP_ROADS-int(counts.swamp)):
			counts.basic -= 1
			counts[kind] += 1
	if contamination>=BOSS_CONTAMINATION: counts.monster -= 1
	var pool: Array = []
	for key in counts:
		for i in range(counts[key]): pool.append(key)
	for i in range(pool.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var old = pool[i]
		pool[i] = pool[j]
		pool[j] = old
	tiles = []
	for i in range(24):
		if i==0: tiles.append("fortune-teller-camp")
		elif i==8: tiles.append("village")
		elif i==HOME: tiles.append("home")
		elif i==BOSS_TILE_INDEX and contamination>=BOSS_CONTAMINATION: tiles.append("boss")
		else: tiles.append(pool.pop_back())
	cleared = []
	scout = {"scouted":false,"intel":[]}
	lap_ready = false


## If contamination reaches 20 during an existing lap (e.g. a failed
## world-tree prayer), reveal the boss without waiting for another lap.
## The caller persists this along with the change in one transaction.
func reveal_boss_at_threshold() -> bool:
	if contamination < BOSS_CONTAMINATION or tiles.size() != 24:
		return false
	if tiles[BOSS_TILE_INDEX] == "boss":
		return false
	# A mid-lap boss reveal must not swallow one of the two guaranteed
	# event locations if the random board originally put it at slot 23.
	# Move that event onto an existing, unoccupied monster tile instead:
	# the boss replaces the displaced monster, exactly as in generate().
	# This keeps the event count, RNG state and swamp-reserved roads intact.
	if tiles[BOSS_TILE_INDEX] == "event":
		for candidate in range(tiles.size()):
			if candidate == position or tiles[candidate] != "monster": continue
			tiles[candidate] = "event"
			cleared.erase(candidate)
			if scout.get("intel",[]) is Array:
				scout["intel"] = scout.get("intel",[]).filter(func(entry): return int(entry.get("index",-1)) != candidate)
			break
	tiles[BOSS_TILE_INDEX] = "boss"
	# A previously cleared or scouted ordinary tile cannot carry those
	# semantics into a fresh boss encounter at the same board slot.
	cleared.erase(BOSS_TILE_INDEX)
	if scout.get("intel",[]) is Array:
		scout["intel"] = scout.get("intel",[]).filter(func(entry): return int(entry.get("index",-1)) != BOSS_TILE_INDEX)
	return true


## Reveal newly corrupted roads immediately when pollution rises mid-lap
## (e.g. a failed world-tree prayer), without rerolling or changing RNG.
## Existing story, home, boss, warp, monster and current hero tiles are safe.
## Caller must persist this in the same transaction as contamination change.
func reveal_swamps_for_contamination() -> int:
	if tiles.size() != 24: return 0
	var needed: int = maxi(0,required_swamp_count(contamination)-tiles.count("swamp"))
	if needed == 0: return 0
	var changed: int = 0
	# Rotate the preferred road per map/movement without advancing RNG state.
	var start: int = (map_serial * 7 + move_serial * 3) % tiles.size()
	for offset in range(tiles.size()):
		if changed >= needed: break
		var i: int = (start+offset)%tiles.size()
		if i == position or tiles[i] != "basic": continue
		tiles[i] = "swamp"
		cleared.erase(i)
		changed += 1
	return changed

## Actual discovery converts exactly one unoccupied ordinary road into a
## forest on the CURRENT board without touching RNG/priority story cells.
## -1 means no safe free road: the caller must not issue a fake unlock.
func reveal_discovered_hill() -> int:
	return reveal_discovered_location("forest")

## Change precisely ONE vacant ordinary road, while preserving its
## in-flight position, two future swamp roads, fixed and story cells.
## The saved unlock flag is committed by RunSession only on success.
func reveal_discovered_location(kind: String) -> int:
	if not Discovery.exists(kind) or tiles.size()!=24 or event_flags.get(Discovery.unlock_flag(kind),false)==true: return -1
	# Never steal the two future swamp reservations on a low-corruption lap.
	if tiles.count("basic") <= maxi(0,RoutePlan.RESERVED_SWAMP_ROADS-tiles.count("swamp")): return -1
	var start: int = (map_serial*7+move_serial*3)%tiles.size()
	for offset in range(tiles.size()):
		var i: int = (start+offset)%tiles.size()
		if i == position or i == BOSS_TILE_INDEX or tiles[i]!="basic": continue
		tiles[i] = kind
		cleared.erase(i)
		return i
	return -1

func move_path(face: int) -> Array:
	move_serial += 1
	last_face = face
	var path: Array = []
	for i in range(face):
		position = (position+1)%24
		path.append(position)
		if position==HOME:
			lap_ready = true
			break
	return path

func warp_destination() -> int:
	for i in range(tiles.size()):
		if i!=position and tiles[i]=="warp": return i
	return position

func leave_home() -> void:
	if lap_ready:
		contamination = mini(100,contamination+LAP_CONTAMINATION_GAIN)
		max_contamination_reached = maxi(max_contamination_reached,contamination)
		laps += 1
	generate()

func snapshot() -> Dictionary:
	return {"version":1,"tiles":tiles,"roster":roster,"position":position,"cleared":cleared,"contamination":contamination,"max_contamination_reached":maxi(max_contamination_reached,contamination),"laps":laps,"lap_ready":lap_ready,"last_face":last_face,"dice_visual_position":dice_visual_position.duplicate(),"dice_visual_rotation":dice_visual_rotation,"dice_visual_face":dice_visual_face,"region":region,"rng_seed":str(rng.seed),"rng_state":str(rng.state),"dice_cards":dice_cards,"brand_cards":brand_cards,"graveyard_corpses":graveyard_corpses,"reward_receipts":reward_receipts,"enemies_defeated":enemies_defeated,"run_result":run_result.duplicate(true),"pending_reward":pending_reward,"next_serial":next_serial,"move_serial":move_serial,"map_serial":map_serial,"previous_map_roll":previous_map_roll,"previous_map_card":previous_map_card,"pending_move":pending_move,"active_encounter":active_encounter,"prophecy":prophecy,"last_prophecy":last_prophecy,"shop_trade":shop_trade,"patrol_plan":patrol_plan,"scout":scout,"prayer_result":prayer_result,"event_flags":event_flags.duplicate(true),"story_events":story_events.duplicate(true)}

func restore(saved: Dictionary) -> bool:
	if saved.get("version",0)!=1 or not saved.get("tiles") is Array or saved.tiles.size()!=24: return false
	if not saved.get("roster") is Array or not saved.get("cleared") is Array: return false
	if saved.get("position",-1)<0 or saved.position>=24 or not saved.get("region","") in ["default","winter","hell"]: return false
	for tile in saved.tiles:
		if not NAMES.has(tile): return false
	if saved.tiles[0]!="fortune-teller-camp" or saved.tiles[8]!="village" or saved.tiles[15]!="home": return false
	for u in saved.roster:
		if not u is Dictionary or not definitions.has(u.get("slug","")) or not u.has("current_hp") or not u.has("brands"): return false
		if u.current_hp<1 or u.current_hp>u.max_hp: return false
	for key in ["contamination","laps","lap_ready","last_face","rng_seed","rng_state"]:
		if not saved.has(key): return false
	if saved.contamination<0 or saved.contamination>100: return false
	for field in ["dice_cards","brand_cards","graveyard_corpses","reward_receipts"]:
		if saved.has(field) and not saved[field] is Array: return false
	for field in ["pending_reward","pending_move","active_encounter","prophecy","last_prophecy","shop_trade","patrol_plan","scout","prayer_result","event_flags","story_events","run_result"]:
		if saved.has(field) and not saved[field] is Dictionary: return false
	if int(saved.get("enemies_defeated",0))<0: return false
	var terminal: Dictionary = saved.get("run_result",{})
	if not terminal.is_empty():
		if terminal.get("reason","")!="battle_defeat" or terminal.get("ended",false)!=true: return false
		for value in ["laps","contamination","enemies_defeated","lost_monsters","surviving_monsters"]:
			if not terminal.has(value) or int(terminal[value])<0: return false
	var stored_flags: Dictionary = saved.get("event_flags",{})
	for flag in stored_flags:
		if not flag is String or str(flag).is_empty() or not stored_flags[flag] is bool: return false
	# Old saves have no story_events key and must restore as unseen events.
	var stored_story_events: Dictionary = saved.get("story_events",{})
	for event_id in stored_story_events:
		if not event_id is String or event_id.is_empty(): return false
		var entry = stored_story_events[event_id]
		if not entry is Dictionary: return false
		if not entry.get("status",null) is String or not entry.status in ["seen","active","complete"]: return false
		if not entry.get("choice",null) is String: return false
		# Old story entries may omit battle_result; treat those as pending.
		if not entry.get("battle_result","") is String: return false
		if not entry.get("battle_result","") in ["","won","lost"]: return false
		if entry.status == "seen" and (not entry.choice.is_empty() or not entry.get("battle_result","").is_empty()): return false
	var plan: Dictionary = saved.get("patrol_plan",RoutePlan.default_plan())
	if not RoutePlan.valid(plan): return false
	var intel_state: Dictionary = saved.get("scout",{"scouted":false,"intel":[]})
	if not intel_state.get("scouted") is bool or not intel_state.get("intel") is Array: return false
	for entry in intel_state.intel:
		if not entry is Dictionary: return false
		var index = int(entry.get("index",-1))
		if index<0 or index>=24 or not entry.get("type","") in ["monster","rare-monster","boss"]: return false
		if saved.tiles[index]!=entry.type or int(entry.get("count",0))<1 or int(entry.count)>4: return false
		if not entry.get("grade","") in ["normal","advanced","hero"] or not entry.get("legion","") in Rules.NEED: return false
	var prediction: Dictionary = saved.get("prophecy",{"rolls":[]})
	if not prediction.get("rolls",[]) is Array: return false
	for key in ["ally_hp","ally_attack","ally_speed","enemy_attack"]:
		if not prediction.get(key,0) is float and not prediction.get(key,0) is int: return false
		if prediction.get(key,0)<0: return false
	var shop: Dictionary = saved.get("shop_trade",{})
	if not shop.is_empty():
		if not shop.get("visit") is String or not shop.get("offers") is Dictionary: return false
		for id in shop.offers:
			if not shop.offers[id] is Array: return false
			for offer in shop.offers[id]:
				if not offer is Dictionary or not offer.get("kind","") in ["dice","brand","unit"] or not offer.get("item") is Dictionary: return false
	var reward: Dictionary = saved.get("pending_reward",{})
	if reward.get("kind","")=="routine":
		var index: int = int(reward.get("index",-1))
		if index<0 or index>=24 or int(saved.position)!=index or saved.tiles[index]!="event": return false
		if not Routine.valid(str(reward.get("event_id",""))) or not str(reward.get("id","")).begins_with("routine-visit:"): return false
		if reward.get("phase","") not in ["choice","overflow"]: return false
		if reward.get("id","") in saved.get("reward_receipts",[]): return false
		var entry: Dictionary = Routine.details(str(reward.event_id))
		if str(entry.effect)=="dice":
			var offered: Dictionary = reward.get("offer",{})
			if not offered.has("card_id") or not offered.has("image"): return false
		if reward.get("phase","")=="overflow":
			if str(entry.effect)!="dice" or not reward.has("reward"): return false
			if reward.reward.get("kind","")!="dice" or not reward.reward.get("item",{}) is Dictionary: return false
	if reward.get("kind","")=="mimic":
		var tile_index = int(reward.get("index",-1))
		var count = int(reward.get("count",0))
		if tile_index<0 or tile_index>=24 or saved.tiles[tile_index]!="gem": return false
		if count<1 or count>4 or str(reward.get("id","")).is_empty(): return false
	var active: Dictionary = saved.get("active_encounter",{})
	if not active.is_empty():
		if not active.has("checkpoint") or not active.has("allies") or not active.has("enemies") or not active.get("phase","") in ["ready","rolled","actions"]: return false
		var checker = Rules.new(definitions)
		if not checker.restore(active.checkpoint): return false
	dice_cards = saved.get("dice_cards",[]).duplicate(true)
	brand_cards = saved.get("brand_cards",[]).duplicate(true)
	graveyard_corpses = saved.get("graveyard_corpses",[]).duplicate(true)
	reward_receipts = saved.get("reward_receipts",[]).duplicate()
	enemies_defeated = maxi(0,int(saved.get("enemies_defeated",0)))
	run_result = saved.get("run_result",{}).duplicate(true)
	if not run_result.is_empty():
		for k in ["laps","contamination","enemies_defeated","lost_monsters","surviving_monsters"]:
			run_result[k] = int(run_result[k])
	pending_reward = saved.get("pending_reward",{}).duplicate(true)
	if pending_reward.get("kind","")=="routine":
		pending_reward["index"] = int(pending_reward.get("index",-1))
	# The unopened 10% mimic chest is a durable reward like a treasure.
	# Godot JSON converts the native enemy count and gem index into floats;
	# restoring ints avoids a false state change (and keeps restart parity).
	if pending_reward.get("kind","")=="mimic":
		pending_reward["index"] = int(pending_reward.get("index",-1))
		pending_reward["count"] = int(pending_reward.get("count",0))
	# JSON parses numeric card faces as floats. A chest's selected index,
	# as well as blessing/curse faces inside its *offered brand cards*, must
	# round-trip as integers. Normalizing only the selected index left a
	# random save/resume mismatch whenever a chest happened to offer a brand.
	if pending_reward.get("kind","")=="treasure":
		if pending_reward.has("selected"):
			pending_reward.selected = int(pending_reward.selected)
		for offer in pending_reward.get("offers",[]):
			if not offer is Dictionary or offer.get("kind","")!="brand": continue
			var source: Dictionary = offer.get("source",{})
			if not source.get("brand",{}) is Dictionary: continue
			for faces in ["bless","curse"]:
				if source.brand.get(faces,[]) is Array:
					source.brand[faces] = source.brand[faces].map(func(n): return int(n))
		# The prepared but not yet claimed brand is also a durable reward.
		var prepared: Dictionary = pending_reward.get("reward",{})
		if prepared.get("kind","")=="brand":
			var item: Dictionary = prepared.get("item",{})
			if item.get("brand",{}) is Dictionary:
				for faces in ["bless","curse"]:
					if item.brand.get(faces,[]) is Array:
						item.brand[faces] = item.brand[faces].map(func(n): return int(n))
	# Captured enemy brands must survive JSON round-trips unchanged.
	# JSON converts dice face integers to floats; a visually identical face
	# may otherwise fail the type-sensitive match during future combat.
	if pending_reward.get("kind","")=="capture":
		if pending_reward.has("selected"): pending_reward.selected=int(pending_reward.selected)
		for corpse in pending_reward.get("corpses",[]):
			if not corpse is Dictionary: continue
			if corpse.has("target"): corpse.target=int(corpse.target)
			var captured: Dictionary=corpse.get("unit",{})
			for brand in captured.get("brands",[]):
				if not brand is Dictionary: continue
				if brand.get("bless",[]) is Array: brand.bless=brand.bless.map(func(n): return int(n))
				if brand.get("curse",[]) is Array: brand.curse=brand.curse.map(func(n): return int(n))
		var offered: Dictionary=pending_reward.get("reward",{})
		if offered.get("kind","")=="unit":
			var acquired: Dictionary=offered.get("item",{})
			for brand in acquired.get("brands",[]):
				if not brand is Dictionary: continue
				if brand.get("bless",[]) is Array: brand.bless=brand.bless.map(func(n): return int(n))
				if brand.get("curse",[]) is Array: brand.curse=brand.curse.map(func(n): return int(n))
	next_serial = maxi(2,int(saved.get("next_serial",2)))
	move_serial = maxi(0,int(saved.get("move_serial",0)))
	map_serial = maxi(0,int(saved.get("map_serial",0)))
	previous_map_roll = int(saved.get("previous_map_roll",saved.get("last_face",0) if move_serial>0 else 0))
	previous_map_card = str(saved.get("previous_map_card",""))
	pending_move = saved.get("pending_move",{}).duplicate(true)
	active_encounter = saved.get("active_encounter",{}).duplicate(true)
	# Godot JSON parses all numbers as floats. Source prophecy faces and
	# accumulated effects are integer game counts; normalize on reload so
	# subsequent saves, card effects and snapshot comparisons remain stable.
	prophecy = prediction.duplicate(true)
	for key in ["ally_hp","ally_attack","ally_speed","enemy_attack"]:
		if prophecy.has(key): prophecy[key] = int(prophecy[key])
	prophecy["rolls"] = prophecy.get("rolls",[]).map(func(face): return int(face))
	last_prophecy = saved.get("last_prophecy",{}).duplicate(true)
	if last_prophecy.has("face"): last_prophecy.face = int(last_prophecy.face)
	shop_trade = shop.duplicate(true)
	# Merchant monster cards are complete unit instances, kept inside the
	# saved offer cache until chosen. Normalize their numeric stats and brand
	# dice faces just like owned roster units so save/reload is lossless.
	for choices in shop_trade.get("offers",{}).values():
		for offer in choices:
			if str(offer.get("kind",""))!="unit": continue
			var candidate: Dictionary = offer.get("item",{})
			for key in ["max_hp","attack","speed","current_hp","altar_enhancements"]:
				if candidate.has(key): candidate[key] = int(candidate[key])
			for brand in candidate.get("brands",[]):
				if not brand is Dictionary: continue
				if brand.get("bless",[]) is Array: brand.bless = brand.bless.map(func(n): return int(n))
				if brand.get("curse",[]) is Array: brand.curse = brand.curse.map(func(n): return int(n))
	patrol_plan = plan.duplicate(true)
	# JSON loads quantity counters as floats (6.0 instead of 6).
	# Normalize to durable integer tile counts, so equality and future
	# + / - controls survive process restarts without a phantom edit.
	if RoutePlan.is_new(patrol_plan):
		for kind in RoutePlan.CHOICES:
			patrol_plan.selection[kind] = int(patrol_plan.selection.get(kind,0))
	# Godot's JSON parser returns count numbers as floats. Treat a saved
	# choice of two stones as the same integer plan selected in the UI,
	# without reinterpreting old 6+5 patrol-inventory saves.
	if RoutePlan.is_new(patrol_plan):
		for kind in RoutePlan.CHOICES:
			patrol_plan.selection[kind] = int(patrol_plan.selection.get(kind,0))
	scout = intel_state.duplicate(true)
	prayer_result = saved.get("prayer_result",{}).duplicate(true)
	event_flags = stored_flags.duplicate(true)
	story_events = stored_story_events.duplicate(true)
	for card in brand_cards:
		card.brand.bless = card.brand.bless.map(func(n): return int(n))
		card.brand.curse = []
	tiles = saved.tiles.duplicate()
	roster = saved.roster.duplicate(true)
	for u in roster:
		for key in ["max_hp","attack","speed","current_hp"]: u[key] = int(u[key])
		# Altar level is a durable integer count; Godot JSON decodes it as float.
		if u.has("altar_enhancements"): u.altar_enhancements = int(u.altar_enhancements)
		for b in u.brands:
			b.bless = b.bless.map(func(n): return int(n))
			b.curse = b.curse.map(func(n): return int(n))
	# Permanently lost owned units are saved in the graveyard with the
	# same numeric/card shape as roster units. JSON parses numbers as float;
	# restore their ints too, so a loss -> reload does not subtly change
	# the corpse item used later for extraction or inheritance.
	for corpse in graveyard_corpses:
		if not corpse is Dictionary: continue
		for key in ["max_hp","attack","speed","current_hp"]:
			if corpse.has(key): corpse[key] = int(corpse[key])
		for b in corpse.get("brands",[]):
			if not b is Dictionary: continue
			if b.get("bless",[]) is Array: b.bless = b.bless.map(func(n): return int(n))
			if b.get("curse",[]) is Array: b.curse = b.curse.map(func(n): return int(n))
	position = int(saved.position)
	cleared = saved.cleared.map(func(n): return int(n))
	contamination = int(saved.contamination)
	max_contamination_reached = clampi(maxi(contamination,int(saved.get("max_contamination_reached",contamination))),0,100)
	laps = int(saved.laps)
	lap_ready = saved.lap_ready
	last_face = int(saved.last_face)
	var stored_die = saved.get("dice_visual_position",[602,308])
	if stored_die is Array and stored_die.size()==2 and (stored_die[0] is int or stored_die[0] is float) and (stored_die[1] is int or stored_die[1] is float):
		# JSON decodes numeric values as floats; convert back to exact integer
		# pixels so world.snapshot() remains byte-equivalent across save/reload.
		dice_visual_position = [clampi(roundi(float(stored_die[0])),0,1204),clampi(roundi(float(stored_die[1])),0,644)]
	else:
		dice_visual_position = [602,308]
	dice_visual_rotation = clampi(roundi(float(saved.get("dice_visual_rotation",0))),-3600,3600)
	dice_visual_face = clampi(int(saved.get("dice_visual_face",saved.last_face)),1,6)
	region = saved.region
	rng.seed = int(saved.rng_seed)
	rng.state = int(saved.rng_state)
	Rules.normalize_doom_name([roster,graveyard_corpses,pending_reward,active_encounter],definitions)
	return true
