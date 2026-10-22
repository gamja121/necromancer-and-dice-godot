extends SceneTree
const RIG = preload("res://systems/final_dragon_battle_rig.gd")
var viewport: SubViewport
var rig
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 viewport=SubViewport.new()
 viewport.size=RIG.CANVAS
 viewport.transparent_bg=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 rig=RIG.new()
 rig.mount(viewport)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RIG.DEST))
 var summary: Dictionary = {}
 for motion in RIG.COUNTS:
  summary[motion]=[]
  for index in range(int(RIG.COUNTS[motion])):
   rig.show_pose(RIG.pose(motion,index))
   await process_frame
   await RenderingServer.frame_post_draw
   var img: Image=viewport.get_texture().get_image()
   var target: String=RIG.DEST+"/%s-%02d.png" % [motion,index+1]
   if img.save_png(target)!=OK:
    push_error("Cannot save "+target)
    quit(1)
    return
   var used:=img.get_used_rect()
   summary[motion].append([used.position.x,used.position.y,used.size.x,used.size.y])
 print("DRAGON_BATTLE_RENDER: "+JSON.stringify(summary))
 print("DRAGON_BATTLE_FRAMES: 16 attack, 8 hit, 20 rot death; 1024x640; book assets unchanged")
 viewport.queue_free()
 rig=null
 await process_frame
 quit(0)
