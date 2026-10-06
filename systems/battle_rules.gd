class_name BattleRules
extends RefCounted

# Port of the V2 rules actually called by v2-auto-battle-practice.js.
var definitions: Dictionary
var rng = RandomNumberGenerator.new()
var units: Array = []
var legions: Dictionary = {}
var round_number = 0
var last_id = ""
var events: Array = []
const NEED = {"skeleton":3,"beast":3,"corpse":2,"plague":3,"ice":3,"summon":2,"demon":3,"plant":2,"insect":2,"element":2}
const COUNTS = {"critical":1,"vampire":0,"combo":1,"freeze":1,"poison":0,"guard":0,"summon":2,"counter":1,"healing":0,"lightspeed":2}
const POOLS = {"spider-knight":["spiderling"],"goblin-chief":["goblin-commoner"],"grave-priest":["skeleton-spear","skeleton-archer","skeleton-cavalry"],"crystal-devourer":["guardian-seed"]}
const WEIGHTS = {1:[100],2:[35,65],3:[20,33,47],4:[15,20,27,38]}

func _init(data: Dictionary = {}, seed_value: int = 1) -> void:
	definitions = data
	rng.seed = seed_value

func choose(list: Array):
	return list[rng.randi_range(0, list.size()-1)]

func make_brand(kind: String) -> Dictionary:
	var curse = rng.randi_range(1,6)
	var available = [1,2,3,4,5,6]
	available.erase(curse)
	var count = COUNTS[kind]
	if count == 0:
		count = rng.randi_range(1,2)
	var bless: Array = []
	for i in range(count):
		var n = choose(available)
		bless.append(n)
		available.erase(n)
	bless.sort()
	return {"type":kind,"bless":bless,"curse":[curse]}

func individual(slug: String, id: String) -> Dictionary:
	var d = definitions[slug]
	var p = ""
	if not d.passives.is_empty() and rng.randf() < d.chance:
		p = choose(d.passives)
	var u = {"id":id,"slug":slug,"name":d.name,"grade":d.grade,"legions":d.legions.duplicate(),"max_hp":int(d.hp),"attack":int(d.attack),"speed":int(d.speed),"passive":p,"brands":[],"is_summon":d.grade == "special"}
	if not d.brands.is_empty():
		u.brands.append(make_brand(choose(d.brands)))
	if p.is_empty() and not u.is_summon:
		var field = "max_hp" if d.bonus == "hp" else d.bonus
		u[field] += int(d.amount)
	return u

func initialize(u: Dictionary) -> void:
	u.base_hp = u.max_hp
	u.base_attack = u.attack
	u.base_speed = u.speed
	u.hp = u.max_hp
	u.alive = true
	u.grudge = 0
	u.summon_power = 0
	u.poison = []
	u.frozen = false
	u.undying_used = false
	u.shields = 0
	u.bless = {}
	u.curse = {}

func start(allies: Array, enemies: Array) -> void:
	units = []
	round_number = 0
	last_id = ""
	for team in ["ally","enemy"]:
		var members = allies if team == "ally" else enemies
		for slot in range(members.size()):
			var u = members[slot].duplicate(true)
			u.team = team
			u.slot = slot
			initialize(u)
			units.append(u)
	legions = {}
	for team in ["ally","enemy"]:
		var counts = {}
		for u in units:
			if u.team == team and not u.is_summon and u.slot < 4:
				for key in u.legions:
					counts[key] = counts.get(key,0)+1
		var enabled: Array = []
		for key in NEED:
			if counts.get(key,0) >= NEED[key]:
				enabled.append(key)
		legions[team] = {"counts":counts,"active":enabled}
	for u in units:
		apply_plant(u)
	refresh()

func active(team: String, kind: String) -> bool:
	var opponent = "enemy" if team == "ally" else "ally"
	return kind in legions[team].active and (kind == "element" or not "element" in legions[opponent].active)

func has(u: Dictionary, kind: String) -> bool:
	return kind in u.legions and active(u.team,kind)

func apply_plant(u: Dictionary) -> void:
	if has(u,"plant"):
		u.max_hp += 3
		u.hp += 3

func living(team: String) -> Array:
	return units.filter(func(u): return u.team == team and u.alive)

func find_id(id: String) -> Dictionary:
	for u in units:
		if u.id == id:
			return u
	return {}

