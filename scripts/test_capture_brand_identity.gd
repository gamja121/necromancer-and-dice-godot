extends SceneTree
## Real encounter -> defeated enemy -> successful soul capture -> reload.
## Verifies type AND blessing/curse face identity; no new brand RNG.
const SessionScript=preload("res://systems/run_session.gd")
const Battle=preload("res://systems/battlefield_rules.gd")
const UnitInfo=preload("res://systems/unit_info.gd")
const CaptureUI=preload("res://systems/corpse_capture.gd")
const LayeredCard=preload("res://systems/layered_unit_card.gd")
var passed:=0
var failed:=0
var save_path: String

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, title: String) -> void:
	if value:
		passed+=1
		print("PASS capture-identity: ",title)
	else:
		failed+=1
		printerr("FAIL capture-identity: ",title)

func normalized_brands(data: Dictionary) -> Array:
	var result: Array=[]
	for original in data.get("brands",[]):
		var brand: Dictionary=original.duplicate(true)
		brand.bless=brand.get("bless",[]).map(func(n): return int(n))
		brand.curse=brand.get("curse",[]).map(func(n): return int(n))
		result.append(brand)
	return result

## UI-visible rows, not just the underlying brand dictionaries.
## A mismatch in UnitInfo formatting must fail even if a save test passes.
func rendered_face_rows(unit: Dictionary, battle) -> Array:
	var view=UnitInfo.new()
	root.add_child(view)
	view.setup(unit,battle)
	var rows: Array=[]
	for child in view.effects.get_children():
		if child is Label:
			var line: String=str(child.text)
			if line.begins_with("축복 [") or line.begins_with("저주 ["):
				rows.append(line)
	view.queue_free()
	return rows

func clear_save() -> void:
	for suffix in ["",".tmp"]:
		var abs=ProjectSettings.globalize_path(save_path+suffix)
		if FileAccess.file_exists(save_path+suffix):
			DirAccess.remove_absolute(abs)

