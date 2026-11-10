extends RefCounted
## The three ordinary-region battle locations use existing hand-inked art.
## Snow and hell keep their old single images until those variants are wired.
## The independent RNG prevents background picks from altering combat rolls.
const NORMAL_FORESTS: Array[String] = [
    "res://assets/battle/backgrounds/dark-forest.jpg",
    "res://assets/battle/backgrounds/castle-forest.jpg",
    "res://assets/battle/backgrounds/graveyard-forest.jpg",
]
const WINTER = "res://assets/battle/backgrounds/snow-forest.jpg"
const HELL = "res://assets/battle/backgrounds/lava-forest.jpg"

static func choose_variant(encounter_id: String, world_seed: int) -> int:
    var picker := RandomNumberGenerator.new()
    picker.seed = ("%s:%s" % [str(world_seed), encounter_id]).hash()
    return picker.randi_range(0, NORMAL_FORESTS.size() - 1)

static func path_for(region: String, battle_receipt: Dictionary = {}) -> String:
    if region == "winter": return WINTER
    if region == "hell": return HELL
    # Compatibility: a battle started in an older version has no receipt.
    var index: int = int(battle_receipt.get("background_variant", 0))
    if index < 0 or index >= NORMAL_FORESTS.size(): index = 0
    return NORMAL_FORESTS[index]
