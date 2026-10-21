extends SceneTree
## Regression for removal of independent brand cards, preserving monster brands.
const Session = preload("res://systems/run_session.gd")
const Catalog = preload("res://systems/reward_catalog.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS retire-brand-card: ",message)
	else:
		failed += 1
		printerr("FAIL retire-brand-card: ",message)

func test_new_game(s: Node) -> void:
	s.start_new_world()
	var world = s.world
	check(not world.snapshot().has("brand_cards"),"new saves have no active standalone brand-card field")
	check(not world.snapshot().has("legacy_brand_cards"),"new saves have no inactive brand-card archive either")
	check(s.create_item("brand",{}).is_empty(),"retired standalone brand card cannot be crafted")
	check(not FileAccess.file_exists("res://assets/cards/brand-card.png"),"obsolete brand-card art is absent from runtime resources")
	check(Catalog.dice_cards().size()==18,"eighteen usable dice-control cards still exist")
	check(world.roster.all(func(u): return not u.brands.is_empty()),"starting monsters retain their own brand effects")
	var donor_id: String=str(world.roster[0].id)
	var receiver_id: String=str(world.roster[1].id)
	world.roster[0].brands=[{"type":"critical","bless":[1],"curse":[]}]
	world.roster[1].brands=[{"type":"guard","bless":[2],"curse":[]}]
	var donor_before: int=world.roster.size()
	var result: Dictionary=s.inherit_at_home(receiver_id,donor_id)
	check(result.get("ok",false),"home inheritance consumes a monster material without any brand card")
	check(world.roster.size()==donor_before-1 and s.owned_unit(donor_id).is_empty(),"donor monster permanently leaves owned roster")
	check(s.owned_unit(receiver_id).brands.size()==2 and s.owned_unit(receiver_id).brands[1].type=="critical","recipient gains one blessing from donor")
	check(not s.inherit_at_home(receiver_id,donor_id).get("ok",false),"same home visit cannot inherit twice")
	s.reload_world()
	world=s.world
	check(world.roster.size()==donor_before-1 and s.owned_unit(receiver_id).brands.size()==2,"monster-only inheritance survives reload")

func test_legacy_archive(s: Node) -> void:
	s.start_new_world()
	var legacy: Dictionary={"id":"brand-card-old-88","brand":{"type":"critical","bless":[4],"curse":[]}}
	var saved: Dictionary=s.world.snapshot().duplicate(true)
	saved["brand_cards"]=[legacy]
	var source_bytes: String=JSON.stringify(saved)
	var path: String=s.save_file_path
	var backup: String=path+".before_standalone_brand_cards.bak"
	for stale in [backup]:
		if FileAccess.file_exists(stale): DirAccess.remove_absolute(ProjectSettings.globalize_path(stale))
	var file=FileAccess.open(path,FileAccess.WRITE)
	check(file!=null,"legacy fixture save can be written")
	if file==null: return
	file.store_string(source_bytes)
	file.close()
	s.reload_world()
	check(s.world.roster.size()==2,"old cards do not disrupt surviving monsters")
	check(not s.world.snapshot().has("brand_cards") and not s.world.snapshot().has("legacy_brand_cards"),"restore purges both old card fields from live memory")
	check(FileAccess.file_exists(backup),"original save backed up outside active gameplay")
	if FileAccess.file_exists(backup):
		check(FileAccess.get_file_as_string(backup)==source_bytes,"one-time backup preserves original card data byte-for-byte")
	check(s.save_world(),"cleaned card-free save persists")
	s.reload_world()
	check(not s.world.snapshot().has("brand_cards") and not s.world.snapshot().has("legacy_brand_cards"),"reloaded save remains entirely free of brand-card collections")
	check(FileAccess.file_exists(backup) and FileAccess.get_file_as_string(backup)==source_bytes,"cleanup never overwrites the recovery backup")
	if FileAccess.file_exists(backup): DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))

