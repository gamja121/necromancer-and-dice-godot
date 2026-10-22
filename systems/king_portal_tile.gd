extends RefCounted
## Story-only cosmetic transformation on another warp stone.
## Warp movement, counts, RNG, boss spawn and hero position remain unchanged.
const ACTIVE_FLAG = "visual:ritual_portal:king_warp_active"
const TARGET_FLAG = "visual:ritual_portal:king_warp_index"
const PATHS = [
	"res://assets/map/tiles/king_portal_01.webp",
	"res://assets/map/tiles/king_portal_02.webp",
	"res://assets/map/tiles/king_portal_03.webp",
	"res://assets/map/tiles/king_portal_04.webp",
	"res://assets/map/tiles/king_portal_05.webp"
]

static func active(world) -> bool:
	return world != null and world.event_flags.get(ACTIVE_FLAG,false)==true

static func target(world) -> int:
	if not active(world) or world.tiles.size()!=24: return -1
	var index: int=int(world.event_flags.get(TARGET_FLAG,-1))
	if index<0 or index>=24 or index==world.position or world.tiles[index]!="warp": return -1
	return index

## Choose another warp without advancing world RNG. Never replace a hero tile.
static func choose_target(world) -> int:
	if world == null or world.tiles.size()!=24: return -1
	var result: int=-1
	var longest: int=-1
	for index in range(world.tiles.size()):
		if index==world.position or world.tiles[index]!="warp": continue
		var clockwise: int=(index-world.position+24)%24
		var distance: int=mini(clockwise,24-clockwise)
		if distance>longest:
			longest=distance
			result=index
	return result

## Caller includes this in the SAME world transaction as the story outcome.
static func activate(world) -> bool:
	if world==null: return false
	if active(world) and target(world)>=0: return true
	var chosen: int=choose_target(world)
	if chosen<0: return false
	world.event_flags[ACTIVE_FLAG]=true
	world.event_flags[TARGET_FLAG]=chosen
	return true

## Invoked when a new lap shuffles tiles, never on ordinary render.
## Only changes which warp is painted; leaves both warp tiles mechanically intact.
static func refresh_after_shuffle(world) -> void:
	if not active(world): return
	if target(world)>=0: return
	var chosen: int=choose_target(world)
	if chosen>=0: world.event_flags[TARGET_FLAG]=chosen

static func texture_path(world, index: int) -> String:
	return PATHS[4] if target(world)==index else ""
