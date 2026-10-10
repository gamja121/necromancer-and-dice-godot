extends RefCounted
## Stage 1 pilot: skull wax-seal marker on a selected parchment action button.
## Only the first press selects. A second press invokes the original callback.
## No red glow, no new animation, no persistent game state in this stage.

const SEAL_SIZE := Vector2(32.0, 32.0)

static func attach(button: Button, original_action: Callable, seal_texture: Texture2D) -> void:
	if not is_instance_valid(button) or seal_texture == null:
		return
	# The button() factory already wired the original callback. Replace only
	# this pilot button's action, leaving all other button handlers intact.
	if not button.pressed.is_connected(original_action):
		push_warning("WaxSealSelection: original button action not connected.")
		return
	button.pressed.disconnect(original_action)

	var seal := TextureRect.new()
	seal.name = "WaxSealSelected"
	seal.texture = seal_texture
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.size = SEAL_SIZE
	# Slightly overlap the right edge, keeping the central lettering legible.
	seal.position = Vector2(button.size.x - SEAL_SIZE.x * 0.7, (button.size.y - SEAL_SIZE.y) * 0.5)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.visible = false
	seal.z_index = 1
	button.add_child(seal)

	button.pressed.connect(func() -> void:
		if not is_instance_valid(button) or button.disabled:
			return
		if not seal.visible:
			seal.show()
			return
		if original_action.is_valid():
			original_action.call()
	)
