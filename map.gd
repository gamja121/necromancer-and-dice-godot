extends Control
const MapPresentation = preload("res://systems/map_presentation.gd")
const MapShuffleGather = preload("res://systems/map_shuffle_gather.gd")
const MapGearShift = preload("res://systems/map_gear_shift.gd")
var presentation
var map_audio: Control
var map_music: AudioStreamPlayer

const BattleResources = preload("res://systems/battle_resources.gd")
const BookBattleLock = preload("res://systems/book_battle_lock.gd")
const ButtonEffects = preload("res://systems/button_effects_module.gd")
const PanelEffects = preload("res://systems/panel_effects_module.gd")
const InkSceneReveal = preload("res://systems/ink_scene_reveal.gd")
const GraveyardGhoulMotion = preload("res://systems/graveyard_ghoul_motion.gd")
const GraveyardStoryEntryMotion = preload("res://systems/graveyard_story_entry_motion.gd")
const CommanderPortraitMotion = preload("res://systems/knight_commander_portrait_motion.gd")
const MonsterHunterLayerMotion = preload("res://systems/monster_hunter_layer_motion.gd")
const CultistStoryLayerMotion = preload("res://systems/cultist_story_layer_motion.gd")
const RitualPortalLayerMotion = preload("res://systems/ritual_portal_layer_motion.gd")
const StoryEventEntry = preload("res://systems/story_event_entry.gd")
const VillageRumorEntry = preload("res://systems/village_rumor_entry.gd")
const KnightCommanderEntry = preload("res://systems/knight_commander_entry.gd")
const MonsterHunterEntry = preload("res://systems/monster_hunter_entry.gd")
const CultistRumorEntry = preload("res://systems/cultist_rumor_entry.gd")
const CultistAltarEntry = preload("res://systems/cultist_altar_entry.gd")
const RitualPortalEntry = preload("res://systems/ritual_portal_entry.gd")
const RitualPortalBeats = preload("res://systems/ritual_portal_beats.gd")
const MonsterKingHuntEntry = preload("res://systems/monster_king_hunt_entry.gd")
const MonsterKingHuntBeats = preload("res://systems/monster_king_hunt_beats.gd")
const CultistAltarBeats = preload("res://systems/cultist_altar_beats.gd")
const CultistRumorBeats = preload("res://systems/cultist_rumor_beats.gd")
const MonsterHunterBeats = preload("res://systems/monster_hunter_beats.gd")
const KnightCommanderBeats = preload("res://systems/knight_commander_beats.gd")
const VillageRumorBeats = preload("res://systems/village_rumor_beats.gd")
const GraveyardStoryBeats = preload("res://systems/graveyard_story_beats.gd")
# Story illustrations keep the existing 16:9 source layout, independently of location scenes.
const TILE_EVENT_SCENE_RECT = Rect2(243.2,136.8,793.6,446.4)
# Ordinary tile locations use the exact embedded battlefield footprint and frame.
# Battle host: (128,126) 1024x450; inner viewport: (+22,+22) 980x406.
const LOCATION_EVENT_SCENE_RECT = Rect2(150.0,148.0,980.0,406.0)
const LOCATION_EVENT_FRAME_RECT = Rect2(128.0,126.0,1024.0,450.0)
# Keep gameplay actions below the wider art, where none of them hide the scene.
const TILE_EVENT_ACTION_RECT = Rect2(515.0,595.0,216.0,58.0)
const TILE_EVENT_EXIT_RECT = Rect2(765.0,595.0,216.0,58.0)
const TILE_EVENT_INHERITANCE_RECT = Rect2(265.0,595.0,216.0,58.0)
const TILE_EVENT_PATROL_RECT = Rect2(515.0,595.0,216.0,58.0)
# Frozen CSS places the ghoul at 55%/18% of the event art frame,
# sized to 30%/64% (not stretched across the whole scene).
const GRAVEYARD_GHOUL_FRACTIONS = Rect2(0.55,0.18,0.30,0.64)
const GRAVEYARD_DIALOGUE_FRAME = "res://assets/map/ui/shared_dialogue_panel.svg"
const SHARED_DIALOGUE_RECT = Rect2(205.0, 516.0, 870.0, 132.0)
const GRAVEYARD_DIALOGUE_RECT = SHARED_DIALOGUE_RECT # unified 132-pixel safe parchment
const StoryBattleRegistry = preload("res://systems/story_battle_registry.gd")

const ExplorationActions = preload("res://systems/exploration_actions.gd")
const PlaceActions = preload("res://systems/place_actions.gd")
const HomeInheritance = preload("res://systems/home_inheritance.gd")
const MapState = preload("res://systems/map_state.gd")
const EventDiscoveryCard = preload("res://systems/event_discovery_card.gd")
const Discovery = preload("res://systems/location_discoveries.gd")
const Routine = preload("res://systems/routine_event_catalog.gd")
const RoutineCard = preload("res://systems/routine_event_card.gd")
const RewardOverflow = preload("res://systems/reward_overflow.gd")
const UnlockNoticeBadge = preload("res://systems/unlock_notice_badge.gd")
const TreasureReward = preload("res://systems/treasure_reward.gd")
const DiceHand = preload("res://systems/dice_control_hand.gd")
const InventoryPanel = preload("res://systems/inventory_panel.gd")
const AudioSettings = preload("res://systems/audio_settings.gd")
const Battlefield = preload("res://battlefield.tscn")
const GameOverScreen = preload("res://systems/game_over_screen.gd")
const BattleDeck = preload("res://systems/battle_deck.gd")
const UnitInfo = preload("res://systems/unit_info.gd")
const DiceAnimation = preload("res://systems/dice_animation.gd")
const Rules = preload("res://systems/battlefield_rules.gd")
const TILE_SIZE = Vector2(120.0,90.0)
const SELECTED_TILE_SCALE = Vector2(1.025,1.025)
const EVENT_IMAGES = {"home":"home","village":"village","graveyard":"graveyard","altar":"altar","unknown":"world-tree","forest":"forest","rest":"camp","fortune-teller-camp":"fortune-teller"}
var session
var dice_animation = DiceAnimation.new()
var world
var stage: Control
var buttons: Array = []
var hero: TextureRect
var dice: TextureButton
# The 24 perimeter tiles form a wall; the painted die (including rotation)
# must stay inside the open central board, on map AND in combat.
const SHARED_DIE_AREA = Rect2(150.0,140.0,980.0,416.0)
const DIE_FOREGROUND_Z = 96
const DIE_BEHIND_LOCATION_Z = 20
var shared_die_busy: bool = false
var game_over_screen: Control
var status: Label

func shared_dice_position() -> Vector2:
	var stored := Vector2(float(world.dice_visual_position[0]),float(world.dice_visual_position[1]))
	var wall: Rect2 = Rect2()
	if is_instance_valid(presentation) and is_instance_valid(presentation.gauge):
		wall = presentation.gauge.dice_wall_rect()
	# Legacy saves may have a pose over a tile or the corruption HUD.
	# Correct only the cosmetic button position; never rewrite the saved roll.
	return dice_animation.safe_rest_position(stored,Vector2(76,76),SHARED_DIE_AREA,wall)

func remember_shared_die() -> void:
	if not is_instance_valid(dice): return
	# Snap a legacy / combat landing away from the tile ring and visible HUD
	# before persisting it; the result, gameplay RNG and turn never change.
	var wall: Rect2 = Rect2()
	if is_instance_valid(presentation) and is_instance_valid(presentation.gauge):
		wall = presentation.gauge.dice_wall_rect()
	var safe: Vector2 = dice_animation.safe_rest_position(dice.position,dice.size,SHARED_DIE_AREA,wall)
	var stopped := Vector2(roundf(safe.x),roundf(safe.y))
	dice.position = stopped
	var final_angle: int = roundi(dice.rotation_degrees)
	dice.rotation_degrees = float(final_angle)
	world.dice_visual_position = [int(stopped.x),int(stopped.y)]
	world.dice_visual_rotation = final_angle
	# Presentation state goes into the ordinary atomic run save; gameplay RNG
	# and saved die result are not changed.
	session.save_world()

func roll_shared_die(face: int, battle_area: bool = false) -> void:
	if not is_instance_valid(dice): return
	shared_die_busy = true
	dice.disabled = true
	# This is ONE stage-space die across battlefield, map, world tree and
	# fortune teller. Always begin at its previous stopping point.
	var wall: Rect2 = Rect2()
	if not battle_area and not is_instance_valid(overlay) and is_instance_valid(presentation.gauge):
		wall = presentation.gauge.dice_wall_rect()
	await dice_animation.roll_map(dice,face,SHARED_DIE_AREA,texture,sound,wall)
	world.dice_visual_face = clampi(face,1,6)
	remember_shared_die()
	shared_die_busy = false
	refresh_shared_die_input()

func refresh_shared_die_input() -> void:
	if not is_instance_valid(dice): return
	if shared_die_busy or moving:
		dice.disabled = true
		return
	if is_instance_valid(embedded_battle):
		# An ongoing round and result/capture screen set the proper state.
		dice.disabled = embedded_battle.busy or (not is_instance_valid(embedded_battle.capture_panel) and not embedded_battle.rules.winner().is_empty())
		return
	if not is_instance_valid(overlay):
		dice.disabled = false
		return
	if overlay is ExplorationActions and overlay.type=="unknown":
		dice.disabled = overlay.busy or overlay.action_button.disabled
	elif overlay is PlaceActions and overlay.type=="fortune-teller-camp":
		dice.disabled = overlay.busy or overlay.confirm_button.disabled
	else:
		dice.disabled = true

func on_shared_die_pressed() -> void:
	if shared_die_busy or moving: return
	if is_instance_valid(embedded_battle):
		await embedded_battle.on_dice_pressed()
	elif overlay is ExplorationActions and overlay.type=="unknown":
		await overlay.pray()
	elif overlay is PlaceActions and overlay.type=="fortune-teller-camp":
		await overlay.roll_prophecy()
	elif not is_instance_valid(overlay):
		await roll_move()

var hud: Label
# Route *all* overlay assignments through the map's audio visibility guard.
# An explicit setter also handles direct scene creation (story/battle/treasure),
# avoiding a one-frame popup overlapping the original location art.
var overlay: Control:
	set(value):
		overlay = value
		if is_instance_valid(map_audio): map_audio.set_modal_blocked(is_instance_valid(value))
		_sync_map_chrome()
var selected = -1
var moving = false
var textures: Dictionary = {}
var embedded_battle: Control
var book_button: TextureButton
var book_lock: Control
var battle_returning = false
var returning_story_event_id: String = ""
var deck_button: TextureButton
var dice_count_label: Label
# Frozen web map hides board controls (not tiles/hero) behind an open event.
# Track only chrome created by render(), so rebuilt boards cannot retain old nodes.
var map_chrome: Array[Control] = []

func raise_shared_die_for_input() -> void:
	if is_instance_valid(dice) and is_instance_valid(stage) and dice.visible and dice.get_parent()==stage:
		stage.move_child(dice,stage.get_child_count()-1)

func _sync_map_chrome() -> void:
	# A single persistent die changes PAINT and INPUT priority with the scene.
	# Battles and the fortune prophecy roll need the REAL shared die above art
	# and clickable. Other location paintings still cover the inactive die.
	var has_overlay: bool = is_instance_valid(overlay)
	var central_battle: bool = has_overlay and overlay.name=="CentralBattle"
	var fortune_prophecy: bool = has_overlay and overlay is PlaceActions and overlay.type=="fortune-teller-camp"
	var foreground_die: bool = not has_overlay or central_battle or fortune_prophecy
	var show_board_controls: bool = not has_overlay or overlay is InventoryPanel
	var show_die: bool = not (overlay is BattleDeck or overlay is HomeInheritance)
	for control in map_chrome:
		if not is_instance_valid(control): continue
		var battle_book_or_deck: bool = control == book_button or control == deck_button or control == dice_count_label
		control.visible = show_die if control == dice else (show_board_controls or (central_battle and battle_book_or_deck))
	if is_instance_valid(dice):
		dice.z_index = DIE_FOREGROUND_Z if foreground_die else DIE_BEHIND_LOCATION_Z
		# Godot GUI input depends on sibling order, NOT z_index alone.
		# Make the shared die the LAST sibling in battle/map/prophecy. Other
		# location overlays must retain painting and click precedence.
		if foreground_die and show_die:
			raise_shared_die_for_input()
		elif has_overlay and overlay.get_parent()==stage:
			stage.move_child(overlay,stage.get_child_count()-1)
	if is_instance_valid(presentation) and is_instance_valid(presentation.gauge):
		presentation.gauge.visible = show_board_controls
	# Keep existing saved face, button and role-specific gameplay rules.
	if is_instance_valid(dice) and not shared_die_busy: refresh_shared_die_input()
	# Only the dedicated prophecy function permits the die above its art.
	# Other location art and buttons still block clicks through the painting.
	if is_instance_valid(dice):
		dice.mouse_filter = Control.MOUSE_FILTER_STOP if foreground_die else Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	DisplayServer.window_set_title("Necromancer and Dice")
	AudioSettings.apply_saved()
	session = get_node("/root/RunSession")
	session.ensure_world()
	world = session.world
	var font = preload("res://assets/fonts/nanum_gothic_regular.ttf")
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	presentation = MapPresentation.new()
	add_child(presentation)
	presentation.setup(self)
	map_music = AudioStreamPlayer.new()
	map_music.bus = "Music"
	map_music.stream = load("res://assets/map/music/map_board.mp3")
	map_music.volume_db = linear_to_db(0.3)
	add_child(map_music)
	map_music.finished.connect(map_music.play)
	if DisplayServer.get_name()!="headless": map_music.play()
	render()
	var battle_resources = BattleResources.new()
	battle_resources.name = "BattleResources"
	add_child(battle_resources)
	battle_resources.setup(world)
	if not session.notice.is_empty():
		status.text = session.notice
		session.notice = ""
	if world.roster.is_empty(): status.text = "출전 가능한 마물이 없습니다 · 새 원정을 시작하세요."
	session.save_world()
	if not world.run_result.is_empty():
		call_deferred("show_game_over",true)
	elif world.pending_reward.get("kind","")=="capture": open_embedded_battle(false)
	elif world.pending_reward.get("kind","") in ["treasure","mimic"]: show_treasure()
	elif world.pending_reward.get("kind","")=="routine": call_deferred("resume_routine_event")
	elif not session.encounter.is_empty(): open_embedded_battle(false)
	elif not world.pending_move.is_empty(): call_deferred("resume_map_move")
	elif not session.pending_story_battle_event_id().is_empty(): call_deferred("show_pending_story_battle_result")
	elif world.tiles[world.position] in ["village","unknown","event","altar","graveyard","forest"]: call_deferred("resume_village_rumor_if_unfinished")

