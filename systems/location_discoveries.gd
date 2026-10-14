extends RefCounted
## Original narrative entries always take priority; this registry only
## offers places after a genuine, story-free generic event arrival.
## No extra RNG roll or unapproved discovery/routine percentages.
const ORDER = ["forest","rest","graveyard","unknown","altar"]
const LOCATIONS = {
	"forest":{
		"title":"언덕 발견", "description":"낡은 길 너머 작은 언덕을 발견했다.",
		"reward":"언덕 타일 해금", "illustration":"res://assets/map/events/forest.jpg"},
	"rest":{
		"title":"숙영지 발견", "description":"이끼 낀 길 끝에서 버려진 숙영지를 발견했다.",
		"reward":"숙영 타일 해금", "illustration":"res://assets/map/events/camp.jpg"},
	"graveyard":{
		"title":"공동묘지 발견", "description":"성벽 바깥 오래된 공동묘지를 발견했다.",
		"reward":"공동묘지 타일 해금", "illustration":"res://assets/map/events/graveyard.jpg"},
	"unknown":{
		"title":"세계수 발견", "description":"뒤틀린 숲 너머 거대한 세계수의 흔적을 발견했다.",
		"reward":"세계수 타일 해금", "illustration":"res://assets/map/events/world-tree.jpg"},
	"altar":{
		"title":"제단 발견", "description":"광신도들이 사용하던 낡은 제단을 발견했다.",
		"reward":"제단 타일 해금", "illustration":"res://assets/map/events/altar.jpg"}
}

static func unlock_flag(kind: String) -> String:
	return "event:discovery:%s:unlocked" % kind

static func receipt_flag(kind: String) -> String:
	return "event:discovery:%s:card_shown" % kind

static func home_flag(kind: String) -> String:
	return "ui:unlock:%s:home_pending" % kind

static func exists(kind: String) -> bool:
	return LOCATIONS.has(kind)

static func details(kind: String) -> Dictionary:
	return LOCATIONS.get(kind,{}).duplicate(true)

static func is_unlocked(world,kind: String) -> bool:
	if not exists(kind): return false
	if kind=="rest":
		return bool(world.patrol_plan.get("rest_unlocked",false)) or world.event_flags.get(unlock_flag(kind),false)==true
	return world.event_flags.get(unlock_flag(kind),false)==true

static func eligible(world,kind: String) -> bool:
	if not exists(kind) or is_unlocked(world,kind): return false
	match kind:
		"forest":
			return world.laps>=1
		"rest":
			# Any past recorded injury (or current damaged unit) after a lap.
			# Existing HOME rest unlock keeps priority if already owned.
			return world.laps>=1 and (world.event_flags.get("discovery:ever_injured",false)==true or world.roster.any(func(u): return int(u.current_hp)<int(u.max_hp)))
		"graveyard":
			# Initial auto cemetery remains for older story/saves; this is
			# an additional discoverable cemetery, after the child plot begins.
			return world.laps>=1 and (not world.graveyard_corpses.is_empty() or world.story_events.get("graveyard_child_ambush_01",{}).get("status","unseen")!="unseen")
		"unknown":
			return world.max_contamination_reached>=20
		"altar":
			return world.story_events.get("cultist_rumor_01",{}).get("status","unseen")!="unseen" or world.event_flags.get("event:cultist_rumor_01:seen",false)==true
	return false

static func next_eligible(world) -> String:
	for kind in ORDER:
		if eligible(world,kind): return kind
	return ""
