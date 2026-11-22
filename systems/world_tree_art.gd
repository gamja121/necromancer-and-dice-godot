extends RefCounted

const WINTER_RUINS = preload("res://assets/map/events/world-tree-ruins-winter.jpg")
const HELL_RUINS = preload("res://assets/map/events/world-tree-ruins-hell.jpg")
const LIVING_TILE = "res://assets/map/tiles/unknown.png"
const RUINS_TILES = {
	"winter": "res://assets/map/tiles/world_tree_ruins_winter.png",
	"hell": "res://assets/map/tiles/world_tree_ruins_hell.png",
}

static func tile_path(world) -> String:
	return RUINS_TILES[world.region] if world.world_tree_destroyed() else LIVING_TILE

static func ruins(region: String) -> Texture2D:
	match region:
		"winter": return WINTER_RUINS
		"hell": return HELL_RUINS
		_: return null
