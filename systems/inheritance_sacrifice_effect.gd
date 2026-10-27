extends RefCounted
## Presentation only. HomeInheritance commits the original transaction first.
const DURATION := 1.24
const EXTRACT_AT := 0.17
const TRAVEL_AT := 0.20
const STAMP_AT := 0.88
const Cards = preload("res://systems/layered_unit_card.gd")
const Info = preload("res://systems/unit_info.gd")
const Inheritance = preload("res://systems/brand_inheritance.gd")
const Sound = preload("res://systems/game_audio.gd")

## Match the applied blessing, which can have sorted/filtered die faces.
## Same-type glyphs look identical; use the first visible compatible glyph.
## This lookup never makes another random choice or changes saved data.
static func source_index(donor: Dictionary, receiver_before: Dictionary, applied: Dictionary, definitions: Dictionary) -> int:
	var kind: String = str(applied.get("type", ""))
	var compatible := false
	for candidate in Inheritance.normalize(donor, definitions):
		if Inheritance.blessing(receiver_before, candidate, definitions) == applied:
			compatible = true
			break
	if not compatible: return -1
	var visible_index := 0
	for raw in donor.get("brands", []):
		if not raw is Dictionary or not Info.ICONS.has(str(raw.get("type", ""))): continue
		if visible_index >= 3: break
		if str(raw.type) == kind: return visible_index
		visible_index += 1
	return -1

static func play(host: Control, preview: TextureRect, hand_card: Control, receiver: TextureRect, context: Dictionary) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree(): return false
	if not is_instance_valid(preview) or not preview.is_inside_tree(): return false
	if not is_instance_valid(receiver) or not receiver.is_inside_tree(): return false
	var effect := BrandTransfer.new()
	effect.name = "InheritanceBrandTransfer"
	host.add_child(effect)
	effect.source_icon_index = source_index(context.get("donor", {}), context.get("receiver_before", {}), context.get("brand", {}), context.get("definitions", {}))
	effect.setup(preview, hand_card, receiver, context)
	await effect.finished
	var presented: bool = is_instance_valid(effect) and effect.completed
	if is_instance_valid(effect) and not effect.is_queued_for_deletion(): effect.queue_free()
	return presented

