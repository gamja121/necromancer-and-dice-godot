extends SceneTree
## Integration smoke test with actual inventory, deck, altar and inheritance card factories.
## Checks stacking and state without touching player saves or changing game rules.

const RewardUI = preload("res://systems/reward_ui.gd")
const InventoryPanel = preload("res://systems/inventory_panel.gd")
const BattleDeck = preload("res://systems/battle_deck.gd")
const PlaceActions = preload("res://systems/place_actions.gd")
const HomeInheritance = preload("res://systems/home_inheritance.gd")
const BrandFrame = preload("res://systems/brand_frame_overlay.gd")
const AltarBadge = preload("res://systems/altar_upgrade_badge.gd")

class FakeSession:
	extends RefCounted
	var world: Dictionary
	func _init(units: Array) -> void:
		world = {"roster":units,"dice_cards":[],"brand_cards":[],"reward_receipts":[]}
	func owned_unit(unit_id: String) -> Dictionary:
		for u in world.roster:
			if str(u.id) == unit_id: return u
		return {}
	func place_visit_id(kind: String, idx: int) -> String:
		return "%s-%d" % [kind,idx]

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS card-screen: ",label)
	else:
		failed += 1
		printerr("FAIL card-screen: ",label)

func unit(idx: int, brand_count: int = 3, altar_level: int = 3) -> Dictionary:
	var marks: Array = []
	for j in range(brand_count): marks.append({"type":"guard","bless":[1],"curse":[5]})
	return {"id":"ui-test-%d"%idx,"slug":"skeleton-archer","name":"해골 궁수","brands":marks,"altar_enhancements":altar_level,"current_hp":8,"max_hp":8,"attack":2,"speed":3}

func assert_decorations(card: Control, prefix: String, frame_expected: bool = true, badge_expected: bool = true) -> void:
	if card == null:
		check(false,prefix+" card exists")
		return
	var frame: TextureRect = card.get_node_or_null("BrandFrameOverlay") as TextureRect
	var badge: TextureRect = card.get_node_or_null("AltarUpgradeBadge") as TextureRect
	check((frame != null)==frame_expected,prefix+" brand frame present as expected")
	check((badge != null)==badge_expected,prefix+" altar plaque present as expected")
	if frame != null and badge != null:
		check(frame.get_parent()==card and badge.get_parent()==card,prefix+" overlays belong to card")
		check(frame.z_index==0 and badge.z_index==0 and frame.z_as_relative and badge.z_as_relative,prefix+" overlays respect card stacking")
		check(frame.mouse_filter==Control.MOUSE_FILTER_IGNORE and badge.mouse_filter==Control.MOUSE_FILTER_IGNORE,prefix+" decoration never intercepts clicks")
		check(frame.texture == BrandFrame.IRON_FRAME and badge.texture == AltarBadge.BADGE_3,prefix+" iron+3 graphic selection")
		var art: Rect2 = AltarBadge._art_rect(card)
		check(absf((badge.position.x+badge.size.x*0.5)-(art.position.x+art.size.x*0.5)) < 0.04,prefix+" plaque center")
		var old: Vector2 = badge.get_global_transform_with_canvas().origin
		card.rotation_degrees += 4.0
		card.scale = Vector2(1.06,1.06)
		var updated: Vector2 = badge.get_global_transform_with_canvas().origin
		check(updated.distance_to(old)>0.1,prefix+" plaque follows card rotation and scale")

