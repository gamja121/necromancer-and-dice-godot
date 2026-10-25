extends SceneTree
## Production action -> real Back -> original location button. No GUI window.
const MAP=preload("res://map.tscn")
const Loads=preload("res://systems/battle_resources.gd")
var passed:=0
var failed:=0
var session: Node
var paths: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: passed+=1; print("PASS used-paper: ",description)
	else: failed+=1; printerr("FAIL used-paper: ",description)
func settle() -> void:
	await process_frame
	await process_frame
	await process_frame
func wait_for(predicate: Callable, limit: int=6000) -> bool:
	var deadline:=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())
func button_at(parent: Node, text: String) -> Button:
	for node in parent.get_children():
		if node is Button and node.text==text: return node
		var child=button_at(node,text)
		if child!=null: return child
	return null
func falling(node: Node) -> int:
	var result:=1 if node.get_meta("spent_paper_falling",false) else 0
	for child in node.get_children(): result+=falling(child)
	return result
func new_map(tag: String, kind: String) -> Control:
	var path: String="user://paper_return_%d_%s.json" % [OS.get_process_id(),tag]
	paths.append(path)
	session.save_file_path=path
	session.start_new_world()
	var w=session.world
	var index: int=w.HOME if kind=="home" else (w.tiles.find("fortune-teller-camp") if kind=="fortune" else w.tiles.find("basic"))
	if kind=="rest":
		w.tiles[index]="rest"
		for unit in w.roster: unit.current_hp=maxi(1,int(unit.max_hp)-1)
	if kind=="home":
		w.roster[0].brands=[{"type":"guard","bless":[2],"curse":[]}]
		w.roster[1].brands=[{"type":"critical","bless":[3],"curse":[]}]
	w.position=index
	check(session.save_world(),tag+": isolated actual world saved")
	var map=MAP.instantiate()
	root.add_child(map)
	await settle()
	map.close_overlay()
	return map
func dispose(map: Control) -> void:
	map.close_overlay()
	map.queue_free()
	await settle()
func verify_return(map: Control, old_id: int, index: int, kind: String, caption: String) -> void:
	check(await wait_for(func(): return is_instance_valid(map.overlay) and map.overlay.get_instance_id()!=old_id),kind+": Back completes before the location painting returns")
	var background: Control=map.overlay
	var paper:=button_at(background,caption)
	check(paper!=null,kind+": return uses the real existing entry button")
	if paper==null: return
	var saved: Dictionary=session.world.snapshot().duplicate(true)
	check(background.get_node_or_null("LocationSceneImage")!=null,kind+": paper falls over the restored location artwork")
	check(background.get_node_or_null("SpentLocationParchment")==null,kind+": no duplicate paper is drawn on top of the real button")
	check(await wait_for(func(): return is_instance_valid(paper) and paper.get_meta("spent_paper_falling",false)),kind+": real paper starts falling after the background returns")
	check(paper.disabled and paper.mouse_filter==Control.MOUSE_FILTER_IGNORE and falling(background)==1,kind+": exactly one original button falls and cannot be reused")
	var style: StyleBoxTexture=paper.get_theme_stylebox("normal") as StyleBoxTexture
	check(style!=null and style.texture.resource_path.contains("parchment_button_variant"),kind+": original painted parchment art is preserved")
	var paper_lifetime: WeakRef=weakref(paper)
	check(await wait_for(func(): return paper_lifetime.get_ref()==null),kind+": the used entry paper finishes falling and is freed")
	check(session.world.snapshot()==saved,kind+": visual fall changes no result, receipt or RNG")
	check(not map.queue_used_location_paper(index,kind),kind+": repeating an already played receipt cannot schedule another fall")
	map.close_overlay()
	if kind=="inheritance": map.show_home(true)
	else: map.show_location(index)
	await create_timer(0.35).timeout
	check(falling(map.overlay)==0,kind+": rebuilding the same visit does not replay its fall")

func prophecy() -> void:
	var map=await new_map("prophecy","fortune")
	var index: int=session.world.position
	map.show_location(index)
	button_at(map.overlay,"예언").pressed.emit()
	await settle()
	var detail: Control=map.overlay
	var old_id: int=detail.get_instance_id()
	var probe:=RandomNumberGenerator.new()
	for seed in range(1,400):
		probe.seed=seed
		if probe.randi_range(1,6)==4:
			session.world.rng.seed=seed
			break
	map.dice.pressed.emit()
	check(await wait_for(func(): return is_instance_valid(detail) and not detail.busy and session.place_visit_id("prophecy",index) in session.world.reward_receipts),"prophecy: genuine shared die commits and finishes")
	check(falling(detail)==0 and detail.get_node_or_null("SpentLocationParchment")==null,"prophecy: result screen never drops a fake entry paper")
	check(map.pending_location_papers.has(session.place_visit_id("prophecy",index)),"prophecy: saved success only queues the exact current visit")
	detail.close_button.pressed.emit()
	await verify_return(map,old_id,index,"prophecy","예언")
	# Keep the existing saved-result view without replaying the entry peel.
	button_at(map.overlay,"예언").pressed.emit()
	await settle()
	check(map.overlay.dice.disabled and falling(map.overlay)==0,"prophecy: saved result can still be inspected without rolling or falling again")
	map.close_overlay()
	# A genuinely new visit must still get its own one-use effect.
	session.world.move_serial+=1
	session.save_world()
	map.show_place_actions(index)
	detail=map.overlay
	old_id=detail.get_instance_id()
	map.dice.pressed.emit()
	check(await wait_for(func(): return is_instance_valid(detail) and not detail.busy and session.place_visit_id("prophecy",index) in session.world.reward_receipts),"prophecy: next visit can use its own prophecy")
	detail.close_button.pressed.emit()
	await verify_return(map,old_id,index,"prophecy","예언")
	await dispose(map)
	session.reload_world()
	map=MAP.instantiate()
	root.add_child(map)
	await settle()
	map.show_location(index)
	await create_timer(0.35).timeout
	check(falling(map.overlay)==0 and map.pending_location_papers.is_empty(),"reload: historical receipts do not manufacture a new return animation")
	await dispose(map)

