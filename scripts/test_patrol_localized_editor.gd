extends SceneTree
## Isolated production patrol controls, locale changes, expansion and repair-to-departure.
const MAP=preload("res://map.tscn")
const STATE=preload("res://systems/map_state.gd")
const DISCOVERY=preload("res://systems/location_discoveries.gd")
const ENGLISH=preload("res://systems/english_translation.gd")
const LOADS=preload("res://systems/battle_resources.gd")
var session: Node
var language: Node
var map: Control
var passed: int=0
var failed: int=0
var capture_dir: String=""
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("PASS patrol-locale: ",message)
	else: failed+=1; printerr("FAIL patrol-locale: ",message)
func settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.30).timeout
func snapshot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var pixels: Image=root.get_texture().get_image()
	var error: Error=pixels.save_png(capture_dir.path_join(name+".png"))
	check(error==OK,"native "+name+" screenshot exported")
func editor() -> Control: return map.overlay.find_child("PatrolRouteEditor",true,false)
func open_editor() -> Control:
	if is_instance_valid(map.overlay): map.close_overlay()
	map.show_exploration_actions(STATE.HOME)
	await settle()
	return map.overlay
func visible_copy_translated(panel: Control) -> bool:
	for node in panel.find_children("*","Control",true,false):
		if not node.is_visible_in_tree(): continue
		if node is Label or node is Button:
			if ENGLISH.has_korean(tr(str(node.text))):
				printerr("UNTRANSLATED ",node.name,": ",node.text)
				return false
		if ENGLISH.has_korean(tr(node.tooltip_text)):
			printerr("UNTRANSLATED tooltip ",node.name)
			return false
	return true
func readable_bounds(panel: Control) -> bool:
	var okay: bool=true
	for node in panel.find_children("*","Label",true,false):
		if not node.is_visible_in_tree(): continue
		var bounds: Rect2=node.get_global_rect()
		if bounds.position.x < -1.0 or bounds.end.x > 1281.0 or node.get_line_count()*node.get_line_height()>node.size.y+3.0:
			printerr("TEXT_BOUNDS ",node.name," ",bounds," lines=",node.get_line_count()," height=",node.get_line_height())
			okay=false
	return okay
func discovered_names_visible(panel: Control) -> bool:
	var viewport: Rect2=panel.body_scroll.get_global_rect()
	for cell in panel.discovery_cells.values():
		if not cell.visible: continue
		for label in cell.find_children("*","Label",true,false):
			if label.is_visible_in_tree() and not viewport.encloses(label.get_global_rect()): return false
	return true

func temporary_locale(code: String, rtl: bool=false) -> Translation:
	var catalog: Translation=Translation.new()
	catalog.set_locale(code)
	for source in language.english.catalog:
		var english: String=str(language.english.catalog[source])
		var padding: String=""
		while (english+padding).length()<ceili(float(english.length())*1.8): padding+=" extra"
		var expanded: String=("مثال "+english) if rtl else ("["+english+padding+"]")
		catalog.add_message(str(source),expanded)
	TranslationServer.add_translation(catalog)
	return catalog
