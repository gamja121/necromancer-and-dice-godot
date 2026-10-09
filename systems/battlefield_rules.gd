extends "res://systems/battle_rules.gd"

var queue: Array = []
var face = 1
var presentation_events: Array = []

# Keep round preparation separate from actions so the scene can present each one.
func begin_round(forced_face: int = 0) -> void:
	if not winner().is_empty(): return
	events = []
	presentation_events.clear()
	round_number += 1
	for u in units:
		u.bless = {}
		u.curse = {}
		u.shields = 0
		if u.alive and has(u,"skeleton"): heal(u,1)
	summon_round()
	face = forced_face if forced_face > 0 else rng.randi_range(1,6)
	for u in units:
		if not u.alive: continue
		var normalized: Array = []
		var base_curse: Array = []
		if not u.brands.is_empty() and u.brands[0].type in definitions[u.slug].brands:
			base_curse = u.brands[0].curse.duplicate()
		for i in range(mini(3,u.brands.size())):
			var brand = u.brands[i].duplicate(true)
			brand.curse = base_curse.duplicate() if i == 0 else []
			brand.bless = brand.bless.filter(func(n): return not n in base_curse)
			if not brand.bless.is_empty() or not brand.curse.is_empty(): normalized.append(brand)
		u.brands = normalized
		for brand in normalized:
			if face in brand.curse: u.curse[brand.type] = u.curse.get(brand.type,0)+1
			elif not face in base_curse and face in brand.bless: u.bless[brand.type] = u.bless.get(brand.type,0)+1
		u.shields = 0 if u.curse.get("guard",0)>0 else u.bless.get("guard",0)
	refresh()
	var support_order = units.filter(func(u): return u.alive)
	support_order.sort_custom(func(a,b): return a.team < b.team if a.team != b.team else a.slot < b.slot)
	for u in support_order: support(u)
	refresh()
	queue = units.filter(func(u): return u.alive)
	var ties: Dictionary = {}
	for u in queue: ties[u.id] = rng.randf()
	queue.sort_custom(func(a,b):
		if rank(a) != rank(b): return rank(a)>rank(b)
		if a.speed != b.speed: return a.speed>b.speed
		if a.slot != b.slot: return a.slot<b.slot
		return ties[a.id]<ties[b.id])
	last_id = ""
	for u in queue:
		if u.slug != "guardian-seed": last_id = u.id

func next_action() -> Dictionary:
	while not queue.is_empty() and winner().is_empty():
		var actor: Dictionary = queue.pop_front()
		if not actor.alive: continue
		var old = units.duplicate(true)
		var event_index = events.size()
		var presentation_start = presentation_events.size()
		before(actor)
		var prepared = units.duplicate(true)
		var before_effects = presentation_events.slice(presentation_start).duplicate(true)
		presentation_start = presentation_events.size()
		var allowed: bool = actor.alive and not actor.frozen and actor.slug!="guardian-seed" and actor.curse.get("combo",0)==0 and actor.curse.get("critical",0)==0
		var missed: bool = actor.alive and not actor.frozen and actor.slug!="guardian-seed" and (actor.curse.get("combo",0)>0 or actor.curse.get("critical",0)>0)
		var target: Dictionary = {}
		if actor.alive:
			target = pick_target("enemy" if actor.team == "ally" else "ally")
			attack(actor,target)
		return {"actor":actor.id,"target":target.get("id",""),"before":old,"after":units.duplicate(true),"events":events.slice(event_index),"prepared":prepared,"before_effects":before_effects,"visual_hits":presentation_events.slice(presentation_start).duplicate(true),"attack_allowed":allowed,"miss":missed}
	return {}


func heal(unit: Dictionary, amount: int) -> int:
	var healed = super.heal(unit,amount)
	if healed>0:
		presentation_events.append({"type":"heal","target":unit.id,"amount":healed,"hp":unit.hp})
	return healed

func damage(target: Dictionary, amount: int, source: Dictionary = {}, kind: String = "attack") -> int:
	if not target.alive or amount<=0: return super.damage(target,amount,source,kind)
	var index = presentation_events.size()
	var shields_before: int = target.shields
	presentation_events.append({})
	var dealt = super.damage(target,amount,source,kind)
	presentation_events[index] = {"type":"damage","target":target.id,"source":source.get("id",""),"amount":dealt,"kind":kind,"blocked":target.shields<shields_before,"critical":kind=="attack" and not source.is_empty() and source.bless.get("critical",0)>0,"hp":target.hp}
	return dealt

# Queue IDs must resolve to the restored unit dictionaries, not detached copies.
func snapshot() -> Dictionary:
	var saved = super.snapshot()
	saved.face = face
	saved.queue = queue.map(func(unit): return str(unit.id))
	saved.events = events.duplicate()
	saved.presentation_events = presentation_events.duplicate(true)
	return saved

func restore(saved: Dictionary) -> bool:
	if not saved.get("queue",[]) is Array: return false
	if not super.restore(saved): return false
	queue = []
	for id in saved.get("queue",[]):
		var unit = find_id(str(id))
		if unit.is_empty(): return false
		queue.append(unit)
	face = int(saved.get("face",1))
	events = saved.get("events",[]).duplicate()
	presentation_events = saved.get("presentation_events",[]).duplicate(true)
	return true
