extends RefCounted

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

func _init(data: Dictionary = {}, seed_value: int = 1) -> void:
	definitions = data
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
	var counts = COUNTS.duplicate()
	var conversion = 2 if contamination>=80 else (1 if contamination>=40 else 0)
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
	lap_ready = false

func move_path(face: int) -> Array:
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
	return {"version":1,"tiles":tiles,"roster":roster,"position":position,"cleared":cleared,"contamination":contamination,"laps":laps,"lap_ready":lap_ready,"last_face":last_face,"region":region,"rng_seed":str(rng.seed),"rng_state":str(rng.state)}

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