func inheritance(success: bool) -> void:
	var map=await new_map("inherit" if success else "inherit_fail","home")
	map.show_home(true)
	button_at(map.overlay,"낙인 계승").pressed.emit()
	await settle()
	var detail: Control=map.overlay
	var old_id: int=detail.get_instance_id()
	detail.select_unit(str(session.world.roster[0].id))
	detail.select_unit(str(session.world.roster[1].id))
	var saved: Dictionary=session.world.snapshot().duplicate(true)
	var path: String=session.save_file_path
	if not success: session.save_file_path="user://paper_missing_folder_%d/fail.json" % OS.get_process_id()
	detail.confirm_button.pressed.emit()
	check(await wait_for(func(): return is_instance_valid(detail) and not detail.busy),"inheritance: confirmation finishes its actual sacrifice/result phase")
	check(falling(detail)==0 and detail.get_node_or_null("SpentLocationParchment")==null,"inheritance: the sacrifice screen never drops the location entry paper")
	if success:
		check(detail.completed and map.pending_location_papers.has(session.home_visit_id()),"inheritance: completed saved operation queues the home entry paper")
	else:
		check(not detail.completed and session.world.snapshot()==saved and map.pending_location_papers.is_empty(),"inheritance: failed save preserves both units and schedules no peel")
	session.save_file_path=path
	button_at(detail,"닫기").pressed.emit()
	if success: await verify_return(map,old_id,session.world.HOME,"inheritance","낙인 계승")
	else:
		check(await wait_for(func(): return is_instance_valid(map.overlay) and map.overlay.get_instance_id()!=old_id),"inheritance: failed operation can return normally")
		await create_timer(0.35).timeout
		check(falling(map.overlay)==0 and not button_at(map.overlay,"낙인 계승").disabled,"inheritance: no fall after failure and the original action remains usable")
	await dispose(map)

func rest(success: bool) -> void:
	var map=await new_map("rest" if success else "rest_fail","rest")
	var index: int=session.world.position
	map.show_location(index)
	var background: Control=map.overlay
	var paper: Button=background.get_node("RestHealAction")
	var saved: Dictionary=session.world.snapshot().duplicate(true)
	var path: String=session.save_file_path
	if not success: session.save_file_path="user://paper_missing_folder_%d/fail.json" % OS.get_process_id()
	paper.pressed.emit()
	if success:
		check(paper.get_meta("spent_paper_falling",false),"rest: the actual clicked heal button starts falling immediately, not a null capture")
		check(session.world.roster.all(func(u): return u.current_hp==u.max_hp) and session.place_visit_id("heal",index) in session.world.reward_receipts,"rest: HP and once-only receipt save before falling")
		var paper_lifetime: WeakRef=weakref(paper)
		check(await wait_for(func(): return paper_lifetime.get_ref()==null),"rest: actual button falls away")
		check(map.overlay==background and background.get_node_or_null("RestHealAction")==null,"rest: the painting stays open and no replacement heal button is created")
		check(await wait_for(func(): return not button_at(background,"맵으로 나가기").disabled),"rest: exit is restored after recovery feedback")
	else:
		check(not paper.get_meta("spent_paper_falling",false) and session.world.snapshot()==saved,"rest: failed save does not drop the button or heal units")
		check(map.overlay==background and not paper.disabled,"rest: failed action leaves its original button available")
	session.save_file_path=path
	await dispose(map)

func cancel_without_use() -> void:
	var map=await new_map("cancel","fortune")
	var index: int=session.world.position
	map.show_place_actions(index)
	check(not map.queue_used_location_paper(index,"prophecy"),"cancel: an unearned action cannot queue any return animation")
	var detail: Control=map.overlay
	var old_id: int=detail.get_instance_id()
	detail.close_button.pressed.emit()
	check(await wait_for(func(): return is_instance_valid(map.overlay) and map.overlay.get_instance_id()!=old_id),"cancel: returns to the painting without using the function")
	await create_timer(0.35).timeout
	check(falling(map.overlay)==0 and map.pending_location_papers.is_empty(),"cancel: no successful receipt means no scheduled paper")
	await dispose(map)

func run() -> void:
	session=root.get_node("RunSession")
	var prior: String=session.save_file_path
	await prophecy()
	await inheritance(true)
	await inheritance(false)
	await rest(true)
	await rest(false)
	await cancel_without_use()
	var deadline:=Time.get_ticks_msec()+5000
	while not Loads.PendingLoads.active.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	await settle()
	session.save_file_path=prior
	for path in paths:
		for suffix in ["",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("ONE_USE_PARCHMENT_FALL: ",passed," passed, ",failed," failed")
	quit(1 if failed>0 else 0)
