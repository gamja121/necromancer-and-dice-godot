extends Control
## Isolated visual-only adapter. It does not alter battle rules or sprite materials.
## Effect rendering is intentionally inert until approved VFX resources are verified.
const Preferences = preload("res://systems/optional_battle_vfx_settings.gd")
var preferences: Dictionary = {}
var battle_scene: Control

func setup(owner_scene: Control) -> void:
	battle_scene = owner_scene
	preferences = Preferences.load_preferences()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func reload_preferences() -> void:
	preferences = Preferences.load_preferences()

func effect_enabled(effect_name: String) -> bool:
	return Preferences.active(preferences, effect_name)

func attack_started(_unit_id: String) -> void:
	if not effect_enabled("shadow_particle"):
		return
	# Pending verified upstream resource import and renderer compatibility check.
	pass

func impact_confirmed(_target_id: String) -> void:
	if not effect_enabled("energy_burst"):
		return
	# Pending verified upstream resource import and renderer compatibility check.
	pass

func death_confirmed(_unit_id: String) -> void:
	if not effect_enabled("dissolve"):
		return
	# Preserve existing permanent-death presentation until a safe replacement
	# has been validated. Never override the existing sprite shader.
	pass
