extends RefCounted
## A persisted index selects the same location across regional artwork sets.
const WINTER = "res://assets/battle/backgrounds/snow-forest.jpg"
const HELL = "res://assets/battle/backgrounds/lava-forest.jpg"
const NORMAL_FORESTS: Array[String] = [
    "res://assets/battle/backgrounds/dark-forest.jpg",
    "res://assets/battle/backgrounds/castle-forest.jpg",
    "res://assets/battle/backgrounds/graveyard-forest.jpg",
]
const WINTER_FORESTS: Array[String] = [
    WINTER,
    "res://assets/battle/backgrounds/snow-castle-forest.jpg",
    "res://assets/battle/backgrounds/snow-graveyard-forest.jpg",
]
const HELL_FORESTS: Array[String] = [
    HELL,
    "res://assets/battle/backgrounds/lava-castle-forest.jpg",
    "res://assets/battle/backgrounds/lava-graveyard-forest.jpg",
]

static func choose_variant(encounter_id: String, world_seed: int) -> int:
    var picker := RandomNumberGenerator.new()
    picker.seed = ("%s:%s" % [str(world_seed), encounter_id]).hash()
    return picker.randi_range(0, NORMAL_FORESTS.size() - 1)

static func path_for(region: String, battle_receipt: Dictionary = {}) -> String:
    var forests: Array[String] = NORMAL_FORESTS
    match region:
        "winter": forests = WINTER_FORESTS
        "hell": forests = HELL_FORESTS
    # Earlier receipts without a variant keep their region's first forest.
    var index: int = int(battle_receipt.get("background_variant", 0))
    if index < 0 or index >= forests.size(): index = 0
    return forests[index]
