extends PanelContainer

const MapState = preload("res://systems/map_state.gd")
const Discovery = preload("res://systems/location_discoveries.gd")
const UnlockBadge = preload("res://systems/unlock_notice_badge.gd")
const WitchHunt = preload("res://systems/witch_hunt_entry.gd")
const KingPortal = preload("res://systems/king_portal_tile.gd")

const DETAIL := {
	"basic":"효과 없음",
	"home":"회복 · 계승 · 순찰 · 출발",
	"village":"마물 교환 · 최대 3회",
	"graveyard":"카드 발굴",
	"rest":"완전 회복",
	"forest":"지정 이동 1~6칸",
	"fortune-teller-camp":"예언",
	"altar":"제물 강화",
	"unknown":"정화 기도",
	"event":"사건 발생",
	"gem":"카드 보상",
	"swamp":"전체 체력 −1",
	"monster":"전투",
	"rare-monster":"전투",
	"boss":"보스 전투",
}
const VISIT_ACTION := {
	"graveyard":"grave-extract", "rest":"heal", "forest":"hill-route",
	"fortune-teller-camp":"prophecy", "altar":"ritual", "unknown":"purify",
}
const WIDTH := 232.0

var tile_index := -1
var previous_tooltip := ""
var title: Label
var detail: Label
var state: Label


func _ready() -> void:
	name = "BoardTileInfo"
	z_index = 45
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size.x = WIDTH

	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f2e4cc")
	paper.border_color = Color("6d5139")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(5)
	paper.set_content_margin_all(7)
	paper.content_margin_left = 13
	paper.content_margin_right = 13
	paper.shadow_color = Color("25180d6e")
	paper.shadow_size = 4
	paper.shadow_offset = Vector2(0,2)
	add_theme_stylebox_override("panel",paper)

	var lines := VBoxContainer.new()
	lines.mouse_filter = MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation",2)
	add_child(lines)
	var heading := HBoxContainer.new()
	heading.mouse_filter = MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation",8)
	lines.add_child(heading)
	title = _line(heading,"TileInfoTitle",18,Color("36231a"))
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	state = _line(heading,"TileInfoState",12,Color("78513a"))
	state.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	detail = _line(lines,"TileInfoDetail",15,Color("4f3322"))
	hide()


func _line(parent: Control, node_name: String, font_size: int, ink: Color) -> Label:
	var line := Label.new()
	line.name = node_name
	line.mouse_filter = MOUSE_FILTER_IGNORE
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_theme_font_size_override("font_size",font_size)
	line.add_theme_color_override("font_color",ink)
	parent.add_child(line)
	return line


func present(index: int, info: Dictionary, tile: Rect2, bounds: Vector2, options_area: Rect2) -> void:
	tile_index = index
	title.text = info.title
	detail.text = info.detail
	state.text = info.state
	state.visible = not state.text.is_empty()
	size = Vector2(WIDTH,56)
	var center := tile.get_center()
	var gap := 8.0
	if center.x < 150:
		position = Vector2(tile.end.x + gap,center.y - size.y * 0.5)
	elif center.x > bounds.x - 105:
		# Give the settings gear beside the uppermost right stone its own space.
		var y := tile.end.y + gap if center.y < 260 else center.y - size.y * 0.5
		position = Vector2(tile.position.x - size.x - gap,y)
	else:
		position = Vector2(center.x - size.x * 0.5,tile.end.y + gap)
		# Keep the bottom row's info in the board margin below the stones.
		if center.y < bounds.y * 0.5 and Rect2(position,size).intersects(options_area):
			position.x = options_area.position.x - size.x - gap
	position = position.clamp(Vector2(12,6),bounds - size - Vector2(12,6))
	show()


static func describe(session, index: int, displayed_region: String) -> Dictionary:
	var world = session.world
	var kind: String = world.tiles[index]
	var tile_title: String = "예언자의 막사" if kind=="fortune-teller-camp" else MapState.NAMES[kind]
	var rule: String = DETAIL.get(kind,"효과 없음")
	var badges: Array[String] = []
	var current: bool = index==world.position

	if current: badges.append("현재 위치")
	if kind=="home" and WitchHunt.home_burned(session):
		tile_title = "전소된 우리집"
		rule = "출발 가능"
	elif kind=="unknown" and displayed_region!="default" and world.world_tree_destroyed():
		tile_title = "세계수 폐허"
		rule = "기도 불가"
	elif kind=="warp":
		if index==KingPortal.target(world): tile_title = "변형 웜홀"
		var destination: int = world.warp_destination(index)
		if index==world.final_dragon_location():
			rule = "봉인 폐허 입구"
		elif destination==index:
			rule = "연결 없음"
		else:
			rule = "%d번 타일 연결" % (destination+1)

	if index in world.cleared and kind in ["monster","rare-monster","boss"]:
		badges.append("처치 완료")
	elif current and _used(session,index,kind):
		badges.append("사용 완료")
	if tile_title!="세계수 폐허" and ((Discovery.exists(kind) and session.event_flag_is_set("ui:unlock:%s:tile_pending" % kind)) or (kind=="rest" and session.event_flag_is_set(UnlockBadge.REST_TILE_PENDING))):
		badges.append("신규")
	if index not in world.cleared and world.scout.scouted and world.scout.intel.any(func(entry): return int(entry.index)==index):
		badges.append("정찰")
	return {"title":tile_title,"detail":rule,"state":" · ".join(badges)}


static func _used(session, index: int, kind: String) -> bool:
	var world = session.world
	match kind:
		"village": return session.shop_trades_remaining(index)<=0
		"gem": return session.treasure_visit_id(index) in world.reward_receipts
		"unknown":
			if world.world_tree_destroyed(): return false
	if not VISIT_ACTION.has(kind): return false
	return session.place_visit_id(VISIT_ACTION[kind],index) in world.reward_receipts