func run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--snapshot-dir="): capture_dir=str(argument).trim_prefix("--snapshot-dir=")
	preload("res://systems/audio_settings.gd").apply_saved()
	session=root.get_node("RunSession")
	language=root.get_node("GameLanguage")
	var previous_save: String=session.save_file_path
	var previous_locale: String=language.locale
	var scratch: String="user://patrol_locale_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	session.start_new_world()
	var w=session.world
	w.position=STATE.HOME
	w.laps=3
	w.contamination=30
	w.max_contamination_reached=30
	for kind in DISCOVERY.ORDER:
		w.event_flags[DISCOVERY.unlock_flag(kind)]=true
		w.event_flags[DISCOVERY.receipt_flag(kind)]=true
		w.event_flags[DISCOVERY.home_flag(kind)]=true
	w.patrol_plan.rest_unlocked=true
	w.patrol_plan.rest_discovered=true
	w.generate()
	w.lap_ready=true
	check(session.save_world(),"isolated all-discoveries HOME fixture saved")
	language.set_language("ko",false)
	map=MAP.instantiate()
	root.add_child(map)
	await settle()
	var actions: Control=await open_editor()
	var panel: Control=editor()
	check(panel!=null,"actual home action hosts the new planning board")
	if panel==null: quit(1); return
	check(panel.find_child("SelectedPatrolSlot0",true,false)==null,"misleading numbered slot selector is gone")
	check(actions.route_plus_buttons.size()==3 and actions.route_minus_buttons.size()==3,"all three tile types expose direct quantity controls")
	var saved: Dictionary=w.snapshot().duplicate(true)
	for step in range(2): actions.route_plus_buttons.monster.pressed.emit()
	var minus: Button=actions.route_minus_buttons.monster
	minus.grab_focus()
	minus.pressed.emit()
	check(root.gui_get_focus_owner()==minus,"quantity adjustment preserves a still-enabled keyboard focus")
	actions.route_plus_buttons.rest.pressed.emit()
	await settle()
	check(actions.plan.selection.monster==1 and actions.plan.selection.rest==1,"direct clicks set actual unsaved quantities")
	check(w.snapshot()==saved,"draft edits do not touch save, receipts or gameplay RNG")
	check(int(w.patrol_preview(actions.plan).remaining)==1,"displayed capacity uses the real next board")
	check(readable_bounds(panel),"Korean text remains within its allocated bounds")
	check(discovered_names_visible(panel),"all five Korean place names are visible without scrolling")
	await snapshot("patrol_ko")
	var same_plus: int=actions.route_plus_buttons.monster.get_instance_id()
	var draft: Dictionary=actions.plan.duplicate(true)
	minus.grab_focus()
	language.set_language("en",false)
	await settle()
	check(visible_copy_translated(panel),"English labels, statuses and tooltips contain no Korean fallback")
	check(readable_bounds(panel),"English copy fits without clipping")
	check(discovered_names_visible(panel),"all five English place names are visible without scrolling")
	check(actions.plan==draft and w.snapshot()==saved,"language switch preserves draft and saved state")
	check(actions.route_plus_buttons.monster.get_instance_id()==same_plus and root.gui_get_focus_owner()==minus,"language switch keeps controls and keyboard focus")
	await snapshot("patrol_en")
	var long_locale: Translation=temporary_locale("de")
	TranslationServer.set_locale("de")
	await settle()
	check(readable_bounds(panel),"expanded translation copy wraps within available width")
	check(actions.action_button.get_global_rect().end.y<=720.0 and actions.close_button.get_global_rect().end.y<=720.0,"expanded copy keeps confirm and back on screen")
	check(actions.plan==draft and w.snapshot()==saved,"pseudo locale changes presentation only")
	await snapshot("patrol_long_text")
	var rtl_locale: Translation=temporary_locale("ar",true)
	TranslationServer.set_locale("ar")
	await settle()
	check(panel.is_layout_rtl(),"editor inherits right-to-left locale direction")
	check(readable_bounds(panel),"RTL copy fits its controls")
	check(actions.plan==draft and w.snapshot()==saved,"RTL changes neither quantities nor RNG")
	await snapshot("patrol_rtl_test")
	TranslationServer.set_locale("ko")
	TranslationServer.remove_translation(long_locale)
	TranslationServer.remove_translation(rtl_locale)
	language.set_language("ko",false)
	await settle()
	actions.route_reset_button.pressed.emit()
	for step in range(2): actions.route_plus_buttons.rest.pressed.emit()
	check(actions.plan.selection.rest==2 and actions.route_plus_buttons.rest.disabled,"discovered camp plus two extras disables the fourth camp")
	check(not actions.route_plus_buttons.rest.tooltip_text.is_empty(),"camp limit provides an explanation at its control")
	# Restore an old six-extra plan: repair must be possible without minting a second receipt.
	map.close_overlay()
	w.patrol_plan.selection={"monster":6,"rest":0,"forest":0}
	var receipt: String=session.place_visit_id("patrol",STATE.HOME)
	if not receipt in w.reward_receipts: w.reward_receipts.append(receipt)
	check(session.save_world(),"previously confirmed unsafe plan fixture saved")
	check(not session.patrol_edit_locked(),"unsafe old plan can re-enter HOME editor for repair")
	map.show_home(true)
	await settle()
	var repair_entry: Button=map.overlay.get_node_or_null("LocationAction_patrol")
	check(is_instance_valid(repair_entry) and repair_entry.visible and not repair_entry.disabled,"real HOME repair entry stays visible instead of falling away")
	repair_entry.pressed.emit()
	await settle()
	actions=map.overlay
	panel=editor()
	check(actions.action_button.disabled,"invalid old plan cannot be reconfirmed unchanged")
	var receipts_before: int=w.reward_receipts.size()
	for step in range(3): actions.route_minus_buttons.monster.pressed.emit()
	check(not actions.action_button.disabled and actions.plan.selection.monster==3,"reducing to real capacity enables safe confirmation")
	actions.action_button.pressed.emit()
	await settle()
	check(w.patrol_plan.selection.monster==3 and w.reward_receipts.size()==receipts_before,"repair persists without a duplicate visit receipt")
	check(session.leave_home(),"repaired plan departs through the actual session path")
	check(w.tiles.size()==24 and w.tiles.count("unknown")==1 and w.tiles.count("altar")==1 and w.tiles.count("graveyard")==2,"next map keeps every earned location and exactly24 slots")
	map.queue_free()
	await process_frame
	var drain: int=Time.get_ticks_msec()+5000
	while not LOADS.PendingLoads.active.is_empty() and Time.get_ticks_msec()<drain: await process_frame
	session.save_file_path=previous_save
	language.set_language(previous_locale,false)
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("PATROL_LOCALIZED_EDITOR: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
