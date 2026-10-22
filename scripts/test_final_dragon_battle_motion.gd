extends SceneTree
## Real battlefield routing, articulated frames, rot progression and pause checks.
const RIG=preload("res://systems/final_dragon_battle_rig.gd")
const LAB=preload("res://systems/final_dragon_battle_lab.gd")
const LAYOUT=preload("res://systems/battle_presentation_layout.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,note: String) -> void:
 if ok:
  passed+=1
  print("PASS dragon-combat: "+note)
 else:
  failed+=1
  printerr("FAIL dragon-combat: "+note)
func occupied(img: Image) -> int:
 var count:=0
 for y in range(0,img.get_height(),4):
  for x in range(0,img.get_width(),4):
   if img.get_pixel(x,y).a>0.10: count+=1
 return count
func wait_idle(lab,seconds: float=10.0) -> bool:
 var until:=Time.get_ticks_msec()+int(seconds*1000.0)
 while lab.busy and Time.get_ticks_msec()<until: await process_frame
 return not lab.busy
func wait_texture(scene,id: String,motion: String,seconds: float=6.0) -> bool:
 var until:=Time.get_ticks_msec()+int(seconds*1000.0)
 while Time.get_ticks_msec()<until:
  var texture: Texture2D=scene.sprites[id].texture
  if texture!=null and texture.resource_path.contains("/dragon/"+motion+"-"): return true
  await process_frame
 return false
func run() -> void:
 var layout=LAYOUT.new()
 check(layout.metrics.has("dragon") and layout.metrics.size()==48,"new combat profile added without removing original 47")
 var m: Dictionary=layout.metrics.dragon
 check(m.attack.size()==16 and m.hit.size()==8 and m.death.size()==20,"16 attack / 8 recoil / 20 decay frames")
 check(int(m.impact_frame)==9 and m.attack_delays.size()==16 and m.death_delays.size()==20,"bite closes on damage frame and custom timings cover all frames")
 var images: Dictionary={}
 for motion in ["attack","hit","death"]:
  images[motion]=[]
  for index in layout.frames("dragon",motion):
   var path: String="res://assets/battle/frames/dragon/%s-%02d.png" % [motion,int(index)]
   var tex=load(path) as Texture2D
   check(tex!=null and tex.get_size()==Vector2(1024,640),"native frame decodes "+motion+"-"+str(index))
   if tex==null: continue
   var img:=tex.get_image()
   images[motion].append(img)
   var bounds:=img.get_used_rect()
   check(bounds.size.x>0 and bounds.position.x>=16 and bounds.position.y>=16 and bounds.end.x<=1008 and bounds.end.y<=624,"transparent safety margin "+motion+"-"+str(index))
 var rest: Image=images.attack[0]
 var open: Image=images.attack[7]
 check(open.get_used_rect().end.x-rest.get_used_rect().end.x>=140,"rendered attack reaches over 140 pixels farther forward")
 var eye:=Vector2(1408,212)
 var rest_eye: Vector2=RIG.point(eye,RIG.pose("attack",0))
 var bite_eye: Vector2=RIG.point(eye,RIG.pose("attack",8))
 var hit_eye: Vector2=RIG.point(eye,RIG.pose("hit",2))
 check(bite_eye.x-rest_eye.x>100.0,"head travels over 100 pixels independently of the planted feet")
 check(hit_eye.x<rest_eye.x-80.0 and hit_eye.y<rest_eye.y-35.0,"recoil throws head back and up visibly")
 var tooth:=Vector2(1484,305)
 var open_gap: float=RIG.point(tooth,RIG.pose("attack",7),true).distance_to(RIG.point(tooth,RIG.pose("attack",7)))
 var closed_gap: float=RIG.point(tooth,RIG.pose("attack",8),true).distance_to(RIG.point(tooth,RIG.pose("attack",8)))
 check(open_gap>closed_gap*1.6,"lower jaw articulates open and snaps closed at impact")
 check(rest.get_data()==images.attack[15].get_data() and rest.get_data()==images.hit[7].get_data(),"attack and hit return to identical neutral artwork")
 var alive_pixels:=occupied(images.death[0])
 var middle_pixels:=occupied(images.death[9])
 var final_pixels:=occupied(images.death[19])
 check(middle_pixels<alive_pixels*0.85 and middle_pixels>alive_pixels*0.25,"mid-death has patchy real holes while body is still recognizable")
 check(final_pixels<alive_pixels*0.08 and images.death[19].get_used_rect().position.y>520,"decay ends in floor debris rather than a translucent standing dragon")
 var enemy: Dictionary={"slug":"dragon","team":"enemy","slot":0}
 var core: Dictionary={"slug":"skeleton-spear","team":"ally","slot":0}
 for surface in [Vector2(1280,720),Vector2(1280,530),Vector2(960,540),Vector2(1920,1080)]:
  var geometry: Dictionary=layout.geometry(enemy,surface)
  var fits:=true
  for motion in images:
   for img in images[motion]:
    var bounds: Rect2i=img.get_used_rect()
    var left: float=geometry.position.x+(1024.0-bounds.end.x)*geometry.scale
    var right: float=geometry.position.x+(1024.0-bounds.position.x)*geometry.scale
    var top: float=geometry.position.y+bounds.position.y*geometry.scale
    var bottom: float=geometry.position.y+bounds.end.y*geometry.scale
    fits=fits and left>=0.0 and right<=surface.x and top>=surface.y*0.18 and bottom<surface.y*0.95
  check(fits,"all combat frames fit actual mirrored boss layout "+str(surface))
  var ordinary: Dictionary=layout.geometry(core,surface)
  var monster_height: float=(float(m.bottom)-float(m.top)+1.0)*geometry.scale
  var core_m: Dictionary=layout.metrics["skeleton-spear"]
  var ordinary_height: float=(float(core_m.bottom)-float(core_m.top)+1.0)*ordinary.scale
  check(monster_height>ordinary_height*2.0,"boss retains colossal screen presence "+str(surface))
 var save_path: String="user://map_run_v1.json"
 var had_save:=FileAccess.file_exists(save_path)
 var save_before:=FileAccess.get_sha256(save_path) if had_save else ""
 var lab=LAB.new()
 root.add_child(lab)
 await process_frame
 var scene=lab.scene
 check(not scene.map_mode and scene.rules.units.size()==5,"real battlefield has four allies and a single dragon; no map loaded")
 check(scene.sprites[lab.dragon_id].texture.resource_path.ends_with("/dragon/attack-01.png"),"live combat uses separate dragon frames, not book final-dragon frames")
 check(scene.sprites[lab.dragon_id].flip_h,"enemy dragon faces actual allied side")
 check(scene.cards[lab.dragon_id].has_node("LayeredCardBase"),"boss card reuses neutral combat artwork instead of leaving an invisible slot")
 scene.show_detail(scene.rules.find_id(lab.dragon_id))
 check(scene.detail!=null and scene.detail.portrait.texture!=null,"dragon unit information has a real loaded portrait")
 scene.detail.queue_free()
 scene.detail=null
 lab.play_attack()
 scene=lab.scene
 check(await wait_texture(scene,lab.dragon_id,"attack"),"actual play_strike enters new attack sequence")
 await create_timer(0.24).timeout
 scene.paused=true
 var frozen_tex: Texture2D=scene.sprites[lab.dragon_id].texture
 var frozen_clock: float=scene.visuals.clock
 await create_timer(0.16).timeout
 check(scene.sprites[lab.dragon_id].texture==frozen_tex and is_equal_approx(scene.visuals.clock,frozen_clock),"pause freezes the real attack frame and visual clock")
 scene.paused=false
 check(await wait_idle(lab),"real attack resumes and completes")
 check(scene.sprites[lab.dragon_id].texture.resource_path.ends_with("/dragon/attack-01.png"),"live attack restores neutral frame")
 check(scene.rules.find_id(lab.dragon_id).hp==70 and scene.rules.find_id(lab.dragon_id).attack==5,"presentation does not alter dragon stats")
 lab.play_hit()
 scene=lab.scene
 check(await wait_texture(scene,lab.dragon_id,"hit"),"ordinary ally strike triggers dragon recoil through production hit route")
 scene.paused=true
 var frozen_hit: Texture2D=scene.sprites[lab.dragon_id].texture
 await create_timer(0.16).timeout
 check(scene.sprites[lab.dragon_id].texture==frozen_hit,"pause also freezes actual recoil")
 scene.paused=false
 check(await wait_idle(lab),"recoil and attacking ally finish without a stuck active state")
 # Setting speed persists across replay; the lab uses the production clock.
 lab.playback_speed=2.0
 lab.reset_fixture()
 check(is_equal_approx(float(lab.scene.speed_values[0]),2.0),"viewer preserves chosen speed when preparing a new motion")
 var before_death:=Time.get_ticks_msec()
 lab.play_death()
 scene=lab.scene
 await create_timer(0.24).timeout
 scene.paused=true
 var frozen_death: Texture2D=scene.sprites[lab.dragon_id].texture
 await create_timer(0.16).timeout
 check(scene.sprites[lab.dragon_id].texture==frozen_death,"production death sequence pauses during progressive decay")
 scene.paused=false
 check(await wait_idle(lab),"production decay completes")
 check(scene.sprites[lab.dragon_id].texture.resource_path.ends_with("/dragon/death-20.png"),"real permanent-death player reaches debris frame 20")
 check(scene.sprites[lab.dragon_id].modulate==Color.WHITE,"decay artwork stays readable instead of pre-dimming to generic corpse opacity")
 check(Time.get_ticks_msec()-before_death<5000,"chosen 2x death speed does not stall")
 lab.reset_fixture()
 check(lab.scene.rules.find_id(lab.dragon_id).alive,"replay can restore a dead preview dragon")
 lab.queue_free()
 await process_frame
 check(FileAccess.file_exists(save_path)==had_save and (not had_save or FileAccess.get_sha256(save_path)==save_before),"all real motion tests preserve personal map save bytes")
 print("DRAGON_COMBAT_TESTS: %d passed, %d failed" % [passed,failed])
 quit(0 if failed==0 else 1)