func test_prior_retirement_archive(s: Node) -> void:
	var original_path: String=s.save_file_path
	var prior_path: String=original_path+".prior_cleanup"
	s.save_file_path=prior_path
	s.start_new_world()
	var snapshot: Dictionary=s.world.snapshot().duplicate(true)
	snapshot["legacy_brand_cards"]=[{"id":"legacy-stored-mark","brand":{"type":"vampire","bless":[3],"curse":[]}}]
	var bytes: String=JSON.stringify(snapshot)
	var file=FileAccess.open(prior_path,FileAccess.WRITE)
	check(file!=null,"intermediate-release archive fixture can be written")
	if file!=null:
		file.store_string(bytes)
		file.close()
		s.reload_world()
		var backup: String=prior_path+".before_standalone_brand_cards.bak"
		check(FileAccess.file_exists(backup) and FileAccess.get_file_as_string(backup)==bytes,"intermediate-release archive is backed up without mutation")
		check(not s.world.snapshot().has("legacy_brand_cards") and not s.world.snapshot().has("brand_cards"),"intermediate-release archive never enters current world")
		check(s.save_world(),"intermediate-release world can save without retired fields")
		s.reload_world()
		check(not s.world.snapshot().has("legacy_brand_cards"),"intermediate-release cleanup persists after reboot")
	for suffix in ["",".tmp",".before_standalone_brand_cards.bak"]:
		if FileAccess.file_exists(prior_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(prior_path+suffix))
	s.save_file_path=original_path

func test_old_chest(s: Node, prepared: bool) -> void:
	s.start_new_world()
	var snapshot: Dictionary=s.world.snapshot().duplicate(true)
	var old_card: Dictionary={"id":"brand-card-old-19","brand":{"type":"critical","bless":[3],"curse":[]}}
	var offers: Array=[
		{"kind":"brand","source":{"brand":{"type":"critical","bless":[3],"curse":[]}}},
		{"kind":"dice","source":Catalog.dice_cards()[1]},
		{"kind":"dice","source":Catalog.dice_cards()[2]}
	]
	snapshot["pending_reward"]={"kind":"treasure","id":"treasure-visit:0:17:9","offers":offers,"selected":0}
	if prepared:
		snapshot.pending_reward["reward"]={"kind":"brand","item":old_card}
	var previous_rng: int=s.world.rng.state
	check(s.world.restore(snapshot),"saved chest containing old brand offer loads")
	var reward: Dictionary=s.world.pending_reward
	check(reward.offers.all(func(offer): return offer.kind in ["unit","dice"]),"all legacy chest brand choices migrated to dice cards")
	check(reward.offers[0].source.has("card_id") and reward.offers[0].source.has("image"),"converted chest offer is a playable dice card")
	check(s.world.rng.state==previous_rng,"migration does not reroll random gameplay state")
	if prepared:
		check(reward.reward.kind=="dice" and reward.reward.item.id==old_card.id,"already-prepared old brand payout becomes a dice card with same unique ID")
	else:
		check(s.prepare_treasure_reward(0),"unprepared old treasure can prepare converted dice reward")
		check(s.world.pending_reward.reward.kind=="dice","converted prepared choice is a dice card")
	var id: String=str(s.world.pending_reward.reward.item.id)
	check(s.save_world(),"converted treasure remains durable")
	s.reload_world()
	check(s.world.pending_reward.reward.kind=="dice" and str(s.world.pending_reward.reward.item.id)==id,"restart never recreates a brand card or rerolls chosen reward")
	check(s.claim_reward().get("ok",false),"converted treasure payout can be claimed")
	check(s.world.dice_cards.any(func(card): return str(card.id)==id),"converted payout enters dice-control inventory")
	check(s.world.pending_reward.is_empty(),"legacy treasure transaction completes")

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	var created: bool = session==null
	if created:
		session=Session.new()
		session.name="RunSession"
		root.add_child(session)
	var former: String=session.save_file_path
	var tmp: String="user://retire_brand_card_%d.json" % OS.get_process_id()
	session.save_file_path=tmp
	test_new_game(session)
	test_legacy_archive(session)
	test_prior_retirement_archive(session)
	test_old_chest(session,false)
	test_old_chest(session,true)
	session.save_file_path=former
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(tmp+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp+suffix))
	check(not FileAccess.file_exists(tmp),"disposable regression save removed")
	print("RETIRE_BRAND_CARD: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
