extends RefCounted
## Early corruption bosses are chosen by the game designer, NOT rolled and
## NOT selectable by players. Previous named selections could not be recovered:
## the three slugs below are PROVISIONAL and editable in this one file.
##
## Contamination: 20-39 -> 20, 40-59 -> 40, 60-79 -> 60.
## Contamination 80+ retains the separate story-locked final dragon.
const ASSIGNMENTS = {20:"death-knight",40:"hydra",60:"kraken"}
const STAGES = [20,40,60]
const FINAL = 80
const PREFIX = "boss:contamination:"

static func current_stage(contamination: int) -> int:
	if contamination>=FINAL: return FINAL
	for i in range(STAGES.size()-1,-1,-1):
		if contamination>=STAGES[i]: return STAGES[i]
	return 0

static func stage_flag(stage: int) -> String:
	return "%s%d:defeated" % [PREFIX,stage]

static func defeated(flags: Dictionary, stage: int) -> bool:
	return flags.get(stage_flag(stage),false)==true

static func boss_slug(stage: int) -> String:
	return str(ASSIGNMENTS.get(stage,"dragon" if stage==FINAL else ""))

static func reserved_slugs() -> Array:
	return ASSIGNMENTS.values().duplicate()

static func valid(definitions: Dictionary) -> bool:
	var seen: Array = []
	for stage in STAGES:
		var slug: String = boss_slug(stage)
		if slug.is_empty() or slug in seen or not definitions.has(slug) or str(definitions[slug].grade) not in ["normal","advanced","hero"]: return false
		seen.append(slug)
	return true
