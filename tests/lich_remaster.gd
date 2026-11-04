extends SceneTree
# Read-only resource regression; never instantiate RunSession/Map or write player saves.
var failures := 0
var passes := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if ok: passes+=1
	else: failures+=1

func _initialize() -> void:
	var metrics: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_visual_metrics.json"))
	var profile: Dictionary=metrics["soul-reaper"]
	check(profile.width==640 and profile.height==512,"640x512 canvas")
	check(profile.bottom-profile.top+1==320,"normal class body320")
	check(profile.impact_frame==7,"downward impact frame7")
	for motion in {"attack":10,"hit":4,"death":11}:
		var count: int={"attack":10,"hit":4,"death":11}[motion]
		var expected: Array=[]
		for n in range(1,count+1): expected.append(n)
		# JSON numbers are floats; compare frame indices as integers like runtime.
		var actual: Array=profile[motion].map(func(n): return int(n))
		check(actual==expected,motion+" sequential mapping")
		for n in expected:
			var path := "res://assets/battle/frames/soul-reaper/%s-%02d.png" % [motion,n]
			var tex := load(path) as Texture2D
			check(tex!=null and tex.get_size()==Vector2(640,512),path.get_file())
	check(profile.attack_delays.size()==10 and profile.death_delays.size()==11,"per-frame timings")
	var first := (load("res://assets/battle/frames/soul-reaper/attack-01.png") as Texture2D).get_image()
	var mask := first.duplicate() as Image
	for y in mask.get_height():
		for x in mask.get_width():
			if mask.get_pixel(x,y).a<0.25: mask.set_pixel(x,y,Color.TRANSPARENT)
	var bounds := mask.get_used_rect()
	check(bounds.position.y==profile.top and bounds.end.y-1==profile.bottom and bounds.size.y==320,"imported texture alpha matches metrics")
	print("LICH RESOURCES ",passes," passed / ",failures," failed")
	quit(1 if failures else 0)
