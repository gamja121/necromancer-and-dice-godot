extends SceneTree
## P4-04A: every original 46-species card / unit info / actual battlefield
## attack, hit, and death presentation, plus legacy Godot Dracula (47th).
## This verifies engine runtime assets and control paths; it does not claim
## Windows/real-monitor visual or audible acceptance.
const BattleScene = preload("res://battlefield.tscn")
const Layout = preload("res://systems/battle_presentation_layout.gd")
const LayeredUnitCard = preload("res://systems/layered_unit_card.gd")

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS p4-all-monsters: ", description)
	else:
		failed += 1
		printerr("FAIL p4-all-monsters: ", description)

func texture_ok(path: String) -> bool:
	if not ResourceLoader.exists(path): return false
	var tex: Texture2D = load(path) as Texture2D
	return tex != null and tex.get_width() > 0 and tex.get_height() > 0

func verify_art_catalog(slugs: Array, layout) -> bool:
	var missing: Array[String] = []
	var total: int = 0
	for raw in slugs:
		var slug: String = str(raw)
		if not LayeredUnitCard.supports(slug): missing.append(slug + ":no_layered_card")
		var card_background: String = str(LayeredUnitCard.BACKGROUNDS.get(slug,LayeredUnitCard.BACKGROUND))
		var card_portrait: String = str(LayeredUnitCard.PORTRAITS.get(slug,""))
		for path in [card_background,card_portrait,LayeredUnitCard.NAMEPLATE,"res://assets/battle/ui/info-portraits/%s.png" % slug]:
			if not texture_ok(path): missing.append(path)
			else: total += 1
		for motion in ["attack", "hit", "death"]:
			var sequence: Array = layout.frames(slug, motion)
			if sequence.is_empty():
				missing.append(slug + ":" + motion + ":no_frames")
				continue
			for i in range(sequence.size()):
				var index: int = int(sequence[i])
				var path: String = "res://assets/battle/frames/%s/%s-%02d.png" % [slug, motion, index]
				if index != i + 1 or not texture_ok(path): missing.append(path)
				else: total += 1
	check(missing.is_empty(), "all 47 layered card backgrounds, cutout portraits, ribbons, information portraits and attack/hit/death paths decode: " + ", ".join(missing.slice(0, 10)))
	check(total >= 47 * 4 + 700, "every layered card component and information portrait plus over 700 animation frames decoded: " + str(total))
	return missing.is_empty()

func check_species(scene, unit: Dictionary) -> void:
	var slug: String = str(unit.slug)
	var id: String = str(unit.id)
	var portrait_path: String = "res://assets/battle/ui/info-portraits/%s.png" % slug
	check(scene.sprites.has(id) and scene.sprites[id].texture == scene.texture(scene.frame_path(unit, "attack", 1)), slug + ": production scene renders real idle frame")
	check(scene.cards.has(id) and scene.cards[id].texture_normal == null and scene.cards[id].has_node("LayeredCardBase") and scene.cards[id].has_node("LayeredCardCharacter"), slug + ": production battle card uses only layered art")
	check(str(scene.cards[id].tooltip_text).contains(str(unit.name)), slug + ": actual card tooltip has original species name")
	var geometry: Dictionary = scene.presentation_layout.geometry(unit, scene.surface_size)
	check(geometry.size.x > 0 and geometry.size.y > 0 and geometry.position.is_finite(), slug + ": original field geometry produces finite sprite bounds")
	scene.show_detail(unit)
	check(is_instance_valid(scene.detail), slug + ": card information UI opens")
	if is_instance_valid(scene.detail):
		check(scene.detail.unit_id == id and scene.detail.portrait.texture != null and scene.detail.portrait.texture.resource_path == portrait_path, slug + ": correct portrait appears in actual information UI")
		# The approved effects panel omits inactive sections. Summoned species
		# without brands/passives may correctly show only the explicit empty state.
		var effect_rows: Array=scene.detail.effects.get_children()
		var has_effects: bool=effect_rows.any(func(row): return str(row.name).begins_with("Brand_") or str(row.name).begins_with("Passive_") or str(row.name) in ["ActiveLegionEffects","ProphecyEffects","StatsChanged","BloomInfo"])
		var empty_state: bool=scene.detail.effects.get_node_or_null("EffectSection_효과없음")!=null
		# An empty fallback is valid only when the inspected combatant has no
		# known displayed effects. Query actual activation, since an opposing
		# element legion can suppress a nominally enabled allied legion.
		var active_legion: bool=false
		for legion in scene.rules.legions[str(unit.team)].active:
			if scene.rules.active(str(unit.team),str(legion)):
				active_legion=true
				break
		var changed_stats: bool=unit.base_hp!=unit.max_hp or unit.base_attack!=unit.attack or unit.base_speed!=unit.speed
		var known_effects: bool=not unit.brands.is_empty() or not str(unit.passive).is_empty() or active_legion or changed_stats
		check(has_effects!=empty_state and (not empty_state or not known_effects), slug + ": information shows active effects or a valid no-effects state for its actual unit data")
		scene.close_detail()

