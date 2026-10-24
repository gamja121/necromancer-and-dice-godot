extends SceneTree
## Stage 5F: frozen web deck-selection and capacity-overflow UI contract.
const Deck = preload("res://systems/battle_deck.gd")
const Overflow = preload("res://systems/reward_overflow.gd")

var passed: int = 0
var failed: int = 0

class FakeSession extends RefCounted:
	var world: Dictionary = {}
	var discarded: Array = []
	var fail_next: bool = false
	func claim_reward(discard_id: String = "") -> Dictionary:
		discarded.append(discard_id)
		if fail_next:
			fail_next = false
			return {"ok":false}
		return {"ok":true,"kept":discard_id!="__new__"}

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("PASS ui-deck-overflow: ",title)
	else:
		failed += 1
		printerr("FAIL ui-deck-overflow: ",title)

func near(a: float, b: float) -> bool:
	return absf(a-b)<0.6

func make_unit(index: int) -> Dictionary:
	return {"id":"monster-%02d" % index,"slug":"skeleton-spear","name":"해골 창병 %d" % index,"brands":[],"altar_enhancements":0,"current_hp":10,"max_hp":10}

func test_deck() -> void:
	var roster: Array = []
	for i in range(10): roster.append(make_unit(i))
	var original: String = JSON.stringify(roster)
	var deck = Deck.new()
	root.add_child(deck)
	deck.setup(roster)
	await process_frame
	check(deck.board != null and near(deck.board.position.x,57.6),"source board centered at 91% width")
	print("MEASURE deck.hand.size=",deck.hand.size)
	check(near(deck.hand.size.x,870.4) and near(deck.hand.size.y,244.8),"roster hand follows original 68 by 34 percent placement")
	check(deck.lineup.get_child_count()==4 and deck.lineup.get_node_or_null("EmptySlot_4")!=null,"four fixed, empty lineup anchors")
	check(deck.confirm_button.disabled and deck.selected_ids.is_empty(),"no battle without selected monster")
	deck.toggle_unit(roster[1].id)
	deck.toggle_unit(roster[0].id)
	check(deck.selected_ids==[roster[1].id,roster[0].id],"actual unique instance IDs retain chosen order")
	check(deck.lineup.get_node_or_null("SelectedUnit_1")!=null and deck.lineup.get_node_or_null("SelectedUnit_2")!=null,"occupied slots render selected card artwork")
	var rate = deck.lineup.get_node("SelectedUnit_1/TargetRate/TargetRateLabel") as Label
	check(rate.text=="피격 35%" and deck.status.text.contains("출전 마물 2/4"),"two-monster hit targeting rates match original")
	var first_card = deck.hand.get_child(0)
	var selected_card = deck.hand.get_child(1)
	check(first_card.get_node_or_null("SelectionOrderBadge")!=null and selected_card.get_node_or_null("SelectionOrderBadge")!=null,"hand shows selected order marker")
	check(selected_card.position.y<first_card.position.y+1,"selected cards rise out of original hand")
	check(not deck.confirm_button.disabled,"start button activates for one or more chosen units")
	deck.toggle_unit(roster[2].id)
	deck.toggle_unit(roster[3].id)
	deck.toggle_unit(roster[4].id)
	check(deck.selected_ids.size()==4 and not roster[4].id in deck.selected_ids,"fifth selected monster rejected at four card capacity")
	var rates: Array = ["15%","20%","27%","38%"]
	var matching: bool = true
	for i in range(4):
		var label: Label = deck.lineup.get_node("SelectedUnit_%d/TargetRate/TargetRateLabel" % (i+1))
		if not label.text.contains(rates[i]): matching = false
	check(matching,"all four exact original hit rate badges match")
	deck.toggle_unit(roster[1].id)
	check(deck.selected_ids.size()==3 and deck.lineup.get_node_or_null("EmptySlot_4")!=null,"deselection compacts order and restores empty anchor")
	check(JSON.stringify(roster)==original,"visual deck selection never mutates real unit roster")
	deck.queue_free()
	await process_frame

