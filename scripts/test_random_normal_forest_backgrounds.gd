extends SceneTree
## A regional backdrop is chosen once per battle and persists through harvest.
const Backdrops = preload("res://systems/battle_backgrounds.gd")
const Battle = preload("res://systems/battlefield_rules.gd")
const REGIONS = {
    "default": Backdrops.NORMAL_FORESTS,
    "winter": Backdrops.WINTER_FORESTS,
    "hell": Backdrops.HELL_FORESTS,
}
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

func test_paths() -> void:
    for region: String in REGIONS:
        var images: Array[String] = REGIONS[region]
        check(images.size()==3, region+" has three locations")
        for variant in range(images.size()):
            var path := Backdrops.path_for(region, {"background_variant":variant})
            check(path==images[variant] and ResourceLoader.exists(path), region+" loads "+path)
        check(Backdrops.path_for(region, {})==images[0], region+" old saves keep their original forest")
        check(Backdrops.path_for(region, {"background_variant":99})==images[0], region+" bad high variant falls back")
        check(Backdrops.path_for(region, {"background_variant":-1})==images[0], region+" bad low variant falls back")
    check(Backdrops.NORMAL_FORESTS[0].ends_with("dark-forest.jpg"), "original normal temple forest reused")
    check(Backdrops.path_for("winter")==Backdrops.WINTER, "winter legacy forest retained")
    check(Backdrops.path_for("hell")==Backdrops.HELL, "hell legacy forest retained")

func test_retained_battle(session: Node, region: String, variant: int) -> void:
    check(session.start_new_world(), region+" creates a disposable run")
    var world = session.world
    var index: int = world.tiles.find("monster")
    check(index>=0, region+" has a normal monster tile")
    if index<0: return
    world.region = region
    world.position = index
    var encounter_id: String = "encounter-%d" % world.next_serial
    for seed in range(100):
        if Backdrops.choose_variant(encounter_id,seed)==variant:
            world.rng.seed = seed
            break
    check(session.start_encounter(index,[str(world.roster[0].id)]), region+" starts a real encounter")
    if session.encounter.is_empty(): return
    check(session.encounter.get("background_variant",-1)==variant
        and world.active_encounter.get("background_variant",-1)==variant, region+" saves the selected variant")
    var chosen_path := Backdrops.path_for(region,session.encounter)
    check(chosen_path==REGIONS[region][variant], region+" resolves to the expected location")
    var before_reload: Dictionary = session.encounter.duplicate(true)
    check(session.reload_world() and session.world.region==region and
        session.encounter.get("id","")==before_reload.id and
        session.encounter.get("phase","")==before_reload.phase and
        session.encounter.get("background_variant",-1)==variant,
        region+" battle identity, phase and background survive restart")
    check(Backdrops.path_for(region,session.encounter)==chosen_path, region+" resumed battle keeps the same picture")

    var rules = Battle.new(session.world.definitions,1337)
    if not rules.restore(session.encounter.checkpoint):
        check(false, region+" battle checkpoint can be restored")
        return
    for enemy in rules.units:
        if enemy.team=="enemy":
            enemy.hp=0
            enemy.alive=false
    check(session.finish_encounter(rules), region+" victory completes and saves harvest")
    var reward: Dictionary = session.world.pending_reward
    check(reward.get("kind","")=="capture" and reward.get("background_variant",-1)==variant,
        region+" harvest retains the battle variant")
    check(session.reload_world() and session.world.pending_reward.get("background_variant",-1)==variant
        and Backdrops.path_for(region,session.world.pending_reward)==chosen_path,
        region+" harvest keeps the same picture after restart")

func _run() -> void:
    var session: Node = root.get_node("RunSession")
    var saved_path: String = session.save_file_path
    var scratch: String = "user://forest_backdrops_%d.json" % OS.get_process_id()
    session.save_file_path = scratch

    test_paths()
    var seen: Dictionary = {}
    var stable: bool = true
    for i in range(120):
        var id: String = "encounter-%d" % i
        var selected: int = Backdrops.choose_variant(id,24680)
        stable = stable and selected==Backdrops.choose_variant(id,24680)
        seen[selected] = true
    check(stable and seen.size()==3, "all three variants selected and repeatably stable")
    test_retained_battle(session,"default",0)
    test_retained_battle(session,"winter",1)
    test_retained_battle(session,"hell",2)

    session.save_file_path=saved_path
    for suffix in ["",".tmp"]:
        if FileAccess.file_exists(scratch+suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
    print("FOREST_BACKDROP_TESTS pass=",passed," fail=",failed)
    quit(0 if failed==0 else 1)
