extends RefCounted
const INQUIRY_ART="res://assets/map/events/manuscript_commander_inquiry_scene.png"
const CROWD_ART="res://assets/map/events/manuscript_witch_hunt_crowd.png"
const HOME_ART="res://assets/map/events/manuscript_witch_hunt_home.png"
const FIRE_ART="res://assets/map/events/manuscript_witch_hunt_fire.png"
const SAVED_ART="res://assets/map/events/manuscript_witch_hunt_saved.png"
const RUINS_ART="res://assets/map/events/manuscript_witch_hunt_ruins.png"
const TITLES=["증언의 대조","집으로 향하는 사람들","문 앞의 횃불"]
const CHOICES=[["목격자와 대면한다","대면을 거절한다"],["경비의 동행을 요청한다","혼자 집으로 돌아간다"],["불씨부터 끈다","넘어진 주민을 구한다"]]
const DECISIONS=[["confront","avoid"],["escort","alone"],["extinguish","rescue"]]
const CHOICE_INDEX=3
const BEATS=[
	[
		{"effect":"기사단장이 예언가와 목격자의 말을 대조하려고 당신을 부른다. 앞서 남긴 설명도 함께 확인할 참이다.","dialogue":"","speaker":""},
		{"effect":"예언가의 답변은 조사 전에 본 문양에 관한 것이었다. 제단에서 있었던 일까지 보증한 것은 아니다.","dialogue":"예언가는 네게 문양을 보여 줬다고 했다. 수레를 옮긴 의도는 현장에 없었으니 모른다더군.","speaker":"기사단장"},
		{"effect":"숲길의 목격자가 자신이 본 범위를 밝힌다.","dialogue":"당신 마물들이 수레를 미는 건 봤소. 무슨 말을 나눴는지는 듣지 못했소.","speaker":"목격자"},
		{"effect":"목격담에 섞인 추측을 주민들 앞에서 바로잡을 기회다. 아이의 행방에 관한 새 증거는 없다.","dialogue":"여기서 네 경위를 다시 말하겠나? 듣고 본 사실부터 구별하겠네.","speaker":"기사단장"}
	],
	[
		{"effect":"마을 길목에 사람들이 모였다. 목격담의 한계를 들은 주민이 섣부른 단정을 말리고 있다.","dialogue":"","speaker":""},
		{"effect":"일부 주민은 판단 유보를 감싸기로 받아들인다.","dialogue":"확인 중이라더니 아직도 저자를 놔두잖아. 기사단이 감싸는 것 아냐?","speaker":"주민"},
		{"effect":"주인공의 집을 직접 뒤져 보자는 말이 나온다. 다른 주민이 제멋대로 행동하지 말라며 막는다.","dialogue":"보지도 않은 일을 사실처럼 말하지 마시오. 집을 뒤지면 없는 증거가 생깁니까?","speaker":"다른 주민"},
		{"effect":"몇 사람이 집 쪽으로 향한다. 경비가 함께하도록 요청하거나, 먼저 혼자 돌아갈 수 있다.","dialogue":"남의 집을 멋대로 수색할 권한은 없다. 손대지 말고 기다려라.","speaker":"기사단장"}
	],
	[
		{"effect":"집 앞에 횃불 든 주민들이 모여 있다. 동행한 경비가 문에서 사람들을 떼어 놓으려 한다.","dialogue":"","speaker":""},
		{"effect":"한 주민이 문을 열라며 마른 처마에 횃불을 들이댄다. 불씨가 붙자 뒤의 사람들이 놀라 밀려든다.","dialogue":"","speaker":""},
		{"effect":"밀린 주민 하나가 문턱에 넘어져 옷이 걸린다. 처마의 불씨와 빠져나오지 못한 사람, 두 곳에 손이 필요하다.","dialogue":"","speaker":""},
		{"effect":"경비가 당신의 손짓을 기다린다. 한쪽을 맡기면 다른 쪽을 도울 수 있다.","dialogue":"","speaker":""}
	]
]
const RESPONSES={
	"confront":[
		{"effect":"문양을 알아본 경위와 제단에서 들은 행선지, 수레를 옮긴 목적을 주민들 앞에서 설명하려 한다.","dialogue":"","speaker":""},
		{"effect":"기사단장이 사실과 추측을 나눠 기록하게 한다.","dialogue":"함께 있었다는 목격담은 있다. 공모했다거나 아이와 관련됐다는 증거는 없다. 이 둘을 섞지 마라.","speaker":"기사단장"},
		{"effect":"공개된 자리에서 반론이 남았다. 일부 주민은 고개를 끄덕이지만, 소문을 믿는 이들까지 곧바로 납득한 것은 아니다.","dialogue":"","speaker":""}
	],
	"avoid":[
		{"effect":"주민들이 둘러선 자리에서 더 말하지 않기로 한다. 경위를 공개적으로 확인하는 대면을 거절한다.","dialogue":"","speaker":""},
		{"effect":"기사단장은 대면 거절을 유죄의 증거로 취급하지 않는다.","dialogue":"목격자가 듣지 못한 말까지 증언할 수는 없지. 다만 주민들은 네 답을 듣지 못한 채 돌아가게 되겠군.","speaker":"기사단장"},
		{"effect":"공식 조사에는 목격담의 한계가 남았다. 그러나 주민들 사이에서는 공개된 해명이 없었다는 말이 다시 퍼졌다.","dialogue":"","speaker":""}
	],
	"escort":[
		{"effect":"주민들의 사적 수색을 막을 수 있도록 경비가 함께 집으로 가 달라고 요청한다.","dialogue":"","speaker":""},
		{"effect":"기사단장이 경비에게 먼저 현장을 지키도록 지시한다.","dialogue":"수색은 내 확인 아래 한다. 동행해서 사람들을 떼어 놓아라. 누구도 집에 손대지 못하게 해.","speaker":"기사단장"},
		{"effect":"경비가 마을 길목에서 주민들을 잠시 붙잡아 둔다. 이번에는 당신이 먼저 주사위를 굴린다.","dialogue":"","speaker":""}
	],
	"alone":[
		{"effect":"경비의 동행을 기다리지 않고 집으로 먼저 돌아가기로 한다. 흥분한 주민들이 앞서 움직이고 있다.","dialogue":"","speaker":""},
		{"effect":"기사단장이 멋대로 집에 손대지 말라고 다시 명한다. 하지만 먼저 떠난 사람들 모두에게 말이 닿지는 않는다.","dialogue":"조사는 내가 맡는다. 군중과 맞서려면 조심하게. 경비가 도착하기 전엔 혼자일 수 있다.","speaker":"기사단장"},
		{"effect":"경비와 동행할 약속 없이 집으로 향한다. 기사단장의 명령과 마을 밖으로 번진 소문 사이에 거리가 벌어졌다.","dialogue":"","speaker":""}
	]
}
const FIRE_RESPONSES={
	"extinguish":{"effect":"처마에 번지는 불씨를 먼저 끄려 한다. 문턱에 걸린 주민에게는 다른 사람의 손이 필요하다.","dialogue":"","speaker":""},
	"rescue":{"effect":"넘어진 주민을 먼저 불길 밖으로 끌어내려 한다. 그동안 처마의 불씨는 다른 사람이 막아야 한다.","dialogue":"","speaker":""}
}
const RESULTS={
	"protected":[
		{"effect":"당신이 한쪽을 처리하는 동안 경비가 다른 쪽을 맡는다. 주민을 끌어내고 처마의 불씨도 껐다.","dialogue":"","speaker":""},
		{"effect":"함께할 경비를 준비한 덕분에 사람과 집을 지켰다. 방화를 시도한 주민들은 제지됐다. 불신이 곧바로 사라지지는 않았지만 독단적인 습격은 멈췄다.","dialogue":"","speaker":""}
	],
	"damaged":[
		{"effect":"불씨를 막아 큰불은 피했다. 뒤늦게 동료들이 넘어진 주민을 끌어내지만, 그는 문턱에 다리를 다친 채 부축받는다.","dialogue":"","speaker":""},
		{"effect":"처마와 문은 상했지만 집은 남았다. 방화의 책임과 주민의 부상은 따로 기록된다. 마을과의 갈등도 남아 있다.","dialogue":"","speaker":""}
	],
	"burned":[
		{"effect":"주민을 불길 밖으로 끌어냈다. 그 사이 마른 지붕 전체로 불이 번진다. 횃불을 들이댄 이들도 더는 가까이 가지 못한다.","dialogue":"","speaker":""},
		{"effect":"주민들의 방화로 집이 전소됐다. 당신에게 구출된 주민은 살아남았다. 집의 회복·계승·순찰 기능은 쓸 수 없지만, 원정과 다음 바퀴는 계속할 수 있다.","dialogue":"","speaker":""}
	]
}