func _run() -> void:
	# 1: actual shared UI card builder (reward, graveyard, shop, overflow).
	var reward = RewardUI.new()
	root.add_child(reward)
	var item := unit(0)
	var first := reward.card(reward,"unit",item,Vector2(120,90),Vector2(136,218),Callable())
	var second := reward.card(reward,"unit",unit(1),Vector2(190,90),Vector2(136,218),Callable())
	assert_decorations(first,"shared reward card")
	check(first.z_index==second.z_index,"overlapping reward cards use draw order, not overlay Z")
	check(second.get_index()>first.get_index(),"later overlapping card drawn after earlier card")
	assert_decorations(second,"second overlapping card")
	var naked := reward.card(reward,"unit",unit(2,1,2),Vector2(350,90),Vector2(136,218),Callable())
	check(naked.get_node_or_null("BrandFrameOverlay")==null and naked.get_node_or_null("AltarUpgradeBadge")!=null,"1 brand +2 altar badge independent")
	var plain := reward.card(reward,"unit",unit(3,3,0),Vector2(490,90),Vector2(136,218),Callable())
	check(plain.get_node_or_null("BrandFrameOverlay")!=null and plain.get_node_or_null("AltarUpgradeBadge")==null,"3 brands without altar badge")
	var dice := reward.card(reward,"dice",{"image":"1","label":"눈금 1"},Vector2(640,90),Vector2(136,218),Callable())
	check(dice.get_node_or_null("BrandFrameOverlay")==null and dice.get_node_or_null("AltarUpgradeBadge")==null,"non-unit cards left unmodified")

	# 2: real inventory fan with eight overlapping cards and hover Z.
	var owned: Array = []
	for i in range(8): owned.append(unit(i+10,2 if i%2==0 else 3,3))
	var fake := FakeSession.new(owned)
	var inventory = InventoryPanel.new()
	root.add_child(inventory)
	inventory.setup(fake)
	check(inventory.fan.entries.size()==8,"inventory has eight active card entries")
	if inventory.fan.entries.size()==8:
		var left: TextureButton = inventory.fan.entries[0].card
		var right: TextureButton = inventory.fan.entries[1].card
		check(left.get_node_or_null("BrandFrameOverlay").texture==BrandFrame.WOOD_FRAME,"inventory two brands wood")
		check(right.get_node_or_null("BrandFrameOverlay").texture==BrandFrame.IRON_FRAME,"inventory three brands iron")
		check(left.get_node_or_null("AltarUpgradeBadge")!=null and right.get_node_or_null("AltarUpgradeBadge")!=null,"inventory badges on overlapping cards")
		left.mouse_entered.emit()
		check(left.z_index==20 and left.get_node("AltarUpgradeBadge").z_index==0,"inventory hover raises whole card with plaque")
		left.mouse_exited.emit()
		check(left.z_index==0,"inventory hover exit restores card stacking")

	# 3: deck formation uses the same overlays on hand cards and lineup cards.
	var deck = BattleDeck.new()
	root.add_child(deck)
	deck.setup(owned)
	check(deck.hand.get_child_count()==8,"pre-battle deck builds eight hand cards")
	if deck.hand.get_child_count()==8:
		assert_decorations(deck.hand.get_child(1),"pre-battle deck hand")
	deck.toggle_unit(str(owned[1].id))
	check(deck.lineup.get_child_count()==1,"selected formation slot generated")
	if deck.lineup.get_child_count()==1:
		assert_decorations(deck.lineup.get_child(0),"pre-battle selected formation")
	deck.toggle_unit(str(owned[1].id))
	check(deck.lineup.get_child_count()==0,"deselection redraw succeeds")

	# 4: actual altar refresh with independent preview cards and real saved unit dictionary.
	var place = PlaceActions.new()
	root.add_child(place)
	place.session = fake
	place.type = "altar"
	place.index = 0
	place.donor_id = str(owned[0].id)
	place.receiver_id = str(owned[1].id)
	place.donor_art = place.art(place,"res://assets/cards/unit-card-skeleton-archer.png",Vector2(178,95),Vector2(144,210))
	place.receiver_art = place.art(place,"res://assets/cards/unit-card-skeleton-archer.png",Vector2(952,95),Vector2(144,210))
	place.donor_hint = place.label_at(place,"",Vector2(140,320),Vector2(200,35))
	place.receiver_hint = place.label_at(place,"",Vector2(900,320),Vector2(200,35))
	place.status = place.label_at(place,"",Vector2(200,435),Vector2(850,58))
	place.confirm_button = Button.new()
	place.add_child(place.confirm_button)
	place.refresh()
	check(place.donor_art.get_node_or_null("AltarUpgradeBadge")!=null,"altar donor preview has badge")
	assert_decorations(place.receiver_art,"altar receiver preview")
	place.receiver_id = ""
	place.refresh()
	check(place.receiver_art.get_node_or_null("AltarUpgradeBadge")==null and place.receiver_art.get_node_or_null("BrandFrameOverlay")==null,"altar empty preview removes previous decorations")

	# 5: real inheritance set_preview, including clear-on-blank behavior.
	var inheritance = HomeInheritance.new()
	root.add_child(inheritance)
	var preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = Vector2(150,208)
	inheritance.add_child(preview)
	inheritance.set_preview(preview,"unit",owned[1])
	assert_decorations(preview,"inheritance receiver preview")
	inheritance.set_preview(preview,"unit",{})
	check(preview.get_node_or_null("BrandFrameOverlay")==null and preview.get_node_or_null("AltarUpgradeBadge")==null,"inheritance blank preview clears both decorations")

	print("CARD_SCREEN_REGRESSION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
