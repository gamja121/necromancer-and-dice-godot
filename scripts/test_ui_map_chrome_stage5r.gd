extends SceneTree
## Stage 5R: fixed web CSS lines 179-183 hides dice-controller, tile-info,
## map-toolbar and contamination HUD while event art has focus.
## The Godot foreground stack also owns inventory/deck overlays; none of
## these should expose underlying board chrome or move/award the world.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
var passed: int = 0
var failed: int = 0
var test_save: String = ""

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS ui-map-chrome: ", description)
	else:
		failed += 1
		printerr("FAIL ui-map-chrome: ", description)

func chrome_hidden(map: Control) -> bool:
	if map.map_chrome.size() != 8: return false
	for control in map.map_chrome:
		if not is_instance_valid(control): return false
		if control==map.dice:
			if not control.visible or not control.is_visible_in_tree(): return false
		else:
			if control.visible or control.is_visible_in_tree(): return false
	return is_instance_valid(map.presentation.gauge) and not map.presentation.gauge.visible

func chrome_visible(map: Control) -> bool:
	if map.map_chrome.size() != 8: return false
	for control in map.map_chrome:
		if not is_instance_valid(control) or not control.visible or not control.is_visible_in_tree(): return false
	return is_instance_valid(map.presentation.gauge) and map.presentation.gauge.visible

func modal_and_chrome(map: Control) -> bool:
	return is_instance_valid(map.overlay) and chrome_hidden(map) and map.map_audio.modal_blocked

func board_remains(map: Control) -> bool:
	if not is_instance_valid(map.hero) or not map.hero.visible: return false
	for tile in map.buttons:
		if not is_instance_valid(tile) or not tile.visible: return false
	return map.buttons.size() == 24

func cleanup() -> void:
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(test_save + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save + suffix))

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	test_save = "user://ui_map_chrome_stage5r_%d.json" % OS.get_process_id()
	cleanup()
	var session = root.get_node_or_null("RunSession")
	var created: bool = session == null
	if created:
		session = SESSION.new()
		session.name = "RunSession"
		root.add_child(session)
	var previous_path: String = session.save_file_path
	session.save_file_path = test_save
	session.start_new_world()
	var map = MAP.instantiate()
	root.add_child(map)
	await process_frame
	var original_snapshot: Dictionary = session.world.snapshot().duplicate(true)
	var original_rng: int = session.world.rng.state
	var original_receipts: Array = session.world.reward_receipts.duplicate()
	check(chrome_visible(map), "all eight native map controls and contamination HUD show on initial board")
	check(board_remains(map), "the 24 tile images and the hero remain visible")

	var layer = map.modal()
	check(layer == map.overlay and modal_and_chrome(map), "opening ordinary location modal hides all map chrome at once")
	check(board_remains(map), "source map tile ring and hero are not hidden with its toolbar")
	check(map.dice.is_visible_in_tree() and map.dice.disabled and not map.book_button.is_visible_in_tree(), "single persistent die stays visible but cannot roll through ordinary location dialogs")
	var saved_status: String = map.status.text
	map.status.text = "Stage5R temporary status"
	map.close_overlay()
	check(chrome_visible(map), "closing ordinary overlay restores all map chrome without rebuilding")
	check(map.status.text == "Stage5R temporary status", "underlying status content survives visibility-only transition")
	map.status.text = saved_status
	check(not map.map_audio.modal_blocked and map.map_audio.visible, "Stage5Q audio options also restore after close")

	var fortune: int = session.world.tiles.find("fortune-teller-camp")
	check(fortune >= 0, "fixed map still has the source fortune-teller scene")
	if fortune >= 0:
		map.show_location(fortune)
		check(modal_and_chrome(map), "location art suppresses toolbar and contamination HUD while shared die remains visible")
		check(board_remains(map), "location overlay leaves board tile imagery intact")
		map.close_overlay()
		check(chrome_visible(map), "location art exit restores the complete toolbar")
		map.show_place_actions(fortune)
		check(modal_and_chrome(map), "nested prophecy/action panel also owns board chrome visibility")
		map.close_overlay()
		check(chrome_visible(map), "closing nested location actions restores toolbar")

	var tree_index: int = session.world.tiles.find("unknown")
	if tree_index >= 0:
		map.show_exploration_actions(tree_index)
		check(modal_and_chrome(map), "world-tree prayer panel cannot expose map HUD beneath its art")
		map.close_overlay()
		check(chrome_visible(map), "world-tree action close restores map controls")

	map.show_home()
	check(modal_and_chrome(map), "home scene hides native board controls behind home painting")
	map.close_overlay()
	check(chrome_visible(map), "home exit returns original map HUD")

	map.show_inventory("unit")
	# The inventory book intentionally keeps board chrome visible behind its input shield.
	# Unlike location actions, the inventory is an overlay on the real board.
	check(is_instance_valid(map.overlay) and map.map_audio.modal_blocked and chrome_visible(map), "book inventory keeps source HUD visible while blocking board inputs")
	map.close_overlay()
	check(chrome_visible(map), "book inventory close restores map controls")
	map.show_inventory("dice")
	check(modal_and_chrome(map), "dice card inventory also suppresses map toolbar")
	map.close_overlay()
	check(chrome_visible(map), "dice card inventory close restores map controls")

	var monster: int = session.world.tiles.find("monster")
	check(monster >= 0, "board has a normal prebattle tile")
	if monster >= 0:
		map.show_battle_deck(monster)
		check(modal_and_chrome(map), "prebattle deck panel hides board toolbar without starting a fight")
		check(session.encounter.is_empty(), "opening deck remains a UI-only operation")
		map.close_overlay()
		check(chrome_visible(map), "canceling prebattle deck restores board chrome")

	check(session.world.snapshot() == original_snapshot, "UI-only transitions do not alter world save state")
	check(map.dice.position==Vector2(602.0,307.6), "all location overlays keep the single die at its original stopping place")
	check(session.world.rng.state == original_rng, "UI-only transitions do not advance gameplay RNG")
	check(session.world.reward_receipts == original_receipts, "UI-only transitions do not award or remove rewards")
	# Simulate a previously completed cosmetic roll; rebuilt stages must load
	# the persisted pose instead of their old hard-coded center.
	map.dice.position = Vector2(375.0,468.0)
	map.dice.rotation_degrees = 27.0
	map.remember_shared_die()
	var previous_dice = map.dice
	map.render()
	check(map.dice != previous_dice and chrome_visible(map), "board render recreates exactly the visible new controls")
	check(map.dice.position == Vector2(375,468) and absf(map.dice.rotation_degrees-27.0)<0.1,
		"rebuilt map die starts at its LAST stopped pose, never auto-centers")
	check(map.map_chrome.size() == 8 and board_remains(map), "reconstructed chrome has no old-stage references")
	map.modal()
	check(modal_and_chrome(map), "overlay after rerender still hides rebuilt board controls")
	map.close_overlay()
	check(chrome_visible(map), "closing rebuilt overlay restores new controls")
	map.queue_free()
	await process_frame
	session.save_file_path = previous_path
	if created: session.queue_free()
	cleanup()
	check(not FileAccess.file_exists(test_save), "test-only save removed without changing player save files")
	print("UI_MAP_CHROME_STAGE5R: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