static func count() -> int: return 7
static func beat(stage: int, index: int, decision: String, explained: bool, confronted: bool, escorted: bool) -> Dictionary:
	if stage<0 or stage>2 or index<0 or index>=count(): return {}
	var result: Dictionary
	if index<4: result=BEATS[stage][index].duplicate(true)
	elif stage<2:
		if not RESPONSES.has(decision): return {}
		result=RESPONSES[decision][index-4].duplicate(true)
	elif index==4:
		if not FIRE_RESPONSES.has(decision): return {}
		result=FIRE_RESPONSES[decision].duplicate(true)
	else: result=RESULTS[outcome(decision,escorted)][index-5].duplicate(true)
	if stage==0 and index==0 and not explained:
		result.effect="감시하던 경비병이 목격자 대조를 위해 당신을 부른다. 기사단장은 듣지 못했던 경위를 다시 물을 참이다."
	if stage==1 and index==0 and not confronted:
		result.effect="마을 길목에 사람들이 모였다. 공개된 답을 듣지 못했다는 말이 돌며 목격담에 대한 추측이 더 거칠어졌다."
	if stage==2 and not escorted:
		if index==0: result.effect="집 앞에 횃불 든 주민들이 모여 있다. 경비는 아직 보이지 않고, 몇 사람이 문을 열라며 다가선다."
		if index==3: result.effect="곁에서 바로 도울 경비는 없다. 한쪽을 먼저 처리하는 동안 다른 쪽은 늦어질 수밖에 없다."
	result["art"]=INQUIRY_ART if stage==0 else (CROWD_ART if stage==1 else ((FIRE_ART if outcome(decision,escorted)=="burned" else SAVED_ART) if index>=5 else HOME_ART))
	return result

static func outcome(decision: String, escorted: bool) -> String:
	if escorted: return "protected"
	return "burned" if decision=="rescue" else "damaged"
