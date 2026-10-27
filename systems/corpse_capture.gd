extends Control
const Sound = preload("res://systems/game_audio.gd")
const Overflow = preload("res://systems/reward_overflow.gd")
const AltarUpgradeBadge = preload("res://systems/altar_upgrade_badge.gd")
const LayeredUnitCard = preload("res://systems/layered_unit_card.gd")
const PermanentDeath = preload("res://systems/permanent_death.gd")
# Selection uses a larger card and the original arrow, never a green frame.
const SELECTED_CAPTURE_SCALE: float = 1.15
var scene
var session
var choices: Array = []
# Enemy capture cards are external children of the map stage in embedded mode.
# Remove these along with the capture panel so they never leak across battles.
var external_choice_nodes: Array = []
var busy = false

func _exit_tree() -> void:
	for node in external_choice_nodes:
		if is_instance_valid(node): node.queue_free()
	external_choice_nodes.clear()

# Keep the original TextureButton for compatibility, but install the
# approved live portrait/scenery/ribbon/brands also used by the battle card.
# Used both by real soul harvest and the layered-card regression fixture.
static func make_choice_card(source: TextureButton, unit: Dictionary) -> TextureButton:
	var option := TextureButton.new()
	# Never expose the obsolete source card art, even in disabled state.
	option.texture_normal = null
	option.texture_disabled = null
	option.ignore_texture_size = true
	option.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	option.size = source.size
	LayeredUnitCard.install(option, str(unit.get("slug", "")), str(unit.get("name", "")), false, unit.get("brands", []))
	return option

func place_choice_node(node: Control, parent: Control) -> void:
	if parent != self:
		external_choice_nodes.append(node)
		node.z_index = 65

var capture_info_panel: Panel
var capture_info_status: Label
var capture_info_title: Label
# Original V2 capture banner lives 7% down the battlefield.
const CAPTURE_BANNER_SIZE = Vector2(430,142)

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
	build_capture_header()
	var pending: Dictionary = session.world.pending_reward
	for index in range(pending.corpses.size()):
		var corpse: Dictionary = pending.corpses[index]
		var unit: Dictionary = scene.rules.find_id(corpse.id)
		if unit.is_empty(): continue
		scene.cards[unit.id].hide()
		scene.bars[unit.id].hide()
		# Do not copy only the old flattened texture: the in-battle
		# approved portrait is a separate child layer on the source card.
		# A new choice must install the same layers, even when locked.
		var option: TextureButton = make_choice_card(scene.cards[unit.id], unit)
		var on_map_tiles: bool = scene.uses_map_tile_dock()
		var choice_parent: Control = scene.detail_parent if on_map_tiles else self
		# During capture, use the SAME bottom-tile rectangle as the defeated
		# enemy's regular battle card. Do not relocate it into the clipped arena.
		option.position = scene.cards[unit.id].position if on_map_tiles else Vector2(scene.unit_x(unit)-option.size.x*0.5,scene.card_rest_y())
		option.tooltip_text = "%s · 필요 주사위 %d 이상" % [corpse.name,int(corpse.target)]
		option.pressed.connect(func(): select_corpse(index))
		choice_parent.add_child(option)
		place_choice_node(option,choice_parent)
		option.pivot_offset = option.size * 0.5
		AltarUpgradeBadge.sync(option,unit)
		# The battle death pose starts at RGB 0.4 / alpha 0.35. Once it is
		# offered as a reward, bring back its silhouette without changing the
		# in-combat death animation, source art, or persisted reward state.
		improve_corpse_visibility(unit)
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
		var caption_pos: Vector2 = Vector2(option.position.x-16,option.position.y+option.size.y+2) if on_map_tiles else Vector2(scene.unit_x(unit)-45,scene.card_rest_y()-24)
		var caption = scene.text(choice_parent,"%d 이상" % int(corpse.target),caption_pos,Vector2(90,24),13)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		place_choice_node(caption,choice_parent)
		var arrow_pos: Vector2 = option.position+Vector2(23,-13 if on_map_tiles else -55)
		var arrow = scene.image(choice_parent,"res://assets/cards/corpse-selection-arrow.png",arrow_pos,Vector2(34,34))
		arrow.rotation = PI
		arrow.pivot_offset = arrow.size*0.5
		arrow.z_index = 8 # Stay visible above the enlarged selected card.
		place_choice_node(arrow,choice_parent)
		choices.append({"card":option,"target":target,"arrow":arrow,"index":index})
	refresh()
	if pending.phase in ["success","failed"]: call_deferred("resume_result")

