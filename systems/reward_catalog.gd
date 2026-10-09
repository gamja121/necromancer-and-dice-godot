extends RefCounted

const UNIT_CAPACITY = 10
const DICE_CAPACITY = 5

static func dice_cards() -> Array:
	var result: Array = []
	for face in range(1,7): result.append({"card_id":"fixed-%d" % face,"label":"눈금 %d" % face,"image":"%d" % face})
	for entry in [["low","작은수"],["high","큰수"],["odd","홀수"],["even","짝수"]]:
		result.append({"card_id":entry[0],"label":entry[1],"image":entry[0]})
	for face in range(1,7): result.append({"card_id":"exclude-%d" % face,"label":"제외 %d" % face,"image":"exclude-%d" % face})
	result.append({"card_id":"repeat","label":"반복","image":"repeat"})
	result.append({"card_id":"echo","label":"효과 재발동","image":"echo"})
	return result

static func image(kind: String, item: Dictionary) -> String:
	if kind=="unit": return "res://assets/cards/unit-card-%s.png" % item.slug
	if kind=="brand": return "res://assets/cards/brand-card.png"
	return "res://assets/cards/dice-control-ko-%s.png" % item.image

static func label(kind: String, item: Dictionary) -> String:
	if kind=="unit": return item.name
	if kind=="dice": return item.label
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interface.json")).brands
	return "%s · 축복 %s" % [data[item.brand.type].name.replace("의 낙인",""),", ".join(item.brand.bless.map(func(n): return str(int(n))))]
