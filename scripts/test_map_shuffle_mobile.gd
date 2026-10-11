extends SceneTree
## Design-space mobile landscape projection regression for the map shuffle.
## Run: godot --headless --path . --script res://scripts/test_map_shuffle_mobile.gd
## This checks geometry at virtual mobile sizes; it is not a visual browser test.

const Layout = preload("res://systems/map_shuffle_layout.gd")
const Gather = preload("res://systems/map_shuffle_gather.gd")

const PHONES = [
	Vector2(640, 360),
	Vector2(667, 375),
	Vector2(800, 360),
	Vector2(844, 390),
	Vector2(960, 540),
	Vector2(1280, 720)
]

var passed := 0
var failed := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, name: String) -> void:
	if ok:
		passed += 1
		print("PASS shuffle-mobile: ", name)
	else:
		failed += 1
		printerr("FAIL shuffle-mobile: ", name)


func scaled_rect(center: Vector2, size: Vector2, offset: Vector2, ratio: Vector2) -> Rect2:
	return Rect2((center + offset - size * 0.5) * ratio, size * ratio)


func projection_is_safe(phone: Vector2) -> Dictionary:
	var ratio := phone / Vector2(1280.0, 720.0)
	var frame := Rect2(Vector2.ZERO, phone)
	var dice := Rect2(Vector2(602.0, 307.6) * ratio, Vector2(76.0, 76.0) * ratio)
	var slots: Array[Dictionary] = Layout.ring_slots()
	var no_overlap := true
	var inside_screen := true
	var dice_clear := true
	var min_width := INF
	var min_height := INF

	# Includes the face + faded contact shadow at 721 points in both orbits.
	for step in range(721):
		var progress: float = float(step) / 720.0
		var faces: Array[Rect2] = []
		var shadows: Array[Rect2] = []
		for slot in slots:
			var scale: float = float(slot["scale"])
			var size: Vector2 = Layout.TILE_SIZE * scale
			var center: Vector2 = Layout.orbit_position(slot, progress)
			var face := scaled_rect(center, size, Vector2.ZERO, ratio)
			var shadow := scaled_rect(center, size, Gather.SHADOW_OFFSET * scale, ratio)
			min_width = minf(min_width, face.size.x)
			min_height = minf(min_height, face.size.y)
			if not frame.encloses(face) or not frame.encloses(shadow):
				inside_screen = false
			if shadow.grow(2.0).intersects(dice) or face.grow(2.0).intersects(dice):
				dice_clear = false
			for earlier in faces:
				# A five-pixel visible clearance (2.5 on each edge) at 640px width.
				if face.grow(2.5).intersects(earlier.grow(2.5)):
					no_overlap = false
				if shadow.grow(2.5).intersects(earlier.grow(2.5)):
					no_overlap = false
			for earlier_shadow in shadows:
				if face.grow(2.5).intersects(earlier_shadow.grow(2.5)):
					no_overlap = false
			faces.append(face)
			shadows.append(shadow)

	return {
		"no_overlap": no_overlap,
		"inside_screen": inside_screen,
		"dice_clear": dice_clear,
		"min_width": min_width,
		"min_height": min_height
	}


func _run() -> void:
	for phone in PHONES:
		var report: Dictionary = projection_is_safe(phone)
		var size_label := "%dx%d" % [int(phone.x), int(phone.y)]
		check(bool(report["no_overlap"]), size_label + " ring tile/shadow clearance")
		check(bool(report["inside_screen"]), size_label + " full ring visible")
		check(bool(report["dice_clear"]), size_label + " dice remains clear")
		check(float(report["min_width"]) >= 28.0 and float(report["min_height"]) >= 21.0, size_label + " 28x21-pixel minimum moving tile silhouette")
		print("MOBILE_SHUFFLE_SIZE: %s / %.1f x %.1f px minimum" % [size_label, float(report["min_width"]), float(report["min_height"])])
	print("MAP_SHUFFLE_MOBILE: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