# Source v2-auto-battle-practice.css .battlefield-capture:
# top 7%; centered, maximum 430px wide; 142px tall; never captures input.
func build_capture_header() -> void:
	capture_info_panel=Panel.new()
	capture_info_panel.name="CaptureInfoPanel"
	capture_info_panel.position=Vector2((size.x-CAPTURE_BANNER_SIZE.x)*0.5,size.y*0.07)
	capture_info_panel.size=CAPTURE_BANNER_SIZE
	capture_info_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var frame=StyleBoxFlat.new()
	frame.bg_color=Color("c9aa94")
	frame.border_color=Color("76573b")
	frame.set_border_width_all(10)
	frame.set_corner_radius_all(3)
	frame.shadow_color=Color(0,0,0,0.45)
	frame.shadow_size=5
	capture_info_panel.add_theme_stylebox_override("panel",frame)
	add_child(capture_info_panel)
	capture_info_title=Label.new()
	capture_info_title.name="CaptureInfoTitle"
	capture_info_title.position=Vector2(15,13)
	capture_info_title.size=Vector2(400,31)
	capture_info_title.text="영혼 수확"
	capture_info_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	capture_info_title.add_theme_font_size_override("font_size",19)
	capture_info_title.add_theme_color_override("font_color",Color("412c21"))
	capture_info_title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	capture_info_panel.add_child(capture_info_title)
	capture_info_status=Label.new()
	capture_info_status.name="CaptureInfoStatus"
	capture_info_status.position=Vector2(16,48)
	capture_info_status.size=Vector2(398,78)
	capture_info_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	capture_info_status.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	capture_info_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	capture_info_status.add_theme_font_size_override("font_size",15)
	capture_info_status.add_theme_color_override("font_color",Color("49382e"))
	capture_info_status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	capture_info_panel.add_child(capture_info_status)

# During capture, restore defeated bodies to their readable full-opacity state.
func improve_corpse_visibility(unit: Dictionary) -> void:
	var sprite: TextureRect = scene.sprites.get(str(unit.id))
	if sprite == null: return
	sprite.show()
	# Opaque enough to recognize the defeated unit, slightly cool to retain
	# a corpse-like appearance on dark battlefield backgrounds.
	sprite.modulate = Color(0.95,0.97,1.0,1.0)
	var appearance: ShaderMaterial = sprite.material as ShaderMaterial
	if appearance != null:
		# Clear any unfinished cinematic attack focus from the last round.
		appearance.set_shader_parameter("dim",0.0)

