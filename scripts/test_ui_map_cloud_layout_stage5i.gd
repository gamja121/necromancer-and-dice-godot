extends SceneTree
## Stage 5I: CSS-source cloud geometry/phase parity; no gameplay state changes.
const Presenter = preload("res://systems/map_presentation.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("PASS ui-cloud-layout: ",title)
	else:
		failed += 1
		printerr("FAIL ui-cloud-layout: ",title)

func closef(a: float, b: float, tolerance: float = 0.8) -> bool:
	return absf(a-b)<tolerance

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var presenter = Presenter.new()
	root.add_child(presenter)
	presenter.setup(Control.new())
	var expected_variants = [1,2,3,4,2,1,4,3]
	var widths = [0.75,0.67,0.78,0.71,0.76,0.69,0.80,0.72]
	var anchors = [-0.21,-0.10,0.06,0.18,0.39,0.48,-0.18,-0.09]
	var offsets = [-0.05,0.03,0.05,-0.04,-0.03,0.04,0.04,-0.04]
	var rotations = [-4.0,3.0,2.0,-3.0,3.0,-2.0,-3.0,3.0]
	var scales = [1.22,1.14,1.20,1.16,1.20,1.15,1.24,1.17]
	var speeds = [0.72,1.12,0.98,0.85,1.12,0.72,0.85,0.98]
	var delays = [0.0,0.165,0.115,0.065,0.165,0.0,0.065,0.115]
	check(Presenter.CLOUD_LANES.size()==8,"source has exactly eight ordered cloud lanes")
	for i in range(8):
		var lane: Dictionary = Presenter.CLOUD_LANES[i]
		var variant: int = expected_variants[i]
		var filename: String = "map_cloud_transition%s.png" % ("" if variant==1 else "_%d" % variant)
		var texture: Texture2D = presenter.textures.get(filename)
		var geo: Dictionary = presenter.cloud_lane_geometry(i,texture)
		var width: float = 1280.0*widths[i]
		var height: float = width*float(texture.get_height())/float(texture.get_width())
		var base_y: float = (720.0*(1.0-anchors[i])-height) if i>=6 else 720.0*anchors[i]
		var delta_y: float = height*offsets[i]
		var left: bool = i%2==0
		var start_x: float = -998.4-width*0.22 if left else 2278.4-width*0.78
		var covered_x: float = -998.4+width*1.08 if left else 2278.4-width*2.08
		var opening_x: float = -998.4+width*2.35 if left else 2278.4-width*3.35
		check(int(lane["variant"])==variant and closef(float(lane["width"]),widths[i],0.0001),"lane %d source order/width" % (i+1))
		check(closef(geo["dimensions"].x,width) and closef(geo["dimensions"].y,height),"lane %d preserves image aspect ratio" % (i+1))
		check(closef(geo["start"].x,start_x) and closef(geo["start"].y,base_y+delta_y),"lane %d original CSS offscreen start and vertical anchor" % (i+1))
		check(closef(geo["covered"].x,covered_x) and closef(geo["covered"].y,base_y+delta_y*0.18),"lane %d CSS 108pct cover with offset contraction" % (i+1))
		check(closef(geo["opening"].x,opening_x) and closef(geo["opening"].y,base_y-delta_y*1.5),"lane %d CSS 235pct exit position" % (i+1))
		var original_rotation: float = rotations[i] if left else -rotations[i]
		check(closef(geo["start_rotation"],original_rotation) and closef(geo["covered_rotation"],original_rotation*0.22) and closef(geo["opening_rotation"],original_rotation*-1.6),"lane %d source rotation phases" % (i+1))
		check(closef(geo["start_scale"],scales[i]) and closef(geo["covered_scale"],scales[i]*1.02) and closef(geo["opening_scale"],scales[i]*1.08),"lane %d source per-lane sprite scales" % (i+1))
		check(closef(geo["duration"],speeds[i]) and closef(geo["delay"],delays[i]),"lane %d original stagger timings" % (i+1))
	check(Presenter.CLOUD_LANES[6]["bottom"] and Presenter.CLOUD_LANES[7]["bottom"],"bottom two lanes use CSS bottom anchors, not arbitrary top percentages")
	for i in range(6): check(not bool(Presenter.CLOUD_LANES[i]["bottom"]),"upper lane %d remains top anchored" % (i+1))
	var damaged: Texture2D = presenter.textures.get("map_cloud_transition_4.png")
	if damaged!=null:
		var area: Rect2i = damaged.get_image().get_used_rect()
		if float(area.size.y)<float(damaged.get_height())*0.5:
			print("KNOWN_LIMITATION cloud 4 has incomplete alpha silhouette; original web file is damaged and replacement art is not approved. Bounds=",area)
		else:
			print("CLOUD_ART_CHECK cloud 4 alpha extent=",area)
	presenter.queue_free()
	await process_frame
	print("UI_CLOUD_LAYOUT_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
