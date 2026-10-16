extends SceneTree
const Settings = preload("res://systems/optional_battle_vfx_settings.gd")
const Adapter = preload("res://systems/optional_battle_vfx_adapter.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_path = "user://test_optional_battle_vfx_%d.cfg" % OS.get_process_id()
	var baseline = Settings.load_preferences(test_path)
	assert(not baseline.enabled, "Experimental VFX must default OFF")
	for key in Settings.KEYS:
		assert(not Settings.active(baseline, key), "All effects must be inert by default")
	var values = Settings.defaults()
	values.enabled = true
	values.energy_burst = false
	assert(Settings.save_preferences(values, test_path) == OK)
	var restored = Settings.load_preferences(test_path)
	assert(Settings.active(restored, "shadow_particle"))
	assert(not Settings.active(restored, "energy_burst"))
	assert(Settings.active(restored, "dissolve"))
	var adapter = Adapter.new()
	root.add_child(adapter)
	adapter.preferences = restored
	adapter.attack_started("dummy")
	adapter.impact_confirmed("dummy")
	adapter.death_confirmed("dummy")
	adapter.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("PASS optional battle VFX settings: default OFF, persistence, safe no-op adapter")
	quit(0)
