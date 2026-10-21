extends SceneTree
const BATTLE = preload("res://battlefield.tscn")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("_run")

func check(ok: bool, note: String) -> void:
	if ok:
		passed += 1
		print("PASS battle-effect-pool: ",note)
	else:
		failed += 1
		printerr("FAIL battle-effect-pool: ",note)

func _run() -> void:
	var scene = BATTLE.instantiate()
	root.add_child(scene)
	var original = scene.visuals.original
	var snapshot: String = JSON.stringify(scene.rules.snapshot())
	var cross: Texture2D = original.sheet_texture("heal-cross.png")
	var node: TextureRect = original.sprite(scene.visuals,cross,"cross",Vector2(32,32))
	var identity: int = node.get_instance_id()
	node.position = Vector2(10,20)
	node.scale = Vector2(2,3)
	node.rotation = 0.6
	node.pivot_offset = Vector2(4,5)
	node.modulate = Color(0.2,0.3,0.4,0.1)
	node.self_modulate = Color(0.4,0.2,0.1,0.2)
	node.flip_h = true
	node.flip_v = true
	node.z_index = 13
	original.release_art(node)
	check(not node.visible and node.texture==null and node.material==null,"release hides art and drops its resource references")
	var frames: Array = original.hit_frames("physical")
	var reused: TextureRect = original.sprite(scene.visuals,frames[0],"physical",Vector2(88,90))
	check(reused.get_instance_id()==identity,"a completed effect node is actually reused")
	check(reused.visible and reused.position==Vector2.ZERO and reused.scale==Vector2.ONE and reused.rotation==0.0 and reused.pivot_offset==Vector2.ZERO,"reuse resets visibility and all effect transforms")
	check(reused.modulate==Color.WHITE and reused.self_modulate==Color.WHITE and not reused.flip_h and not reused.flip_v and reused.z_index==0,"reuse resets alpha, tint, flips and drawing depth")
	check(reused.texture==frames[0] and reused.material==original.material("physical") and reused.size==Vector2(88,90),"new effect receives its own texture, material and dimensions")
	check(reused.get_index()==scene.visuals.get_child_count()-1,"reused art has the same newest-sibling order as fresh art")
	original.release_art(reused)
	var label: Control = original.label(scene.visuals,"critical")
	check(label.z_index==13,"label retains its intended drawing depth")
	original.release_art(label)
	var plain: TextureRect = original.sprite(scene.visuals,cross,"cross",Vector2(28,28))
	check(plain.material==null and plain.z_index==0,"cross cannot inherit a label shader or depth")
	original.release_art(plain)
	var many: Array[TextureRect] = []
	for i in range(original.MAX_IDLE_SPRITES+5):
		many.append(original.sprite(scene.visuals,cross,"cross",Vector2(20,20)))
	for item in many: original.release_art(item)
	await process_frame
	await process_frame
	check(original.idle_sprites.size()==original.MAX_IDLE_SPRITES,"idle art pool has a hard 64-node limit")
	var already_idle: TextureRect = original.idle_sprites[0]
	original.release_art(already_idle)
	check(not already_idle.is_queued_for_deletion() and original.idle_sprites.size()==original.MAX_IDLE_SPRITES,"duplicate release cannot corrupt a full pool")
	var retained_clean: bool = true
	for item in original.idle_sprites:
		retained_clean = retained_clean and not item.visible and item.texture==null and item.material==null
	check(retained_clean,"idle pool retains no old image or material")
	var id: String = scene.rules.units[0].id
	scene.visuals.play_hit(id,"physical",0.15)
	check(not scene.visuals.art_items.back().node.visible,"delayed reused art stays hidden until its scheduled start")
	scene.visuals.show_reports([{"type":"heal","target":id,"amount":3,"hp":scene.rules.units[0].hp,"blocked":false,"critical":false}])
	await scene.wait_time(1.4)
	check(scene.visuals.art_items.is_empty(),"delayed hit, number and healing sprites finish through the production updater")
	check(original.idle_sprites.size()<=original.MAX_IDLE_SPRITES,"normal effect expiration preserves the pool bound")
	check(JSON.stringify(scene.rules.snapshot())==snapshot,"effect reuse never changes combat data or RNG")
	var references: Array = []
	for item in original.idle_sprites: references.append(weakref(item))
	scene.queue_free()
	for i in range(6): await process_frame
	check(references.all(func(reference): return reference.get_ref()==null),"leaving battle frees every pooled scene node")
	print("BATTLE_EFFECT_POOL: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
