extends SceneTree
## Capture actual rendered village-rumor book scenes in CI, using a disposable
## abandoned-child save. Never change gameplay rules or personal saves.
const MAP = preload("res://map.tscn")
const STORY = preload("res://systems/story_event_entry.gd")
const RUMOR = preload("res://systems/village_rumor_entry.gd")
const BEATS = preload("res://systems/village_rumor_beats.gd")

var failures: int = 0
var captured: int = 0
var output: String = "user://village-rumor-screens"
var save_file: String = ""

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if ok:
        print("PASS village-capture: ", label)
    else:
        failures += 1
        printerr("FAIL village-capture: ", label)

func save_view(map: Control, filename: String, text_label: String) -> void:
    check(is_instance_valid(map.overlay), text_label + " book opened")
    if not is_instance_valid(map.overlay): return
    if map.overlay.has_method("skip_opening"):
        map.overlay.skip_opening()
    if map.overlay.has_method("reveal_for_input"):
        map.overlay.reveal_for_input()
    await create_timer(1.3).timeout
    await RenderingServer.frame_post_draw
    var view: Image = root.get_texture().get_image()
    check(view != null and not view.is_empty(), text_label + " real renderer pixels")
    if view == null or view.is_empty(): return
    var colors: Dictionary = {}
    for y in range(9):
        for x in range(15):
            colors[view.get_pixel(int((x+0.5)*view.get_width()/15), int((y+0.5)*view.get_height()/9)).to_html(false)] = true
    check(colors.size() > 12, text_label + " nonblank distinct colors")
    var path: String = output.path_join(filename)
    var error: Error = view.save_png(path)
    check(error == OK, text_label + " PNG file saved")
    if error == OK:
        captured += 1
        print("VILLAGE_GUI_SCREENSHOT ",path," ",view.get_width(),"x",view.get_height())

func _run() -> void:
    output = OS.get_environment("VILLAGE_CAPTURE_DIR")
    if output.is_empty(): output = "user://village-rumor-screens"
    check(DisplayServer.get_name() != "headless", "actual non-headless graphical renderer")
    check(DirAccess.make_dir_recursive_absolute(output) == OK, "screen output directory created")
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
    DisplayServer.window_set_size(Vector2i(1280,720))
    var session: Node = root.get_node("RunSession")
    var old_path: String = session.save_file_path
    save_file = "user://village_gui_capture_%d.json" % OS.get_process_id()
    session.save_file_path = save_file
    session.start_new_world()
    session.world.contamination = 93
    session.world.lap_ready = true
    session.world.leave_home()
    var grave: int = session.world.tiles.find("graveyard")
    var village: int = session.world.tiles.find("village")
    check(grave >= 0 and village >= 0, "real game board has cemetery and village")
    if grave >= 0 and village >= 0:
        session.world.position = grave
        check(STORY.begin(session,grave), "original child event begins")
        check(STORY.choose(session,grave,"leave"), "abandoned-child branch created only in temporary save")
        session.world.position = village
        check(RUMOR.begin(session,village) == RUMOR.ABANDONED_ID, "actual village rumor unlocked")
        var map: Control = MAP.instantiate()
        root.add_child(map)
        current_scene = map
        for i in range(8): await process_frame
        if is_instance_valid(map.overlay): map.close_overlay()
        check(BEATS.count(RUMOR.ABANDONED_ID) == 6, "real six-beat abandoned branch")
        for beat_index in [0,1,2,3]:
            if beat_index > 0:
                check(RUMOR.advance(session,village,RUMOR.ABANDONED_ID,beat_index-1), "actual Continue persists step %d" % beat_index)
            check(RUMOR.current_beat(session,RUMOR.ABANDONED_ID) == beat_index, "correct story step %d" % beat_index)
            map.show_village_rumor_beat(village,RUMOR.ABANDONED_ID)
            await save_view(map,"%02d_village_rumor_real_game.png" % beat_index, "beat %d" % beat_index)
        current_scene = null
        map.queue_free()
        await process_frame
    session.save_file_path = old_path
    for suffix in ["",".tmp"]:
        var path: String = save_file + suffix
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("VILLAGE_GUI_CAPTURE: %d captured, %d failed" % [captured,failures])
    quit(0 if failures == 0 and captured == 4 else 1)
