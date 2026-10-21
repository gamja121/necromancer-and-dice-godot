extends Node
## Shared, presentation-only text reveal: narration first, then dialogue.
## Does not touch event progress, choice callbacks, or saved state.
@export var characters_per_second: float = 42.0

var entries: Array[Label] = []
var cursor: int = 0
var remainder: float = 0.0

func _ready() -> void:
	set_process(false)

func track(label: Label) -> void:
	if not is_instance_valid(label): return
	entries.append(label)
	label.visible_characters = 0
	set_process(true)

func clear() -> void:
	entries.clear()
	cursor = 0
	remainder = 0.0
	set_process(false)

func is_revealing() -> bool:
	for label in entries:
		if is_instance_valid(label) and label.visible_characters >= 0 and label.visible_characters < label.get_total_character_count():
			return true
	return false

func reveal_all() -> bool:
	if not is_revealing(): return false
	for label in entries:
		if is_instance_valid(label): label.visible_characters = -1
	cursor = entries.size()
	remainder = 0.0
	set_process(false)
	return true

func _process(delta: float) -> void:
	if cursor >= entries.size():
		set_process(false)
		return
	var label: Label = entries[cursor]
	if not is_instance_valid(label):
		cursor += 1
		return
	var total: int = label.get_total_character_count()
	if total <= 0:
		label.visible_characters = -1
		cursor += 1
		return
	remainder += delta * characters_per_second
	var step: int = int(remainder)
	if step <= 0: return
	remainder -= float(step)
	label.visible_characters = mini(total,maxi(0,label.visible_characters) + step)
	if label.visible_characters >= total:
		cursor += 1
		if cursor >= entries.size(): set_process(false)
