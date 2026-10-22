extends SceneTree
## Real seed promotion, render-only growth, paused frames and stable handoff.
const Battle = preload("res://battlefield.tscn")
const Layout = preload("res://systems/battle_presentation_layout.gd")
var passed := 0
var failed := 0
var bloom_done := false
var evidence_dir := ""

func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL animation-release: ",message)

func _initialize() -> void:
	call_deferred("_run")

func present_round(scene, before: Array, after: Array) -> void:
	await scene.visuals.play_round(before,after,[])
	bloom_done = true

func capture(name: String) -> void:
	if evidence_dir.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image!=null and image.save_png(evidence_dir+"/"+name+".png")==OK,"native capture "+name)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--evidence-dir" in args: evidence_dir=args[args.find("--evidence-dir")+1]
	var layout = Layout.new()
	var fixed := 0
	for slug in layout.metrics:
		var p: Dictionary=layout.metrics[slug]
		if slug!="dragon" and p.get("rigid_idle",false): fixed+=1
	check(fixed==43 and bool(layout.metrics.get("dragon",{}).get("rigid_idle",false)),"original43 remastered units plus separate dragon preserve their drawn proportions")
	var cases := 0
	for surface in [Vector2(1280,530),Vector2(1280,720),Vector2(1920,1080)]:
		for team in ["ally","enemy"]:
			for slot in range(5):
				var seed: Dictionary=layout.geometry({"slug":"guardian-seed","team":team,"slot":slot},surface)
				var adult: Dictionary=layout.geometry({"slug":"crystal-devourer","team":team,"slot":slot},surface)
				check(seed.size.is_equal_approx(adult.size) and seed.position.is_equal_approx(adult.position) and seed.pivot.is_equal_approx(adult.pivot) and seed.foot.is_equal_approx(adult.foot),"seed/adult fixed geometry")
				cases+=1
	var last: Image = (load("res://assets/battle/frames/guardian-seed/attack-10.png") as Texture2D).get_image()
	var adult_image: Image = (load("res://assets/battle/frames/crystal-devourer/attack-01.png") as Texture2D).get_image()
	check(last.get_data()==adult_image.get_data(),"bloom endpoint is the exact adult image")
	var scene=Battle.instantiate()
	scene.selection=["guardian-seed","guardian-seed","ice-princess","siren"]
	root.add_child(scene)
	await process_frame
	scene.speed_index=2
	# Exercise the real existing promotion rule before presenting its result.
	for u in scene.rules.units:
		u.passive=""
		u.brands=[]
		if u.slug=="guardian-seed": u.born_round=0
	scene.rules.round_number=2
	var before: Array=scene.rules.units.duplicate(true)
	scene.rules.summon_round()
	var after: Array=scene.rules.units.duplicate(true)
	var ids: Array=[]
	for old in before:
		if old.slug=="guardian-seed":
			ids.append(str(old.id))
			check(scene.rules.find_id(old.id).slug=="crystal-devourer","original rule promotes a mature seed")
	check(ids.size()==2,"two simultaneous blooming seeds")
	var snapshot: String=JSON.stringify(scene.rules.snapshot())
	var rng_state: int=scene.rules.rng.state
	scene.render_units(after)
	for id in ids:
		check(scene.visuals.states[id].slug=="guardian-seed" and scene.sprites[id].texture.resource_path.contains("/guardian-seed/"),"seed remains visible during pre-bloom round cues")
	var feet: Dictionary={}
	for id in ids: feet[id]=scene.sprites[id].position+scene.sprites[id].pivot_offset
	present_round(scene,before,after)
	scene.paused=true
	var paused_texture: Texture2D=scene.sprites[ids[0]].texture
	await capture("seed_bloom_start")
	await create_timer(0.08).timeout
	check(scene.sprites[ids[0]].texture==paused_texture and not bloom_done,"pause holds the actual bloom frame")
	scene.paused=false
	var observed: Dictionary={paused_texture.resource_path.get_file():true}
	var roots_fixed := true
	var mid_captured := false
	var deadline: int=Time.get_ticks_msec()+9000
	while not bloom_done and Time.get_ticks_msec()<deadline:
		for id in ids:
			var sprite: TextureRect=scene.sprites[id]
			roots_fixed=roots_fixed and (sprite.position+sprite.pivot_offset).is_equal_approx(feet[id]) and sprite.scale.is_equal_approx(Vector2.ONE)
			var path: String=sprite.texture.resource_path
			if path.contains("/guardian-seed/attack-"):
				observed[path.get_file()]=true
				if not mid_captured and path.ends_with("attack-05.png"):
					mid_captured=true
					await capture("seed_bloom_middle")
		await process_frame
	check(bloom_done,"real round presentation completes")
	check(observed.size()==10,"all10 growth frames were displayed")
	check(roots_fixed,"growth maintains both root anchors and scale")
	for id in ids:
		var unit: Dictionary=scene.rules.find_id(id)
		check(scene.sprites[id].texture==scene.texture(scene.frame_path(unit,"attack",1)),"handoff holds the adult idle image")
		check(not scene.visuals.active.has(id),"completed bloom releases its visual state")
	await capture("seed_bloom_end")
	check(JSON.stringify(scene.rules.snapshot())==snapshot and scene.rules.rng.state==rng_state,"presentation does not change rules, stats, RNG or saved state")
	await scene.visuals.play_strike(ids[0],scene.rules.units[4].id,{})
	check(not scene.visuals.active.has(ids[0]),"adult can use its normal attack")
	# A seed cannot play a combat strike through the presentation entry point.
	scene.selection=["guardian-seed","ice-princess","forest-fairy","mimic"]
	scene.reset_battle()
	await process_frame
	var seed: Dictionary=scene.rules.units[0]
	var idle: Texture2D=scene.sprites[seed.id].texture
	await scene.visuals.play_strike(seed.id,scene.rules.units[4].id,{})
	check(scene.sprites[seed.id].texture==idle and not scene.visuals.active.has(seed.id),"seed bloom is not used as a combat attack")
	await capture("remastered_battle")
	scene.queue_free()
	await process_frame
	print("BATTLE_ANIMATION_RELEASE: %d passed, %d failed; geometry=%d" % [passed,failed,cases])
	quit(0 if failed==0 else 1)
