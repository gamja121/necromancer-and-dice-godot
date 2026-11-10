extends SceneTree
## One normal forest is chosen per battle, with exact save/reload continuity.
## Run with: godot --headless --path . --script scripts/test_random_normal_forest_backgrounds.gd
const Backdrops = preload("res://systems/battle_backgrounds.gd")
const Battle = preload("res://systems/battlefield_rules.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS forest-backdrops: ", label)
    else:
        failed += 1
        printerr("FAIL forest-backdrops: ", label)

func _run() -> void:
    var session: Node = root.get_node("RunSession")
    var saved_path: String = session.save_file_path
    var scratch: String = "user://forest_backdrops_%d.json" % OS.get_process_id()
    session.save_file_path = scratch

    check(Backdrops.NORMAL_FORESTS.size()==3, "exactly three normal location images")
    for path in Backdrops.NORMAL_FORESTS:
        check(ResourceLoader.exists(path), "normal art imported: "+path)
    check(Backdrops.NORMAL_FORESTS[0].ends_with("dark-forest.jpg"), "original temple forest reused")
    check(Backdrops.path_for("winter", {"background_variant":2})==Backdrops.WINTER, "snow art remains unchanged")
    check(Backdrops.path_for("hell", {"background_variant":2})==Backdrops.HELL, "hell art remains unchanged")
    check(Backdrops.path_for("default", {})==Backdrops.NORMAL_FORESTS[0], "old saves keep original forest")
    check(Backdrops.path_for("default", {"background_variant":99})==Backdrops.NORMAL_FORESTS[0], "invalid variant falls back safely")

    var seen: Dictionary = {}
    var stable: bool = true
    for i in range(120):
        var id: String = "encounter-%d" % i
        var selected: int = Backdrops.choose_variant(id,24680)
        stable = stable and selected==Backdrops.choose_variant(id,24680)
        seen[selected] = true
    check(stable and seen.size()==3, "all three variants selected and repeatably stable")

    session.start_new_world()
    var w = session.world
    var monster_index: int = w.tiles.find("monster")
    check(monster_index>=0, "new board has a normal monster tile")
    if monster_index>=0:
        w.position = monster_index
        var rng_before: int = w.rng.state
        var selected_ids: Array = [str(w.roster[0].id)]
        check(session.start_encounter(monster_index,selected_ids), "real normal encounter begins")
        if not session.encounter.is_empty():
            var picked: int = int(session.encounter.get("background_variant",-1))
            check(picked in [0,1,2], "selected normal background stored with encounter")
            check(w.active_encounter.get("background_variant",-1)==picked, "same variant stored in world save")
            var selected_path: String = Backdrops.path_for("default",session.encounter)
            check(selected_path==Backdrops.NORMAL_FORESTS[picked], "display resolves to chosen image")
            var before_reload: Dictionary = session.encounter.duplicate(true)
            session.reload_world()
            check(session.encounter==before_reload, "same battle and background survive restart")
            check(Backdrops.path_for("default",session.encounter)==selected_path, "background unchanged on resumed battle")

            var rules = Battle.new(session.world.definitions,1337)
            check(rules.restore(session.encounter.checkpoint), "saved battle checkpoint restores")
            for enemy in rules.units:
                if enemy.team=="enemy":
                    enemy.hp=0
                    enemy.alive=false
            check(session.finish_encounter(rules), "victory completes and saves harvest")
            var reward: Dictionary = session.world.pending_reward
            if reward.get("kind","")=="capture":
                check(reward.get("background_variant",-1)==picked, "harvest keeps battle background")
                session.reload_world()
                check(session.world.pending_reward.get("background_variant",-1)==picked, "harvest backdrop survives restart")
            else:
                check(false, "expected real capture reward")
        else:
            check(false, "missing newly started encounter")

    session.save_file_path=saved_path
    if FileAccess.file_exists(scratch):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
    print("FOREST_BACKDROP_TESTS pass=",passed," fail=",failed)
    quit(0 if failed==0 else 1)
