extends RefCounted
## Visual-only preferences. Separate from run saves and combat RNG.
const PATH = "user://optional_battle_vfx.cfg"
const KEYS = ["shadow_particle", "energy_burst", "dissolve"]

static func defaults() -> Dictionary:
	return {"enabled": false, "shadow_particle": true, "energy_burst": true, "dissolve": true}

static func load_preferences(path: String = PATH) -> Dictionary:
	var values = defaults()
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return values
	values.enabled = bool(config.get_value("battle_vfx", "enabled", false))
	for key in KEYS:
		values[key] = bool(config.get_value("battle_vfx", key, true))
	return values

static func save_preferences(values: Dictionary, path: String = PATH) -> Error:
	var config = ConfigFile.new()
	config.set_value("battle_vfx", "enabled", bool(values.get("enabled", false)))
	for key in KEYS:
		config.set_value("battle_vfx", key, bool(values.get(key, true)))
	return config.save(path)

static func active(values: Dictionary, effect_name: String) -> bool:
	return bool(values.get("enabled", false)) and effect_name in KEYS and bool(values.get(effect_name, true))
