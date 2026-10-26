extends SceneTree
## Real UI hooks, isolated save, and presentation clock/input/RNG contracts.
const MAP = preload("res://map.tscn")
const State = preload("res://systems/map_state.gd")
const BossStoryFixture = preload("res://scripts/boss_story_test_fixture.gd")
const BATTLE = preload("res://battlefield.tscn")
const Rules = preload("res://systems/battlefield_rules.gd")
const Accent = preload("res://systems/presentation_accent.gd")
var passed: int = 0
var failed: int = 0
var evidence: bool = false
var confirmed_silk_strikes: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("PASS natural-presentation: ",message)
	else: failed += 1; printerr("FAIL natural-presentation: ",message)

func capture(name_value: String) -> void:
	if not evidence: return
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://.natural_motion/"+name_value+".png")

func on_combat_accent(node: Node) -> void:
	if node.name!="PresentationAccent_silk": return
	confirmed_silk_strikes += 1
	if evidence:
		await create_timer(0.025).timeout
		await capture("06_queen_actual_impact")

func run() -> void:
	evidence = "--render-evidence" in OS.get_cmdline_user_args()
	if evidence:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280,720)
		root.content_scale_size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.natural_motion"))
	var session = root.get_node("RunSession")
	var old_save: String = session.save_file_path
	session.save_file_path = "res://.natural_motion/isolated_run.json"
	session.start_new_world()
	var world = session.world
	var factory = Rules.new(world.definitions if "definitions" in world else JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units,912)
	world.roster.clear()
	for slug in ["skeleton-spear","skeleton-archer","skeleton-cavalry","spider-knight"]:
		world.roster.append(factory.individual(slug,"presentation-"+slug))
	session.save_world()
	var map = MAP.instantiate()
	root.add_child(map)
	await process_frame
	check(map.stage.get_node_or_null("PresentationAccent_boss")==null,"loading a saved board does not replay boss reveal")
	var monster: int = world.tiles.find("monster")
	map.show_battle_deck(monster)
	var deck = map.overlay
	await create_timer(0.85).timeout
	var before: String = JSON.stringify(world.snapshot())
	var rng_before: int = world.rng.state
	for i in range(3): deck.toggle_unit(str(world.roster[i].id))
	var cue = deck.board.get_node_or_null("PresentationAccent_legion")
	check(is_instance_valid(cue) and cue.anchors.size()==3,"third matching real deck card produces one group cue")
	check(cue.mouse_filter==Control.MOUSE_FILTER_IGNORE,"accent cannot intercept card or confirm input")
	await create_timer(0.22).timeout
	await capture("01_legion")
	check(JSON.stringify(world.snapshot())==before and world.rng.state==rng_before,"deck accent leaves saved roster, rules and RNG untouched")
	deck.toggle_unit(str(world.roster[0].id))
	check(deck.board.get_node_or_null("PresentationAccent_legion")==null,"losing group eligibility removes the previous visual immediately")
	map.close_overlay()
	world.contamination = 15
	world.reveal_swamps_for_contamination()
	session.save_world()
	before = JSON.stringify(world.snapshot())
	map.modal()
	map.presentation.refresh()
	await process_frame
	check(map.stage.get_node_or_null("PresentationAccent_swamp")==null,"a result panel does not consume the map accent behind its veil")
	map.close_overlay()
	await process_frame
	await process_frame
	check(map.stage.get_node_or_null("PresentationAccent_swamp")!=null,"saved contamination crossing accents new swamp tiles")
	await create_timer(0.22).timeout
	await capture("02_swamp")
	check(JSON.stringify(world.snapshot())==before,"swamp accent never mutates the saved board")
	world.contamination = State.BOSS_CONTAMINATION
	BossStoryFixture.seed_completed_final_hunt(world)
	check(world.reveal_boss_at_threshold(),"completed final story and current contamination gate reveal the boss")
	session.save_world()
	map.presentation.refresh()
	await process_frame
	check(map.stage.get_node_or_null("PresentationAccent_boss")!=null,"saved boss reveal receives a bounded tile accent")
	await create_timer(0.22).timeout
	await capture("03_boss")
	map.queue_free()
	await process_frame
	map = MAP.instantiate()
	root.add_child(map)
	await process_frame
	check(map.stage.get_node_or_null("PresentationAccent_boss")==null,"reopening an existing boss board is quiet")
	var new_hill: int = world.tiles.find("basic")
	world.tiles[new_hill] = "forest"
	session.save_world()
	map.show_discovery_card("forest")
	var discovery_card:Control=map.find_child("EventDiscoveryCard",true,false) as Control
	var reward_tile:TextureRect=discovery_card.get_node_or_null("EventDiscoveryTile") as TextureRect if discovery_card!=null else null
	check(discovery_card!=null and reward_tile!=null and reward_tile.texture==map.texture("res://assets/map/tiles/forest.png"),"discovery card explains the forest before the board accent")
	await create_timer(0.35).timeout
	await capture("04_discovery")
	if discovery_card!=null: discovery_card.dismiss()
	check(not is_instance_valid(map.overlay),"one tap closes the ordinary discovery card")
	await process_frame
	cue = map.stage.get_node_or_null("PresentationAccent_discovery")
	check(is_instance_valid(cue) and cue.anchors.size()==1 and cue.anchors[0].is_equal_approx(map.center(new_hill)),"completed tile reveal points to the new location, not an existing forest")
	map.queue_free()
	await process_frame
	var battle = BATTLE.instantiate()
	battle.selection = ["spider-knight","skeleton-spear","skeleton-archer","skeleton-cavalry"]
	root.add_child(battle)
	await process_frame
	var actor: String = str(battle.rules.units[0].id)
	var target: String = str(battle.rules.units[4].id)
	before = JSON.stringify(battle.rules.snapshot())
	battle.visuals.play_species_accent(actor,target)
	cue = battle.visuals.get_node_or_null("PresentationAccent_silk")
	check(is_instance_valid(cue),"Spider Queen uses the dedicated silk accent")
	battle.paused = true
	var age_before: float = cue.age
	await create_timer(0.15).timeout
	check(is_equal_approx(cue.age,age_before),"species accent freezes with battle pause")
	battle.paused = false
	await create_timer(0.055).timeout
	await capture("05_queen_silk")
	check(JSON.stringify(battle.rules.snapshot())==before,"species accent leaves combat state and RNG unchanged")
	await create_timer(0.9).timeout
	check(not is_instance_valid(cue),"finished accents release their nodes")
	# Resolve a real round and present the queen's real action. The accent
	# must come from play_strike's confirmed impact, not a second damage roll.
	battle.visuals.child_entered_tree.connect(on_combat_accent)
	# The lab normally generates random brands/passives. A shielding enemy
	# can correctly block the hit and produce no silk: use a controlled
	# positive-hit fixture instead of assuming every random attack connects.
	battle.rules.rng.seed = 912
	for unit in battle.rules.units:
		unit.brands = []
		unit.passive = ""
	battle.rules.units[0].passive = "initiative"
	battle.rules.begin_round(4)
	while not battle.rules.queue.is_empty():
		var action: Dictionary = battle.rules.next_action()
		if action.is_empty(): break
		if str(action.actor)!=actor: continue
		battle.render_units(action.before)
		before = JSON.stringify(battle.rules.snapshot())
		await battle.visuals.play_action(action)
		check(JSON.stringify(battle.rules.snapshot())==before,"real strike presentation never resolves combat twice")
		break
	check(confirmed_silk_strikes>0,"real confirmed Queen strike invokes species accent at impact")
	var connected_count := confirmed_silk_strikes
	await battle.visuals.play_strike(actor,target,{"type":"damage","target":target,"amount":0,"hp":battle.visuals.states[target].hp,"blocked":true,"critical":false})
	check(confirmed_silk_strikes==connected_count,"a blocked zero-damage strike produces no false silk impact")
	battle.queue_free()
	await process_frame
	session.save_file_path = old_save
	print("NATURAL_PRESENTATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