func heal(u: Dictionary, n: int) -> int:
	if not u.alive:
		return 0
	var amount = maxi(0,mini(n,u.max_hp-u.hp))
	u.hp += amount
	return amount

func refresh() -> void:
	for u in units:
		var pack_count = 0
		if u.passive == "pack":
			for a in living(u.team):
				if a.slot < 4:
					for key in a.legions:
						if key in u.legions:
							pack_count += 1
							break
		u.attack = maxi(0,u.base_attack+u.grudge+u.summon_power+maxi(0,round_number-14)+(1 if has(u,"beast") else 0)+(1 if pack_count >= 3 else 0)-u.curse.get("counter",0))
		u.speed = 0 if u.curse.get("lightspeed",0)>0 else u.base_speed+(2 if has(u,"demon") else 0)+2*u.bless.get("lightspeed",0)

func damage(target: Dictionary, n: int, source: Dictionary = {}, kind: String = "attack") -> int:
	if not target.alive or n <= 0:
		return 0
	if kind == "attack":
		n = maxi(1,n-(1 if has(target,"insect") else 0)-(1 if target.passive == "bone" else 0))
	elif kind == "counter" and target.passive == "bone":
		n = maxi(1,n-1)
	n += target.curse.get("guard",0)
	if target.shields > 0:
		target.shields -= 1
		return 0
	var dealt = mini(target.hp,n)
	target.hp -= dealt
	if target.hp <= 0 and target.passive == "undying" and not target.undying_used:
		target.undying_used = true
		target.hp = 1
	if target.hp <= 0:
		target.alive = false
		events.append("%s 전사" % target.name)
		if not source.is_empty() and source.alive and source.passive == "feast" and kind in ["attack","poison"]:
			source.max_hp += 2
			heal(source,2)
	if dealt > 0 and not source.is_empty() and source.team != target.team and kind in ["attack","counter"] and target.passive == "grudge":
		target.grudge += 1
	refresh()
	return dealt

func poison(u: Dictionary, count: int, source: Dictionary) -> void:
	if not u.alive or has(u,"plague"):
		return
	for i in range(count):
		if u.poison.size() < 3:
			u.poison.append({"remaining":2,"source":source.id})

func summon_round() -> void:
	for team in ["ally","enemy"]:
		if living(team).any(func(u): return u.slot == 4):
			continue
		var owner = {}
		var cost = false
		if active(team,"summon"):
			var candidates = living(team).filter(func(u): return u.slot < 4 and POOLS.has(u.slug))
			if not candidates.is_empty():
				owner = choose(candidates)
		else:
			for u in living(team):
				if u.passive == "soul" and u.hp > 1:
					owner = u
					cost = true
					break
		if owner.is_empty():
			continue
		if cost:
			owner.hp -= 1
		var slug = choose(POOLS[owner.slug])
		var d = definitions[slug]
		var pet = {"id":"%s_summon_%d" % [team,round_number],"slug":slug,"name":d.name,"grade":d.grade,"legions":d.legions.duplicate(),"max_hp":int(d.hp),"attack":int(d.attack),"speed":int(d.speed),"passive":"","brands":[],"is_summon":true,"team":team,"slot":4,"owner_slot":owner.slot,"born_round":round_number}
		initialize(pet)
		apply_plant(pet)
		# Keep dead summon objects for poison source attribution.
		units.append(pet)
		events.append("%s → %s 소환" % [owner.name,pet.name])
	for seed_unit in units.duplicate():
		if seed_unit.alive and seed_unit.slug == "guardian-seed" and round_number >= seed_unit.born_round+2:
			var d = definitions["crystal-devourer"]
			seed_unit.slug = "crystal-devourer"
			seed_unit.name = d.name
			seed_unit.legions = d.legions.duplicate()
			seed_unit.max_hp = int(d.hp)
			seed_unit.attack = int(d.attack)
			seed_unit.speed = int(d.speed)
			initialize(seed_unit)
			apply_plant(seed_unit)
			events.append("씨앗 → 식인식물 변신")