func _run() -> void:
	save_path="user://test_capture_brand_identity_%d.json" % OS.get_process_id()
	clear_save()
	var session=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SessionScript.new()
		session.name="RunSession"
		root.add_child(session)
	var previous_path: String=session.save_file_path
	session.save_file_path=save_path
	session.start_new_world()
	var world=session.world
	var index: int=world.tiles.find("monster")
	check(index>=0,"a real monster tile exists")
	check(world.roster.size()>0,"initial owned unit available")
	if index<0 or world.roster.is_empty():
		session.save_file_path=previous_path
		if created: session.queue_free()
		clear_save()
		quit(1)
		return
	var owned_id: String=str(world.roster[0].id)
	check(session.start_encounter(index,[owned_id]),"actual enemy encounter created and saved")
	if session.encounter.is_empty():
		session.save_file_path=previous_path
		if created: session.queue_free()
		clear_save()
		quit(1)
		return
	var origin: Dictionary=session.encounter.enemies[0].duplicate(true)
	# A random encounter may contain only unbranded monsters. The fixture
	# must always exercise the buggy branch where a brand can be re-rolled.
	if normalized_brands(origin).is_empty():
		for opponent in session.encounter.enemies:
			if not normalized_brands(opponent).is_empty():
				origin=opponent.duplicate(true)
				break
	if normalized_brands(origin).is_empty():
		var generator=Battle.new(world.definitions,19)
		origin=generator.individual("skeleton-spear",str(session.encounter.enemies[0].id))
		session.encounter.enemies[0]=origin.duplicate(true)
		world.active_encounter=session.encounter.duplicate(true)
		check(session.save_world(),"test-only branded enemy fixture saved")
	check(not normalized_brands(origin).is_empty(),"a fought enemy carries a testable brand")
	var battle=Battle.new(world.definitions,7)
	battle.start(session.encounter.allies,session.encounter.enemies)
	check(normalized_brands(battle.find_id(str(origin.id)))==normalized_brands(origin),"battle uses original enemy's exact dice faces")
	var battle_face_rows: Array=rendered_face_rows(battle.find_id(str(origin.id)),battle)
	check(not battle_face_rows.is_empty(),"enemy information screen actually displays brand dice faces")
	check(battle_face_rows.size()==normalized_brands(origin).size()*2,"enemy information screen lists all blessing and curse rows")
	for enemy in battle.units:
		if enemy.team=="enemy":
			enemy.hp=0
			enemy.alive=false
	check(battle.winner()=="ally","real rules consider all enemies defeated")
	check(session.finish_encounter(battle),"victory creates durable captured corpse offers")
	check(world.pending_reward.get("kind","")=="capture","victory enters corpse capture phase")
	if world.pending_reward.get("kind","")!="capture":
		session.save_file_path=previous_path
		if created: session.queue_free()
		clear_save()
		quit(1)
		return
	var corpse: Dictionary={}
	for possible in world.pending_reward.corpses:
		if str(possible.get("id",""))==str(origin.id):
			corpse=possible
			break
	check(not corpse.is_empty(),"original defeated enemy appears in corpse list")
	check(not corpse.get("unit",{}).is_empty(),"corpse persists the exact enemy source unit")
	check(str(corpse.get("slug",""))==str(origin.slug) and str(corpse.get("name",""))==str(origin.name),"corpse listed for reward retains exact fought enemy name and species")
	check(str(corpse.get("unit",{}).get("slug",""))==str(origin.slug) and str(corpse.get("unit",{}).get("name",""))==str(origin.name),"durable corpse source does not transform into a different monster")
	check(normalized_brands(corpse.get("unit",{}))==normalized_brands(origin),"corpse brands exactly match actual fought enemy")
	check(str(corpse.get("unit",{}).get("passive",""))==str(origin.get("passive","")),"original passive also preserved")
	# Simulate reopening capture UI after game restart, before rolling.
	session.reload_world()
	world=session.world
	check(world.pending_reward.get("kind","")=="capture","capture offers survive save/reload")
	corpse={}
	for candidate in world.pending_reward.corpses:
		if str(candidate.get("id",""))==str(origin.id):
			corpse=candidate
			break
	check(normalized_brands(corpse.get("unit",{}))==normalized_brands(origin),"blessing/curse face numbers remain identical after JSON reload")
	# Existing player saves created before this fix have no corpse.unit.
	# Their saved battle checkpoint must still recover the defeated enemy.
	var legacy: Dictionary=corpse.duplicate(true)
	legacy.erase("unit")
	var rng_before_legacy: int=world.rng.state
	var old_save_item: Dictionary=session.create_item("unit",legacy)
	check(normalized_brands(old_save_item)==normalized_brands(origin),"older active capture saves recover exact brands from battle snapshot")
	check(world.rng.state==rng_before_legacy,"legacy capture recovery does not reroll a brand")
	# A guaranteed success only in the disposable test fixture. Production
	# still rolls the original required target (2 to 6) unchanged.
	var chosen: int=world.pending_reward.corpses.find(corpse)
	world.pending_reward.corpses[chosen].target=1
	check(session.save_world(),"isolated guaranteed-success test target saved")
	var rng_state_before: int=world.rng.state
	var expected_rng=RandomNumberGenerator.new()
	expected_rng.seed=world.rng.seed
	expected_rng.state=rng_state_before
	var expected_face: int=expected_rng.randi_range(1,6)
	var result: Dictionary=session.roll_capture()
	check(result.get("ok",false) and result.get("success",false),"actual capture roll succeeds")
	check(int(result.get("face",0))==expected_face,"capture still rolls exactly one original d6")
	check(world.rng.state==expected_rng.state,"successful capture does not reroll enemy brand or consume extra RNG")
	var item: Dictionary=world.pending_reward.get("reward",{}).get("item",{})
	check(normalized_brands(item)==normalized_brands(origin),"captured reward has identical brand types/blessing/curse faces")
	check(str(item.get("passive",""))==str(origin.get("passive","")),"captured reward retains enemy passive")
	check(str(item.get("id",""))!=str(origin.id),"new owned card has a distinct ID")
	check(str(item.get("slug",""))==str(origin.slug) and str(item.get("name",""))==str(origin.name),"soul-harvest reward has the exact enemy species and name, not a randomly rerolled monster")
	var source_button:=TextureButton.new()
	source_button.size=Vector2(96,120)
	var chosen_art: TextureButton=CaptureUI.make_choice_card(source_button,corpse.get("unit",{}))
	root.add_child(chosen_art)
	check(str(chosen_art.get_meta("layered_slug",""))==str(origin.slug),"visible soul-harvest candidate uses the fought enemy's species")
	var portrait: TextureRect=chosen_art.get_node_or_null("LayeredCardCharacter") as TextureRect
	check(portrait!=null and portrait.texture!=null and portrait.texture.resource_path==str(LayeredCard.PORTRAITS.get(str(origin.slug),"")),"capture card portrait resolves to that species's registered card source")
	chosen_art.queue_free()
	source_button.queue_free()
	check(int(item.get("current_hp",0))==int(item.get("max_hp",-1)),"captured card starts with full persistent HP")
	# Crash/restart after success, before claiming the reward.
	session.reload_world()
	world=session.world
	item=world.pending_reward.get("reward",{}).get("item",{})
	check(normalized_brands(item)==normalized_brands(origin),"prepared captured card survives reload with matching dice faces")
	var count_before: int=world.roster.size()
	var claim: Dictionary=session.claim_reward()
	check(claim.get("ok",false) and claim.get("kept",false),"actual capture reward safely claimed")
	check(world.roster.size()==count_before+1,"exactly one monster added to the deck")
	var recruited: Dictionary=world.roster[-1]
	check(normalized_brands(recruited)==normalized_brands(origin),"owned deck exactly reproduces the fought monster's dice faces")
	check(str(recruited.get("passive",""))==str(origin.get("passive","")),"owned monster passive remains unchanged")
	check(str(recruited.get("slug",""))==str(origin.slug) and str(recruited.get("name",""))==str(origin.name),"captured monster in roster retains the same fought species and name")
	var recruited_battle=Battle.new(world.definitions,27)
	var foe=Battle.new(world.definitions,29).individual("skeleton-archer","display-test-foe")
	recruited_battle.start([recruited],[foe])
	var owned_face_rows: Array=rendered_face_rows(recruited_battle.find_id(str(recruited.id)),recruited_battle)
	check(owned_face_rows==battle_face_rows,"actual enemy and captured owned-unit info screens show identical brand types and dice face rows")
	var receipt_count: int=world.reward_receipts.size()
	session.reload_world()
	world=session.world
	check(normalized_brands(world.roster[-1])==normalized_brands(origin),"roster keeps original brands after another reload")
	check(str(world.roster[-1].get("slug",""))==str(origin.slug) and str(world.roster[-1].get("name",""))==str(origin.name),"save/reload never changes the captured enemy's species or name")
	check(world.reward_receipts.size()==receipt_count and world.pending_reward.is_empty(),"reward cannot be duplicated on reload")
	session.save_file_path=previous_path
	if created: session.queue_free()
	clear_save()
	print("CAPTURE_BRAND_IDENTITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
