extends RefCounted
## Registered full-canvas ImageGen layers from the seven approved paintings.
## Values place the untouched PNGs; no texture cropping or runtime pixel scans.
## A player reply mirrors the rumor protagonist into the opposite picture side.
const DRAW_RECTS = {
	"manuscript_village_villagers.png": Rect2(0.07860532,0.08726301,0.82245370,0.82245370),
	"manuscript_village_necromancer.png": Rect2(0.14903730,0.14386792,0.75457547,0.75457547),
	"manuscript_commander_actor.png": Rect2(0.14562312,0.14062312,0.73937688,0.73937688),
	"manuscript_hunter_scene.png": Rect2(0.11966643,0.15832512,0.74167488,0.74167488),
	"manuscript_cultist_procession.png": Rect2(0.07976889,0.16001170,0.82503435,0.82503435),
	"manuscript_altar_ritual.png": Rect2(0.13560403,0.19867205,0.71409396,0.71409396),
	"manuscript_altar_summon.png": Rect2(0.12390772,0.16465499,0.73471438,0.73471438),
	"manuscript_portal_energy.png": Rect2(0.10374613,0.11303869,0.77647059,0.77647059),
	"manuscript_portal_cultists.png": Rect2(0.05479341,0.04002331,0.86642191,0.86642191),
	"manuscript_portal_omen.png": Rect2(0.08116953,0.08308791,0.81691209,0.81691209),
	"manuscript_hunt_scene.png": Rect2(0.08574089,0.06938639,0.85753341,0.85753341),
}

static func layer_bounds(path: String, dimensions: Vector2, mirrored_player: bool = false) -> Rect2:
	var normalized: Rect2 = DRAW_RECTS.get(path.get_file(),Rect2(0,0,1,1))
	if mirrored_player:
		normalized.position.x = 1.0-normalized.end.x
	return Rect2(normalized.position*dimensions,normalized.size*dimensions)