func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

func image(parent: Control, path: String, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var node = TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture = texture(path)
	node.position = pos
	node.size = dimensions
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func shared_story_frame(panel: Control) -> TextureRect:
	# Decorative art only. No labels, buttons, named tabs, hit-testing or saved state.
	var frame = image(panel, GRAVEYARD_DIALOGUE_FRAME, SHARED_DIALOGUE_RECT.position, SHARED_DIALOGUE_RECT.size)
	frame.name = "SharedStoryDialogueFrame"
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame

func label_at(parent: Control, value: String, pos: Vector2, dimensions: Vector2, font_size: int = 15) -> Label:
	var node = Label.new()
	node.text = value
	node.position = pos
	node.size = dimensions
	var display_size: int = font_size
	# Keep story captions in two non-overlapping parchment lanes, never
	# over the controls at y=653. Old event-specific coordinates are input only.
	var story_frame: bool = parent.get_node_or_null("SharedStoryDialogueFrame") != null or parent.get_node_or_null("StoryDialogueFrame") != null
	if story_frame and pos.y >= 525.0 and pos.y < 640.0 and dimensions.x >= 640.0:
		var spoken: bool = pos.y >= 590.0
		node.position = Vector2(275.0, 593.0 if spoken else 535.0)
		node.size = Vector2(730.0, 44.0 if spoken else 51.0)
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if value.length() > (58 if spoken else 80): display_size = mini(display_size,15)
		if value.length() > (105 if spoken else 126): display_size = mini(display_size,14)
		node.clip_text = true
		node.set_meta("ui_story_copy_role","speech" if spoken else "narration")
	# Some story beats deliberately use narrower custom text lanes (e.g. 492 px).
	# Preserve the original layout AND its story font for all these lines too.
	if story_frame and pos.y >= 525.0 and pos.y < 645.0 and dimensions.x >= 450.0 and not node.has_meta("ui_story_copy_role"):
		node.set_meta("ui_story_copy_role","speech" if pos.y >= 590.0 else "narration")
	node.add_theme_font_size_override("font_size",display_size)
	node.add_theme_color_override("font_color",Color("f2dfb5"))
	node.add_theme_color_override("font_shadow_color",Color.BLACK)
	node.add_theme_constant_override("shadow_offset_y",2)
	parent.add_child(node)
	return node

func button(parent: Control, title: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var node = Button.new()
	node.text = title
	node.position = pos
	node.size = dimensions
	node.pressed.connect(callback)
	parent.add_child(node)
	add_button_effect(node)
	return node

func add_button_effect(node: BaseButton) -> void:
	if node.has_node("ButtonEffectsModule"): return
	var effect = ButtonEffects.new()
	effect.name = "ButtonEffectsModule"
	effect.hover_scale = Vector2(1.04,1.04)
	effect.hover_rotation_degrees = 0.6
	node.add_child(effect)

func center(index: int) -> Vector2:
	return MapState.centers()[index]*Vector2(12.8,7.2)

func tile_path(index: int) -> String:
	var id: String = world.tiles[index]
	# The frozen web map retains a separate rare-monster-cleared tile silhouette.
	if index in world.cleared and id in ["monster","rare-monster","boss"]: id += "-cleared"
	return "res://assets/map/tiles/"+id+".png"

func render() -> void:
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	buttons = []
	map_chrome.clear()
	stage = Control.new()
	stage.size = Vector2(1280,720)
	add_child(stage)
	var background = image(stage,"res://assets/map/maps/%s-map.jpg" % world.region,Vector2.ZERO,stage.size)
	background.stretch_mode = TextureRect.STRETCH_SCALE
	presentation.install(stage)
	for i in range(24):
		var node = TextureButton.new()
		node.ignore_texture_size = true
		node.texture_normal = texture(tile_path(i))
		node.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		node.size = TILE_SIZE
		node.position = center(i)-node.size/2
		node.pivot_offset = node.size/2
		node.tooltip_text = "%d번 · %s%s" % [i+1,MapState.NAMES[world.tiles[i]]," · 처치 완료" if i in world.cleared else ""]
		node.pressed.connect(func(): select_tile(i))
		stage.add_child(node)
		if (world.tiles[i]=="rest" and session.event_flag_is_set(UnlockNoticeBadge.REST_TILE_PENDING)) or (Discovery.exists(str(world.tiles[i])) and session.event_flag_is_set("ui:unlock:%s:tile_pending" % world.tiles[i])):
			UnlockNoticeBadge.attach(node,"신규")
			node.tooltip_text += " · 새로 해금된 장소"
		if world.scout.scouted and not i in world.cleared and world.scout.intel.any(func(entry): return int(entry.index)==i):
			var badge = label_at(node,"정찰",Vector2(78,0),Vector2(40,20),10)
			badge.add_theme_color_override("font_color",Color("eed998"))
			node.tooltip_text += " · 정찰 정보 확인"
		node.z_index = 4
		buttons.append(node)
	hero = image(stage,"res://assets/map/hero/necromancer-hero.png",Vector2.ZERO,Vector2(81.92,120))
	hero.z_index = 16
	hero.position = hero_position(world.position)
	dice = TextureButton.new()
	dice.ignore_texture_size = true
	dice.texture_normal = texture("res://assets/battle/dice/result-%02d.png" % world.dice_visual_face)
	dice.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	dice.size = Vector2(76,76)
	# roll_map() rotates the same die around its centre. Restoring a saved
	# rotation with Godot's default (0,0) pivot makes the painted die jump
	# relative to its saved stage-space position after location exit,
	# battlefield return, board redraw, or save/reload.
	# Establish the same pivot BEFORE assigning the restored rotation.
	dice.pivot_offset = dice.size*0.5
	dice.position = shared_dice_position()
	dice.rotation_degrees = world.dice_visual_rotation
	dice.z_index = DIE_FOREGROUND_Z
	dice.tooltip_text = "주사위 · 멈춘 자리에서 다시 누르기"
	dice.pressed.connect(on_shared_die_pressed)
	stage.add_child(dice)
	status = label_at(stage,"주사위를 굴려 길을 따라 이동하세요",Vector2(285,385),Vector2(710,38),16)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.z_index = 25
	hud = label_at(stage,"%s · %d바퀴" % [{"default":"기본 지역","winter":"겨울 지역","hell":"지옥 지역"}[world.region],world.laps],Vector2(420,16),Vector2(440,30),14)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.z_index = 25
	var restart_button = button(stage,"새 원정",Vector2(12,12),Vector2(94,30),confirm_new_run)
	restart_button.z_index = 25
	var book = TextureButton.new()
	book.ignore_texture_size = true
	book.texture_normal = texture("res://assets/map/ui/map-book-closed.png")
	book.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	book.size = Vector2(133,133)
	book.position = Vector2(13,550)
	book.z_index = 50
	book.tooltip_text = "보유 마물"
	book.pressed.connect(show_roster)
	book_button = book
	stage.add_child(book)
	add_button_effect(book)
	book_lock = BookBattleLock.new()
	book.add_child(book_lock)
	var roster_count = label_at(stage,"보유 마물 %d" % world.roster.size(),Vector2(20,684),Vector2(130,26),12)
	roster_count.z_index = 51
	deck_button = TextureButton.new()
	deck_button.ignore_texture_size = true
	deck_button.texture_normal = texture("res://assets/map/ui/map-card-deck.png")
	deck_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	deck_button.position = Vector2(1134,563)
	deck_button.size = Vector2(128,120)
	deck_button.z_index = 50
	deck_button.tooltip_text = "주사위·낙인 카드 보관함"
	deck_button.pressed.connect(func():
		if is_instance_valid(embedded_battle):
			embedded_battle.show_dice_hand()
		else:
			show_inventory("dice"))
	stage.add_child(deck_button)
	add_button_effect(deck_button)
	dice_count_label = label_at(stage,"주사위 카드 %d/5" % world.dice_cards.size(),Vector2(1120,684),Vector2(150,26),12)
	dice_count_label.z_index = 51
	map_chrome.append_array([dice,status,hud,restart_button,book,roster_count,deck_button,dice_count_label])
	map_audio = AudioSettings.new()
	map_audio.setup(stage)
	map_audio.set_modal_blocked(is_instance_valid(overlay))
	var options: Button = map_audio.get_child(0)
	options.text = ""
	options.position = Vector2(1053,133)
	options.size = Vector2(58,58)
	options.tooltip_text = "오디오 옵션"
	for state in ["normal","hover","pressed","disabled","focus"]: options.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	image(options,"res://assets/map/ui/map_audio_options.webp",Vector2.ZERO,options.size)
	add_button_effect(options)
	dice.disabled = moving
	_sync_map_chrome()
	highlight(world.position)

func hero_position(index: int) -> Vector2:
	return center(index)-Vector2(40.96,86.4)

func highlight(index: int) -> void:
	selected = index
	for i in range(buttons.size()):
		buttons[i].scale = SELECTED_TILE_SCALE if i==index else Vector2.ONE
		buttons[i].z_index = 5 if i==index else 4

func roll_move(instance_id: String = "") -> void:
	if moving or is_instance_valid(overlay): return
	if not world.pending_move.is_empty():
		await resume_map_move()
		return
	moving = true
	dice.disabled = true
	var result: Dictionary = session.prepare_map_roll(instance_id)
	if not result.get("ok",false):
		status.text = str(result.get("reason","이동 저장 실패"))
		moving = false
		dice.disabled = false
		return
	dice_count_label.text = "주사위 카드 %d/5" % world.dice_cards.size()
	status.text = "주사위를 굴리는 중…"+(" · "+str(result.label) if not str(result.label).is_empty() else "")
	# The selected contamination frame is a real collision wall for the
	# Cosmetic shared die: same rest position on map, battle, and places.
	await roll_shared_die(int(result.face))
	var previous = int(result.origin)
	for raw_index in result.path:
		var index = int(raw_index)
		hero.flip_h = center(index).x<center(previous).x
		sound("move")
		var motion = create_tween()
		motion.tween_property(hero,"position",hero_position(index),0.23)
		await motion.finished
		highlight(index)
		previous = index
	await resume_map_move()

func resume_map_move() -> void:
	if world.pending_move.is_empty(): return
	moving = true
	dice.disabled = true
	var result: Dictionary = world.pending_move.duplicate(true)
	var landed = int(result.get("landed",world.position))
	hero.position = hero_position(landed)
	highlight(landed)
	var from_hill: bool = str(result.get("source",""))=="hill"
	if not from_hill:
		dice.texture_normal = texture("res://assets/battle/dice/result-%02d.png" % int(result.face))
	status.text = ("언덕 선택 · %d칸 이동 · %s 도착" % [result.path.size(),MapState.NAMES[world.tiles[world.position]]]) if from_hill else ("주사위 %d · %d칸 이동 · %s 도착%s" % [int(result.face),result.path.size(),MapState.NAMES[world.tiles[world.position]]," · "+str(result.label) if not str(result.label).is_empty() else ""])
	if world.tiles[landed]=="warp" and landed!=world.position:
		status.text = "%d번 워프 → %d번 워프" % [landed+1,world.position+1]
		await presentation.warp(hero,hero_position(world.position))
		highlight(world.position)
	elif world.tiles[landed]=="swamp":
		status.text = "오염된 늪지대 · 보유 마물 HP -1 · HP 1 보호"
		await presentation.swamp_hit()
	if not session.complete_map_move():
		status.text = "이동 완료 저장 실패 · 주사위를 눌러 다시 저장하세요"
		moving = false
		dice.disabled = false
		return
	moving = false
	dice.disabled = false
	var type: String = world.tiles[world.position]
	if type in ["monster","rare-monster","boss"] and not world.position in world.cleared: show_tile(world.position)
	elif type in EVENT_IMAGES or type in ["gem","event"]: show_tile(world.position, true)

func select_tile(index: int) -> void:
	if moving or is_instance_valid(overlay) or not world.pending_move.is_empty(): return
	highlight(index)
	status.text = "%d번 · %s%s" % [index+1,MapState.NAMES[world.tiles[index]]," · 처치 완료" if index in world.cleared else ""]
	show_tile(index)

func modal(dim_board: bool = true) -> Control:
	var node = Control.new()
	node.size = Vector2(1280,720)
	node.z_index = 80
	stage.add_child(node)
	var backdrop = ColorRect.new()
	backdrop.color = Color("030201c4") if dim_board else Color.TRANSPARENT
	backdrop.size = node.size
	backdrop.set_meta("ui_backdrop",true)
	node.add_child(backdrop)
	overlay = node
	PanelEffects.attach(node)
	return node

func close_overlay() -> void:
	if is_instance_valid(book_button) and (not is_instance_valid(book_lock) or not book_lock.locked): book_button.texture_normal = texture("res://assets/map/ui/map-book-closed.png")
	if is_instance_valid(deck_button): deck_button.texture_normal = texture("res://assets/map/ui/map-card-deck.png")
	if is_instance_valid(overlay):
		stage.remove_child(overlay)
		overlay.queue_free()
	overlay = null

func dismiss_overlay(after: Callable = Callable()) -> void:
	var panel = overlay
	if not is_instance_valid(panel): return
	if panel.has_method("close_cards"):
		if panel.closing: return
		await panel.close_cards()
		if overlay != panel: return
	var effect = panel.get_node_or_null("PanelEffectsModule")
	if effect == null:
		close_overlay()
		if after.is_valid(): after.call()
		return
	effect.play_close(func():
		if overlay != panel: return
		close_overlay()
		if after.is_valid(): after.call())

func show_tile(index: int, actual_landing: bool = false) -> void:
	var type: String = world.tiles[index]
	# Dispatch the earliest available story before generic location actions.
	# can_enter blocks previewing other tiles and saves on an actual landing.
	if type in ["graveyard","event"] and StoryEventEntry.can_enter(session,index):
		if StoryEventEntry.begin(session,index):
			show_graveyard_child_intro(index)
			return
		status.text = session.notice
	# The first village rumor follows the resolved child story and never
	# preempts the graveyard story on the generic event tile.
	if type in ["village","event"]:
		var rumor_id: String = VillageRumorEntry.eligible_event_id(session,index)
		if not rumor_id.is_empty():
			var started_rumor: String = VillageRumorEntry.begin(session,index)
			if not started_rumor.is_empty():
				show_village_rumor_intro(index,started_rumor)
				return
			status.text = session.notice
	# Story priority: graveyard -> village rumor -> commander.
	if type in ["village","event"] and KnightCommanderEntry.can_enter(session,index):
		if KnightCommanderEntry.begin(session,index):
			show_knight_commander_intro(index)
			return
		status.text = session.notice
	# Follow the canonical event tile order; the hunter only appears
	# after the commander quest has actually been accepted.
	if type in ["unknown","event"] and MonsterHunterEntry.can_enter(session,index):
		if MonsterHunterEntry.begin(session,index):
			show_monster_hunter_intro(index)
			return
		status.text = session.notice
	# The human-involvement clue from the completed hunter story unlocks
	# a new village rumor. It cannot award the tracking quest yet.
	if type in ["village","event"] and CultistRumorEntry.can_enter(session,index):
		if CultistRumorEntry.begin(session,index):
			show_cultist_rumor_intro(index)
			return
		status.text = session.notice
	# P1-05I-5: original altar fight/pass both require explicit tracking confirmation.
	if type in ["altar","event"] and CultistAltarEntry.can_enter(session,index):
		if CultistAltarEntry.begin(session,index):
			show_cultist_altar_intro(index)
			return
		status.text = session.notice
	# P1-05J-1: the forest (or event wildcard) reveals the portal only
	# after the *completed* cultist altar story and new tracking quest.
	if type in ["forest","event"] and RitualPortalEntry.can_enter(session,index):
		if RitualPortalEntry.begin(session,index):
			show_ritual_portal_intro(index)
			return
		status.text = session.notice
	# P1-05K-1: completed portal revival unlocks a *new* first visit
	# to the world tree (or canonical wildcard event), never a boss fight.
	if type in ["unknown","event"] and MonsterKingHuntEntry.can_enter(session,index):
		if MonsterKingHuntEntry.begin(session,index):
			show_monster_king_hunt_intro(index)
			return
		status.text = session.notice
	# Only show a previously saved, unacknowledged fifth-scene result.
	if type in ["unknown","event"] and MonsterKingHuntEntry.can_resume_completion(session,index):
		show_monster_king_hunt_beat(index)
		return
	# Real event arrival only: display the first discovery card after all
	# canonical story entries/resumable results have had priority. Map tile
	# preview clicks never trigger a new event or persist a receipt.
	if type == "event" and actual_landing and index == world.position:
		# Never use a failed narrative transition as an unlock fallback.
		var blocked_by_story: bool = StoryEventEntry.can_enter(session,index) or not VillageRumorEntry.eligible_event_id(session,index).is_empty() or KnightCommanderEntry.can_enter(session,index) or MonsterHunterEntry.can_enter(session,index) or CultistRumorEntry.can_enter(session,index) or CultistAltarEntry.can_enter(session,index) or RitualPortalEntry.can_enter(session,index) or MonsterKingHuntEntry.can_enter(session,index) or MonsterKingHuntEntry.can_resume_completion(session,index)
		if blocked_by_story:
			status.text = session.notice if not session.notice.is_empty() else "기존 사건을 다시 확인하세요."
			return
		var outcome: Dictionary = session.begin_story_free_event(index)
		if not bool(outcome.get("ok",false)):
			status.text = str(outcome.get("reason","사건 저장 실패 · 다시 시도하세요"))
			return
		if str(outcome.get("type",""))=="discovery":
			show_discovery_card(str(outcome.location))
		else:
			show_routine_card()
		return
	if type=="basic": return
	if type=="home":
		show_home()
		return
	if type in ["monster","rare-monster","boss"] and not index in world.cleared:
		show_battle_deck(index)
		return
	if type=="gem":
		show_treasure(index)
		return
	if type=="warp":
		use_warp(index)
		return
	if type in EVENT_IMAGES:
		show_location(index)
		return
	var panel = modal()
	image(panel,tile_path(index),Vector2(465,160),Vector2(350,260))
	var title = label_at(panel,MapState.NAMES[type],Vector2(290,92),Vector2(700,36),24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(panel,"돌아가기",Vector2(550,574),Vector2(180,42),dismiss_overlay)

func show_first_discovery_card() -> void:
	show_discovery_card("forest")

func show_discovery_card(kind: String) -> void:
	# All 5 place discoveries use one identical single-tap dismissal UI.
	# The card appears ONLY after the new location and HOME hint are saved.
	var details: Dictionary = Discovery.details(kind)
	if details.is_empty(): return
	var panel = modal()
	var card = EventDiscoveryCard.new()
	panel.add_child(card)
	card.setup("발견",str(details.title),str(details.description),str(details.reward),
		str(details.illustration),"res://assets/map/tiles/%s.png" % kind)
	var dark_area = panel.get_child(0) as Control
	if is_instance_valid(dark_area):
		dark_area.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
				card.dismiss()
			elif event is InputEventScreenTouch and event.pressed:
				card.dismiss())
	card.closed.connect(func():
		# The saved board now carries the new tile artwork, not a mockup.
		close_overlay()
		render()
		status.text = "%s 타일 해금! 길 한 칸이 변했습니다 · 집에서 확인하세요." % MapState.NAMES[kind])

## Resuming a saved unopened routine card must not reroll the incident,
## spend the reward, or re-enter an old story after a process restart.
func resume_routine_event() -> void:
	if world.pending_reward.get("kind","")!="routine": return
	if world.pending_reward.get("phase","")=="overflow":
		show_routine_overflow()
	elif world.pending_reward.get("phase","")=="choice":
		show_routine_card()

func show_routine_card() -> void:
	var pending: Dictionary = world.pending_reward
	if pending.get("kind","")!="routine" or pending.get("phase","")!="choice": return
	var entry: Dictionary = Routine.details(str(pending.get("event_id","")))
	if entry.is_empty(): return
	var panel = modal()
	var card = RoutineCard.new()
	panel.add_child(card)
	card.setup_routine(entry,Routine.reward_image(str(pending.event_id),pending.get("offer",{})))
	card.chosen.connect(func(choice: String):
		var outcome: Dictionary = session.complete_routine_choice(choice)
		if not bool(outcome.get("ok",false)):
			card.allow_retry()
			status.text = str(outcome.get("reason","사건 결과를 저장하지 못했습니다. 다시 선택하세요."))
			return
		close_overlay()
		render()
		if bool(outcome.get("overflow",false)):
			show_routine_overflow()
		else:
			status.text = str(outcome.get("message","루틴 사건 완료")))

func show_routine_overflow() -> void:
	if world.pending_reward.get("kind","")!="routine" or world.pending_reward.get("phase","")!="overflow":
		return
	var popup = RewardOverflow.new()
	stage.add_child(popup)
	overlay = popup
	popup.resolved.connect(func(outcome: Dictionary):
		close_overlay()
		render()
		status.text = "주사위 제어 카드 획득" if bool(outcome.get("kept",false)) else "새 카드 획득을 포기했습니다.")
	popup.setup(session)

func show_roster() -> void:
	show_inventory("unit")

func show_inventory(kind: String) -> void:
	if moving or is_instance_valid(overlay) or not world.pending_move.is_empty(): return
	if kind=="dice":
		show_dice_hand()
		return
	sound("book-cards-open")
	book_button.texture_normal = texture("res://assets/map/ui/map-book-open.png")
	var panel = InventoryPanel.new()
	stage.add_child(panel)
	overlay = panel
	panel.setup(session,kind,book_button.get_global_transform_with_canvas()*(book_button.size*Vector2(0.9,0.5)))
	panel.closed.connect(dismiss_overlay)

func show_treasure(index: int = -1) -> void:
	if not session.open_treasure(index):
		status.text = session.notice if not session.notice.is_empty() else "보상 저장 실패 · 다시 시도하세요"
		return
	var panel = TreasureReward.new()
	stage.add_child(panel)
	overlay = panel
	panel.finished.connect(func():
		close_overlay()
		render()
		status.text = "보물상자 보상을 정리했습니다")
	panel.mimic_revealed.connect(func(index: int):
		close_overlay()
		status.text = "보물상자에서 미믹 출현 · 출전 마물을 선택하세요"
		show_battle_deck(index))
	panel.setup(self)

func animate_reward_to_inventory(kind: String, source: TextureButton) -> void:
	var target: TextureButton = deck_button if kind=="dice" else book_button
	var flyer = image(stage,source.texture_normal.resource_path,source.global_position,source.size)
	# Carry visual-only badges with the reward card during the flying-to-inventory animation.
	for overlay_name in ["BrandFrameOverlay","AltarUpgradeBadge"]:
		var overlay = source.get_node_or_null(overlay_name)
		if overlay is TextureRect:
			var copy: TextureRect = overlay.duplicate()
			copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
			flyer.add_child(copy)
	flyer.z_index = 220
	flyer.pivot_offset = flyer.size*0.5
	var start = flyer.position
	var end = target.position+target.size*0.5-flyer.size*0.5
	var control = start.lerp(end,0.4)+Vector2(0,-70)
	source.hide()
	var flight = create_tween()
	flight.tween_method(func(t: float):
		flyer.position = start*(1-t)*(1-t)+control*2*(1-t)*t+end*t*t
		flyer.scale = Vector2.ONE*lerpf(1.0,0.1,t)
		flyer.rotation_degrees = lerpf(source.rotation_degrees,0.0,t)
		flyer.modulate.a = minf(1.0,(1.0-t)*4.0),0.0,1.0,0.88).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await flight.finished
	flyer.queue_free()
	target.pivot_offset = target.size*0.5
	var receive = create_tween()
	receive.tween_property(target,"scale",Vector2.ONE*1.08,0.1)
	receive.tween_property(target,"scale",Vector2.ONE,0.16)
	await receive.finished

func confirm_new_run() -> void:
	if moving or is_instance_valid(overlay): return
	var panel = modal()
	var question = label_at(panel,"현재 원정을 끝내고 새로 시작하시겠습니까?",Vector2(300,280),Vector2(680,50),22)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(panel,"취소",Vector2(460,380),Vector2(150,42),close_overlay)
	button(panel,"새 원정 시작",Vector2(650,380),Vector2(180,42),func():
		var previous_world = world
		var previous_encounter: Dictionary = session.encounter.duplicate(true)
		var candidate = MapState.new(world.definitions,Time.get_ticks_usec(),world.patrol_plan)
		session.world = candidate
		session.encounter = {}
		if not session.save_world():
			session.world = previous_world
			session.encounter = previous_encounter
			status.text = session.notice
			return
		world = candidate
		close_overlay()
		if get_tree().change_scene_to_file("res://intro.tscn")!=OK: render())


func show_battle_deck(index: int, story_event_id: String = "") -> void:
	if world.roster.is_empty():
		status.text = "출전 가능한 마물이 없습니다 · 새 원정을 시작하세요."
		return
	var deck = BattleDeck.new()
	deck.z_index = 80
	stage.add_child(deck)
	overlay = deck
	deck.setup(world.roster)
	deck.rename_submitted.connect(func(instance_id: String, candidate: String):
		var result: Dictionary = session.rename_owned_unit(instance_id,candidate)
		if is_instance_valid(deck): deck.apply_rename_result(instance_id,result))
	deck.confirmed.connect(func(ids: Array):
		var started: bool = session.start_story_encounter(story_event_id,index,ids) if not story_event_id.is_empty() else session.start_encounter(index,ids)
		if started:
			open_embedded_battle()
		else:
			close_overlay()
			status.text = session.notice if not session.notice.is_empty() else "출전 편성을 확인할 수 없습니다. 다시 선택하세요.")


func open_embedded_battle(animate_lock: bool = true) -> void:
	battle_returning = false
	returning_story_event_id = str(session.encounter.get("event_id",""))
	map_music.stream_paused = true
	close_overlay()
	if is_instance_valid(book_lock): book_lock.set_locked(true,animate_lock)
	var host = Control.new()
	host.name = "CentralBattle"
	# The battle viewport stays at its original position and size; the frame surrounds it.
	host.position = Vector2(128,126)
	host.size = Vector2(1024,450)
	host.clip_contents = true
	host.z_index = 30
	stage.add_child(host)
	overlay = host
	for child in stage.get_children():
		if child is BaseButton: child.disabled = true
	dice.disabled = false
	# The deck that lives on the map, not an extra battle-local copy, opens
	# battle dice controls while the chained monster book remains locked.
	if is_instance_valid(deck_button): deck_button.disabled = false
	# Leave the ONE stage die visible above the battle viewport and frame.
	dice.show()
	map_audio.hide()
	status.hide()
	hero.hide()
	var viewport = Control.new()
	viewport.name = "BattleViewport"
	viewport.position = Vector2(22,22)
	viewport.size = Vector2(980,406)
	viewport.clip_contents = true
	host.add_child(viewport)
	var battle = Battlefield.instantiate()
	battle.embedded = true
	# Only the freshly confirmed deck triggers the black-silhouette intro.
	# Saved encounters are opened with animate_lock=false and skip it.
	battle.play_entry_summon = animate_lock
	battle.detail_parent = stage
	battle.external_dice_deck_button = deck_button
	battle.external_dice_deck_count_label = dice_count_label
	battle.external_main_dice = dice
	battle.map_owner = self
	battle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	battle.size = Vector2(1280,530)
	battle.scale = Vector2.ONE*(viewport.size.x/1280.0)
	embedded_battle = battle
	battle.finished.connect(finish_embedded_battle)
	viewport.add_child(battle)
	var frame = NinePatchRect.new()
	frame.name = "BattleFrame"
	frame.texture = texture("res://assets/map/ui/battle_frame.png")
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw_center = false
	# Keep corners at a fixed, restrained size; only the border strips stretch.
	frame.scale = Vector2.ONE*0.22
	frame.size = host.size/0.22
	frame.patch_margin_left = 170
	frame.patch_margin_right = 170
	frame.patch_margin_top = 150
	frame.patch_margin_bottom = 150
	frame.z_index = 10
	host.add_child(frame)
	host.modulate.a = 0.0
	var entry = create_tween()
	entry.tween_property(host,"modulate:a",1.0,0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# The defeated expedition is committed in the same save as the battle loss.
# An archived defeat must never resume normal map interactions.
func show_game_over(instant: bool = false) -> void:
	if is_instance_valid(game_over_screen) or world.run_result.is_empty(): return
	var footprints: Array=[]
	if is_instance_valid(embedded_battle):
		for unit in embedded_battle.rules.units:
			if unit.team!="ally" or int(unit.slot)>=4: continue
			var point: Vector2=embedded_battle.presentation_layout.geometry(unit,embedded_battle.surface_size).foot
			var global_point: Vector2=embedded_battle.get_global_transform_with_canvas()*point
			footprints.append(stage.get_global_transform_with_canvas().affine_inverse()*global_point)
	game_over_screen=GameOverScreen.new()
	stage.add_child(game_over_screen)
	game_over_screen.setup(session,dice,footprints,instant)
	if is_instance_valid(map_music): map_music.stream_paused=true
	if is_instance_valid(embedded_battle):
		embedded_battle.dice.disabled=true
		embedded_battle.set_deck_disabled(true)

func finish_embedded_battle() -> void:
	if not world.run_result.is_empty():
		show_game_over()
		return
	if battle_returning: return
	battle_returning = true
	var completed_story_event_id: String = returning_story_event_id
	returning_story_event_id = ""
	if is_instance_valid(overlay): overlay.hide()
	if is_instance_valid(book_lock):
		book_lock.set_locked(false)
		await book_lock.transition_finished
	map_music.stream_paused = false
	embedded_battle = null
	overlay = null
	battle_returning = false
	world = session.world
	render()
	status.text = session.notice
	session.notice = ""
	if world.roster.is_empty(): status.text += " · 출전 가능한 마물이 없습니다."
	if not completed_story_event_id.is_empty() and session.story_battle_result_pending(completed_story_event_id):
		show_story_battle_result(completed_story_event_id)


func sound(kind: String) -> void:
	if DisplayServer.get_name()=="headless": return
	var player = AudioStreamPlayer.new()
	player.bus = "SFX"
	var extension = "mp3" if kind in ["treasure-chest-open","book-cards-open"] else "ogg"
	player.stream = load("res://assets/battle/sfx/%s.%s" % [kind,extension])
	player.volume_db = -12
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null


func show_dice_hand() -> void:
	if moving or is_instance_valid(overlay) or not world.pending_move.is_empty(): return
	deck_button.texture_normal = texture("res://assets/map/ui/map-card-deck-open.png")
	var hand = DiceHand.new()
	stage.add_child(hand)
	overlay = hand
	hand.setup(world.dice_cards,session.dice_context())
	hand.closed.connect(dismiss_overlay)
	hand.chosen.connect(func(id: String):
		close_overlay()
		roll_move(id))

func location_scene_image(parent: Control, path: String) -> TextureRect:
	# Shared across ordinary locations AND their feature/action panels.
	# Reuse the native embedded battle's actual inner viewport and nine-patch frame.
	# Center-cover crops excess height without stretching the illustration sideways.
	var scene_art = image(parent,path,LOCATION_EVENT_SCENE_RECT.position,LOCATION_EVENT_SCENE_RECT.size)
	scene_art.name = "LocationSceneImage"
	scene_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var frame = NinePatchRect.new()
	frame.name = "LocationBattleFrame"
	frame.texture = texture("res://assets/map/ui/battle_frame.png")
	frame.position = LOCATION_EVENT_FRAME_RECT.position
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw_center = false
	frame.scale = Vector2.ONE*0.22
	frame.size = LOCATION_EVENT_FRAME_RECT.size/0.22
	frame.patch_margin_left = 170
	frame.patch_margin_right = 170
	frame.patch_margin_top = 150
	frame.patch_margin_bottom = 150
	# Frame belongs to the painting, not a top-level glass layer over
	# buttons/text built after location_scene_image().
	frame.z_index = 0
	parent.add_child(frame)
	return scene_art

func show_home(interior: bool = false) -> void:
	var panel = modal(false)
	var home_art = location_scene_image(panel,"res://assets/map/events/home-interior.jpg" if interior else "res://assets/map/events/home.jpg")
	# The home exterior opens with ink; entering the house shows interior art instantly.
	if not interior:
		InkSceneReveal.play(home_art)
	var title = label_at(panel,"우리집 · 실내" if interior else "우리집",Vector2(290,92),Vector2(700,36),24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Every newly discovered real place is displayed inside HOME.
	# Keep rows compact and away from the bottom action buttons.
	var discovery_row: int = 0
	for kind in Discovery.ORDER:
		if not session.event_flag_is_set(Discovery.unlock_flag(kind)): continue
		var y: float = 427.0 + float(discovery_row)*34.0
		var place_icon = image(panel,"res://assets/map/tiles/%s.png" % kind,Vector2(245,y),Vector2(38,34))
		place_icon.name = "HomeUnlocked_%s" % kind
		place_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		place_icon.z_index=13
		var message = label_at(panel,"%s 타일 해금 · 자동 배치" % MapState.NAMES[kind],Vector2(298,y),Vector2(430,33),16)
		message.name = "HomeUnlockText_%s" % kind
		message.add_theme_color_override("font_color",Color("ffe4ad"))
		message.add_theme_color_override("font_shadow_color",Color.BLACK)
		message.add_theme_constant_override("shadow_offset_y",2)
		message.mouse_filter=Control.MOUSE_FILTER_IGNORE
		message.z_index=13
		if session.event_flag_is_set(Discovery.home_flag(kind)):
			UnlockNoticeBadge.attach(place_icon,"NEW")
		discovery_row+=1
	location_button(panel,"나가기",TILE_EVENT_EXIT_RECT.position,TILE_EVENT_EXIT_RECT.size,exit_home,4)
	if not interior:
		location_button(panel,"들어가기",TILE_EVENT_ACTION_RECT.position,TILE_EVENT_ACTION_RECT.size,func():
			var injured = world.roster.any(func(u): return u.current_hp<u.max_hp)
			if not session.enter_home():
				status.text = session.notice
				return
			close_overlay()
			status.text = "귀환 · 모든 마물 체력 완전 회복"
			show_home(true)
			if injured: await presentation.full_heal())
	else:
		var allowed: Dictionary = session.home_action_allowed()
		var action = location_button(panel,"낙인 계승",TILE_EVENT_INHERITANCE_RECT.position,TILE_EVENT_INHERITANCE_RECT.size,show_home_inheritance,3)
		action.disabled = not allowed.ok
		var patrol = location_button(panel,"순찰경로",TILE_EVENT_PATROL_RECT.position,TILE_EVENT_PATROL_RECT.size,func():
			close_overlay()
			show_exploration_actions(MapState.HOME))
		patrol.disabled = session.place_visit_id("patrol",MapState.HOME) in world.reward_receipts
		if Discovery.ORDER.any(func(kind): return session.event_flag_is_set(Discovery.home_flag(kind))):
			UnlockNoticeBadge.attach(patrol,"NEW")
		if not allowed.ok:
			var hint = label_at(panel,str(allowed.reason),Vector2(350,665),Vector2(580,30),15)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func show_home_inheritance() -> void:
	var allowed: Dictionary = session.home_action_allowed()
	if not allowed.ok:
		status.text = allowed.reason
		return
	close_overlay()
	var panel = HomeInheritance.new()
	stage.add_child(panel)
	overlay = panel
	panel.setup(session,self)
	panel.closed.connect(func(): dismiss_overlay(func(): show_home(true)))

func show_place_actions(index: int) -> void:
	var panel = PlaceActions.new()
	stage.add_child(panel)
	overlay = panel
	panel.setup(self,index)
	# Type/action controls are initialized in setup, AFTER overlay's setter.
	# Now restore the die only for this panel's actual click-to-roll action.
	_sync_map_chrome()
	panel.closed.connect(func(): dismiss_overlay(func():
		world = session.world
		presentation.refresh()
		show_location(index)))

func show_exploration_actions(index: int) -> void:
	var panel = ExplorationActions.new()
	stage.add_child(panel)
	overlay = panel
	panel.setup(self,index)
	_sync_map_chrome()
	panel.closed.connect(func():
		highlight(world.position)
		dismiss_overlay(func():
			world = session.world
			if index==MapState.HOME: show_home(true)
			else: show_location(index)))
	panel.leave_to_map.connect(func():
		# Graveyard extraction should return to playable board in one click.
		# Rebuild visuals only; the saved corpse/receipt state is untouched.
		dismiss_overlay(func():
			world = session.world
			render()
			status.text = "공동묘지 탐색을 마치고 맵으로 돌아왔습니다."))
	panel.hill_route_chosen.connect(func(steps: int):
		close_overlay()
		move_from_hill(index,steps))

## Use the same pending-map-move animation and restore pipeline as a die,
## but do not roll or change the visible die. The RunSession already saved
## the selection, target effects and one-use receipt before animation.
func move_from_hill(index: int, steps: int) -> void:
	if moving or is_instance_valid(overlay): return
	var result: Dictionary=session.prepare_hill_move(index,steps)
	if not result.get("ok",false):
		status.text=str(result.get("reason","언덕 이동을 저장하지 못했습니다."))
		highlight(world.position)
		if world.position==index and world.pending_move.is_empty(): show_exploration_actions(index)
		return
	moving=true
	dice.disabled=true
	highlight(index)
	var previous: int=index
	for raw_index in result.path:
		var tile_index: int=int(raw_index)
		hero.flip_h=center(tile_index).x<center(previous).x
		sound("move")
		var motion=create_tween()
		motion.tween_property(hero,"position",hero_position(tile_index),0.23)
		await motion.finished
		highlight(tile_index)
		previous=tile_index
	await resume_map_move()

func location_button(parent: Control, title: String, pos: Vector2, dimensions: Vector2, callback: Callable, variant: int = 1) -> Button:
	var node = button(parent,title,pos,dimensions,callback)
	# Location actions must draw over both the source painting and its frame.
	node.z_index = 11
	var style = StyleBoxTexture.new()
	style.texture = texture("res://assets/map/ui/parchment_button_variant_%02d.png" % variant)
	style.content_margin_left = 10
	style.content_margin_right = 10
	for state in ["normal","hover","pressed","disabled","focus"]: node.add_theme_stylebox_override(state,style)
	node.add_theme_color_override("font_color",Color("3f2818"))
	node.add_theme_color_override("font_hover_color",Color("3f2818"))
	node.add_theme_color_override("font_pressed_color",Color("3f2818"))
	node.add_theme_color_override("font_disabled_color",Color("6c594680"))
	node.add_theme_font_size_override("font_size",18)
	return node

## The story presentation advances only by explicit input; no timer picks a choice.
## Each explicit button advances one durable scene; a reopened save resumes
## the last confirmed beat, and the final scene is completed only on '마치기'.
## Only automatically reopen a scene previously discovered and still unfinished.
## A first visit remains driven by show_tile() and never consumes a new event.
func resume_village_rumor_if_unfinished() -> void:
	if is_instance_valid(overlay): return
	var index: int=world.position
	# Restore an already-discovered child at the exact persisted scene, or
	# restore its selected rescue deck before a battle has started. Reload
	# alone must never discover a previously unseen child.
	if StoryEventEntry.can_enter(session,index):
		var child: Dictionary=session.get_story_event(StoryEventEntry.EVENT_ID)
		if child.status in ["seen","active"] and world.event_flags.get(StoryEventEntry.SEEN_FLAG,false)==true:
			show_graveyard_child_intro(index)
			return
	var event_id: String=VillageRumorEntry.eligible_event_id(session,index)
	if not event_id.is_empty() and session.get_story_event(event_id).status=="seen":
		if VillageRumorEntry.current_beat(session,event_id)>=0:
			show_village_rumor_beat(index,event_id)
		return
	# A reload may resume a previously seen commander, never first-trigger.
	if KnightCommanderEntry.can_enter(session,index):
		if session.get_story_event(KnightCommanderEntry.EVENT_ID).status=="seen":
			show_knight_commander_intro(index)
			return
	# On reload, show the first hunter scene only if its first discovery
	# was already saved. Never auto-start a previously unseen hunter.
	if MonsterHunterEntry.can_enter(session,index):
		if session.get_story_event(MonsterHunterEntry.EVENT_ID).status=="seen":
			show_monster_hunter_intro(index)
			return
	# A saved first cultist rumor encounter can reopen; never generate a
	# previously unseen event solely by loading the map scene.
	if CultistRumorEntry.can_enter(session,index):
		if session.get_story_event(CultistRumorEntry.EVENT_ID).status=="seen":
			show_cultist_rumor_intro(index)
			return
	# On reconnect, never create an unseen altar story. Restore saved
	# arrivals, ritual reveals, unresolved pass and acknowledged outcomes.
	if CultistAltarEntry.can_enter(session,index):
		if session.get_story_event(CultistAltarEntry.EVENT_ID).status=="seen" or session.get_story_event(CultistAltarEntry.EVENT_ID).status=="active":
			show_cultist_altar_intro(index)
			return
	# Saved portal intervention or acknowledged epilogue resumes at its tile;
	# reconnect never starts combat or concludes the quest automatically.
	if RitualPortalEntry.can_enter(session,index):
		if session.get_story_event(RitualPortalEntry.EVENT_ID).status in ["seen","active"]:
			show_ritual_portal_intro(index)
			return
	# Reload resumes an already-saved arrival, trace or revival-mode dialogue.
	# No world-tree scene begins solely by loading a save.
	if MonsterKingHuntEntry.can_enter(session,index):
		if session.get_story_event(MonsterKingHuntEntry.EVENT_ID).status=="seen":
			show_monster_king_hunt_intro(index)
			return
	if MonsterKingHuntEntry.can_resume_completion(session,index):
		show_monster_king_hunt_beat(index)

func show_village_rumor_intro(index: int, event_id: String) -> void:
	show_village_rumor_beat(index,event_id)

func show_village_rumor_beat(index: int, event_id: String) -> void:
	if index!=world.position or world.tiles[index] not in ["village","event"]: return
	if VillageRumorEntry.eligible_event_id(session,index)!=event_id: return
	var beat_index: int=VillageRumorEntry.current_beat(session,event_id)
	var beat: Dictionary=VillageRumorBeats.beat(event_id,beat_index)
	if beat.is_empty(): return
	if is_instance_valid(overlay): close_overlay()
	var panel=modal()
	var artwork=image(panel,VillageRumorEntry.SCENE_ART,Vector2(243.2,136.8),Vector2(793.6,446.4))
	if beat_index==0: InkSceneReveal.play(artwork)
	for layer in beat.layers:
		image(panel,str(layer),Vector2(243.2,136.8),Vector2(793.6,446.4))
	shared_story_frame(panel)
	var heading=label_at(panel,"사건 · 마을",Vector2(352,84),Vector2(575,42),24)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var narrative=label_at(panel,str(beat.effect),Vector2(275,533),Vector2(730,66),17)
	narrative.add_theme_color_override("font_color", Color("271a10"))
	narrative.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	narrative.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	narrative.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if not str(beat.dialogue).is_empty():
		var dialogue=label_at(panel,"%s: %s" % [str(beat.speaker),str(beat.dialogue)],Vector2(294,601),Vector2(692,50),16)
		dialogue.add_theme_color_override("font_color", Color("271a10"))
		dialogue.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		dialogue.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		dialogue.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var final_scene: bool=VillageRumorBeats.is_final(event_id,beat_index)
	if world.tiles[index]=="village":
		location_button(panel,"계속" if not final_scene else "마치기",Vector2(463,653),Vector2(171,48),func(): advance_village_rumor(index,event_id,beat_index),1)
		location_button(panel,"마을 기능",Vector2(651,653),Vector2(194,48),func(): dismiss_overlay(func():show_location(index)),4)
	else:
		location_button(panel,"계속" if not final_scene else "마치기",Vector2(651,653),Vector2(194,48),func(): advance_village_rumor(index,event_id,beat_index),1)
	location_button(panel,"돌아가기",Vector2(866,653),Vector2(171,48),func(): dismiss_overlay(render),4)

func advance_village_rumor(index: int, event_id: String, shown_beat: int) -> void:
	var finishing: bool=VillageRumorBeats.is_final(event_id,shown_beat)
	if not VillageRumorEntry.advance(session,index,event_id,shown_beat):
		status.text="마을 소문 진행 상태를 저장할 수 없습니다. 다시 시도하세요."
		return
	if finishing:
		close_overlay()
		render()
		status.text="마을 소문 사건 완료"
	else:
		show_village_rumor_beat(index,event_id)

## Preserve the P1-05C entry point while rendering the persisted
## seven-beat story. Dismissing does not mark the event complete.
func show_knight_commander_intro(index: int) -> void:
	show_knight_commander_beat(index)

func show_knight_commander_beat(index: int) -> void:
	if not KnightCommanderEntry.can_enter(session,index): return
	var beat_index: int=KnightCommanderEntry.current_beat(session)
	var beat: Dictionary=KnightCommanderBeats.beat(beat_index)
	if beat.is_empty(): return
	if is_instance_valid(overlay): close_overlay()
	var panel=modal()
	var artwork=image(panel,KnightCommanderEntry.ART,Vector2(243.2,136.8),Vector2(793.6,446.4))
	if beat_index==0: InkSceneReveal.play(artwork)
	# The frozen web uses distinct right/mirrored commander and left player
	# portrait footprints, with entrance animation only at beats 0, 2 and 3.
	var player_reply: bool = str(beat.id)=="player_reply"
	var portrait_bounds: Rect2 = CommanderPortraitMotion.source_rect(TILE_EVENT_SCENE_RECT,player_reply)
	var portrait = image(panel,str(beat.portrait),portrait_bounds.position,portrait_bounds.size)
	portrait.name = "PlayerStoryPortrait" if player_reply else "CommanderStoryPortrait"
	CommanderPortraitMotion.play(portrait,player_reply,beat.id in ["arrival","recognition","player_reply"])
	shared_story_frame(panel)
	var heading=label_at(panel,"사건 · 기사단장",Vector2(348,84),Vector2(584,42),24)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var narrative=label_at(panel,str(beat.effect),Vector2(285,530),Vector2(710,63),17)
	narrative.add_theme_color_override("font_color", Color("271a10"))
	narrative.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	narrative.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	narrative.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var speech=label_at(panel,"%s: %s" % [str(beat.speaker),str(beat.dialogue)],Vector2(288,598),Vector2(704,49),16)
	speech.add_theme_color_override("font_color", Color("271a10"))
	speech.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	speech.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var finishing: bool=KnightCommanderBeats.is_final(beat_index)
	if world.tiles[index]=="village":
		location_button(panel,"계속" if not finishing else "마치기",Vector2(463,653),Vector2(171,48),func(): advance_knight_commander(index,beat_index),1)
		location_button(panel,"마을 기능",Vector2(651,653),Vector2(194,48),func(): dismiss_overlay(func():show_location(index)),4)
	else:
		location_button(panel,"계속" if not finishing else "마치기",Vector2(651,653),Vector2(194,48),func(): advance_knight_commander(index,beat_index),1)
	location_button(panel,"돌아가기",Vector2(866,653),Vector2(171,48),func(): dismiss_overlay(render),4)

func advance_knight_commander(index: int, shown_beat: int) -> void:
	var finishing: bool=KnightCommanderBeats.is_final(shown_beat)
	if not KnightCommanderEntry.advance(session,index,shown_beat):
		status.text="기사단장 사건 진행 저장 실패 · 다시 시도하세요."
		return
	if finishing:
		close_overlay()
		render()
		status.text="[오염에 대한 의뢰를 받았습니다.]"
	else:
		show_knight_commander_beat(index)

## P1-05F: retains the first-intro API; renders every saved hunter beat.
## Leaving the panel never consumes the encounter or the investigation quest.
func show_monster_hunter_intro(index: int) -> void:
	show_monster_hunter_beat(index)

func show_monster_hunter_beat(index: int) -> void:
	if not MonsterHunterEntry.can_enter(session,index): return
	var beat_index: int=MonsterHunterEntry.current_beat(session)
	var beat: Dictionary=MonsterHunterBeats.beat(beat_index)
	if beat.is_empty(): return
	if is_instance_valid(overlay): close_overlay()
	var panel=modal()
	var art=image(panel,MonsterHunterEntry.BASE_ART,Vector2(243.2,136.8),Vector2(793.6,446.4))
	if beat_index==0: InkSceneReveal.play(art)
	var visual: String=str(beat.visual)
	var visual_art: String=MonsterHunterBeats.visual_art(visual)
	if not visual_art.is_empty():
		var is_player: bool=visual=="player"
		var is_hunter_portrait: bool=visual=="portrait"
		var art_rect: Rect2=CommanderPortraitMotion.source_rect(TILE_EVENT_SCENE_RECT,true) if is_player else MonsterHunterLayerMotion.source_rect(TILE_EVENT_SCENE_RECT,is_hunter_portrait)
		var story_layer=image(panel,visual_art,art_rect.position,art_rect.size)
		story_layer.name="HunterPlayerPortrait" if is_player else ("HunterPortrait" if is_hunter_portrait else "HunterSceneLayer")
		if is_player:
			# Existing Stage V source player-enter: 0.48s from -7%/+2%.
			CommanderPortraitMotion.play(story_layer,true,beat.id=="player_reply")
		else:
			# Original web: only warning_reveal/unnatural/clue scenes and
			# identify/sent_by_commander portraits animate on reappearance.
			var animated: bool=beat.id in (["identify","sent_by_commander"] if is_hunter_portrait else ["warning_reveal","unnatural","clue"])
			MonsterHunterLayerMotion.play(story_layer,is_hunter_portrait,animated)
	shared_story_frame(panel)
	var heading=label_at(panel,"사건 · 세계수",Vector2(350,84),Vector2(582,42),24)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var effect=label_at(panel,str(beat.effect),Vector2(286,541),Vector2(708,58),17)
	effect.add_theme_color_override("font_color", Color("271a10"))
	effect.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if not str(beat.dialogue).is_empty():
		var speech=label_at(panel,"%s: %s" % [str(beat.speaker),str(beat.dialogue)],Vector2(291,604),Vector2(698,47),16)
		speech.add_theme_color_override("font_color", Color("271a10"))
		speech.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		speech.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var finishing: bool=MonsterHunterBeats.is_final(beat_index)
	if world.tiles[index]=="unknown":
		location_button(panel,"계속" if not finishing else "마치기",Vector2(463,653),Vector2(171,48),func(): advance_monster_hunter(index,beat_index),1)
		location_button(panel,"세계수 기능",Vector2(651,653),Vector2(194,48),func(): dismiss_overlay(func():show_location(index)),4)
	else:
		location_button(panel,"계속" if not finishing else "마치기",Vector2(651,653),Vector2(194,48),func(): advance_monster_hunter(index,beat_index),1)
	location_button(panel,"돌아가기",Vector2(866,653),Vector2(171,48),func(): dismiss_overlay(render),4)

func advance_monster_hunter(index: int, shown_beat: int) -> void:
	var finishing: bool=MonsterHunterBeats.is_final(shown_beat)
	if not MonsterHunterEntry.advance(session,index,shown_beat):
		status.text="마물 사냥꾼 사건 진행 저장 실패 · 다시 시도하세요."
		return
	if finishing:
		close_overlay()
		render()
		status.text="[오염을 퍼뜨리는 자들에 대한 단서를 얻었습니다.]"
	else:
		show_monster_hunter_beat(index)

## P1-05H: current scene is reconstructed from the saved sequential beat flags.
## Dismissing does not consume the event or its tracking reward.
func show_cultist_rumor_intro(index: int) -> void:
	show_cultist_rumor_beat(index)

func show_cultist_rumor_beat(index: int) -> void:
	if not CultistRumorEntry.can_enter(session,index): return
	var beat_index: int=CultistRumorEntry.current_beat(session)
	var beat: Dictionary=CultistRumorBeats.beat(beat_index)
	if beat.is_empty(): return
	if is_instance_valid(overlay): close_overlay()
	var panel=modal()
	var art=image(panel,CultistRumorEntry.BASE_ART,Vector2(243.2,136.8),Vector2(793.6,446.4))
	if beat_index==0: InkSceneReveal.play(art)
	var layer: String=CultistRumorBeats.layer_for(str(beat.visual))
	if not layer.is_empty():
		var bounds: Rect2=CultistStoryLayerMotion.source_rect(TILE_EVENT_SCENE_RECT,false)
		var procession=image(panel,layer,bounds.position,bounds.size)
		procession.name="CultistProcessionLayer"
		CultistStoryLayerMotion.play(procession,false,beat.id=="procession")
	shared_story_frame(panel)
	var heading=label_at(panel,"사건 · 같은 문양",Vector2(350,84),Vector2(582,42),24)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var effect=label_at(panel,str(beat.effect),Vector2(286,541),Vector2(708,58),17)
	effect.add_theme_color_override("font_color", Color("271a10"))
	effect.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if not str(beat.dialogue).is_empty():
		var dialogue=label_at(panel,"%s: %s" % [str(beat.speaker),str(beat.dialogue)],Vector2(291,604),Vector2(698,47),16)
		dialogue.add_theme_color_override("font_color", Color("271a10"))
		dialogue.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		dialogue.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		dialogue.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var finishing: bool=CultistRumorBeats.is_final(beat_index)
	if world.tiles[index]=="village":
		location_button(panel,"계속" if not finishing else "마치기",Vector2(463,653),Vector2(171,48),func(): advance_cultist_rumor(index,beat_index),1)
		location_button(panel,"마을 기능",Vector2(651,653),Vector2(194,48),func(): dismiss_overlay(func():show_location(index)),4)
	else:
		location_button(panel,"계속" if not finishing else "마치기",Vector2(651,653),Vector2(194,48),func(): advance_cultist_rumor(index,beat_index),1)
	location_button(panel,"돌아가기",Vector2(866,653),Vector2(171,48),func(): dismiss_overlay(render),4)

func advance_cultist_rumor(index: int, shown_beat: int) -> void:
	var finishing: bool=CultistRumorBeats.is_final(shown_beat)
	if not CultistRumorEntry.advance(session,index,shown_beat):
		status.text="광신도 소문 저장 실패 · 다시 시도하세요."
		return
	if finishing:
		close_overlay()
		render()
		status.text="[광신도들의 흔적을 추적합니다.]"
	else:
		show_cultist_rumor_beat(index)

## P1-05I-5: selected fight, pass follow-up and deliberate tracking completion.
## P1-05J-1: original first portal scene only. Reopening a saved arrival
## is read-only; do not enable energy layers, final battle or revival.
## P1-05J-4: the source-canonical fourth scene reveals the king omen.
## Final intervention, combat and actual revival stay locked.
## P1-05K-1: original king-hunt first world-tree scene only.
## The hunter's portrait, later clues and final king fight remain locked.
## P1-05K-2: first arrival → saved corrupted beast + hunter reveal.
## No revival-mode speech, location clues or final fight in this stage.
func show_monster_king_hunt_intro(index: int) -> void:
	show_monster_king_hunt_beat(index)

func show_monster_king_hunt_beat(index: int) -> void:
	if not MonsterKingHuntEntry.can_enter(session,index) and not MonsterKingHuntEntry.can_resume_completion(session,index): return
	var beat_index: int=MonsterKingHuntEntry.current_beat(session)
	var beat: Dictionary=MonsterKingHuntBeats.beat(beat_index,MonsterKingHuntEntry.revival_mode(session))
	if beat.is_empty(): return
	if is_instance_valid(overlay): close_overlay()
	var panel=modal()
	var art=image(panel,MonsterKingHuntEntry.BASE_ART,Vector2(243.2,136.8),Vector2(793.6,446.4))
	if beat_index==0: InkSceneReveal.play(art)
	# Frozen web reuses the already ported hunter scene and hunter portrait
	# layer CSS, but only trace and revival play their source animations.
	var visual: String=str(beat.visual)
	var layer_path: String=MonsterKingHuntBeats.visual_art(visual)
	if not layer_path.is_empty():
		var is_portrait: bool=visual=="portrait"
		var bounds: Rect2=MonsterHunterLayerMotion.source_rect(TILE_EVENT_SCENE_RECT,is_portrait)
		var hunt_layer=image(panel,layer_path,bounds.position,bounds.size)
		hunt_layer.name="KingHuntPortrait" if is_portrait else "KingHuntSceneLayer"
		MonsterHunterLayerMotion.play(hunt_layer,is_portrait,beat.id==("revival" if is_portrait else "trace"))
	shared_story_frame(panel)
	var heading=label_at(panel,"사건 · 왕의 흔적",Vector2(350,84),Vector2(582,42),24)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var effect=label_at(panel,str(beat.effect),Vector2(285,548),Vector2(710,61),18)
	effect.add_theme_color_override("font_color", Color("271a10"))
	effect.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if not str(beat.dialogue).is_empty():
		var speech=label_at(panel,"%s: %s" % [str(beat.speaker),str(beat.dialogue)],Vector2(285,616),Vector2(710,34),16)
		speech.add_theme_color_override("font_color", Color("271a10"))
		speech.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		speech.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	# Explicitly confirm the fifth original beat before committing quest flags.
	if beat_index<4:
		location_button(panel,"계속",Vector2(463,653) if world.tiles[index]=="unknown" else Vector2(651,653),Vector2(171,48),func(): advance_monster_king_hunt(index,beat_index),1)
	elif beat_index==4:
		location_button(panel,"마치기",Vector2(463,653) if world.tiles[index]=="unknown" else Vector2(651,653),Vector2(171,48),func(): acknowledge_monster_king_hunt(index),1)
	if world.tiles[index]=="unknown":
		location_button(panel,"세계수 기능",Vector2(651,653),Vector2(194,48),func(): dismiss_overlay(func():show_location(index)),4)
	location_button(panel,"돌아가기",Vector2(866,653),Vector2(171,48),func(): dismiss_overlay(render),4)

func advance_monster_king_hunt(index: int, shown_beat: int) -> void:
	var saved: bool=MonsterKingHuntEntry.finish(session,index) if shown_beat==3 else MonsterKingHuntEntry.advance(session,index,shown_beat)
	if not saved:
		status.text="마물의 왕 추적 장면 저장 실패 · 다시 시도하세요."
		return
	show_monster_king_hunt_beat(index)

func acknowledge_monster_king_hunt(index: int) -> void:
	if not MonsterKingHuntEntry.acknowledge_completion(session,index):
		status.text="봉인 폐허 확인 저장 실패 · 다시 시도하세요."
		return
	close_overlay()
	if world.tiles[index]=="unknown": show_location(index)
	else: render()

func show_ritual_portal_intro(index: int) -> void:
	if RitualPortalEntry.aftermath_ready(session,index):
		show_ritual_portal_aftermath(index)
	else:
		show_ritual_portal_beat(index)

func show_ritual_portal_beat(index: int) -> void:
	if RitualPortalEntry.aftermath_ready(session,index):
		show_ritual_portal_aftermath(index)
		return
	if not RitualPortalEntry.can_enter(session,index): return
	var beat_index: int=RitualPortalEntry.current_beat(session)
	var beat: Dictionary=RitualPortalBeats.beat(beat_index)
	if beat.is_empty(): return
	var scene_state: Dictionary=session.get_story_event(RitualPortalEntry.EVENT_ID)
	var intervening: bool=scene_state.status=="active" and scene_state.choice=="intervene"
	if is_instance_valid(overlay): close_overlay()
	var panel=modal()
	var art=image(panel,RitualPortalEntry.BASE_ART,Vector2(243.2,136.8),Vector2(793.6,446.4))
	if beat_index==0: InkSceneReveal.play(art)
	var visual: String=str(beat.visual)
	var layer_path: String=RitualPortalBeats.layer_for(visual)
	if not layer_path.is_empty():
		var bounds: Rect2=RitualPortalLayerMotion.source_rect(TILE_EVENT_SCENE_RECT)
		var ritual_art=image(panel,layer_path,bounds.position,bounds.size)
		ritual_art.name="PortalEnergyLayer" if visual=="energy" else ("PortalCultistsLayer" if visual=="cultists" else "PortalOmenLayer")
		# Frozen web JS animates portal_reveal and omen; its crossing ID
		# is absent from the canonical five beats, so cultists stay still.
		RitualPortalLayerMotion.play(ritual_art,beat.id in ["portal_reveal","omen"])
	shared_story_frame(panel)
	var heading=label_at(panel,"사건 · 마물의 왕 부활 의식",Vector2(350,84),Vector2(582,42),24)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var narration: String=RitualPortalBeats.INTERVENTION_EFFECT if intervening and scene_state.battle_result=="" else str(beat.effect)
	var effect=label_at(panel,narration,Vector2(285,558),Vector2(710,59),18)
	effect.add_theme_color_override("font_color", Color("271a10"))
	effect.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if not str(beat.dialogue).is_empty() and not intervening:
		var dialogue=label_at(panel,"%s: %s" % [beat.speaker,beat.dialogue],Vector2(285,619),Vector2(710,29),16)
		dialogue.add_theme_color_override("font_color", Color("271a10"))
		dialogue.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		dialogue.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if beat_index<4:
		location_button(panel,"계속",Vector2(463,653) if world.tiles[index]=="forest" else Vector2(651,653),Vector2(171,48),func(): advance_ritual_portal(index,beat_index),1)
	elif scene_state.status=="seen" and beat.get("battleReady",false)==true:
		location_button(panel,"저지한다",Vector2(455,653),Vector2(183,48),func(): choose_ritual_portal_intervention(index,beat_index),1)
	elif intervening and scene_state.battle_result=="":
		if not world.roster.is_empty():
			location_button(panel,"출전 마물 선택",Vector2(455,653),Vector2(183,48),func(): show_story_battle_deck(RitualPortalEntry.EVENT_ID,index),1)
	elif intervening:
		var saved=label_at(panel,"전투 승패 기록 저장됨 · 부활 결과는 다음 장면에서 확정됩니다.",Vector2(285,619),Vector2(710,32),16)
		saved.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if world.tiles[index]=="forest":
		location_button(panel,"숲 기능",Vector2(651,653),Vector2(194,48),func(): dismiss_overlay(func():show_location(index)),4)
	location_button(panel,"돌아가기",Vector2(866,653),Vector2(171,48),func(): dismiss_overlay(render),4)

func advance_ritual_portal(index: int, shown_beat: int) -> void:
	if not RitualPortalEntry.advance(session,index,shown_beat):
		status.text="전이문 장면 저장 실패 · 다시 시도하세요."
		return
	show_ritual_portal_beat(index)

func choose_ritual_portal_intervention(index: int, shown_beat: int) -> void:
	if not RitualPortalEntry.choose_intervention(session,index,shown_beat):
		status.text="전이문 저지 선언 저장 실패 · 다시 시도하세요."
		return
	show_ritual_portal_beat(index)
	# The omen remains visible briefly before the existing 1–4 owned-unit
	# deck selector appears. Reconnecting never auto-starts a combat.
	var declaration_overlay=overlay
	await get_tree().create_timer(0.76).timeout
	if is_instance_valid(declaration_overlay) and overlay==declaration_overlay and RitualPortalEntry.can_enter(session,index):
		if session.get_story_event(RitualPortalEntry.EVENT_ID).choice=="intervene":
			show_story_battle_deck(RitualPortalEntry.EVENT_ID,index)

## After a real fight has been acknowledged, replay this canonical
## outcome on reconnect. Completing the portal needs an explicit Finish press.
func show_ritual_portal_aftermath(index: int) -> void:
	if not RitualPortalEntry.aftermath_ready(session,index): return
	var result: String=str(session.get_story_event(RitualPortalEntry.EVENT_ID).battle_result)
	var beat: Dictionary=RitualPortalBeats.aftermath(result)
	if beat.is_empty(): return
	if is_instance_valid(overlay): close_overlay()
	var panel=modal()
	var art=image(panel,RitualPortalEntry.BASE_ART,Vector2(243.2,136.8),Vector2(793.6,446.4))
	InkSceneReveal.play(art)
	var bounds: Rect2=RitualPortalLayerMotion.source_rect(TILE_EVENT_SCENE_RECT)
	var omen=image(panel,RitualPortalBeats.OMEN_ART,bounds.position,bounds.size)
	omen.name="PortalOmenLayer"
	RitualPortalLayerMotion.play(omen,false)
	shared_story_frame(panel)
	var heading=label_at(panel,"사건 · 마물의 왕 부활 의식",Vector2(350,84),Vector2(582,42),24)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var effect=label_at(panel,str(beat.effect),Vector2(285,548),Vector2(710,65),17)
	effect.add_theme_color_override("font_color", Color("271a10"))
	effect.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var speech=label_at(panel,"%s: %s" % [beat.speaker,beat.dialogue],Vector2(285,619),Vector2(710,34),16)
	speech.add_theme_color_override("font_color", Color("271a10"))
	speech.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	speech.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	location_button(panel,"마치기",Vector2(463,653),Vector2(171,48),func(): finish_ritual_portal(index),1)
	if world.tiles[index]=="forest":
		location_button(panel,"숲 기능",Vector2(651,653),Vector2(194,48),func(): dismiss_overlay(func():show_location(index)),4)
	location_button(panel,"돌아가기",Vector2(866,653),Vector2(171,48),func(): dismiss_overlay(render),4)

func finish_ritual_portal(index: int) -> void:
	if not RitualPortalEntry.finish(session,index):
		status.text="마물의 왕 부활 결과 저장 실패 · 다시 시도하세요."
		return
	close_overlay()
	if world.tiles[index]=="forest":
		show_location(index)
	else:
		render()
	status.text="전이문 의식 종료 · 마물의 왕 추적 시작"

func show_cultist_altar_intro(index: int) -> void:
	if CultistAltarEntry.followup_ready(session,index):
		show_cultist_altar_followup(index)
	else:
		show_cultist_altar_beat(index)

func show_cultist_altar_beat(index: int) -> void:
	if CultistAltarEntry.followup_ready(session,index):
		show_cultist_altar_followup(index)
		return
	if not CultistAltarEntry.can_enter(session,index): return
	var beat_index: int=CultistAltarEntry.current_beat(session)
	var beat: Dictionary=CultistAltarBeats.beat(beat_index)
	if beat.is_empty(): return
	var altar_state: Dictionary=session.get_story_event(CultistAltarEntry.EVENT_ID)
	var fighting: bool=altar_state.status=="active" and altar_state.choice=="fight"
	if is_instance_valid(overlay): close_overlay()
	var panel=modal()
	var artwork=image(panel,CultistAltarEntry.BASE_ART,Vector2(243.2,136.8),Vector2(793.6,446.4))
	if beat_index==0: InkSceneReveal.play(artwork)
	var layer_path: String=CultistAltarBeats.SUMMON if fighting else CultistAltarBeats.layer_for(str(beat.visual))
	if not layer_path.is_empty():
		var bounds: Rect2=CultistStoryLayerMotion.source_rect(TILE_EVENT_SCENE_RECT,true)
		var ritual_art=image(panel,layer_path,bounds.position,bounds.size)
		ritual_art.name="CultistSummonLayer" if fighting else "CultistRitualLayer"
		CultistStoryLayerMotion.play(ritual_art,true,beat.id=="ritual_reveal" or (fighting and altar_state.battle_result==""))
	shared_story_frame(panel)
	var heading=label_at(panel,"사건 · 광신도의 의식",Vector2(350,84),Vector2(582,42),24)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var narration: String=CultistAltarBeats.SUMMON_EFFECT if fighting else str(beat.effect)
	var effect=label_at(panel,narration,Vector2(285,573),Vector2(710,64),18)
	effect.add_theme_color_override("font_color", Color("271a10"))
	effect.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if beat_index<2:
		if world.tiles[index]=="altar":
			location_button(panel,"계속",Vector2(463,653),Vector2(171,48),func(): advance_cultist_altar(index,beat_index),1)
		else:
			location_button(panel,"계속",Vector2(651,653),Vector2(194,48),func(): advance_cultist_altar(index,beat_index),1)
	elif altar_state.status=="seen" and beat.get("choice",false)==true:
		location_button(panel,"싸운다",Vector2(320,653),Vector2(164,48),func(): choose_cultist_altar(index,beat_index,"fight"),1)
		location_button(panel,"지나간다",Vector2(504,653),Vector2(164,48),func(): choose_cultist_altar(index,beat_index,"pass"),1)
	elif fighting:
		if altar_state.battle_result=="won":
			var won_note=label_at(panel,"소환 마물 격퇴 기록 저장됨 · 후속 사건 연결 대기",Vector2(315,613),Vector2(715,33),16)
			won_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		elif altar_state.battle_result=="lost":
			var lost_note=label_at(panel,"전투 패배 기록 저장됨 · 남은 마물로 재도전 가능",Vector2(315,613),Vector2(715,33),16)
			lost_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if altar_state.battle_result!="won" and not world.roster.is_empty():
			location_button(panel,"출전 마물 선택",Vector2(319,653),Vector2(225,48),func(): show_story_battle_deck(CultistAltarEntry.EVENT_ID,index),1)
		if altar_state.battle_result=="":
			location_button(panel,"선택 변경",Vector2(557,653),Vector2(126,48),func(): reconsider_cultist_altar(index),4)
	elif altar_state.status=="active":
		var receipt=label_at(panel,"‘지나간다’ 선택 저장됨 · 후속 처리는 다음 단계에서 연결됩니다.",Vector2(300,613),Vector2(730,35),16)
		receipt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		location_button(panel,"선택 변경",Vector2(463,653),Vector2(171,48),func(): reconsider_cultist_altar(index),1)
	if world.tiles[index]=="altar":
		location_button(panel,"제단 기능",Vector2(692,653),Vector2(153,48),func(): dismiss_overlay(func():show_location(index)),4)
	location_button(panel,"돌아가기",Vector2(866,653),Vector2(171,48),func(): dismiss_overlay(render),4)

## Original final narration is shown only after a pass was saved or a battle
## result was acknowledged. Closing/reloading never consumes the quest handoff.
func show_cultist_altar_followup(index: int) -> void:
	if not CultistAltarEntry.followup_ready(session,index): return
	var story: Dictionary=session.get_story_event(CultistAltarEntry.EVENT_ID)
	var narration: String=CultistAltarBeats.followup_effect(str(story.choice),str(story.battle_result))
	if narration.is_empty(): return
	if is_instance_valid(overlay): close_overlay()
	var panel=modal()
	var art=image(panel,CultistAltarEntry.BASE_ART,Vector2(243.2,136.8),Vector2(793.6,446.4))
	InkSceneReveal.play(art)
	var overlay_path: String=CultistAltarBeats.RITUAL if story.choice=="pass" else CultistAltarBeats.SUMMON
	var bounds: Rect2=CultistStoryLayerMotion.source_rect(TILE_EVENT_SCENE_RECT,true)
	var overlay_layer=image(panel,overlay_path,bounds.position,bounds.size)
	overlay_layer.name="CultistRitualLayer" if story.choice=="pass" else "CultistSummonLayer"
	CultistStoryLayerMotion.play(overlay_layer,true,false)
	shared_story_frame(panel)
	var heading=label_at(panel,"사건 · 광신도의 의식",Vector2(350,84),Vector2(582,42),24)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var effect=label_at(panel,narration,Vector2(285,548),Vector2(710,62),17)
	effect.add_theme_color_override("font_color", Color("271a10"))
	effect.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var speech=label_at(panel,"%s: %s" % [CultistAltarBeats.FOLLOWUP_SPEAKER,CultistAltarBeats.FOLLOWUP_DIALOGUE],Vector2(285,610),Vector2(710,34),16)
	speech.add_theme_color_override("font_color", Color("271a10"))
	speech.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	speech.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if story.choice=="pass":
		location_button(panel,"선택 변경",Vector2(320,653),Vector2(164,48),func(): reconsider_cultist_altar(index),4)
		location_button(panel,"마치기",Vector2(504,653),Vector2(164,48),func(): finish_cultist_altar(index),1)
	else:
		location_button(panel,"마치기",Vector2(463,653),Vector2(171,48),func(): finish_cultist_altar(index),1)
	if world.tiles[index]=="altar":
		location_button(panel,"제단 기능",Vector2(692,653),Vector2(153,48),func(): dismiss_overlay(func():show_location(index)),4)
	location_button(panel,"돌아가기",Vector2(866,653),Vector2(171,48),func(): dismiss_overlay(render),4)

func finish_cultist_altar(index: int) -> void:
	if not CultistAltarEntry.finish(session,index):
		status.text="광신도 제단 추적 기록 저장 실패 · 다시 시도하세요."
		return
	close_overlay()
	if world.tiles[index]=="altar":
		show_location(index)
	else:
		render()
	status.text="광신도의 의식 확인 · 마물의 왕 부활 의식의 흔적 추적 시작"

func advance_cultist_altar(index: int, shown_beat: int) -> void:
	if not CultistAltarEntry.advance(session,index,shown_beat):
		status.text="광신도 제단 장면 저장 실패 · 다시 시도하세요."
		return
	show_cultist_altar_beat(index)

func choose_cultist_altar(index: int, shown_beat: int, decision: String) -> void:
	if not CultistAltarEntry.choose(session,index,shown_beat,decision):
		status.text="광신도 제단 선택 저장 실패 · 다시 시도하세요."
		return
	show_cultist_altar_beat(index)
	if decision=="fight":
		# Show the original summoned-monsters layer before deck selection.
		# Reconnecting opens the same saved summon scene, not an automatic fight.
		var choice_overlay=overlay
		await get_tree().create_timer(0.76).timeout
		if is_instance_valid(choice_overlay) and overlay==choice_overlay and CultistAltarEntry.can_enter(session,index):
			if session.get_story_event(CultistAltarEntry.EVENT_ID).choice=="fight":
				show_story_battle_deck(CultistAltarEntry.EVENT_ID,index)

func reconsider_cultist_altar(index: int) -> void:
	if not CultistAltarEntry.reconsider(session,index):
		status.text="광신도 제단 선택 변경 실패 · 다시 시도하세요."
		return
	show_cultist_altar_beat(index)

func show_graveyard_child_intro(index: int) -> void:
	var state: Dictionary = session.get_story_event(StoryEventEntry.EVENT_ID)
	show_graveyard_child_beat(index,3 if state.status == "active" and state.choice == "protect_child" else maxi(0,StoryEventEntry.current_beat(session)))

func show_graveyard_child_beat(index: int, beat_index: int) -> void:
	if index != world.position or session.get_story_event(StoryEventEntry.EVENT_ID).status == "complete": return
	var beat: Dictionary = GraveyardStoryBeats.beat(beat_index)
	if beat.is_empty(): return
	if is_instance_valid(overlay): close_overlay()
	var panel = modal()
	var artwork = image(panel,GraveyardStoryBeats.BASE_ART,Vector2(243.2,136.8),Vector2(793.6,446.4))
	artwork.name="StorySceneImage"
	if beat_index == 0:
		InkSceneReveal.play(artwork)
		GraveyardStoryEntryMotion.play_board_drop(artwork)
	if beat.ghoul:
		# The stationary direct-child frame receives the common modal entrance.
		# Animate only its nested image to avoid competing position tweens.
		var ghoul_frame = TextureRect.new()
		ghoul_frame.name = "StoryCharacterLayer"
		ghoul_frame.position = TILE_EVENT_SCENE_RECT.position + TILE_EVENT_SCENE_RECT.size * GRAVEYARD_GHOUL_FRACTIONS.position
		ghoul_frame.size = TILE_EVENT_SCENE_RECT.size * GRAVEYARD_GHOUL_FRACTIONS.size
		ghoul_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(ghoul_frame)
		var ghoul_art = image(ghoul_frame,GraveyardStoryBeats.GHOUL_ART,Vector2.ZERO,ghoul_frame.size)
		ghoul_art.name = "GhoulSprite"
		GraveyardGhoulMotion.play(ghoul_art,beat_index == 1)
	var heading = label_at(panel,"습격받는 아이",Vector2(352,84),Vector2(575,42),24)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var state: Dictionary = session.get_story_event(StoryEventEntry.EVENT_ID)
	var chosen: bool = state.status == "active" and state.choice == "protect_child"
	var description: String = "아이를 구하기 위해 구울 앞을 막아섰다. 출전할 마물을 선택해 구울과 싸우세요." if chosen else str(beat.effect)
	var has_dialogue: bool=not str(beat.dialogue).is_empty() and not chosen
	# One visual footprint for all event parchment, even when the child
	# is silent. Only spoken beats use the legacy StoryDialogueFrame alias.
	var frame = shared_story_frame(panel)
	if has_dialogue: frame.name = "StoryDialogueFrame"
	var narration = label_at(panel,description,Vector2(275,535),Vector2(730,51),17)
	narration.name = "StoryInfoPanel"
	narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narration.add_theme_color_override("font_color",Color("271a10"))
	narration.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	if has_dialogue:
		var speaker=label_at(panel,"아이",Vector2(283,592),Vector2(113,21),16)
		speaker.name="StoryDialogueName"
		speaker.add_theme_color_override("font_color",Color("68351f"))
		speaker.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		var dialogue=label_at(panel,str(beat.dialogue),Vector2(401,596),Vector2(592,42),17)
		dialogue.name="StoryDialogueText"
		dialogue.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		dialogue.add_theme_color_override("font_color",Color("21150d"))
		dialogue.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		if not beat.choice:
			var advance_hint=label_at(panel,"▼",Vector2(1013,609),Vector2(26,24),17)
			advance_hint.name="StoryDialogueNext"
			GraveyardStoryEntryMotion.play_next_hint(advance_hint)
			advance_hint.add_theme_color_override("font_color",Color("5e4329"))
			advance_hint.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	# The original location actions remain available on graveyard tiles.
	if world.tiles[index] == "graveyard":
		location_button(panel,"공동묘지 기능",Vector2(692,653),Vector2(153,48),func(): dismiss_overlay(func(): show_location(index)),4)
	if chosen:
		location_button(panel,"출전 마물 선택",Vector2(455,653),Vector2(223,48),func(): show_graveyard_story_deck(index),1)
		location_button(panel,"돌아가기",Vector2(866,653),Vector2(171,48),func(): dismiss_overlay(render),4)
	elif beat.choice:
		location_button(panel,"아이를 구한다",Vector2(284,653),Vector2(197,48),func(): choose_graveyard_child(index,"protect_child"),1)
		location_button(panel,"지나친다",Vector2(494,653),Vector2(175,48),func(): choose_graveyard_child(index,"leave"),2)
		location_button(panel,"나가기",Vector2(866,653),Vector2(171,48),func(): dismiss_overlay(render),4)
	else:
		location_button(panel,"계속",Vector2(463,653),Vector2(171,48),func(): advance_graveyard_child_beat(index,beat_index),1)
		location_button(panel,"나가기",Vector2(866,653),Vector2(171,48),func(): dismiss_overlay(render),4)

func advance_graveyard_child_beat(index: int, shown_beat: int) -> void:
	if not StoryEventEntry.advance(session,index,shown_beat):
		status.text="공동묘지 장면 저장 실패 · 다시 시도하세요."
		return
	show_graveyard_child_beat(index,shown_beat+1)

func choose_graveyard_child(index: int, choice_id: String) -> void:
	if not StoryEventEntry.choose(session,index,choice_id):
		status.text = "사건 선택을 저장할 수 없습니다. 다시 시도하세요."
		return
	if choice_id == "leave":
		status.text = "아이를 지나쳤습니다. 공동묘지 사건이 완료되었습니다."
		dismiss_overlay(render)
	else:
		status.text = "아이를 구하기로 선택했습니다. 출전 마물 1~4마리를 고르세요."
		show_graveyard_story_deck(index)

func show_graveyard_story_deck(index: int) -> void:
	show_story_battle_deck(StoryEventEntry.EVENT_ID,index)

## Every registered event routes through the existing 1–4 card BattleDeck.
func show_story_battle_deck(event_id: String, index: int) -> void:
	var spec: Dictionary = StoryBattleRegistry.definition(event_id)
	if not StoryBattleRegistry.can_start(world,session.get_story_event(event_id),index,spec): return
	if not session.encounter.is_empty() or not world.active_encounter.is_empty(): return
	if not world.pending_move.is_empty() or not world.pending_reward.is_empty(): return
	if world.roster.is_empty(): return
	if is_instance_valid(overlay): close_overlay()
	show_battle_deck(index,event_id)

## Retained wrappers for the P1-03D screen; all outcome UI is now data-driven.
func show_graveyard_battle_result() -> void:
	show_story_battle_result(StoryEventEntry.EVENT_ID)

func show_pending_story_battle_result() -> void:
	var event_id: String = session.pending_story_battle_event_id()
	if not event_id.is_empty(): show_story_battle_result(event_id)

func show_story_battle_result(event_id: String) -> void:
	if is_instance_valid(overlay): return
	var view: Dictionary = session.story_battle_presentation(event_id)
	if view.is_empty(): return
	world = session.world
	var panel = modal()
	var art = image(panel,str(view.background),Vector2(243.2,136.8),Vector2(793.6,446.4))
	InkSceneReveal.play(art)
	if not str(view.overlay).is_empty():
		image(panel,str(view.overlay),Vector2(243.2,136.8),Vector2(793.6,446.4))
	shared_story_frame(panel)
	var heading = label_at(panel,str(view.title),Vector2(360,84),Vector2(568,42),24)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var narrative = label_at(panel,str(view.narration),Vector2(285,558),Vector2(710,62),18)
	narrative.add_theme_color_override("font_color", Color("271a10"))
	narrative.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	narrative.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narrative.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not str(view.dialogue).is_empty():
		var dialogue = label_at(panel,str(view.dialogue),Vector2(396,619),Vector2(492,26),17 if not view.retry else 16)
		dialogue.add_theme_color_override("font_color", Color("271a10"))
		dialogue.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if view.retry and not world.roster.is_empty():
		location_button(panel,"다시 도전",Vector2(637,653),Vector2(206,48),func(): acknowledge_story_battle_result_ui(event_id,true),1)
	location_button(panel,"부활 확인" if event_id==RitualPortalEntry.EVENT_ID else ("흔적 확인" if event_id==CultistAltarEntry.EVENT_ID else "맵으로"),Vector2(870,653),Vector2(165,48),func(): acknowledge_story_battle_result_ui(event_id,false),4)

func acknowledge_graveyard_result(retry: bool) -> void:
	acknowledge_story_battle_result_ui(StoryEventEntry.EVENT_ID,retry)

func acknowledge_story_battle_result_ui(event_id: String, retry: bool) -> void:
	var view: Dictionary = session.story_battle_presentation(event_id)
	if view.is_empty() or (retry and not view.retry): return
	if not session.acknowledge_story_battle_result(event_id):
		status.text = "사건 결과 저장 실패 · 다시 시도하세요."
		return
	var index: int = world.position
	close_overlay()
	if retry and not world.roster.is_empty():
		show_story_battle_deck(event_id,index)
	elif event_id==CultistAltarEntry.EVENT_ID and CultistAltarEntry.followup_ready(session,index):
		# The battle receipt is acknowledged, but story completion waits for
		# the separate original narration and explicit '마치기' press.
		show_cultist_altar_followup(index)
	elif event_id==RitualPortalEntry.EVENT_ID and RitualPortalEntry.aftermath_ready(session,index):
		# Keep the source weak/full revival epilogue separate from the result
		# acknowledgement and save every quest flag only at final Finish.
		show_ritual_portal_aftermath(index)
	else:
		render()
		status.text = session.notice
		session.notice = ""

func acknowledge_discovery_action(kind: String) -> void:
	# Called only from enabled original location actions, never from preview.
	var flag: String = "ui:unlock:%s:action_pending" % kind
	if Discovery.exists(kind) and session.event_flag_is_set(flag):
		session.set_event_flag(flag,false)

func show_location(index: int) -> void:
	var type: String = world.tiles[index]
	# Seeing a new location acknowledges the board marker; the action marker
	# remains until that newly unlocked function has really been used.
	if Discovery.exists(type) and session.event_flag_is_set("ui:unlock:%s:tile_pending" % type):
		if session.set_event_flag("ui:unlock:%s:tile_pending" % type,false):
			for button_index in range(buttons.size()):
				if world.tiles[button_index]!=type: continue
				var marker = buttons[button_index].get_node_or_null("UnlockNewBadge")
				if is_instance_valid(marker): marker.hide()
	var panel = modal(false)
	var scene_art = location_scene_image(panel,"res://assets/map/events/%s.jpg" % EVENT_IMAGES[type])
	# Reveal artwork only for all seven location tile types; keep UI unaffected.
	InkSceneReveal.play(scene_art)
	var exit = location_button(panel,"나가기",TILE_EVENT_EXIT_RECT.position,TILE_EVENT_EXIT_RECT.size,func(): dismiss_overlay(render),4)
	if type=="rest":
		var allowed = session.rest_allowed(index)
		var heal = location_button(panel,"전체 회복",TILE_EVENT_ACTION_RECT.position,TILE_EVENT_ACTION_RECT.size,func():
			var result = session.heal_at_rest(index)
			status.text = result.reason
			if not result.ok: return
			exit.disabled = true
			await presentation.full_heal()
			close_overlay()
			show_location(index))
		heal.name = "RestHealAction"
		if session.event_flag_is_set(UnlockNoticeBadge.REST_ACTION_PENDING):
			UnlockNoticeBadge.attach(heal,"NEW")
		heal.disabled = not allowed.ok
		heal.tooltip_text = "" if allowed.ok else allowed.reason
	elif type in ["village","altar","fortune-teller-camp"]:
		var names = {"village":"마물 상점","altar":"의식","fortune-teller-camp":"예언"}
		var variant = {"village":1,"altar":2,"fortune-teller-camp":4}[type]
		var action = location_button(panel,names[type],TILE_EVENT_ACTION_RECT.position,TILE_EVENT_ACTION_RECT.size,func():
			acknowledge_discovery_action(type)
			close_overlay()
			show_place_actions(index),variant)
		if Discovery.exists(type) and session.event_flag_is_set("ui:unlock:%s:action_pending" % type):
			UnlockNoticeBadge.attach(action,"NEW")
		var key = "ritual" if type=="altar" else "prophecy"
		if type!="village": action.disabled = session.place_visit_id(key,index) in world.reward_receipts
	elif type in ["unknown","graveyard","forest"]:
		var names = {"unknown":"기도","graveyard":"시체 파헤치기","forest":"이동 위치 선택"}
		var variant = {"unknown":3,"graveyard":4,"forest":2}[type]
		var action = location_button(panel,names[type],TILE_EVENT_ACTION_RECT.position,TILE_EVENT_ACTION_RECT.size,func():
			acknowledge_discovery_action(type)
			close_overlay()
			show_exploration_actions(index),variant)
		if Discovery.exists(type) and session.event_flag_is_set("ui:unlock:%s:action_pending" % type):
			UnlockNoticeBadge.attach(action,"NEW")
		if type=="unknown": action.disabled = session.place_visit_id("purify",index) in world.reward_receipts
		if type=="graveyard": action.disabled = world.graveyard_corpses.is_empty() or session.place_visit_id("grave-extract",index) in world.reward_receipts

func use_warp(index: int) -> void:
	if moving: return
	var result = session.warp_from(index)
	if not result.ok: status.text = result.reason; return
	moving = true
	dice.disabled = true
	hero.position = hero_position(index)
	status.text = "%d번 워프 → %d번 워프" % [index+1,int(result.destination)+1]
	await presentation.warp(hero,hero_position(int(result.destination)))
	highlight(world.position)
	status.text = "%d번 워프로 이동 완료" % (world.position+1)
	dice.disabled = false
	moving = false

func exit_home() -> void:
	if moving: return
	moving = true
	close_overlay()
	# Lock input, save exactly one generated lap, then gather two rings,
	# turn ONE gear tooth and visibly exchange two actual tile pairs.
	# A failed save never animates or reveals another map.
	var input_lock: Control = presentation.effect(true)
	dice.disabled = true
	var contamination_before_exit: int = world.contamination
	# Keep the pre-save identities for the visible gather/one-notch/swaps.
	var previous_tiles: Array = world.tiles.duplicate()
	var ok: bool = session.leave_home()
	world = session.world
	if ok:
		var next_tile_textures: Array = []
		for i in range(MapState.centers().size()):
			next_tile_textures.append(texture(tile_path(i)))
		var gear = MapGearShift.new()
		stage.add_child(gear)
		if gear.prepare(buttons,next_tile_textures,previous_tiles,world.tiles,world.map_serial):
			await gear.play_once(next_tile_textures)
			gear.clean_up()
		gear.queue_free()
		# Ring travel and swaps use the saved source->target manifest.
		# No post-landing flip, reroll or unrelated texture replacement.
		render()
	# On save failure, persist_change() already restored the prior map.
	input_lock.queue_free()
	moving = false
	dice.disabled = false
	if not ok:
		status.text = session.notice if not session.notice.is_empty() else "맵 교체 저장 실패 · 다시 시도하세요"
		show_home()
	else:
		status.text = "새 경로 · %d바퀴 · 오염도 %d/100" % [world.laps,world.contamination]
		if contamination_before_exit < MapState.BOSS_CONTAMINATION and world.contamination >= MapState.BOSS_CONTAMINATION:
			status.text += " · 보스 타일 출현"
