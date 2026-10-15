extends SceneTree
## Save/restore + UI ownership + live battle checkpoint proof for custom names.
const Deck = preload("res://systems/battle_deck.gd")
const Info = preload("res://systems/unit_info.gd")
const Rules = preload("res://systems/battlefield_rules.gd")

var passed: int = 0
var failed: int = 0
func check(ok: bool, note: String) -> void:
	if ok:
		passed += 1
		print("PASS monster-nickname: ",note)
	else:
		failed += 1
		printerr("FAIL monster-nickname: ",note)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = root.get_node_or_null("RunSession")
	check(session != null,"real RunSession autoload present")
	if session == null:
		quit(1)
		return
	var old_path: String = session.save_file_path
	var disposable: String = "user://monster_nickname_%d.json" % OS.get_process_id()
	session.save_file_path = disposable
	session.start_new_world()
	var first: String = str(session.world.roster[0].id)
	var second: String = str(session.world.roster[1].id)
	var first_name: String = str(session.owned_unit(first).name)
	var second_name: String = str(session.owned_unit(second).name)
	var old_stats: Dictionary = session.owned_unit(first).duplicate(true)
	for invalid in ["","    ","ABCDEFGHIJKLM","가\n나","\t사신"]:
		check(not session.rename_owned_unit(first,invalid).get("ok",false),"invalid name rejected")
	check(not session.rename_owned_unit("enemy-0","사칭").get("ok",false),"enemy instance ID cannot be renamed")
	var picked: Dictionary = {"id":first,"name":"잔불"}
	var result: Dictionary = session.rename_owned_unit(first,"  잔불  ")
	check(result.get("ok",false) and result.get("name","")=="잔불","owned instance accepts trimmed personal name")
	check(str(session.owned_unit(first).get("nickname",""))=="잔불" and str(session.owned_unit(first).name)=="잔불","both display name and explicit custom identity stored")
	check(session.owned_unit(second).name==second_name,"identical species owned copy remains independent")
	for key in ["slug","max_hp","attack","speed","current_hp","brands","passive"]:
		check(session.owned_unit(first).get(key)==old_stats.get(key),"rename never changes stat/property "+key)
	check(session.rename_owned_unit(first,"잔불").get("ok",false),"setting the same name is idempotent")
	session.reload_world()
	check(str(session.owned_unit(first).name)=="잔불","custom name persists across disk save/reload")
	# Repeated fresh-world UI: direct button click never toggles selected_ids.
	var deck=Deck.new()
	root.add_child(deck)
	deck.setup(session.world.roster)
	await process_frame
	check(deck.selected_ids.is_empty(),"card selection initially empty")
	check(deck.hand.get_child_count()==2,"two individual original cards on hand")
	var hand_card: Control=deck.hand.get_child(0)
	check(hand_card.get_node_or_null("OwnedCardInfo") is Button,"owned card has separate accessible Information action")
	deck.open_info(first)
	check(deck.selected_ids.is_empty(),"information opening does not toggle deck selection")
	check(is_instance_valid(deck.info_window) and deck.info_window.allow_rename,"owned unit information exposes rename action")
	if is_instance_valid(deck.info_window):
		deck.rename_submitted.connect(func(instance_id: String, value: String):
			deck.apply_rename_result(instance_id,session.rename_owned_unit(instance_id,value)))
		deck.info_window.open_rename_editor()
		check(is_instance_valid(deck.info_window.rename_input),"rename entry displayed above existing information")
		deck.info_window.rename_input.text = "우리 잔불"
		deck.info_window.submit_rename()
		check(str(session.owned_unit(first).name)=="우리 잔불","entering edit commits chosen monster's name")
		check(deck.selected_ids.is_empty(),"renaming does not alter deck selection")
		check(not is_instance_valid(deck.info_window.rename_dialog),"successful edit closes only edit overlay")
		check(deck.hand.get_child(0).tooltip_text=="우리 잔불","hand tooltip immediately updates")
		deck.info_window.close()
		await process_frame
	deck.queue_free()
	await process_frame
	# The same information window refuses renames for enemy and summons.
	var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var rules=Rules.new(definitions,115)
	var summoned=rules.individual("guardian-seed","summon-01")
	summoned.is_summon=true
	var enemy=rules.individual("goblin-rider","enemy-00")
	rules.start([session.owned_unit(first)],[enemy,summoned])
	var enemy_info=Info.new()
	root.add_child(enemy_info)
	enemy_info.setup(rules.units[1],rules,{},true)
	check(not enemy_info.allow_rename and enemy_info.rename_button==null,"enemy card information is read-only")
	enemy_info.close()
	await process_frame
	var summon_info=Info.new()
	root.add_child(summon_info)
	summon_info.setup(rules.units[2],rules,{},true)
	check(not summon_info.allow_rename,"summoned monster card information cannot be renamed")
	summon_info.close()
	await process_frame
	# Failed atomic write must restore the original nickname and all other state.
	var rollback_snapshot: Dictionary = session.world.snapshot().duplicate(true)
	var valid_path: String=session.save_file_path
	session.save_file_path = "user://monster_nickname_missing_%d/no_save.json" % OS.get_process_id()
	check(not session.rename_owned_unit(first,"유실").get("ok",false),"unwritable save path rejects rename")
	check(session.world.snapshot()==rollback_snapshot,"failed rename rolls back every world field")
	session.save_file_path = valid_path
	check(session.rename_owned_unit(first,"인연").get("ok",false),"renaming works again after storage recovery")
	# Active combat checkpoint carries the same name, preventing midbattle reload reversion.
	var index: int=session.world.tiles.find("monster")
	check(index>=0,"genuine hostile tile exists")
	if index>=0:
		session.world.position=index
		check(session.save_world(),"real encounter approach checkpoint saved")
		check(session.start_encounter(index,[first]),"real selected owned fighter starts combat")
		check(session.rename_owned_unit(first,"잿빛 인연").get("ok",false),"renaming an active fighter succeeds")
		var saved_encounter: Dictionary=session.world.active_encounter
		check(saved_encounter.get("allies",[]).any(func(u):return str(u.id)==first and str(u.name)=="잿빛 인연"),"encounter's initial ally copy renamed")
		check(saved_encounter.checkpoint.units.any(func(u):return str(u.id)==first and str(u.name)=="잿빛 인연"),"battle checkpoint saves same custom name")
		session.reload_world()
		check(not session.encounter.is_empty(),"active encounter reload succeeds")
		check(str(session.owned_unit(first).name)=="잿빛 인연","roster retains name after active battle reload")
		check(session.encounter.checkpoint.units.any(func(u):return str(u.id)==first and str(u.name)=="잿빛 인연"),"resumed combat retains name")
	# Legacy canonical name normalizer must not erase a renamed Doom Executor.
	var doom: Dictionary={"slug":"doom-executor","name":"내 사신","nickname":"내 사신"}
	Rules.normalize_doom_name(doom,definitions)
	check(doom.name=="내 사신","species correction respects user's own Doom Executor nickname")
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(disposable+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(disposable+suffix))
	session.save_file_path=old_path
	print("MONSTER_NICKNAME: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