func check_motion_frame(scene, unit: Dictionary, motion: String) -> void:
	var id: String = str(unit.id)
	var sequence: Array = scene.motion_frames(unit, motion)
	check(not sequence.is_empty(), str(unit.slug) + ": " + motion + " profile exists")
	if sequence.is_empty(): return
	await scene.animate_unit(id, motion)
	var last_path: String = scene.frame_path(unit, motion, int(sequence.back()))
	check(scene.sprites[id].texture == scene.texture(last_path), str(unit.slug) + ": actual animate_unit finishes " + motion + " on final image")
	scene.render_units(scene.rules.units)

func check_batch(scene, names: Array, expected: int) -> void:
	var snapshot_before: Array = scene.rules.units.duplicate(true)
	var actor_ids: Array = []
	var target_id: String = str(scene.rules.units[4].id)
	for i in range(expected):
		var unit: Dictionary = scene.rules.units[i]
		check(unit.team == "ally" and str(unit.slug) == str(names[i]), str(names[i]) + ": actual battlefield construction uses requested original unit")
		actor_ids.append(str(unit.id))
		check_species(scene, unit)
		for motion in ["attack", "hit", "death"]:
			await check_motion_frame(scene, unit, motion)
		await scene.visuals.play_strike(str(unit.id), target_id, {})
		var first: String = scene.frame_path(unit, "attack", 1)
		check(not scene.visuals.active.has(unit.id) and scene.sprites[unit.id].texture == scene.texture(first), str(unit.slug) + ": real BattleVisuals strike ends without stranded animation")
	# The original death presenter processes multiple simultaneous casualties.
	# Use disposable lab units flagged as summoned to avoid simulating owned
	# permanent loss for the 46 source-art sweep.
	var after: Array = snapshot_before.duplicate(true)
	for i in range(expected):
		after[i].alive = false
		after[i].hp = 0
		after[i].is_summon = true
	await scene.visuals.play_deaths(snapshot_before, after)
	for i in range(expected):
		var dead: Dictionary = after[i]
		var final_path: String = scene.frame_path(dead, "death", int(scene.motion_frames(dead, "death").back()))
		check(scene.sprites[dead.id].texture == scene.texture(final_path), str(dead.slug) + ": original permanent-death presenter reached final sprite frame")
		check(scene.visuals.removed.has(dead.id) and not scene.cards[dead.id].visible, str(dead.slug) + ": finished summoned death hides sprite and card")
	for id in actor_ids:
		check(not scene.sprites[id].visible, str(scene.rules.find_id(id).slug) + ": expired death sprite stays removed")

func verify_dracula_owned_death(scene) -> void:
	# Dracula is preserved in old Godot saves, but never enters new random
	# encounters or treasure. Verify the non-summon permanent-death UI too.
	scene.selection = ["dracula", "skeleton-spear", "skeleton-archer", "ghoul"]
	scene.reset_battle()
	await process_frame
	var before: Array = scene.rules.units.duplicate(true)
	var dead: Array = before.duplicate(true)
	var owned: Dictionary = dead[0]
	check(str(owned.slug) == "dracula" and not bool(owned.is_summon), "retained Dracula can be instantiated as an owned, non-summoned battle unit")
	dead[0].alive = false
	dead[0].hp = 0
	await scene.visuals.play_deaths(before, dead)
	check(scene.visuals.removed.has(owned.id), "Dracula owned death completes real card-and-sprite dissolution")
	check(not scene.sprites[owned.id].visible and not scene.cards[owned.id].visible, "Dracula permanent-death presentation hides both former assets")

func _run() -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/fixtures/web_v2_units_46.json"))
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json"))
	if not source is Dictionary or not data is Dictionary:
		check(false, "fixed original fixture and Godot species catalog parse")
		quit(1)
		return
	var original: Dictionary = source.units
	var definitions: Dictionary = data.units
	var names: Array = original.keys()
	names.sort()
	check(original.size() == 46 and definitions.size() == 48 and definitions.has("dracula") and definitions.has("dragon"), "46 original species, retained Dracula and separate lap-60 dragon boss")
	for slug in names:
		check(definitions.has(slug), "fixed-source species remains in catalog: " + str(slug))
	names.append("dracula")
	var layout = Layout.new()
	check(layout.metrics.size() == 48 and layout.metrics.has("dragon"), "48 live profiles including dragon; original 47-species coverage preserved")
	if not verify_art_catalog(names, layout):
		print("P4_ALL_MONSTER_PRESENTATION: %d passed, %d failed" % [passed, failed])
		quit(1)
		return
	var scene = BattleScene.instantiate()
	scene.selection = names.slice(0, 4)
	root.add_child(scene)
	await process_frame
	check(not scene.map_mode, "actual production battlefield opened as isolated lab, without mutating a player save")
	scene.speed_index = 2
	for offset in range(0, names.size(), 4):
		var selection: Array = names.slice(offset, mini(offset + 4, names.size()))
		var count: int = selection.size()
		while selection.size() < 4:
			selection.append(names[(offset + selection.size()) % names.size()])
		if offset > 0:
			scene.selection = selection
			scene.reset_battle()
			await process_frame
		check(scene.rules.units.size() >= 8, "real battle can instantiate squad " + str(offset / 4 + 1))
		await check_batch(scene, selection, count)
	await verify_dracula_owned_death(scene)
	scene.queue_free()
	await process_frame
	print("P4_ALL_MONSTER_PRESENTATION: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
