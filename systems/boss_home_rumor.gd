extends RefCounted
## Short overheard rumors for the assigned intermediate bosses.

const KIND = "boss-home-rumor"
const TITLE = "길목의 소문"
const NARRATION = [
	"길을 나서려는 순간, 가까운 곳에서 낮은 목소리가 들린다.",
	"다른 주민이 목소리를 낮춘다."
]
const SPEAKERS = ["주민", "다른 주민"]
const DIALOGUE = {
	"death-knight": [
		"어젯밤 외곽길에서 쇠 끄는 소리가 났대. 갑옷 입은 자가 혼자 길을 돌고 있었다더군.",
		"갑옷이라면… 요 며칠 소문에 돌던 데스 나이트인가?"
	],
	"hydra": [
		"물가에서 뱀 머리가 여럿 솟았대. 본 사람마다 머릿수를 다르게 말하더군.",
		"히드라라면 당분간 물가를 피하는 게 좋겠어."
	],
	"kraken": [
		"새벽에 물가에 매 둔 배가 뒤집혔대. 물 위로 굵은 촉수가 올라오는 걸 봤다더군.",
		"촉수라고? 크라켄 소문이 사실이었나 보군."
	],
	"spider-knight": [
		"나뭇가지에 밧줄만 한 거미줄이 걸렸대. 그 너머로 긴 다리가 여럿 움직였다는군.",
		"거미 여왕을 봤다던 사냥꾼 얘기가 헛소문은 아니었군."
	],
	"goblin-chief": [
		"요 며칠 고블린 무리가 외곽길에 자꾸 나타난대. 어젯밤엔 뿔나팔 소리까지 들렸다는군.",
		"고블린 족장이 온 모양이군. 놈들이 다시 뭉쳤잖아."
	],
	"grave-priest": [
		"무덤가에서 뼈 부딪치는 소리가 나더니, 해골들이 하나씩 일어났다더군.",
		"그 해골들을 불러낸 해골 소환사를 봤다는 사람도 있더라고."
	]
}


static func receipt(stage: int) -> String:
	return "%s:%d" % [KIND, stage]
