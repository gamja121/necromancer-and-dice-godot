extends SceneTree
## 5P: original browser freeze-status-label graphic on actual Godot combatants.
const BattleScene=preload("res://battlefield.tscn")
const FreezeArt=preload("res://assets/battle/ui/freeze-status-label.png")
const Visuals=preload("res://systems/battle_visuals.gd")
var passed: int=0
var failed: int=0

func check(value: bool, label: String) -> void:
	if value:
		passed+=1
		print("PASS ui-freeze: ",label)
	else:
		failed+=1
		printerr("FAIL ui-freeze: ",label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(FreezeArt!=null and FreezeArt.get_size()==Vector2(96,58),"unchanged original freeze PNG imports at exact 96x58 dimensions")
	var original: Image=FreezeArt.get_image()
	check(original!=null and not original.is_empty() and original.get_used_rect().size.x>70,"original image has visible source pixels")
	check(Visuals.FREEZE_BADGE_SIZE.x==78 and absf(Visuals.FREEZE_BADGE_SIZE.y-78.0*58.0/96.0)<0.01,"source CSS badge has original aspect, 78px browser cap")
	var session=root.get_node_or_null("RunSession")
	var prior_encounter: Dictionary={}
	var prior_world
	if session!=null:
		prior_encounter=session.encounter.duplicate(true)
		prior_world=session.world
		session.encounter={}
	var battle=BattleScene.instantiate()
	root.add_child(battle)
	await process_frame
	check(battle.visuals!=null and battle.rules.units.size()>=6,"actual production battlefield initializes all units")
	check(battle.visuals.freeze_badges.is_empty(),"no frozen icons appear on a fresh unfrozen battlefield")
	var ally: Dictionary=battle.rules.units[0]
	var enemy: Dictionary=battle.rules.units[4]
	var ally_id: String=str(ally.id)
	var enemy_id: String=str(enemy.id)
	var state_before: String=JSON.stringify(battle.rules.snapshot())
	battle.render_units(battle.rules.units)
	check(battle.visuals.freeze_badges.is_empty(),"rerendering unmodified units never fabricates freeze icons")
	check(JSON.stringify(battle.rules.snapshot())==state_before,"UI sync cannot change combat RNG or checkpoint")
	ally.frozen=true
	battle.render_units(battle.rules.units)
	check(battle.visuals.freeze_badges.has(ally_id),"genuinely frozen ally creates exactly one original image badge")
	if battle.visuals.freeze_badges.has(ally_id):
		var badge: TextureRect=battle.visuals.freeze_badges[ally_id]
		check(badge.visible and badge.texture==FreezeArt,"frozen ally uses exact source image rather than text replacement")
		check(badge.size==Visuals.FREEZE_BADGE_SIZE and badge.mouse_filter==Control.MOUSE_FILTER_IGNORE,"badge preserves source scale and never captures input")
		check(badge.position.x>=battle.unit_x(ally)-40 and badge.position.x<=battle.unit_x(ally)-38,"badge centered above its owner's HP bar")
		check(badge.position.y<battle.bars[ally_id].position.y,"freeze badge floats above health bar, not over bottom dock")
		check(badge.get_parent()==battle.visuals,"status artwork belongs to battle visuals, not stateful unit cards")
	check(not battle.visuals.freeze_badges.has(enemy_id),"unchanged enemy never inherits ally frozen status")
	var snapshot_frozen: Dictionary=battle.rules.snapshot().duplicate(true)
	battle.render_units(battle.rules.units)
	check(battle.visuals.freeze_badges.size()==1,"multiple syncs never duplicate freeze art nodes")
	enemy.frozen=true
	battle.render_units(battle.rules.units)
	check(battle.visuals.freeze_badges.has(enemy_id) and battle.visuals.freeze_badges[enemy_id].visible,"enemy and ally can independently show frozen badge")
	check(battle.visuals.freeze_badges[enemy_id].texture==FreezeArt,"enemy freeze uses unflipped readable original artwork")
	ally.frozen=false
	battle.render_units(battle.rules.units)
	check(not battle.visuals.freeze_badges[ally_id].visible and battle.visuals.freeze_badges[enemy_id].visible,"status removal hides only previously frozen ally")
	ally.frozen=true
	battle.render_units(battle.rules.units)
	check(battle.visuals.freeze_badges[ally_id].visible,"re-freezing reuses original badge instead of creating another")
	ally.alive=false
	ally.hp=0
	battle.render_units(battle.rules.units)
	check(not battle.visuals.freeze_badges[ally_id].visible,"dead unit cannot display a persistent frozen label")
	ally.alive=true
	ally.hp=mini(1,int(ally.max_hp))
	ally.frozen=true
	battle.visuals.removed[ally_id]=true
	battle.render_units(battle.rules.units)
	check(not battle.visuals.freeze_badges[ally_id].visible,"removed summon cannot leave an orphan frozen badge")
	battle.visuals.removed.erase(ally_id)
	battle.render_units(battle.rules.units)
	check(battle.visuals.freeze_badges[ally_id].visible,"restored unit correctly shows genuine frozen status")
	# A saved rules checkpoint is the real source of truth for all status flags.
	check(battle.rules.restore(snapshot_frozen),"production battle checkpoint restores frozen state")
	battle.render_units(battle.rules.units)
	check(battle.visuals.freeze_badges[ally_id].visible and not battle.visuals.freeze_badges[enemy_id].visible,"render after checkpoint reload displays only saved frozen ally")
	check(JSON.stringify(battle.rules.snapshot())==JSON.stringify(snapshot_frozen),"visual-only source graphic preserves actual checkpoint")
	var badge_before: TextureRect=battle.visuals.freeze_badges[ally_id]
	var count_before: int=battle.visuals.freeze_badges.size()
	await process_frame
	check(badge_before.position.x>=battle.unit_x(ally)-40 and badge_before.position.x<=battle.unit_x(ally)-38,"frozen badge tracks unit presentation after a real frame")
	check(battle.visuals.freeze_badges.size()==count_before,"per-frame update does not allocate extra images")
	battle.reset_battle()
	await process_frame
	check(battle.visuals.freeze_badges.is_empty(),"new encounter discards old status badges and preserves clean state")
	battle.queue_free()
	await process_frame
	if session!=null:
		session.encounter=prior_encounter
		session.world=prior_world
	print("UI_FREEZE_STATUS_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
