extends RefCounted

const WINTER_RUINS = preload("res://assets/map/events/world-tree-ruins-winter.jpg")
const HELL_RUINS = preload("res://assets/map/events/world-tree-ruins-hell.jpg")

static func ruins(region: String) -> Texture2D:
	match region:
		"winter": return WINTER_RUINS
		"hell": return HELL_RUINS
		_: return null