func test_overflow(kind: String, capture: bool = false) -> void:
	var items: Array = []
	if kind=="unit":
		for i in range(10): items.append(make_unit(i))
	else:
		for i in range(5):
			items.append({"id":"dice-%d" % i,"image":"1","label":"주사위 %d" % i})
	var new_item: Dictionary = make_unit(11) if kind=="unit" else {"id":"dice-new","image":"1","label":"신규 주사위"}
	var fake = FakeSession.new()
	fake.world = {"roster":items if kind=="unit" else [],"dice_cards":items if kind=="dice" else [],"pending_reward":{"kind":"capture" if capture else "treasure","reward":{"kind":kind,"item":new_item}}}
	var original = JSON.stringify(fake.world)
	var panel = Overflow.new()
	root.add_child(panel)
	panel.setup(fake)
	await process_frame
	var background = panel.get_node_or_null("RewardOverflowPanel") as Panel
	check(background!=null,"overflow renders a parchment panel for "+kind)
	check(panel.choices.size()==items.size()+1 and panel.choices.has("__new__"),"all existing and incoming cards are available for "+kind)
	check(panel.confirm.disabled and near(panel.confirm.modulate.a,0.45),"confirmation disabled until a deliberate choice for "+kind)
	check(panel.title_label.text.contains("10/10" if kind=="unit" else "5/5"),"overflow shows the actual capacity for "+kind)
	if kind=="unit":
		check(panel.is_monster_swap and background.size==Vector2(1184,675),"all monster reward sources use the new wide exchange screen")
		check(panel.monster_grid!=null and panel.monster_grid.columns==5 and panel.monster_grid.get_child_count()==10,"owned monster cards display in exactly two rows of five")
		check(panel.card_scroll==null,"monster exchange never hides choices behind a horizontal scroller")
		check(panel.choices["__new__"].size==Vector2(180,283) and panel.get_node_or_null("NewRewardBadge")!=null,"incoming monster has its own large identified portrait")
		check(panel.get_node_or_null("OverflowDeclineNew")!=null,"discarding the new monster is a separate explicit action")
		check(panel.choices[str(items[0].id)].size==Vector2(116,166),"owned cards are easier to inspect than the former tiny eleven-card row")
	else:
		check(not panel.is_monster_swap and background.size==Vector2(760,496),"dice still use the original overflow UI")
		check(panel.card_scroll!=null and panel.card_scroll.size==Vector2(690,260),"dice overflow retains the original scrolling row")
		check(panel.choices["__new__"].get_parent().get_node_or_null("NewRewardBadge")!=null,"dice incoming card retains the source badge")
	var first_id: String=str(items[0].id)
	panel.select_card(first_id)
	check(panel.selected==first_id and not panel.confirm.disabled,"existing card choice allows deliberate confirmation for "+kind)
	check(panel.choices[first_id].get_node("OverflowSelectedOutline").visible,"selected existing card is visibly highlighted for "+kind)
	if kind=="unit":
		check(panel.confirm.text=="교체하고 획득" and panel.selection_detail.text.contains("체력 10/10"),"monster choice previews the exact unit being sacrificed")
	else:
		check(near(panel.choices[first_id].position.y,7.0),"dice still lift the selected card")
	check(fake.discarded.is_empty() and JSON.stringify(fake.world)==original,"mere UI selection never spends or saves a reward for "+kind)
	panel.select_card("__new__")
	check(panel.selected=="__new__" and not panel.choices[first_id].get_node("OverflowSelectedOutline").visible,"incoming reward may be refused for "+kind)
	if kind=="unit":
		check(panel.confirm.text=="새 마물 포기 확정","new-monster refusal requires its own second confirmation")
	fake.fail_next = true
	panel.finish()
	check(is_instance_valid(panel) and not panel.confirm.disabled and panel.status.text.contains("저장 실패"),"save failure keeps choice and permits retry for "+kind)
	panel.finish()
	check(fake.discarded==["__new__","__new__"],"refusal callback receives the precise discard key on retry for "+kind)
	await process_frame
	check(not is_instance_valid(panel),"completed overflow closes for "+kind)

func test_monster_exchange_accept() -> void:
	var items: Array = []
	for i in range(10): items.append(make_unit(i))
	var fake = FakeSession.new()
	fake.world = {"roster":items,"dice_cards":[],"pending_reward":{"kind":"capture","reward":{"kind":"unit","item":make_unit(11)}}}
	var original = JSON.stringify(fake.world)
	var panel = Overflow.new()
	root.add_child(panel)
	panel.setup(fake)
	await process_frame
	panel.select_card(str(items[3].id))
	check(panel.confirm.text=="교체하고 획득" and panel.choices[str(items[3].id)].get_node("OverflowSelectedOutline").visible,"only the chosen outgoing monster is visually identified")
	check(JSON.stringify(fake.world)==original and fake.discarded.is_empty(),"selection leaves permanent roster unchanged")
	panel.finish()
	check(fake.discarded==[str(items[3].id)],"confirm sends the precise old monster ID to the existing transaction")
	await process_frame
	check(not is_instance_valid(panel),"successful exchange closes the modal")

func _run() -> void:
	await test_deck()
	await test_overflow("unit")
	await test_overflow("dice")
	await test_overflow("unit",true)
	await test_monster_exchange_accept()
	print("UI_DECK_OVERFLOW_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
