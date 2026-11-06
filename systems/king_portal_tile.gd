extends RefCounted

const ACTIVE_FLAG = "visual:ritual_portal:king_warp_active"
const TARGET_PREFIX = "visual:ritual_portal:king_warp_index:"
const PATHS = [
	"res://assets/map/tiles/king_portal_01.webp",
	"res://assets/map/tiles/king_portal_02.webp",
	"res://assets/map/tiles/king_portal_03.webp",
	"res://assets/map/tiles/king_portal_04.webp",
	"res://assets/map/tiles/king_portal_05.webp",
]

static func target(world) -> int:
	if world.event_flags.get(ACTIVE_FLAG,false)!=true: return -1
	for index in range(world.tiles.size()):
		if world.tiles[index]=="warp" and world.event_flags.get(TARGET_PREFIX+str(index),false)==true:
			return index
	return -1

## Paint one existing warp, favoring the farther endpoint. The position is
## a boolean receipt so old v1 saves and transactional rollback share a schema.
static func paint(world) -> bool:
	if target(world)>=0: return false
	var chosen: int = -1
	var longest: int = -1
	for index in range(world.tiles.size()):
		if world.tiles[index]!="warp" or index==world.position: continue
		var distance: int = absi(index-world.position)
		distance=mini(distance,world.tiles.size()-distance)
		if distance>longest:
			chosen=index
			longest=distance
	# A legacy board may have one remaining warp and no safe repair tile.
	if chosen<0: chosen=world.tiles.find("warp")
	if chosen<0: return false
	for key in world.event_flags.keys():
		if str(key).begins_with(TARGET_PREFIX): world.event_flags.erase(key)
	world.event_flags[ACTIVE_FLAG]=true
	world.event_flags[TARGET_PREFIX+str(chosen)]=true
	return true
