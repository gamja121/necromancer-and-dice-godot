extends SceneTree
const LAB=preload("res://systems/final_dragon_battle_lab.gd")
var lab
var capture:=""
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--capture="): capture=argument.trim_prefix("--capture=")
 root.mode=Window.MODE_WINDOWED
 root.content_scale_size=Vector2i(1280,820)
 root.size=Vector2i(1280,820)
 lab=LAB.new()
 root.add_child(lab)
 DisplayServer.window_set_title("드래곤 전투 동작 확인 · 사건 연출 보존")
 if not capture.is_empty():
  DirAccess.make_dir_recursive_absolute(capture)
  await process_frame
  await save_picture("battle-idle")
  var unit: Dictionary=lab.scene.rules.find_id(lab.dragon_id)
  for item in [["attack",8,"attack-open"],["attack",9,"attack-bite"],["hit",3,"hit-recoil"],["death",10,"death-rot"],["death",20,"death-remains"]]:
   lab.scene.visuals.active[lab.dragon_id]=true
   lab.scene.sprites[lab.dragon_id].texture=lab.scene.texture(lab.scene.frame_path(unit,item[0],int(item[1])))
   await save_picture(str(item[2]))
  lab.queue_free()
  await process_frame
  print("DRAGON_BATTLE_GALLERY: native battlefield screenshots saved "+capture)
  quit(0)
func save_picture(name: String) -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(capture.path_join(name+".png"))
