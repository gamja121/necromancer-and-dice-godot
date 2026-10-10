extends Control
const Overflow = preload("res://systems/reward_overflow.gd")
const BrandCompletionSeal = preload("res://systems/brand_completion_seal.gd")
var scene
var session
var choices: Array = []
var busy = false

func setup(battle_scene) -> void:
	scene = battle_scene
	session = scene.session
	size = scene.surface_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60
	scene.round_label.text = "전투 승리 · 영혼 수확"
	scene.map_return.disabled = true
	scene.pause_button.disabled = true
	scene.speed_button.disabled = true
	scene.dice.show()
	var face = int(session.world.pending_reward.get("roll",session.world.pending_reward.get("face",1)))
	scene.dice.texture_normal = scene.texture("res://assets/battle/dice/result-%02d.png" % face)
	var pending: Dictionary = session.world.pending_reward
	for index in range(pending.corpses.size()):
		var corpse: Dictionary = pending.corpses[index]
		var unit: Dictionary = scene.rules.find_id(corpse.id)
		if unit.is_empty(): continue
		scene.cards[unit.id].hide()
		scene.bars[unit.id].hide()
		var option = TextureButton.new()
		option.texture_normal = scene.cards[unit.id].texture_normal
		option.ignore_texture_size = true
		option.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		option.size = scene.cards[unit.id].size
		option.position = Vector2(scene.unit_x(unit)-option.size.x*0.5,scene.card_rest_y())
		option.tooltip_text = "%s · 필요 주사위 %d 이상" % [corpse.name,int(corpse.target)]
		option.pressed.connect(func(): select_corpse(index))
		add_child(option)
		BrandCompletionSeal.sync(option,unit)
		var sprite: TextureRect = scene.sprites[unit.id]
		var target = Button.new()
		target.flat = true
		target.focus_mode = Control.FOCUS_NONE
		for state in ["normal","hover","pressed","disabled","focus"]:
			target.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		target.position = sprite.position
		target.size = sprite.size
		target.tooltip_text = option.tooltip_text
		target.pressed.connect(func(): select_corpse(index))
		add_child(target)
		var caption = scene.text(self,"%d 이상" % int(corpse.target),Vector2(scene.unit_x(unit)-45,scene.card_rest_y()-24),Vector2(90,24),13)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var arrow = scene.image(self,"res://assets/cards/corpse-selection-arrow.png",option.position+Vector2(23,-55),Vector2(34,34))
		arrow.rotation = PI
		arrow.pivot_offset = arrow.size*0.5
		choices.append({"card":option,"target":target,"arrow":arrow,"index":index})
	refresh()
	if pending.phase in ["success","failed"]: call_deferred("resume_result")

func refresh() -> void:
	var pending: Dictionary = session.world.pending_reward
	var corpse: Dictionary = pending.corpses[int(pending.selected)]
	for choice in choices:
		var selected = int(pending.selected)==choice.index
		choice.card.modulate = Color.WHITE if selected else Color(0.65,0.65,0.65)
		choice.arrow.visible = selected
		choice.card.disabled = busy or pending.locked
		choice.target.disabled = busy or pending.locked
	scene.message.text = "%s · 주사위 %d 이상 · 남은 시도 %d%s" % [corpse.name,int(corpse.target),int(pending.attempts)," · 대상 고정" if pending.locked else " · 시체를 선택하세요"]
	scene.dice.tooltip_text = "영혼 수확 주사위 굴리기"
	scene.dice.disabled = busy

func select_corpse(index: int) -> void:
	if busy: return
	if session.select_capture(index): refresh()
	else: scene.message.text = "선택 저장 실패 · 다시 시도하세요"

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func roll() -> void:
	if busy: return
	if session.world.pending_reward.phase=="success":
		await complete_success()
		return
	if session.world.pending_reward.phase=="failed":
		await complete_failure()
		return
	var result: Dictionary = session.roll_capture()
	if not result.get("ok",false):
		scene.message.text = "수확 판정 저장 실패 · 다시 시도하세요"
		return
	busy = true
	scene.busy = true
	refresh()
	await scene.dice_animation.roll_battle(scene.dice,scene.texture,scene.sound,wait)
	scene.dice.texture_normal = scene.texture("res://assets/battle/dice/result-%02d.png" % int(result.face))
	scene.sound("dice-land")
	await scene.cues.play_dice_result(int(result.face))
	if result.success:
		await wait(0.42)
		await complete_success()
	elif session.world.pending_reward.phase=="failed":
		await complete_failure()
	else:
		await wait(0.62)
		busy = false
		scene.busy = false
		refresh()
		scene.message.text += " · 실패, 한 번 더 시도할 수 있습니다"

func resume_result() -> void:
	if session.world.pending_reward.phase=="success": await complete_success()
	else: await complete_failure()

func complete_success() -> void:
	busy = true
	scene.busy = true
	refresh()
	var pending: Dictionary = session.world.pending_reward
	var corpse: Dictionary = pending.corpses[int(pending.selected)]
	scene.message.text = corpse.name+" · 영혼 수확 성공"
	var selected_card: TextureButton = choices[int(pending.selected)].card
	var spirit = scene.image(self,"res://assets/cards/unit-card-%s.png" % corpse.slug,selected_card.position,selected_card.size)
	spirit.pivot_offset = spirit.size*0.5
	spirit.modulate = Color(0.8,1,1)
	selected_card.hide()
	var motion = create_tween()
	motion.tween_property(spirit,"position",scene.surface_size*0.5-spirit.size*0.5,0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.parallel().tween_property(spirit,"scale",Vector2.ONE*1.12,0.52)
	motion.tween_property(spirit,"position:y",scene.surface_size.y-spirit.size.y*0.35,0.48)
	motion.parallel().tween_property(spirit,"scale",Vector2.ONE*0.22,0.48)
	motion.parallel().tween_property(spirit,"modulate:a",0.0,0.48)
	await motion.finished
	spirit.queue_free()
	var outcome: Dictionary = session.claim_reward()
	if outcome.get("overflow",false):
		var overflow = Overflow.new()
		(scene.detail_parent if scene.embedded else scene.layer).add_child(overflow)
		overflow.setup(session)
		outcome = await overflow.resolved
	if not outcome.get("ok",false):
		busy = false
		scene.busy = false
		scene.dice.disabled = false
		selected_card.show()
		scene.message.text = "획득 저장 실패 · 주사위를 눌러 다시 저장하세요"
		return
	session.notice += " · "+(corpse.name+" 획득" if outcome.kept else "신규 마물 카드 버림")
	await wait(0.65)
	scene.busy = false
	scene.return_to_map()

func complete_failure() -> void:
	busy = true
	scene.busy = true
	scene.dice.disabled = true
	scene.message.text = "영혼 수확 실패 · 시도 횟수를 모두 사용했습니다"
	await wait(0.9)
	if not session.dismiss_failed_capture():
		busy = false
		scene.busy = false
		scene.dice.disabled = false
		scene.message.text = "결과 저장 실패 · 주사위를 눌러 다시 저장하세요"
		return
	session.notice += " · 영혼 수확 실패"
	scene.busy = false
	scene.return_to_map()