func refresh() -> void:
	var pending: Dictionary = session.world.pending_reward
	var corpse: Dictionary = pending.corpses[int(pending.selected)]
	for choice in choices:
		var selected = int(pending.selected)==choice.index
		choice.card.modulate = Color.WHITE if selected else Color(1,1,1,0.97)
		choice.card.pivot_offset = choice.card.size * 0.5
		choice.card.scale = Vector2.ONE * (SELECTED_CAPTURE_SCALE if selected else 1.0)
		choice.card.z_index = 6 if selected else 0
		choice.arrow.visible = selected
		choice.card.disabled = busy or pending.locked
		choice.target.disabled = busy or pending.locked
	scene.message.text = "%s · 주사위 %d 이상 · 남은 시도 %d%s" % [corpse.name,int(corpse.target),int(pending.attempts)," · 대상 고정" if pending.locked else " · 시체를 선택하세요"]
	if is_instance_valid(capture_info_status):
		capture_info_status.text = "%s · %d 이상\n남은 시도 %d%s" % [corpse.name,int(corpse.target),int(pending.attempts)," · 대상 고정" if pending.locked else " · 시체를 선택하세요"]
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
	if scene.embedded and is_instance_valid(scene.map_owner):
		# Post-victory capture uses the same full-stage die and physical
		# bouncing animation as the map and battle. roll_capture() has ALREADY
		# committed the outcome; this is presentation only, with no new RNG.
		await scene.map_owner.roll_shared_die(int(result.face),true)
	else:
		# Standalone battlefield has no persistent map die or map owner.
		await scene.dice_animation.roll_battle(scene.dice,scene.texture,scene.sound,wait)
	scene.dice.texture_normal = scene.texture("res://assets/battle/dice/result-%02d.png" % int(result.face))
	# The shared map animation already plays the landing SFX.
	if not (scene.embedded and is_instance_valid(scene.map_owner)):
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
	# Commit the actual soul first. A full monster book may prompt the
	# player to discard a card; nothing should visibly enter the book
	# until the player has chosen to KEEP this newly captured monster.
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
	if outcome.kept:
		Sound.cue(scene,"capture_success")
		if scene.uses_map_tile_dock() and is_instance_valid(scene.map_owner) and is_instance_valid(scene.map_owner.book_button):
			# The battle cards and the actual chained monster book share the
			# original map stage. Reuse the SAME curved flight, brand/badge
			# overlays and book contact pulse as ordinary inventory rewards.
			# No flight to the arena center and no fake book in the viewport.
			await scene.map_owner.animate_reward_to_inventory("unit",selected_card)
		else:
			# Standalone battle previews have no actual map book to fly into.
			# Preserve their old collection effect instead of targeting a
			# nonexistent UI button. Normal gameplay always uses the map.
			var spirit_parent: Control = scene.detail_parent if scene.uses_map_tile_dock() else self
			var spirit: Control = LayeredUnitCard.flight_visual_copy(selected_card)
			if spirit != null:
				spirit_parent.add_child(spirit)
				spirit.position = selected_card.position
			else:
				# All registered monsters have layered cards, including in
				# standalone preview mode; never resurrect a flattened PNG.
				spirit = LayeredUnitCard.make_preview(spirit_parent,corpse,selected_card.position,selected_card.size)
				AltarUpgradeBadge.sync(spirit,scene.rules.find_id(str(corpse.id)))
			spirit.z_index = 76 if spirit_parent!=self else 0
			spirit.pivot_offset = spirit.size*0.5
			spirit.modulate = Color(0.8,1,1)
			selected_card.hide()
			var flight_size: Vector2 = spirit_parent.size if spirit_parent!=self else scene.surface_size
			var motion = create_tween()
			motion.tween_property(spirit,"position",flight_size*0.5-spirit.size*0.5,0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			motion.parallel().tween_property(spirit,"scale",Vector2.ONE*1.12,0.52)
			motion.tween_property(spirit,"position:y",flight_size.y-spirit.size.y*0.35,0.48)
			motion.parallel().tween_property(spirit,"scale",Vector2.ONE*0.22,0.48)
			motion.parallel().tween_property(spirit,"modulate:a",0.0,0.48)
			await motion.finished
			spirit.queue_free()
	else:
		# If the player discarded the NEW card during overflow, do not
		# falsely animate it as though it entered the monster book.
		var discard = create_tween()
		discard.tween_property(selected_card,"modulate:a",0.0,0.18)
		await discard.finished
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
	# The terminal failure is now persisted. Dissolve every unrecovered enemy
	# card using the *same* permanent-death shader, sound and rising ash as the
	# allied permanent-loss presentation, then return to the live map. Never
	# remove the cards before the save succeeds, so failed storage stays retryable.
	var failed_cards: Array = []
	for choice in choices:
		if is_instance_valid(choice.card): failed_cards.append(choice.card)
	var effect = PermanentDeath.new()
	(scene.detail_parent if scene.uses_map_tile_dock() else scene.layer).add_child(effect)
	await effect.play_failed_capture(scene,failed_cards)
	effect.queue_free()
	session.notice += " · 영혼 수확 실패"
	scene.busy = false
	scene.return_to_map()