class BrandTransfer extends Control:
	signal finished
	var age := 0.0
	var source: TextureRect
	var hand_card: Control
	var receiver: TextureRect
	var receiver_entry: Dictionary
	var origin: Vector2
	var landing: Vector2
	var donor_center: Vector2
	var emblem: AtlasTexture
	var source_icon_index := -1
	var source_icon: TextureRect
	var landed_icon: TextureRect
	var landing_probe: TextureRect
	var probe_icon: TextureRect
	var source_scale := Vector2.ONE
	var source_color := Color.WHITE
	var receiver_color := Color.WHITE
	var stamped := false
	var ended := false
	var completed := false

	func local_center(item: Control) -> Vector2:
		return get_global_transform_with_canvas().affine_inverse() * (item.get_global_transform_with_canvas() * (item.size * 0.5))

	func setup(donor: TextureRect, hand: Control, target: TextureRect, context: Dictionary) -> void:
		size = Vector2(1280, 720)
		z_index = 250
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		source = donor
		hand_card = hand
		receiver = target
		receiver_entry = context.get("receiver", {}).duplicate(true)
		source_scale = source.scale
		source_color = source.modulate
		receiver_color = receiver.modulate
		donor_center = local_center(source)
		origin = donor_center
		var source_row := source.get_node_or_null("LayeredCardPreview/LayeredCardBrands") as Control
		if source_row != null and source_icon_index >= 0 and source_icon_index < source_row.get_child_count():
			source_icon = source_row.get_child(source_icon_index) as TextureRect
			if source_icon != null: origin = local_center(source_icon)
		landing = local_center(receiver)
		# Probe the exact appended slot with the same card layout as the live UI.
		# Keep it hidden and attached beside the target so panel motion is shared.
		if not receiver_entry.is_empty() and receiver.get_parent() is Control:
			landing_probe = TextureRect.new()
			landing_probe.name = "InheritanceLandingProbe"
			landing_probe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			landing_probe.position = receiver.position
			landing_probe.size = receiver.size
			landing_probe.mouse_filter = Control.MOUSE_FILTER_IGNORE
			receiver.get_parent().add_child(landing_probe)
			Cards.sync_preview(landing_probe, receiver_entry)
			landing_probe.hide()
			var row := landing_probe.get_node_or_null("LayeredCardPreview/LayeredCardBrands") as Control
			if row != null and row.get_child_count() > 0:
				probe_icon = row.get_child(row.get_child_count() - 1) as TextureRect
				if probe_icon != null: landing = local_center(probe_icon)
		var kind: String = str(context.get("brand", {}).get("type", ""))
		if Info.ICONS.has(kind):
			emblem = AtlasTexture.new()
			emblem.atlas = Cards.BRAND_ICON_EXTRA if kind in ["combo", "freeze", "lightspeed", "counter"] else Cards.BRAND_ICON_SHEET
			emblem.region = Info.ICONS[kind]
			emblem.filter_clip = true
		source.pivot_offset = source.size * 0.5

	func path(t: float) -> Vector2:
		var q: float = 1.0 - t
		# The arch crosses the top border, above the parchment's information.
		var a := Vector2(origin.x + 6.0, -10.0)
		var b := Vector2(landing.x - 6.0, -10.0)
		return origin*q*q*q + 3.0*a*q*q*t + 3.0*b*q*t*t + landing*t*t*t

	func _process(delta: float) -> void:
		if ended: return
		if not is_instance_valid(source) or not source.is_inside_tree() or not is_instance_valid(receiver) or not receiver.is_inside_tree():
			finish()
			return
		age += delta
		if is_instance_valid(probe_icon) and not stamped: landing = local_center(probe_icon)
		var drain: float = smoothstep(0.05, 0.47, age)
		source.modulate = source_color.lerp(Color(0.48, 0.60, 0.54, 0.0), drain)
		source.scale = source_scale * (1.0 - drain * 0.06)
		if is_instance_valid(hand_card): hand_card.modulate.a = 1.0 - drain
		if age >= EXTRACT_AT and is_instance_valid(source_icon): source_icon.hide()
		if age >= STAMP_AT and not stamped:
			stamped = true
			# The original receiver preview still has the old marks until arrival.
			if not receiver_entry.is_empty(): Cards.sync_preview(receiver, receiver_entry)
			var row := receiver.get_node_or_null("LayeredCardPreview/LayeredCardBrands") as Control
			if row != null and row.get_child_count() > 0:
				landed_icon = row.get_child(row.get_child_count() - 1) as TextureRect
				if landed_icon != null: landing = local_center(landed_icon)
			if is_instance_valid(landing_probe): landing_probe.queue_free()
			Sound.cue(get_parent(), "book_stamp")
		if stamped:
			if is_instance_valid(landed_icon): landing = local_center(landed_icon)
			var pulse: float = 1.0 - smoothstep(STAMP_AT, 1.18, age)
			receiver.modulate = receiver_color * Color(1.0 + pulse*0.10, 1.0 + pulse*0.20, 1.0 + pulse*0.15)
		queue_redraw()
		if age >= DURATION: finish(true)

	func finish(success: bool = false) -> void:
		if ended: return
		completed = success
		ended = true
		set_process(false)
		hide()
		if is_instance_valid(receiver): receiver.modulate = receiver_color
		if is_instance_valid(landing_probe) and not landing_probe.is_queued_for_deletion(): landing_probe.queue_free()
		finished.emit()

	func _exit_tree() -> void:
		# Release awaiters as cancelled; an exiting owner must not rebuild its UI.
		finish()

	func _draw() -> void:
		if ended: return
		if age < 0.52:
			var fade: float = 1.0 - smoothstep(0.22, 0.52, age)
			for i in range(9):
				var seed: float = float(i)
				var p: float = clampf((age - seed*0.009)/0.40, 0.0, 1.0)
				var start := donor_center + Vector2(sin(seed*2.3)*54.0, cos(seed*1.7)*77.0)
				var pos: Vector2 = start.lerp(origin, p) + Vector2(sin(p*PI + seed)*8.0, 0)
				draw_line(pos, pos + Vector2(4.0, -5.0), Color(0.34, 0.47, 0.38, fade*0.55), 1.4, true)
			draw_arc(origin, 20.0 + age*9.0, -PI*0.7, PI*1.1, 36, Color(0.85, 0.86, 0.65, fade), 1.8, true)
		if age >= EXTRACT_AT and age < STAMP_AT:
			var travel: float = smoothstep(TRAVEL_AT, STAMP_AT, age)
			for strand in range(3):
				var points := PackedVector2Array()
				for j in range(28):
					var u: float = clampf(travel - float(27 - j)/27.0*0.18, 0.0, 1.0)
					var pos: Vector2 = path(u) + Vector2(0.0, sin(u*19.0 + strand*1.8)*float(strand)*2.3)
					points.append(pos)
				draw_polyline(points, Color(0.15, 0.21, 0.16, 0.55), 4.0, true)
				draw_polyline(points, Color(0.38, 0.72, 0.64, 0.58 - float(strand)*0.12), 2.2, true)
				if strand == 0: draw_polyline(points, Color(0.94, 0.91, 0.69, 0.90), 1.0, true)
			var center: Vector2 = path(travel)
			var side: float = lerpf(29.0, 44.0, sin(travel*PI))
			draw_circle(center, side*0.64, Color(0.40, 0.74, 0.65, 0.12))
			draw_arc(center, side*0.65, age*4.0, age*4.0 + PI*1.55, 48, Color(0.87, 0.87, 0.66, 0.90), 1.2, true)
			if emblem != null: draw_texture_rect(emblem, Rect2(center - Vector2.ONE*side*0.5, Vector2.ONE*side), false)
		if age >= STAMP_AT:
			var p: float = clampf((age - STAMP_AT)/0.36, 0.0, 1.0)
			var ink := Color(0.59, 0.84, 0.70, 1.0 - p)
			draw_arc(landing, 17.0 + p*23.0, 0, TAU, 64, Color(0.18, 0.27, 0.20, (1.0 - p)*0.7), 3.5, true)
			draw_arc(landing, 17.0 + p*23.0, 0, TAU, 64, ink, 1.6, true)
			draw_arc(landing, 14.0 + p*13.0, PI*0.10, PI*1.85, 48, Color(0.96, 0.90, 0.64, 1.0 - p), 1.3, true)
			for i in range(6):
				var angle: float = TAU*float(i)/6.0
				var direction := Vector2(cos(angle), sin(angle))
				draw_line(landing + direction*(23.0 + p*14.0), landing + direction*(29.0 + p*16.0), ink, 1.2, true)
