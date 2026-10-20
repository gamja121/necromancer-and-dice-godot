class_name PresentationAccent
extends Control
## Short, deterministic accents over existing art. No input, RNG or saved state.
var kind: String = ""
var anchors: Array[Vector2] = []
var tint := Color("d9bb7d")
var caption: String = ""
var caption_rect := Rect2()
var age: float = 0.0
var duration: float = 0.7
var clock_source: Callable
var started: float = 0.0

static func legion_groups(units: Array, needs: Dictionary) -> Dictionary:
	var groups: Dictionary = {}
	for unit in units.slice(0,4):
		if unit.get("is_summon",false): continue
		for key in unit.get("legions",[]):
			if not groups.has(key): groups[key] = []
			groups[key].append(str(unit.id))
	for key in groups.keys():
		if groups[key].size()<int(needs.get(key,999)): groups.erase(key)
	return groups

static func create(parent: Control, effect_kind: String, points: Array[Vector2], color: Color,
		lifetime: float = 0.7, clock: Callable = Callable()) -> PresentationAccent:
	var cue := PresentationAccent.new()
	cue.name = "PresentationAccent_" + effect_kind
	cue.kind = effect_kind
	cue.anchors = points.duplicate()
	cue.tint = color
	cue.duration = maxf(0.1,lifetime)
	cue.clock_source = clock
	if clock.is_valid(): cue.started = float(clock.call())
	cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cue.focus_mode = Control.FOCUS_NONE
	cue.size = parent.size
	cue.z_index = 80
	parent.add_child(cue)
	return cue

func _process(delta: float) -> void:
	if clock_source.is_valid(): age = maxf(0.0,float(clock_source.call())-started)
	else: age += delta
	if age >= duration:
		queue_free()
		return
	queue_redraw()

func envelope(t: float) -> float:
	return smoothstep(0.0,0.12,t)*(1.0-smoothstep(0.48,1.0,t))

func _draw() -> void:
	var t := clampf(age/duration,0.0,1.0)
	match kind:
		"legion": _draw_link(t)
		"silk": _draw_silk(t)
		"dust", "bone": _draw_debris(t)
		"swamp", "discovery", "boss": _draw_tile(t)

func _draw_link(t: float) -> void:
	for i in range(anchors.size()):
		var local_t := clampf((t-float(i)*0.065)/0.80,0.0,1.0)
		var opacity := envelope(local_t)
		var at := anchors[i]
		# Four small, warm pinpricks at the card/body base; no neon body outline.
		for arm in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			draw_line(at+arm*3.0,at+arm*(8.0+local_t*5.0),Color(tint,opacity*0.8),1.2,true)
		if i == 0: continue
		var curve := PackedVector2Array()
		var reveal := smoothstep(0.08,0.44,t)
		for step in range(25):
			var u := float(step)/24.0*reveal
			var point := anchors[i-1].lerp(at,u)
			point.y += sin(u*PI)*11.0
			curve.append(point)
		draw_polyline(curve,Color(tint,envelope(t)*0.55),1.2,true)
	if not caption.is_empty():
		var font := get_theme_default_font()
		var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		var p := caption_rect.position+Vector2((caption_rect.size.x-width)*0.5,23.0-3.0*smoothstep(0.0,0.3,t))
		draw_string_outline(font,p,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18,3,Color(0.08,0.06,0.04,envelope(t)*0.8))
		draw_string(font,p,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(tint,envelope(t)))

func _draw_silk(t: float) -> void:
	if anchors.size()<2: return
	var target := anchors[1]
	var direction := (target-anchors[0]).normalized()
	# Keep the residue local to the impact. A screen-wide straight thread
	# reads as a laser and crosses unrelated combatants in a four-unit party.
	var origin := target-direction*34.0
	var side := direction.orthogonal()
	var reach := 1.0-pow(1.0-minf(1.0,t/0.20),3.0)
	var alpha := (1.0-smoothstep(0.20,1.0,t))*0.52
	# Thin, bowed strands follow the strike, then sag and disappear. This is
	# an attack accent, never a persistent web/status icon on the victim.
	for strand in range(3):
		var points := PackedVector2Array()
		for step in range(20):
			var u := float(step)/19.0*reach
			var bend := sin(u*PI)*(float(strand-1)*7.0+9.0*t)
			points.append(origin.lerp(target,u)+side*bend+Vector2(0,12.0*t*u))
		draw_polyline(points,Color(tint,alpha*(0.75 if strand!=1 else 1.0)),1.0,true)

func _draw_debris(t: float) -> void:
	if anchors.is_empty(): return
	for i in range(9 if kind=="dust" else 5):
		var phase := float(i)*2.39996
		var speed := 15.0+float(i%4)*8.0
		var offset := Vector2(cos(phase)*speed*t,-sin(float(i+1))*7.0-26.0*t+38.0*t*t)
		var alpha := sin(minf(1.0,t/0.13)*PI*0.5)*(1.0-t)
		var point := anchors[0]+offset
		if kind=="bone":
			draw_line(point,point+Vector2(cos(phase+t*4),sin(phase+t*4))*3.5,Color(tint,alpha*0.55),1.5,true)
		else:
			soft_spot(point,2.0+float(i%3)+t*5.0,Color(tint,alpha*0.12))

func soft_spot(point: Vector2, radius: float, color: Color) -> void:
	for ring in range(5,0,-1):
		var scale_value := float(ring)/5.0
		draw_circle(point,radius*scale_value,Color(color,color.a*(1.0-scale_value)*0.7))

func _draw_tile(t: float) -> void:
	for at in anchors:
		var alpha := envelope(t)
		if kind=="discovery":
			# A quiet glint points to the actual changed tile after the card closes.
			for arm in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				draw_line(at+arm*(27.0+t*5.0),at+arm*(34.0+t*8.0),Color(tint,alpha*0.75),1.6,true)
		else:
			for i in range(14):
				var phase := float(i)*2.39996
				var radius := 16.0+float(i%5)*5.0
				var point := at+Vector2(cos(phase)*radius,sin(phase)*radius*0.42-t*18.0)
				soft_spot(point,10.0+t*10.0,Color(tint,alpha*0.11))
			if kind=="boss":
				# Broken, hand-drawn looking arcs keep the map art legible.
				for i in range(3):
					var angle := float(i)*TAU/3.0-t*0.22
					draw_arc(at,30.0+6.0*smoothstep(0.0,0.4,t),angle,angle+1.2,18,Color(tint,alpha*0.55),1.3,true)
