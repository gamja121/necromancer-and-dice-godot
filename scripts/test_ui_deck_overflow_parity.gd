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
	check(deck.hand.size==Vector2(870.4,244.8),"roster hand follows original 68 by 34 percent placement")
	check(deck.lineup.get_child_count()==4 and deck.lineup.get_node_or_null("EmptySlot_4")!=null,"four fixed, empty lineup anchors")
	check(deck.confirm_button.disabled and deck.selected_ids.is_empty(),"no battle without selected monster")
	deck.toggle_unit(roster[1].id)
	deck.toggle_unit(roster[0].id)
	check(deck.selected_ids==[roster[1].id,roster[0].id],"actual unique instance IDs retain chosen order")
	check(deck.lineup.get_node_or_null("SelectedUnit_1")!=null and deck.lineup.get_node_or_null("SelectedUnit_2")!=null,"occupied slots render selected card artwork")
	var rate = deck.lineup.get_node("SelectedUnit_1/TargetRate/TargetRateLabel") as Label
	check(rate.text=="피격 35%" and deck.status.text.contains("35 · 65%"),"two-monster hit targeting rates match original")
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

func test_overflow(kind: String) -> void:
	var items: Array = []
	if kind=="unit":
		for i in range(10): items.append(make_unit(i))
	else:
		for i in range(5):
			items.append({"id":"dice-%d" % i,"image":"1","label":"주사위 %d" % i})
	var new_item: Dictionary = make_unit(11) if kind=="unit" else {"id":"dice-new","image":"1","label":"신규 주사위"}
	var fake = FakeSession.new()
	fake.world = {"roster":items if kind=="unit" else [],"dice_cards":items if kind=="dice" else [],"pending_reward":{"reward":{"kind":kind,"item":new_item}}}
	var original = JSON.stringify(fake.world)
	var panel = Overflow.new()
	root.add_child(panel)
	panel.setup(fake)
	await process_frame
	check(panel.get_node_or_null("RewardOverflowPanel")!=null and panel.get_node("RewardOverflowPanel").size==Vector2(760,496),"original narrow parchment panel replaces wide dark placeholder for "+kind)
	check(panel.card_scroll != null and panel.card_scroll.size==Vector2(690,260),"original horizontal touch-scroll inventory for "+kind)
	check(panel.choices.size()==items.size()+1 and panel.choices.has("__new__"),"all old cards plus new candidate available for "+kind)
	check(panel.confirm.disabled and near(panel.confirm.modulate.a,0.45),"confirmation disabled until deliberate discard choice for "+kind)
	check(panel.title_label.text.contains("10/10" if kind=="unit" else "5/5"),"overflow shows correct capacity for "+kind)
	check(panel.choices["__new__"].get_parent().get_node_or_null("NewRewardBadge")!=null,"new card marked with source red badge for "+kind)
	panel.select_card(str(items[0].id))
	check(panel.selected==str(items[0].id) and not panel.confirm.disabled,"existing card discard selection enables confirmation for "+kind)
	check(panel.choices[str(items[0].id)].get_node("OverflowSelectedOutline").visible,"only chosen card receives gold glow for "+kind)
	check(near(panel.choices[str(items[0].id)].position.y,7.0) and near(panel.choices[str(items[1].id)].position.y,16.0),"chosen candidate lifts while other cards remain seated for "+kind)
	check(fake.discarded.is_empty() and JSON.stringify(fake.world)==original,"UI-only selection does not spend reward or edit save for "+kind)
	panel.select_card("__new__")
	check(panel.selected=="__new__" and not panel.choices[str(items[0].id)].get_node("OverflowSelectedOutline").visible,"new reward can itself be discarded for "+kind)
	fake.fail_next=true
	panel.finish()
	check(is_instance_valid(panel) and not panel.confirm.disabled and panel.status.text.contains("저장 실패"),"failed persistence keeps selection available for retry for "+kind)
	panel.finish()
	check(fake.discarded==[ "__new__", "__new__" ],"persist callback receives exact discard key even on retry for "+kind)
	await process_frame
	check(not is_instance_valid(panel),"success releases modal for "+kind)

func _run() -> void:
	await test_deck()
	await test_overflow("unit")
	await test_overflow("dice")
	print("UI_DECK_OVERFLOW_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
