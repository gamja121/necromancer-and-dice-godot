extends RefCounted
const Catalog = preload("res://systems/reward_catalog.gd")

static func card(card_id: String) -> Dictionary:
	for item in Catalog.dice_cards():
		if item.card_id==card_id: return item
	return {}

static func can_use(card_id: String, context: Dictionary) -> Dictionary:
	if card(card_id).is_empty(): return {"ok":false,"reason":"존재하지 않는 카드입니다."}
	var effective = str(context.get("previous_card","")) if card_id=="echo" else card_id
	if card_id=="echo" and (effective.is_empty() or card(effective).is_empty() or effective=="echo"):
		return {"ok":false,"reason":"먼저 다른 제어 카드를 사용해야 합니다."}
	if effective=="repeat" and not int(context.get("previous_roll",0)) in range(1,7):
		return {"ok":false,"reason":"먼저 주사위를 한 번 굴려야 합니다."}
	return {"ok":true}

static func values(card_id: String) -> Array:
	if card_id.begins_with("fixed-"): return [int(card_id.get_slice("-",1))]
	if card_id=="low": return [1,2,3]
	if card_id=="high": return [4,5,6]
	if card_id=="odd": return [1,3,5]
	if card_id=="even": return [2,4,6]
	if card_id.begins_with("exclude-"):
		var excluded = int(card_id.get_slice("-",1))
		return [1,2,3,4,5,6].filter(func(face): return face!=excluded)
	return []

static func resolve(card_id: String, context: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var available = can_use(card_id,context)
	if not available.ok: return available
	var effective = str(context.get("previous_card","")) if card_id=="echo" else card_id
	var face = int(context.get("previous_roll",0))
	if effective!="repeat":
		var pool = values(effective)
		if pool.is_empty(): return {"ok":false,"reason":"카드 효과를 확인할 수 없습니다."}
		face = int(pool[rng.randi_range(0,pool.size()-1)])
	return {"ok":true,"face":face,"effective_card":effective,"label":card(card_id).label}

static func description(card_id: String) -> String:
	if card_id=="repeat": return "직전 주사위 눈금을 한 번 더 적용합니다"
	if card_id=="echo": return "직전 제어 카드의 효과를 다시 적용합니다"
	return "나올 수 있는 눈금: "+", ".join(values(card_id).map(func(n): return str(n)))
