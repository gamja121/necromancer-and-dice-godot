extends "res://scripts/test_ui_altar_ritual_stage5n.gd"
## Complete real transaction/restart suite with actual GPU framebuffers.
func locales() -> Array: return ["ko","en"]
func capture(tag:String) -> void:
	if DisplayServer.get_name()=="headless": return
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var shot:Image=root.get_texture().get_image()
	if check(shot.get_size()==Vector2i(1280,720) and shot.save_png("res://altar_random_%s.png"%tag)==OK,"actual native framebuffer "+tag):
		captures+=1
