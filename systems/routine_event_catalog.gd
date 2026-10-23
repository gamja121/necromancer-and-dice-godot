extends RefCounted
## Six repeatable, choice-based event cards. Gameplay uses ONLY existing
## consumable dice-control cards, ordinary unit HP and contamination.
const ORDER = [
	"wounded_soldier", "abandoned_wagon", "lost_traveler",
	"smoke_camp", "wandering_merchant", "broken_seal"
]
const CARDS = {
	"wounded_soldier":{
		"title":"쓰러진 병사","description":"무너진 성벽 아래 부상병이 도움을 청한다.",
		"action":"도와준다","decline":"지나간다","reward":"주사위 제어 카드 1장",
		"effect":"dice","illustration":"res://assets/map/events/knight-commander-village-day.webp"},
	"abandoned_wagon":{
		"title":"버려진 마차","description":"수풀에 걸린 마차에서 작은 주사위 주머니가 보인다.",
		"action":"살펴본다","decline":"떠난다","reward":"주사위 제어 카드 1장",
		"effect":"dice","illustration":"res://assets/map/events/village.jpg"},
	"lost_traveler":{
		"title":"길 잃은 행인","description":"안개 속 길을 잃은 행인이 오래된 지도를 내민다.",
		"action":"길을 알려준다","decline":"지나간다","reward":"주사위 제어 카드 1장",
		"effect":"dice","illustration":"res://assets/map/events/forest.jpg"},
	"smoke_camp":{
		"title":"그을린 야영지","description":"꺼져 가는 모닥불에 아직 따뜻한 붕대가 남아 있다.",
		"action":"잠시 쉰다","decline":"지나간다","reward":"아군 마물 체력 1 회복",
		"effect":"heal","illustration":"res://assets/map/events/camp.jpg"},
	"wandering_merchant":{
		"title":"낯선 행상인","description":"지친 행상인이 치료 약초를 나누겠다고 손짓한다.",
		"action":"약초를 받는다","decline":"거절한다","reward":"아군 마물 체력 1 회복",
		"effect":"heal","illustration":"res://assets/map/events/village.jpg"},
	"broken_seal":{
		"title":"깨진 봉인","description":"길가의 금 간 봉인에서 검은 기운이 새어 나온다.",
		"action":"봉인을 다듬는다","decline":"물러난다","reward":"오염도 1 감소",
		"effect":"cleanse","illustration":"res://assets/map/events/altar.jpg"}
}

static func valid(card_id: String) -> bool:
	return CARDS.has(card_id)

## Each routine scene may have its own approved original illustration.
## The archive delivered on 2026-10-14 contains routine_wounded_soldier.png.
## Other dedicated originals must be supplied separately; NEVER show another
## routine's artwork as a substitute. Uninstalled art preserves the old fallback.
static func dedicated_art_path(card_id: String) -> String:
	if not valid(card_id): return ""
	return "res://assets/map/events/routine_%s.png" % card_id

static func details(card_id: String) -> Dictionary:
	var result: Dictionary = CARDS.get(card_id,{}).duplicate(true)
	if result.is_empty(): return result
	var original: String = dedicated_art_path(card_id)
	if ResourceLoader.exists(original):
		result["illustration"] = original
	return result

static func choose(rng: RandomNumberGenerator) -> String:
	return str(ORDER[rng.randi_range(0, ORDER.size()-1)])

static func reward_image(card_id: String, offered_dice: Dictionary = {}) -> String:
	var card: Dictionary = details(card_id)
	if card.get("effect","")=="dice" and not offered_dice.is_empty():
		return "res://assets/cards/dice-control-ko-%s.png" % str(offered_dice.get("image","1"))
	if card.get("effect","")=="heal": return "res://assets/map/tiles/rest.png"
	return "res://assets/map/tiles/swamp.png"
