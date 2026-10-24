extends RefCounted
## Visual-only paper peel: animate the existing parchment Button artwork,
## never a second painted asset, and never mutate the reward/receipt state.
## Call ONLY after the operation's save has succeeded.
const SHAKE_SECONDS := 0.09
const RELEASE_SECONDS := 0.10
const FALL_SECONDS := 0.48

static func play(paper: Button) -> void:
	if not is_instance_valid(paper) or not paper.is_inside_tree(): return
	if paper.has_meta("spent_paper_falling"): return
	paper.set_meta("spent_paper_falling",true)
	paper.disabled=true
	paper.mouse_filter=Control.MOUSE_FILTER_IGNORE
	paper.focus_mode=Control.FOCUS_NONE
	paper.tooltip_text=""
	var original_pos: Vector2=paper.position
	# Disable the regular hover/click tween before taking ownership of transforms.
	var button_effect=paper.get_node_or_null("ButtonEffectsModule")
	if button_effect!=null:
		button_effect.stop_animation()
		button_effect.set_process(false)
		button_effect.set_process_input(false)
	paper.pivot_offset=Vector2(paper.size.x*0.18,paper.size.y*0.10)
	var tear=paper.create_tween()
	tear.tween_property(paper,"rotation_degrees",-5.0,SHAKE_SECONDS).set_trans(Tween.TRANS_SINE)
	tear.tween_property(paper,"rotation_degrees",8.0,RELEASE_SECONDS).set_trans(Tween.TRANS_SINE)
	await tear.finished
	if not is_instance_valid(paper) or not paper.is_inside_tree(): return
	var fly=paper.create_tween().set_parallel(true)
	fly.tween_property(paper,"position",original_pos+Vector2(180.0,maxf(350.0,780.0-original_pos.y)),FALL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(paper,"rotation_degrees",48.0,FALL_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly.tween_property(paper,"scale",Vector2(0.78,0.78),FALL_SECONDS).set_trans(Tween.TRANS_SINE)
	fly.tween_property(paper,"modulate:a",0.0,FALL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fly.finished
	if is_instance_valid(paper):
		paper.queue_free()