func target_weights(team: String) -> Array:
	var formation = living(team).filter(func(u): return u.slot < 4 and not u.is_summon)
	for pet in living(team).filter(func(u): return u.slot == 4):
		formation = formation.filter(func(u): return u.slot != pet.owner_slot)
		formation.append(pet)
	formation.sort_custom(func(a,b): return a.get("owner_slot",a.slot) < b.get("owner_slot",b.slot))
	if formation.is_empty():
		return []
	var weights = WEIGHTS[formation.size()].duplicate()
	if team == "enemy":
		weights.reverse()
	var result: Array = []
	for i in range(formation.size()):
		result.append({"unit":formation[i],"chance":weights[i]})
	return result

func pick_target(team: String) -> Dictionary:
	var options = target_weights(team)
	var roll_value = rng.randf()*100.0
	for entry in options:
		roll_value -= entry.chance
		if roll_value < 0:
			return entry.unit
	return {} if options.is_empty() else options.back().unit

func rank(u: Dictionary) -> int:
	if round_number == 1 and u.passive == "initiative":
		return 2
	return -1 if u.curse.get("lightspeed",0)>0 else 0

func support(u: Dictionary) -> void:
	if not u.alive:
		return
	for i in range(u.bless.get("healing",0)):
		var allies = living(u.team)
		allies.sort_custom(func(a,b): return float(a.hp)/a.max_hp < float(b.hp)/b.max_hp if a.hp*b.max_hp != b.hp*a.max_hp else a.slot < b.slot)
		if not allies.is_empty():
			heal(allies[0],2)
	for i in range(u.curse.get("healing",0)):
		var allies = living(u.team)
		allies.sort_custom(func(a,b): return a.hp > b.hp if a.hp != b.hp else a.slot < b.slot)
		if not allies.is_empty():
			damage(allies[0],1,u,"curse")
	if u.curse.get("freeze",0)>0:
		u.frozen = true
	poison(u,u.curse.get("poison",0),u)
	if u.curse.get("summon",0)>0:
		damage(u,u.curse.summon,u,"curse")
	else:
		for pet in living(u.team):
			if pet.slot == 4:
				var n = u.bless.get("summon",0)
				heal(pet,n)
				pet.summon_power += n

func attack(a: Dictionary, t: Dictionary) -> void:
	if not a.alive or t.is_empty() or not t.alive or a.slug == "guardian-seed":
		return
	if a.frozen:
		a.frozen = false
		events.append("%s 빙결 · 행동 취소" % a.name)
		return
	if a.curse.get("combo",0)>0 or a.curse.get("critical",0)>0:
		events.append("%s 공격 취소/빗나감" % a.name)
		return
	for i in range(1+a.bless.get("combo",0)):
		if not a.alive or not t.alive:
			break
		refresh()
		var p = a.attack
		if a.passive == "late" and last_id == a.id:
			p += 1
		if a.passive == "cold" and a.speed > t.speed:
			p += 1
		if a.passive == "weak" and (not t.poison.is_empty() or t.frozen or t.curse.get("counter",0)>0 or t.curse.get("lightspeed",0)>0):
			p += 1
		var raw = p*(1+a.bless.get("critical",0))+(1 if has(a,"ice") and t.frozen else 0)
		var hit = damage(t,raw,a)
		events.append("%s → %s · 피해 %d" % [a.name,t.name,hit])
		if hit > 0:
			heal(a,hit*a.bless.get("vampire",0))
			if t.alive:
				poison(t,a.bless.get("poison",0),a)
				if a.bless.get("freeze",0)>0 and not t.frozen:
					t.frozen = true
		if t.alive and hit>0 and t.bless.get("counter",0)>0:
			damage(a,maxi(1,ceili(t.attack*0.5))*t.bless.counter,t,"counter")
	if a.alive and a.curse.get("vampire",0)>0:
		damage(a,a.curse.vampire,a,"curse")

func before(u: Dictionary) -> void:
	for p in u.poison:
		if u.alive:
			damage(u,1,find_id(p.source),"poison")
		p.remaining -= 1
	u.poison = u.poison.filter(func(p): return p.remaining > 0)

func winner() -> String:
	if living("ally").is_empty():
		return "enemy"
	if living("enemy").is_empty():
		return "ally"
	return ""

