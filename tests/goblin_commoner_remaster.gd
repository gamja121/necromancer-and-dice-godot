extends SceneTree
# Portable, read-only resource and summon regression. No player save access.
const SLUG = "goblin-commoner"
var passes := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if ok: passes+=1
	else: failures+=1

func bounds(im: Image) -> Rect2i:
	var mask := im.duplicate() as Image
	for y in mask.get_height():
		for x in mask.get_width():
			if mask.get_pixel(x,y).a<0.25: mask.set_pixel(x,y,Color.TRANSPARENT)
	return mask.get_used_rect()

func _initialize() -> void:
	var metrics: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_visual_metrics.json"))
	var p: Dictionary=metrics[SLUG]
	check(p.width==576 and p.height==384,"576x384 frame canvas")
	check(p.bottom-p.top+1==320,"standing body320")
	check(p.impact_frame==7,"single punch impact7")
	check(p.attack_delays.size()==10 and p.death_delays.size()==8 and p.hit_interval>0,"motion pacing matches counts")
	for motion in {"attack":10,"hit":7,"death":8}:
		var count: int={"attack":10,"hit":7,"death":8}[motion]
		var expected: Array=[]
		for i in range(1,count+1): expected.append(i)
		check(p[motion].map(func(n): return int(n))==expected,motion+" sequential source mapping")
		for i in expected:
			var path := "res://assets/battle/frames/%s/%s-%02d.png" % [SLUG,motion,i]
			var tex := load(path) as Texture2D
			check(tex!=null and tex.get_size()==Vector2(576,384),path.get_file())
	var first := (load("res://assets/battle/frames/goblin-commoner/attack-01.png") as Texture2D).get_image()
	var b := bounds(first)
	check(b.size.y==320 and b.position.y==p.top and b.end.y-1==p.bottom,"imported alpha matches visual metrics")
	check(first.get_pixel(0,0).a==0 and first.get_pixel(575,383).a==0,"transparent canvas corners")
	var before := bounds((load("res://assets/battle/frames/goblin-commoner/attack-06.png") as Texture2D).get_image())
	var impact := bounds((load("res://assets/battle/frames/goblin-commoner/attack-07.png") as Texture2D).get_image())
	check(before.end.x<impact.end.x-15,"frame6 before contact; frame7 full extension")
	check(absi(before.position.y-impact.position.y)<=3 and absi(before.end.y-impact.end.y)<=3,"attack pair shares body height and floor")
	check(FileAccess.get_sha256("res://assets/battle/frames/goblin-commoner/death-07.png")!=FileAccess.get_sha256("res://assets/battle/frames/goblin-commoner/death-08.png"),"last two decay stages distinct")
	var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var d: Dictionary=definitions[SLUG]
	check(d.hp==10 and d.attack==1 and d.speed==1,"commoner stats HP10 ATK1 SPD1 unchanged")
	check(d.grade=="special" and d.brands.is_empty() and d.passives.is_empty(),"summon identity; no new brands/passives")
	var rules=load("res://systems/battlefield_rules.gd").new(definitions,9111)
	rules.start([rules.individual("goblin-chief","chief0"),rules.individual("goblin-chief","chief1")],[rules.individual("dracula","enemy0")])
	rules.begin_round(1)
	var pets: Array=rules.units.filter(func(u): return u.is_summon and u.slug==SLUG and u.team=="ally")
	check(pets.size()==1 and pets[0].slot==4 and pets[0].max_hp==10,"real chief summon uses remastered commoner")
	print("GOBLIN COMMONER RESOURCES ",passes," passed / ",failures," failed")
	quit(1 if failures else 0)
