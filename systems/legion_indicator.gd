extends Button
## One existing legion emblem's interaction and activation light. Presentation only.
const NAMES = {"skeleton":"언데드","beast":"야수","corpse":"시체","plague":"역병","ice":"얼음","summon":"소환","demon":"악마","plant":"식물","insect":"벌레","element":"원소"}
const EFFECTS = {
	"skeleton":"매 라운드 시작 시 살아 있는 언데드 마물의 HP를 1 회복합니다. 실제 회복이 발생하는 순간만 점등합니다.",
	"beast":"야수 군단 마물의 공격력이 1 증가합니다. 전투 중 지속 적용됩니다.",
	"corpse":"군단 조건은 성립하지만 현재 전투 규칙에 별도 시체 군단 효과는 정의되어 있지 않습니다.",
	"plague":"역병 군단 마물은 독에 걸리지 않습니다. 전투 중 지속 적용됩니다.",
	"ice":"얼음 군단 마물이 빙결된 적을 공격하면 추가 피해 1을 줍니다. 해당 공격 순간에만 점등합니다.",
	"summon":"매 라운드 소환 가능한 마물이 있으면 비용 없이 소환을 시도합니다. 군단을 통해 실제 소환이 일어난 순간에만 점등합니다.",
	"demon":"악마 군단 마물의 속도가 2 증가합니다. 전투 중 지속 적용됩니다.",
	"plant":"전투 시작 시 식물 군단 마물의 최대 HP가 3 증가합니다. 해당 강화가 유지되는 동안 점등합니다.",
	"insect":"벌레 군단 마물이 일반 공격을 받으면 피해를 1 줄입니다(최소 피해 1). 전투 중 지속 적용됩니다.",
	"element":"상대 원소 군단이 없으면 상대의 원소 외 다른 군단 효과를 무효화합니다. 전투 중 지속 적용됩니다."
}
const CONTINUOUS = ["beast","plague","demon","plant","insect","element"]
var kind: String = ""
var team: String = ""
var active_effect: bool = false
var elapsed: float = 0.0
var pulse_end: float = 0.0
var notice_end: float = 0.0
var battle_scene
var notice: Label

func configure(scene, side: String, key: String, is_active: bool) -> void:
	battle_scene = scene
	team = side
	kind = key
	active_effect = is_active and key in CONTINUOUS
	name = "LegionIndicator_%s_%s" % [side,key]
	size = Vector2(54,54)
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "클릭: %s 군단 효과" % NAMES.get(key,key)
	pressed.connect(func(): battle_scene.show_legion_effect_info(team,kind))
	notice = Label.new()
	notice.name = "LegionActivationNotice"
	notice.text = "효과 발동"
	notice.position = Vector2(50,17) if side=="ally" else Vector2(-64,17)
	notice.size = Vector2(65,22)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_theme_font_size_override("font_size",11)
	notice.add_theme_color_override("font_color",Color("a8ffbf") if side=="ally" else Color("ffaaa0"))
	notice.add_theme_color_override("font_outline_color",Color("18120f"))
	notice.add_theme_constant_override("outline_size",4)
	notice.visible = false
	add_child(notice)
	if active_effect: announce()

func announce() -> void:
	notice_end = maxf(notice_end,elapsed+1.15)

func trigger() -> void:
	# Temporary effects only light up when gameplay reports an actual use.
	pulse_end = maxf(pulse_end,elapsed+0.8)
	announce()

func _process(delta: float) -> void:
	if battle_scene != null and not battle_scene.paused:
		elapsed += delta * battle_scene.battle_tempo
	if notice != null:
		notice.visible = elapsed<notice_end
	queue_redraw()

func _draw() -> void:
	if not active_effect and elapsed>=pulse_end: return
	var strength := 0.58+0.27*sin(elapsed*4.0) if active_effect else minf(1.0,(pulse_end-elapsed)*2.0)
	var tint := Color("79e69e") if team=="ally" else Color("f08d79")
	var center := Vector2(27,27)
	# Soft ambient ring + small accents: do not obscure the original crossed-swords icon.
	draw_circle(center,26.0,Color(tint,0.10*strength),true)
	draw_arc(center,23.5,0.0,TAU,32,Color(tint,0.70*strength),2.5,true)
	draw_arc(center,26.0,0.0,TAU,32,Color(tint,0.19*strength),4.5,true)
	for i in 4:
		var angle := elapsed*0.5+float(i)*TAU/4.0
		var p := center+Vector2(cos(angle),sin(angle))*23.5
		draw_circle(p,1.8,Color(tint,0.9*strength),true)
