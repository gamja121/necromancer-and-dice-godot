extends RefCounted
const LIMIT = 3
static func draw(random: RandomNumberGenerator) -> Dictionary:
	var bucket: int = random.randi_range(0,9999)
	if bucket<100: return {"attack":2,"hp":3,"speed":3,"jackpot":true}
	var amount: int = random.randi_range(0,99)
	if bucket<3400: return {"attack":2 if amount<5 else 1,"hp":0,"speed":0,"jackpot":false}
	if bucket<6700: return {"attack":0,"hp":3 if amount<5 else 2,"speed":0,"jackpot":false}
	return {"attack":0,"hp":0,"speed":1 if amount<75 else (2 if amount<95 else 3),"jackpot":false}
static func whole(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func valid(value) -> bool:
	if not value is Dictionary or not value.get("jackpot") is bool: return false
	for key in ["attack","hp","speed"]:
		if not whole(value.get(key),0,3): return false
	var attack: int = int(value.attack)
	var hp: int = int(value.hp)
	var speed: int = int(value.speed)
	if value.jackpot: return attack==2 and hp==3 and speed==3
	return (attack in [1,2] and hp==0 and speed==0) or (attack==0 and hp in [2,3] and speed==0) or (attack==0 and hp==0 and speed in [1,2,3])
static func valid_pending(saved: Dictionary, definitions: Dictionary) -> bool:
	var pending = saved.get("pending_reward",{})
	if not pending is Dictionary or pending.get("kind","")!="altar_boon": return false
	if not whole(pending.get("index"),0,23): return false
	for key in ["position","laps","move_serial","map_serial"]:
		if not whole(saved.get(key,0),0,2147483647): return false
	var index: int = int(pending.index)
	if int(saved.get("position",-1))!=index or saved.get("tiles",[]).size()!=24 or saved.tiles[index]!="altar": return false
	if not saved.get("run_result",{}).is_empty() or not saved.get("active_encounter",{}).is_empty() or not saved.get("pending_move",{}).is_empty(): return false
	var visit: String = "ritual-visit:%d:%d:%d"%[int(saved.get("laps",0)),int(saved.get("move_serial",0)),index]
	if int(saved.get("map_serial",0))>0: visit+=":map:%d"%int(saved.map_serial)
	if pending.get("id","")!=visit or visit in saved.get("reward_receipts",[]): return false
	if not valid(pending.get("boon")): return false
	var donor = pending.get("donor",{})
	if not donor is Dictionary or not donor.get("id") is String or donor.id.is_empty() or not definitions.has(donor.get("slug","")): return false
	if not donor.get("name") is String or not donor.get("brands") is Array: return false
	for key in ["max_hp","current_hp","attack","speed"]:
		if not whole(donor.get(key),0,2147483647): return false
	if int(donor.max_hp)<1 or int(donor.current_hp)<1 or int(donor.current_hp)>int(donor.max_hp): return false
	if not whole(donor.get("altar_enhancements",0),0,LIMIT): return false
	for brand in donor.brands:
		if not brand is Dictionary or not brand.get("bless") is Array or not brand.get("curse") is Array: return false
		for face in brand.bless+brand.curse:
			if not whole(face,1,6): return false
	var eligible: bool = false
	for unit in saved.get("roster",[]):
		if not unit is Dictionary or unit.get("id","")==donor.id: return false
		if not whole(unit.get("altar_enhancements",0),0,LIMIT): return false
		if int(unit.get("altar_enhancements",0))<LIMIT: eligible=true
	return eligible
static func normalize(pending: Dictionary) -> void:
	pending.index=int(pending.index)
	for key in ["attack","hp","speed"]: pending.boon[key]=int(pending.boon[key])
	var donor: Dictionary = pending.donor
	for key in ["max_hp","current_hp","attack","speed","altar_enhancements"]:
		if donor.has(key): donor[key]=int(donor[key])
	for brand in donor.brands:
		brand.bless=brand.bless.map(func(n):return int(n))
		brand.curse=brand.curse.map(func(n):return int(n))
