class_name PresentationAccent
extends Control
## Short, deterministic accents over existing art. No input, RNG or saved state.
const LIFESTEAL_DELAY := 0.02
const LIFESTEAL_SECONDS := LIFESTEAL_DELAY+0.56

var kind: String = ""
var anchors: Array[Vector2] = []
var tint := Color("d9bb7d")
var caption: String = ""
var caption_rect := Rect2()
var age: float = 0.0
var duration: float = 0.7
var clock_source: Callable
var anchor_source: Callable
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
		"critical_shockwave": _draw_critical_shockwave(t)
		"lifesteal": _draw_lifesteal(t)
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
		var width := font.get_string_size(tr(caption),HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		var p := caption_rect.position+Vector2((caption_rect.size.x-width)*0.5,23.0-3.0*smoothstep(0.0,0.3,t))
		draw_string_outline(font,p,tr(caption),HORIZONTAL_ALIGNMENT_LEFT,-1,18,3,Color(0.08,0.06,0.04,envelope(t)*0.8))
		draw_string(font,p,tr(caption),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(tint,envelope(t)))

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

func _draw_critical_shockwave(t: float) -> void:
	if anchors.is_empty(): return
	var foot := anchors[0]
	for ring in range(2):
		var delay := float(ring)*0.13
		if t<delay: continue
		var phase := clampf((t-delay)*1.13,0.0,1.0)
		var radius := 15.0+108.0*(1.0-pow(1.0-phase,2.0))
		var contour := PackedVector2Array()
		for i in range(41):
			var angle := float(i)*TAU/40.0
			var uneven := radius*(1.0+sin(angle*7.0)*0.045+sin(angle*13.0)*0.028)
			contour.append(foot+Vector2(cos(angle)*uneven,sin(angle)*uneven*0.18))
		draw_polyline(contour,Color(tint,(1.0-phase)*0.79),2.4 if ring==0 else 1.3,true)
	var spread := 1.0-pow(1.0-t,2.0)
	var fade := (1.0-t)*0.74
	for i in range(14):
		var direction := -1.0 if i%2==0 else 1.0
		var x := direction*(6.0+(25.0+float(i%7)*8.0)*spread)
		var y := -sin(t*PI)*(10.0+float(i%5)*8.0)
		var point := foot+Vector2(x,y)
		if i%3==0:
			soft_spot(point,6.0+12.0*t,Color(0.69,0.52,0.33,fade*0.35))
		else:
			var chip_size := (3.0+float(i%4))*maxf(0.2,1.0-t)
			var chip := PackedVector2Array([
				point+Vector2(-chip_size,0),point+Vector2(chip_size*0.3,-chip_size),
				point+Vector2(chip_size,0),point+Vector2(0,chip_size*0.7)
			])
			draw_colored_polygon(chip,Color(0.77,0.59,0.37,fade))
			draw_line(chip[0],chip[1],Color(tint,fade),1.1,true)

func soft_spot(point: Vector2, radius: float, color: Color) -> void:
	for ring in range(5,0,-1):
		var scale_value := float(ring)/5.0
		draw_circle(point,radius*scale_value,Color(color,color.a*(1.0-scale_value)*0.7))

func _draw_lifesteal(t: float) -> void:
	var delay := LIFESTEAL_DELAY/LIFESTEAL_SECONDS
	if t<delay: return
	var points: Array[Vector2] = anchor_source.call() if anchor_source.is_valid() else anchors
	if points.size()<2: return
	var progress := (t-delay)/(1.0-delay)
	var donor := points[0]
	var receiver := points[1]
	var route := receiver-donor
	var distance := route.length()
	var fit := clampf(distance/235.0,0.35,1.0)
	var lift := 51.0*fit
	for i in range(3):
		_draw_lifesteal_wisp(donor,route,lift,fit,progress,i)

	var pull := progress/0.27
	if pull<1.0:
		var forward := _lifesteal_heading(route,lift,0.0)
		for i in range(9):
			var radial := Vector2.RIGHT.rotated(float(i)*2.399)
			var spark := donor+radial*(6.0+float(i%4)*5.0)*(1.0-pull)+forward*pull*35.0*fit
			draw_circle(spark,1.35+float(i%3)*0.60,Color(1.0,0.22,0.34,(1.0-pull)*0.86),true)
	var arrive := smoothstep(0.70,0.86,progress)*(1.0-smoothstep(0.86,1.0,progress))
	if arrive<=0.0: return
	draw_circle(receiver,24.0,Color(tint,arrive*0.22),true)
	draw_circle(receiver,9.0,Color(1.0,0.27,0.37,arrive*0.32),true)
	for i in range(6):
		var angle := float(i)*TAU/6.0
		draw_arc(receiver,17.0*lerpf(1.2,0.56,progress),angle,angle+0.52,8,Color(0.94,0.12,0.25,arrive*0.80),1.7,true)

func _lifesteal_heading(route: Vector2, lift: float, t: float) -> Vector2:
	return (route-Vector2(0,cos(t*PI)*PI*lift)).normalized()

func _lifesteal_wisp_point(donor: Vector2, route: Vector2, lift: float, fit: float,
		t: float, along: float, progress: float, strand: int) -> Vector2:
	var arc := sin(PI*t)
	var side := _lifesteal_heading(route,lift,t).orthogonal()
	var wave := sin(float(strand)*1.59+along*11.0-progress*6.0)
	return donor+route*t-Vector2(0,arc*lift)+side*(wave*(5.5+float(strand)*3.2)+float(strand-1)*10.0)*arc*fit

func _draw_lifesteal_wisp(donor: Vector2, route: Vector2, lift: float, fit: float, progress: float, strand: int) -> void:
	var leading := clampf((progress-float(strand)*0.055)/0.63,0.0,1.0)
	var trailing := lerpf(maxf(0.0,leading-0.68),1.0,smoothstep(0.64,1.0,progress))
	if (leading-trailing)*route.length()<5.0: return
	var opacity := smoothstep(0.0,0.15,progress)*(1.0-smoothstep(0.74,1.0,progress))
	for i in range(13):
		var along := float(i)/12.0
		var t := lerpf(trailing,leading,along)
		var point := _lifesteal_wisp_point(donor,route,lift,fit,t,along,progress,strand)
		point += _lifesteal_heading(route,lift,t).orthogonal()*sin(float(i)*1.8+progress*8.0)*5.5*fit
		var radius := (8.0+float(i%4)*2.4)*(0.50+0.50*sin(PI*along))*fit
		radius *= 1.0-0.65*smoothstep(0.65,1.0,t)
		draw_circle(point,radius,Color(0.33,0.011,0.048,opacity*0.12),true)
		draw_circle(point,radius*0.72,Color(0.55,0.018,0.082,opacity*0.13),true)

	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var ember := PackedVector2Array()
	for i in range(29):
		var along := float(i)/28.0
		var t := lerpf(trailing,leading,along)
		var point := _lifesteal_wisp_point(donor,route,lift,fit,t,along,progress,strand)
		var side := _lifesteal_heading(route,lift,t).orthogonal()
		var width := (2.0+pow(maxf(0.0,sin(PI*along)),0.73)*(8.5-float(strand)*1.65))*fit
		width *= 1.0-smoothstep(0.61,1.0,t)*0.75
		upper.append(point+side*width*(1.0+0.21*sin(float(i)*1.9+float(strand))))
		lower.append(point-side*width*(1.0+0.14*cos(float(i)*2.2)))
		ember.append(point+side*(0.7+1.6*sin(float(i)*0.77))*fit)
	var silhouette := upper.duplicate()
	lower.reverse()
	silhouette.append_array(lower)
	draw_colored_polygon(silhouette,Color(0.39+0.12*float(strand),0.012,0.076+0.024*float(strand),opacity*0.48))
	draw_polyline(upper,Color(0.30,0.005,0.045,opacity*0.39),2.4,true)
	draw_polyline(ember,Color(0.83,0.055+0.028*float(strand),0.18,opacity*0.37),3.1,true)
	draw_polyline(ember.slice(4,20),Color(0.99,0.26,0.32,opacity*0.33),1.15,true)
	for i in range(4):
		var t := lerpf(trailing,leading,(float(i)+1.0)/5.0)
		var spark := _lifesteal_wisp_point(donor,route,lift,fit,t,float(i)/4.0,progress,strand)
		draw_circle(spark+Vector2(0,-9.0-float(i%2)*4.0)*fit,1.25+float(i%3)*0.45,Color(0.99,0.12,0.26,opacity*0.65),true)

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