func step(forced_face: int = 0) -> Dictionary:
	if not winner().is_empty():
		return {"face":0,"events":[],"winner":winner(),"round":round_number}
	events = []
	round_number += 1
	for u in units:
		u.bless = {}
		u.curse = {}
		u.shields = 0
		if u.alive and has(u,"skeleton"):
			heal(u,1)
	summon_round()
	var face = forced_face if forced_face>0 else rng.randi_range(1,6)
	for u in units:
		if not u.alive:
			continue
		for b in u.brands:
			if face in b.bless:
				u.bless[b.type] = u.bless.get(b.type,0)+1
			if face in b.curse:
				u.curse[b.type] = u.curse.get(b.type,0)+1
		u.shields = 0 if u.curse.get("guard",0)>0 else u.bless.get("guard",0)
	refresh()
	var support_order = units.filter(func(u): return u.alive)
	support_order.sort_custom(func(a,b): return a.team < b.team if a.team != b.team else a.slot < b.slot)
	for u in support_order:
		support(u)
	refresh()
	var queue = units.filter(func(u): return u.alive)
	# JS random tie break is replaced with stable ID; recorded as a parity difference.
	queue.sort_custom(func(a,b):
		if rank(a) != rank(b): return rank(a)>rank(b)
		if a.speed != b.speed: return a.speed>b.speed
		if a.slot != b.slot: return a.slot<b.slot
		return a.id<b.id)
	last_id = ""
	for u in queue:
		if u.slug != "guardian-seed":
			last_id = u.id
	var order: Array = []
	for u in queue:
		order.append(u.name)
	for u in queue:
		if not winner().is_empty():
			break
		if not u.alive:
			continue
		before(u)
		if u.alive:
			attack(u,pick_target("enemy" if u.team == "ally" else "ally"))
	return {"face":face,"events":events.duplicate(),"winner":winner(),"round":round_number,"order":order}

func snapshot() -> Dictionary:
	return {"version":1,"units":units.duplicate(true),"legions":legions.duplicate(true),"round":round_number,"last_id":last_id,"rng_seed":str(rng.seed),"rng_state":str(rng.state)}

func restore(saved: Dictionary) -> bool:
	if saved.get("version",0)!=1 or not saved.get("units") is Array or not saved.get("legions") is Dictionary:
		return false
	for key in ["round","last_id","rng_seed","rng_state"]:
		if not saved.has(key): return false
	if not saved.units.is_empty():
		for team in ["ally","enemy"]:
			if not saved.legions.get(team) is Dictionary: return false
			if not saved.legions[team].get("counts") is Dictionary or not saved.legions[team].get("active") is Array: return false
	var seen_ids: Array = []
	for u in saved.units:
		if not u is Dictionary or not definitions.has(u.get("slug","")) or not u.get("team","") in ["ally","enemy"]:
			return false
		for key in ["id","name","max_hp","base_hp","base_attack","base_speed","hp","alive","passive","legions","brands","poison","bless","curse","slot","is_summon","grudge","summon_power","shields","frozen","undying_used"]:
			if not u.has(key): return false
		if not u.brands is Array or not u.poison is Array or not u.legions is Array or not u.bless is Dictionary or not u.curse is Dictionary: return false
		if u.id in seen_ids or u.hp < 0 or u.hp > u.max_hp or u.alive != (u.hp>0): return false
		seen_ids.append(u.id)
		for b in u.brands:
			if not b is Dictionary or not COUNTS.has(b.get("type","")) or not b.get("bless") is Array or not b.get("curse") is Array: return false
		for p in u.poison:
			if not p is Dictionary or not p.has("remaining") or not p.has("source"): return false
	units = saved.units.duplicate(true)
	# JSON decodes numbers as floats; Array membership is type-sensitive in Godot.
	# Restore dice faces to integers so blessings/curses still trigger after loading.
	for u in units:
		for field in ["slot","owner_slot","born_round","max_hp","base_hp","base_attack","base_speed","hp","attack","speed","grudge","summon_power","shields"]:
			if u.has(field): u[field] = int(u[field])
		for b in u.brands:
			b.bless = b.bless.map(func(face): return int(face))
			b.curse = b.curse.map(func(face): return int(face))
		for p in u.poison: p.remaining = int(p.remaining)
		for key in u.bless: u.bless[key] = int(u.bless[key])
		for key in u.curse: u.curse[key] = int(u.curse[key])
	legions = saved.legions.duplicate(true)
	round_number = int(saved.round)
	last_id = saved.last_id
	rng.seed = int(saved.rng_seed)
	rng.state = int(saved.rng_state)
	refresh()
	return true
