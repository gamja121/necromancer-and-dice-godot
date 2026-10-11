extends SceneTree
## P2-01: fixed web v2-rules.js:roll curse-first across every
## active brand of the SAME unit and face. The production battlefield
## uses the shared resolver; round queue tie RNG must survive reload.
const Base=preload("res://systems/battle_rules.gd")
const Active=preload("res://systems/battlefield_rules.gd")

var passed: int=0
var failed: int=0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed+=1
		print("PASS battle-parity: ",description)
	else:
		failed+=1
		printerr("FAIL battle-parity: ",description)

func test_resolver() -> void:
	var mixed: Array=[
		{"type":"counter","bless":[4],"curse":[3]},
		{"type":"critical","bless":[3,4],"curse":[]},
		{"type":"guard","bless":[3],"curse":[]}
	]
	var cursed: Dictionary=Base.resolve_brand_face(mixed,3)
	check(cursed.curse.get("counter",0)==1,"source curse remains active on selected face")
	check(cursed.bless.is_empty(),"single curse cancels all other same-face blessings for this unit")
	var healthy: Dictionary=Base.resolve_brand_face(mixed,4)
	check(healthy.curse.is_empty(),"curse on another face does not activate")
	check(healthy.bless.get("counter",0)==1 and healthy.bless.get("critical",0)==1,"uncursed same-face blessings stack normally")
	var multi: Dictionary=Base.resolve_brand_face([
		{"type":"counter","bless":[],"curse":[2]},
		{"type":"guard","bless":[],"curse":[2]},
		{"type":"healing","bless":[2],"curse":[]}
	],2)
	check(multi.curse.get("counter",0)==1 and multi.curse.get("guard",0)==1,"multiple curses are retained")
	check(multi.bless.is_empty(),"multiple curses still cancel blessings")
	check(Base.resolve_brand_face([],2).bless.is_empty(),"empty brand collection safe")

func make_unit(defs: Dictionary, slug: String, unit_id: String, brands: Array) -> Dictionary:
	var d: Dictionary=defs[slug]
	return {"id":unit_id,"slug":slug,"name":unit_id,"grade":str(d.grade),
		"legions":d.legions.duplicate(),"max_hp":80,"attack":0,
		"speed":1,"passive":"","brands":brands.duplicate(true),"is_summon":false}

func test_real_battlefield() -> void:
	var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json"))
	if not parsed is Dictionary or not parsed.has("units"):
		check(false,"unit catalog for real battlefield");return
	var defs: Dictionary=parsed.units
	var slug: String="skeleton-spear"
	if not defs.has(slug) or defs[slug].brands.is_empty():
		check(false,"original unit with base brand");return
	var native_brand: String=str(defs[slug].brands[0])
	var inherited_brand: String="guard" if native_brand!="guard" else "critical"
	var ally: Dictionary=make_unit(defs,slug,"ally-test",[
		{"type":native_brand,"bless":[4],"curse":[3]},
		{"type":inherited_brand,"bless":[3,4],"curse":[]}
	])
	var enemy: Dictionary=make_unit(defs,slug,"enemy-test",[
		{"type":native_brand,"bless":[4],"curse":[5]},
		{"type":"lightspeed","bless":[3],"curse":[]}
	])
	var battle=Active.new(defs,1947)
	battle.start([ally],[enemy])
	var restored=Active.new(defs,1947)
	check(restored.restore(battle.snapshot()),"initial battle checkpoint restores")
	battle.begin_round(1)
	restored.begin_round(1)
	check(battle.queue.map(func(u): return str(u.id))==restored.queue.map(func(u): return str(u.id)),"tied round order uses restorable RNG")
	check(str(battle.rng.state)==str(restored.rng.state),"RNG tie draw stays deterministic after restore")
	battle.begin_round(3)
	var cursed_unit: Dictionary=battle.find_id("ally-test")
	var blessed_unit: Dictionary=battle.find_id("enemy-test")
	check(cursed_unit.curse.get(native_brand,0)==1,"production round applies base curse")
	check(cursed_unit.bless.is_empty(),"production round blocks inherited blessing on the same cursed face")
	check(blessed_unit.curse.is_empty(),"curse from another unit is not global")
	check(blessed_unit.bless.get("lightspeed",0)==1,"independent unit receives same-face blessing")
	check(cursed_unit.brands.size()==2 and not 3 in cursed_unit.brands[1].bless,"production normalizes inherited overlap as fixed web")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(battle.snapshot()))
	var resumed=Active.new(defs,1001)
	check(resumed.restore(saved),"battle save JSON restores active brand policy")
	resumed.begin_round(4)
	var later: Dictionary=resumed.find_id("ally-test")
	check(later.curse.is_empty(),"after reload, noncursed face does not inherit old curse")
	check(later.bless.get(inherited_brand,0)==1,"after reload, inherited blessing on safe face works")
	check(later.bless.get(native_brand,0)==1,"after reload, base blessing still works")
	check(battle.find_id("ally-test").bless.is_empty(),"restoring cloned battle does not mutate original state")

func _run() -> void:
	test_resolver()
	test_real_battlefield()
	print("BATTLE_SOURCE_PARITY_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
