extends Control
## Isolated viewer of the real battlefield renderer. Never starts/saves a map.
const BATTLE=preload("res://battlefield.tscn")
var scene
var busy:=false
var playback_speed:=1.0
var dragon_id:="dragon-preview"
var ally_id:="ally-0"
var label: Label
var buttons: Array[Button]=[]
func _ready() -> void:
 size=Vector2(1280,820)
 label=Label.new()
 label.position=Vector2(34,786)
 label.size=Vector2(1220,30)
 label.add_theme_font_override("font",load("res://assets/fonts/NanumBarunGothic.ttf"))
 label.add_theme_font_size_override("font_size",18)
 add_child(label)
 _button("공격 · 크게 물기",28,func(): play_attack())
 _button("피격 · 머리 반동",225,func(): play_hit())
 _button("사망 · 부패",422,func(): play_death())
 _button("다시 세우기",619,func(): reset_fixture())
 _button("일시정지 / 재생",816,func(): scene.paused=not scene.paused)
 _button("0.5 / 1 / 2 배속",1013,func():
  var speeds: Array=[0.5,1.0,2.0]
  playback_speed=float(speeds[(speeds.find(playback_speed)+1)%3])
  scene.speed_values=[playback_speed]
 )
 reset_fixture()
func _button(title: String,x: float,callback: Callable) -> void:
 var b:=Button.new()
 b.text=title
 b.position=Vector2(x,735)
 b.size=Vector2(181,42)
 b.add_theme_font_override("font",load("res://assets/fonts/NanumBarunGothic.ttf"))
 b.add_theme_font_size_override("font_size",17)
 b.pressed.connect(callback)
 add_child(b)
 buttons.append(b)
func reset_fixture() -> void:
 if busy: return
 var session=get_node_or_null("/root/RunSession")
 if session!=null and (session.world!=null or not session.encounter.is_empty()):
  push_error("Dragon lab requires a fresh isolated process; refuses an active map session.")
  return
 if is_instance_valid(scene):
  remove_child(scene)
  scene.queue_free()
 scene=BATTLE.instantiate()
 scene.selection=["skeleton-spear","skeleton-archer","ghoul","plague-doctor"]
 add_child(scene)
 move_child(scene,0)
 scene.stop_audio()
 scene.speed_values=[playback_speed]
 scene.speed_index=0
 for id in scene.sprites:
  scene.sprites[id].queue_free()
  scene.bars[id].queue_free()
  scene.cards[id].queue_free()
 scene.sprites.clear()
 scene.bars.clear()
 scene.cards.clear()
 for dict in [scene.visuals.states,scene.visuals.homes,scene.visuals.layouts,scene.visuals.active,scene.visuals.hit_motions,scene.visuals.removed]:
  dict.clear()
 var allies: Array=[]
 for i in range(4):
  allies.append(scene.rules.individual(scene.selection[i],"ally-"+str(i)))
 var enemy: Dictionary=scene.rules.individual("dragon",dragon_id)
 enemy.final_boss=true
 enemy.boss_extra_passive="undying"
 scene.rules.start(allies,[enemy])
 scene.render_units(scene.rules.units)
 scene.round_label.text="4 VS 1"
 scene.message.text="드래곤 전투 모션 확인"
 # Remove obsolete enemy legion ornaments from the initial ordinary fixture.
 for ornament in scene.layer.get_children():
  if ornament is Control and ornament.position.x>1000.0 and ornament.position.y>=82.0 and ornament.position.y<135.0:
   ornament.hide()
 # Standard dice/new battle UI is inactive in this motion-only lab.
 _disable_buttons(scene.layer)
 label.text="전투용 드래곤 동작 확인 · 사건용 연출은 별도 보존 · 개인 저장/진행과 무관"
func _disable_buttons(node: Node) -> void:
 if node is BaseButton: node.disabled=true
 for child in node.get_children(): _disable_buttons(child)
func _prepare() -> bool:
 if busy: return false
 reset_fixture()
 busy=true
 return true
func play_attack() -> void:
 if not _prepare(): return
 label.text="공격: 머리를 크게 전진 → 입을 벌림 → 턱을 닫는 9번째 프레임에서 타격"
 scene.visuals.set_focus(dragon_id,ally_id)
 var report: Dictionary={"type":"damage","source":dragon_id,"target":ally_id,"kind":"attack","amount":5,"hp":maxi(0,int(scene.rules.find_id(ally_id).hp)-5)}
 await scene.visuals.play_strike(dragon_id,ally_id,report)
 scene.visuals.set_focus()
 busy=false
func play_hit() -> void:
 if not _prepare(): return
 label.text="피격: 머리와 목이 크게 뒤로 젖혀짐 → 흔들림을 거쳐 원래 자세로 회복"
 scene.visuals.set_focus(ally_id,dragon_id)
 var report: Dictionary={"type":"damage","source":ally_id,"target":dragon_id,"kind":"attack","amount":2,"hp":68}
 await scene.visuals.play_strike(ally_id,dragon_id,report)
 scene.visuals.set_focus()
 busy=false
func play_death() -> void:
 if not _prepare(): return
 label.text="사망: 썩은 색과 얼룩 → 날개/몸 구멍 확산 → 붕괴 → 바닥의 잔해"
 var before: Array=scene.rules.units.duplicate(true)
 var dragon: Dictionary=scene.rules.find_id(dragon_id)
 dragon.alive=false
 dragon.hp=0
 var after: Array=scene.rules.units.duplicate(true)
 scene.render_units(after)
 await scene.visuals.play_deaths(before,after)
 busy=false
