extends RefCounted

const RoutePlan = preload("res://systems/route_plan.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const HOME = 15
const COUNTS = {"basic":2,"graveyard":1,"altar":1,"unknown":1,"forest":1,"rest":2,"monster":5,"rare-monster":1,"gem":1,"event":2,"swamp":2,"warp":2}
const NAMES = {"basic":"길","graveyard":"공동묘지","altar":"제단","unknown":"세계수","forest":"언덕","rest":"숙영","monster":"일반 마물","rare-monster":"희귀 마물","gem":"보물상자","event":"사건","swamp":"오염된 늪지대","warp":"워프","home":"우리집","village":"마을","fortune-teller-camp":"점술가의 막사","boss":"보스"}
var definitions: Dictionary
var rng = RandomNumberGenerator.new()
var tiles: Array = []
var roster: Array = []
var position = HOME
var cleared: Array = []
var contamination = 0
var laps = 0
var lap_ready = false
var last_face = 1
var region = "default"
var dice_cards: Array = []
var brand_cards: Array = []
var graveyard_corpses: Array = []
var reward_receipts: Array = []
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

func generate() -> void:
	map_serial += 1
	var counts = COUNTS.duplicate()
	var deltas = RoutePlan.deltas(patrol_plan)
	for type in deltas: counts[type] += int(deltas[type])
	var requested_conversion = 2 if contamination>=80 else (1 if contamination>=40 else 0)
	var conversion = mini(requested_conversion,counts.basic)
	counts.basic -= conversion
	counts.monster += conversion
	if contamination>=80: counts.monster -= 1
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
		elif i==23 and contamination>=80: tiles.append("boss")
		else: tiles.append(pool.pop_back())
	cleared = []
	scout = {"scouted":false,"intel":[]}
	lap_ready = false

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
		contamination = mini(100,contamination+4)
		laps += 1
	generate()

func snapshot() -> Dictionary:
	return {"version":1,"tiles":tiles,"roster":roster,"position":position,"cleared":cleared,"contamination":contamination,"laps":laps,"lap_ready":lap_ready,"last_face":last_face,"region":region,"rng_seed":str(rng.seed),"rng_state":str(rng.state),"dice_cards":dice_cards,"brand_cards":brand_cards,"graveyard_corpses":graveyard_corpses,"reward_receipts":reward_receipts,"pending_reward":pending_reward,"next_serial":next_serial,"move_serial":move_serial,"map_serial":map_serial,"previous_map_roll":previous_map_roll,"previous_map_card":previous_map_card,"pending_move":pending_move,"active_encounter":active_encounter,"prophecy":prophecy,"last_prophecy":last_prophecy,"shop_trade":shop_trade,"patrol_plan":patrol_plan,"scout":scout,"prayer_result":prayer_result,"event_flags":event_flags.duplicate(true),"story_events":story_events.duplicate(true)}

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
	for field in ["pending_reward","pending_move","active_encounter","prophecy","last_prophecy","shop_trade","patrol_plan","scout","prayer_result","event_flags","story_events"]:
		if saved.has(field) and not saved[field] is Dictionary: return false
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
		if entry.status == "seen" and not entry.choice.is_empty(): return false
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
				if not offer is Dictionary or not offer.get("kind","") in ["dice","brand"] or not offer.get("item") is Dictionary: return false
	var reward: Dictionary = saved.get("pending_reward",{})
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
	pending_reward = saved.get("pending_reward",{}).duplicate(true)
	next_serial = maxi(2,int(saved.get("next_serial",2)))
	move_serial = maxi(0,int(saved.get("move_serial",0)))
	map_serial = maxi(0,int(saved.get("map_serial",0)))
	previous_map_roll = int(saved.get("previous_map_roll",saved.get("last_face",0) if move_serial>0 else 0))
	previous_map_card = str(saved.get("previous_map_card",""))
	pending_move = saved.get("pending_move",{}).duplicate(true)
	active_encounter = saved.get("active_encounter",{}).duplicate(true)
	prophecy = prediction.duplicate(true)
	last_prophecy = saved.get("last_prophecy",{}).duplicate(true)
	shop_trade = shop.duplicate(true)
	patrol_plan = plan.duplicate(true)
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
		for b in u.brands:
			b.bless = b.bless.map(func(n): return int(n))
			b.curse = b.curse.map(func(n): return int(n))
	position = int(saved.position)
	cleared = saved.cleared.map(func(n): return int(n))
	contamination = int(saved.contamination)
	laps = int(saved.laps)
	lap_ready = saved.lap_ready
	last_face = int(saved.last_face)
	region = saved.region
	rng.seed = int(saved.rng_seed)
	rng.state = int(saved.rng_state)
	return true
