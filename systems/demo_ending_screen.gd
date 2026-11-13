extends "res://systems/final_chapter_screen.gd"
## The last page of the demo reads the expedition's committed story outcomes.
const Hunt = preload("res://systems/witch_hunt_entry.gd")
const Rumor = preload("res://systems/village_rumor_entry.gd")
const Altar = preload("res://systems/cultist_altar_entry.gd")
const Inquiry = preload("res://systems/commander_inquiry_entry.gd")
const Ritual = preload("res://systems/ritual_portal_entry.gd")
const RUINS = preload("res://assets/map/events/demo_ending_sealed_ruins.png")
const FISSURE_SHADER = """
shader_type canvas_item;
void fragment() {
	vec2 offset = (UV - vec2(0.808, 0.298)) * vec2(95.0, 25.0);
	float glow = exp(-dot(offset, offset) * 0.6);
	COLOR = vec4(1.0, 0.74, 0.38, glow * COLOR.a * 0.85);
}
"""

var epilogue: Dictionary

static func chapter_for(flags: Dictionary, riot_state: String, fire_in_progress: bool = false) -> Dictionary:
	var chapter := {
		"id": "quiet",
		"title": "고요한 귀환",
		"home": "폐허 너머로 마을의 지붕이 보였다. 돌아갈 길이 남아 있었다.",
		"art": "res://assets/map/events/home.jpg",
		"caption": "우리집"
	}
	if riot_state == "burned" or flags.get(Hunt.BURNED_FLAG, false):
		chapter = {"id":"burned", "title":"재가 남은 길", "home":"고룡은 쓰러졌지만, 돌아갈 집은 잿더미가 되었다.", "art":"res://assets/map/events/manuscript_witch_hunt_ruins.png", "caption":"전소된 집"}
	elif flags.get(Hunt.DAMAGED_FLAG, false):
		chapter = {"id":"damaged", "title":"그을린 문 앞에서", "home":"처마는 그을렸지만 집은 남았다. 문턱에서 다친 주민은 부축을 받아 돌아갔다.", "art":"res://assets/map/events/manuscript_witch_hunt_fire.png", "caption":"손상된 집"}
	elif riot_state == "stopped" or flags.get(Hunt.PROTECTED_FLAG, false):
		chapter = {"id":"protected", "title":"꺼진 횃불", "home":"주민들의 행렬을 막았다. 집으로 돌아가는 길에 더는 횃불이 보이지 않았다.", "art":"res://assets/map/events/manuscript_witch_hunt_saved.png", "caption":"지켜 낸 집"}
	elif riot_state == "active" or fire_in_progress:
		chapter = {"id":"unresolved", "title":"아직 꺼지지 않은 횃불", "home":"고룡은 쓰러졌다. 집을 향해 떠난 주민들의 행방은 아직 알 수 없었다.", "art":"res://assets/map/events/manuscript_witch_hunt_crowd.png", "caption":"집으로 향한 주민들"}
	var trail: Array[String] = []
	if flags.get(Rumor.RESCUED_FLAG, false):
		trail.append("공동묘지에서 아이를 구했다.")
	elif flags.get(Rumor.ABANDONED_FLAG, false):
		trail.append("공동묘지에서 아이를 지나쳤다.")
	if flags.get(Altar.FIGHT_FLAG, false):
		trail.append("제단에서 광신도와 맞섰다.")
	elif flags.get(Altar.PASS_FLAG, false):
		trail.append("제단을 지나 의식의 흔적을 추적했다.")
	elif flags.get(Altar.INFILTRATE_FLAG, false):
		trail.append("광신도에게 접근해 의식의 단서를 얻었다.")
	if flags.get(Inquiry.TESTIMONY_FLAG, false):
		trail.append("기사단에 진술을 남겼다.")
	elif flags.get(Inquiry.WATCH_FLAG, false):
		trail.append("기사단은 감시를 명했다.")
	if flags.get(Ritual.WEAKENED_FLAG, false):
		trail.append("부활 의식의 힘을 약화했다.")
	elif flags.get(Ritual.FULL_REVIVAL_FLAG, false):
		trail.append("부활 의식은 끝까지 이어졌다.")
	if flags.get(Hunt.RESCUED_FLAG, false):
		trail.append("불길에 갇힌 주민을 구했다.")
	chapter["trail"] = trail
	var village: Array[String] = []
	if flags.get(Hunt.PUBLIC_FLAG, false):
		village.append("목격자와 공개 대면했다.")
	elif flags.get(Hunt.REFUSED_FLAG, false):
		village.append("목격자와의 대면을 거절했다.")
	if flags.get(Hunt.ESCORT_FLAG, false):
		village.append("경비의 동행을 요청했다.")
	elif flags.get(Hunt.ALONE_FLAG, false):
		village.append("경비 없이 집으로 향했다.")
	chapter["village"] = village
	return chapter

