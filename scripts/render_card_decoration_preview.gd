extends SceneTree
## Capture actual Godot inventory, deck, altar, and inheritance screens via Xvfb.
## These are rendered UI screens, not newly generated art assets.
const InventoryPanel = preload("res://systems/inventory_panel.gd")
const BattleDeck = preload("res://systems/battle_deck.gd")
const PlaceActions = preload("res://systems/place_actions.gd")
const HomeInheritance = preload("res://systems/home_inheritance.gd")
const Battlefield = preload("res://battlefield.gd")
const AltarBadge = preload("res://systems/altar_upgrade_badge.gd")

class PreviewSession:
	extends RefCounted
	var world: Dictionary
	func _init() -> void:
		var owned: Array = []
		for i in range(8):
			var marks: Array = []
			for j in range(2 if i%2==0 else 3):
				marks.append({"type":"guard","bless":[1],"curse":[5]})
			owned.append({
				"id":"frame-preview-%d" % i,"slug":"skeleton-archer",
				"name":"해골 궁수","brands":marks,"altar_enhancements":3,
				"current_hp":8,"max_hp":8,"attack":2,"speed":3
			})
		world = {
			"roster":owned,"dice_cards":[],"brand_cards":[],
			"reward_receipts":[],"tiles":["altar"],
			"definitions":JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
		}
	func owned_unit(unit_id: String) -> Dictionary:
		for u in world.roster:
			if str(u.id)==unit_id: return u
		return {}
	func place_visit_id(kind: String, index: int) -> String:
		return "%s-%d" % [kind,index]
	func home_action_allowed() -> Dictionary:
		return {"ok":true}

class PreviewMap:
	extends RefCounted
	var session
	func _init(fake_session) -> void:
		session = fake_session
	# The production PlaceActions now asks its Map host to paint the shared
	# location scene. Keep this preview double in sync so the altar screenshot
	# actually contains the same artwork and frame instead of script errors.
	func location_scene_image(parent: Control, path: String) -> TextureRect:
		var scene_art := TextureRect.new()
		scene_art.name = "LocationSceneImage"
		scene_art.texture = load(path)
		scene_art.position = Vector2(150,148)
		scene_art.size = Vector2(980,406)
		scene_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		scene_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(scene_art)
		var frame := NinePatchRect.new()
		frame.name = "LocationBattleFrame"
		frame.texture = load("res://assets/map/ui/battle_frame.png")
		frame.position = Vector2(128,126)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.draw_center = false
		frame.scale = Vector2.ONE * 0.22
		frame.size = Vector2(1024,450) / 0.22
		frame.patch_margin_left = 170
		frame.patch_margin_right = 170
		frame.patch_margin_top = 150
		frame.patch_margin_bottom = 150
		parent.add_child(frame)
		return scene_art

func _initialize() -> void:
	call_deferred("_run")

func _theme() -> Theme:
	var theme = Theme.new()
	theme.default_font = load("res://assets/fonts/nanum_gothic_regular.ttf")
	theme.default_font_size = 15
	return theme

func _capture(kind: String) -> bool:
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if picture == null or picture.is_empty():
		printerr("CARD_PREVIEW_FAILED: ",kind," image unavailable")
		return false
	picture.resize(800,450,Image.INTERPOLATE_LANCZOS)
	var output: String = ProjectSettings.globalize_path("res://card_preview_%s.webp" % kind)
	var err: Error = picture.save_webp(output,false,0.77)
	if err != OK:
		printerr("CARD_PREVIEW_FAILED: ",kind," WebP save ",err)
		return false
	print("CARD_PREVIEW_SAVED: ",kind," ",output)
	return true

func _run() -> void:
	root.size = Vector2i(1280,720)
	var session = PreviewSession.new()
	var style = _theme()

	var inventory = InventoryPanel.new()
	inventory.theme = style
	root.add_child(inventory)
	inventory.setup(session)
	await create_timer(1.30).timeout
	if not await _capture("inventory"): quit(1); return
	inventory.queue_free()
	await process_frame

	var deck = BattleDeck.new()
	deck.theme = style
	root.add_child(deck)
	deck.setup(session.world.roster)
	deck.selected_ids.append(str(session.world.roster[1].id))
	deck.render_selection()
	await create_timer(1.10).timeout
	if not await _capture("deck"): quit(1); return
	deck.queue_free()
	await process_frame

	var altar = PlaceActions.new()
	altar.theme = style
	root.add_child(altar)
	altar.setup(PreviewMap.new(session),0)
	altar.donor_id = str(session.world.roster[0].id)
	altar.receiver_id = str(session.world.roster[1].id)
	altar.refresh()
	await create_timer(0.20).timeout
	if not await _capture("altar"): quit(1); return
	altar.queue_free()
	await process_frame

	var inheritance = HomeInheritance.new()
	inheritance.theme = style
	root.add_child(inheritance)
	inheritance.setup(session)
	inheritance.material_id = str(session.world.roster[0].id)
	inheritance.receiver_id = str(session.world.roster[1].id)
	inheritance.render_selection()
	await create_timer(0.20).timeout
	if not await _capture("inheritance"): quit(1); return
	inheritance.queue_free()
	await process_frame

	var battlefield = Battlefield.new()
	battlefield.theme = style
	root.add_child(battlefield)
	if battlefield.cards.is_empty() or battlefield.rules.units.is_empty():
		printerr("CARD_PREVIEW_FAILED: battlefield cards unavailable")
		quit(1)
		return
	var selected: Dictionary = battlefield.rules.units[0]
	selected.brands = [{"type":"guard","bless":[1],"curse":[5]},{"type":"critical","bless":[2],"curse":[]},{"type":"freeze","bless":[3],"curse":[]}]
	selected.altar_enhancements = 3
	var card: TextureButton = battlefield.cards[selected.id]
	AltarBadge.sync(card,selected)
	await create_timer(0.35).timeout
	if not await _capture("battle"): quit(1); return
	print("CARD_PREVIEW_ALL_SCREENS: 5 rendered")
	quit(0)