func show_demo_ending(world, archived: bool, acknowledge: Callable = Callable()) -> void:
	mode = "ending"
	record = world.run_result.duplicate(true)
	var fire_status: String = world.story_events.get(Hunt.IDS[2], {}).get("status", "")
	epilogue = chapter_for(world.event_flags, str(world.riot.get("state", "")), fire_status in ["seen", "active"])
	_new_book(archived)
	book.copy("봉인 폐허의 기록", Rect2(118,126,450,30), 18, Color("775b3d"))
	book.copy("고룡의 숨이 멎었다.", Rect2(178,425,360,30), 16, Color("81684b"))
	var ruins := _illustration(RUINS, Book.ART_RECT.size)
	book.art.add_child(ruins)

	var memory := _illustration(load(str(epilogue.art)), Vector2(128,72))
	memory.position = Vector2(178,471)
	book.add_child(memory)
	book.copy(str(epilogue.caption), Rect2(320,472,225,24), 16, Color("81684b"))
	for i in range(epilogue.village.size()):
		book.copy(epilogue.village[i], Rect2(320,498+i*20,225,20), 14, Color("81684b"))
	var seal := Book.Seal.new()
	seal.position = Vector2(463,128)
	seal.rotation_degrees = -0.12
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(seal)
	var stamp: Label = book.copy("격 파", Rect2(0,18,70,30), 20, Book.RED_INK)
	stamp.reparent(seal, false)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	book.copy("종언의 고룡 격파", Rect2(702,124,432,24), 15, Color("81684b"))
	title = book.copy(str(epilogue.title), Rect2(702,154,432,48), 29)
	narrative = book.copy(str(epilogue.home), Rect2(702,217,432,68), 19)
	for i in range(epilogue.trail.size()):
		book.copy(epilogue.trail[i], Rect2(702,295+i*24,432,24), 15)
	var fields := [["완주한 바퀴","laps"],["쓰러뜨린 적","enemies_defeated"],["전투 생존 마물","surviving_monsters"],["떠나보낸 마물","lost_monsters"]]
	for i in range(fields.size()):
		var x: float = 702.0 + (i % 2) * 212.0
		var y: float = 430.0 + (i / 2) * 27.0
		book.copy("%s  %d" % [tr(fields[i][0]), int(record.get(fields[i][1],0))], Rect2(x,y,210,25), 15)
	hint = book.copy("닫혔던 틈에서 빛이 새어 나왔다.", Rect2(702,510,432,27), 15, Color("81684b"))
	action_button = _action("책을 덮고 타이틀로" if archived else "체험판 완료", Rect2(700,548,440,44),
		func(): _complete_demo(acknowledge))
	action_button.name = "CloseFinalChapter"
	action_button.disabled = not archived
	if archived:
		action_button.grab_focus()
		return

	var glow := ColorRect.new()
	glow.modulate.a = 0.0
	glow.size = Book.ART_RECT.size
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = FISSURE_SHADER
	var light := ShaderMaterial.new()
	light.shader = shader
	glow.material = light
	book.art.add_child(glow)
	seal.modulate.a = 0.0
	hint.modulate.a = 0.0
	book.opened.connect(func():
		Sound.cue(self, "final_clear")
		InkReveal.play(ruins, 1.15)
		ending_reveal = create_tween()
		ending_reveal.tween_interval(0.9)
		ending_reveal.tween_callback(func(): Sound.cue(self, "book_stamp"))
		ending_reveal.tween_property(seal, "modulate:a", 1.0, 0.35)
		ending_reveal.tween_interval(0.55)
		ending_reveal.tween_property(glow, "modulate:a", 1.0, 0.23)
		ending_reveal.parallel().tween_property(hint, "modulate:a", 1.0, 0.4)
		ending_reveal.tween_property(glow, "modulate:a", 0.0, 0.7)
		ending_reveal.tween_callback(func():
			action_button.disabled = false
			action_button.grab_focus()))

func _illustration(texture: Texture2D, dimensions: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.size = dimensions
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture

func _complete_demo(acknowledge: Callable) -> void:
	if leaving or action_button.disabled or book.opening: return
	if acknowledge.is_valid() and not acknowledge.call():
		hint.add_theme_color_override("font_color", Book.RED_INK)
		show_storage_error("체험판 완료를 저장하지 못했습니다. 다시 시도하세요.")
		return
	_finish_ending(Callable())
