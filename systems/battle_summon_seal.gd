extends Node2D
## Draws the floor markings and their light. The combatant owns the reveal shader.

const ENTRY_SECONDS := 0.97
const ROUND_SECONDS := 0.75
const INK := Color("6f4491")
const VIOLET := Color("ae7ded")
const BONE := Color("f3d8af")
var phase := -1.0
var radius := 94.0

func project(p: Vector2) -> Vector2:
	return Vector2(p.x*radius*(1.0+p.y*0.13),p.y*radius*0.255)

func on_circle(a: float, r: float) -> Vector2:
	return project(Vector2(cos(a),sin(a))*r)

func trace(begin: float, span: float, r: float, strength: float, detail: float) -> void:
	if span<=0.002 or strength<=0.0: return
	var line := PackedVector2Array()
	var segments := maxi(3,ceilf(span*13.0))
	for i in range(segments+1):
		var angle := begin+span*float(i)/float(segments)
		var worn := 1.0+sin(angle*21.0+r*18.0)*0.008+sin(angle*9.5)*0.006
		line.append(on_circle(angle,r*worn))
	draw_polyline(line,Color(0.065,0.039,0.075,strength*0.80),4.6,true)
	draw_polyline(line,Color(VIOLET,strength*0.19),5.1,true)
	draw_polyline(line,Color(INK.lerp(BONE,detail),strength),1.60,true)

func carve(begin: float, ending: float, radius_fraction: float, fill: float, opacity: float) -> void:
	var span := ending-begin
	trace(begin,span,radius_fraction,opacity*0.20,0.13)
	trace(begin,span*fill,radius_fraction,opacity*0.91,0.65)

func carved_letters(t: float, opacity: float) -> void:
	for i in range(15):
		var a := -PI*0.70+float(i)*TAU/15.0
		var amount := smoothstep(0.12+float(i)*0.016,0.22+float(i)*0.016,t)
		var center := Vector2.from_angle(a)*0.83
		var axis := Vector2.from_angle(a)
		var side := axis.orthogonal()
		var width := 0.019+0.004*float(i%2)
		var outer := center+axis*0.051
		var inner := center-axis*0.049
		var color := Color(VIOLET.lerp(BONE,0.61),opacity*amount)
		draw_line(project(outer),project(inner),color,1.28,true)
		var tick := 0.026 if i%2==0 else -0.026
		draw_line(project(inner+axis*0.018+side*width),project(outer-axis*0.023+side*tick),color,1.05,true)
		draw_line(project(center-side*width),project(center+axis*0.031+side*width*1.5),color,0.95,true)

func _draw() -> void:
	if phase<0.0 or phase>=1.0: return
	var t := phase
	var opacity := smoothstep(0.0,0.10,t)*(1.0-smoothstep(0.72,1.0,t))
	var lock := smoothstep(0.25,0.40,t)*(1.0-smoothstep(0.47,0.72,t))
	var fill := smoothstep(0.04,0.37,t)
	for i in range(11):
		var r := (1.12-float(i)*0.056)*(0.88+0.12*fill)
		var lit := PackedVector2Array()
		for j in range(41): lit.append(on_circle(float(j)*TAU/41.0,r))
		draw_colored_polygon(lit,Color(VIOLET,(0.017+lock*0.017)*opacity))
	for i in range(10):
		var edge := float(i)*TAU/10.0-PI*0.70
		var progress := clampf(fill*10.0-float(i),0.0,1.0)
		carve(edge,edge+0.574,1.0,progress,opacity)
		carve(edge+0.028,edge+0.596,0.692,progress,opacity*0.78)
	trace(-PI*0.70,TAU*smoothstep(0.13,0.41,t),0.928,opacity*0.64,0.52)
	carved_letters(t,opacity*0.88)
	var square := PackedVector2Array()
	for i in range(5):
		var a := float(i)*TAU/4.0+0.08
		square.append(on_circle(a,0.60))
	draw_polyline(square,Color(INK,opacity*fill*0.61),1.4,true)
	for i in range(4):
		var a := float(i)*TAU/4.0+0.08
		draw_line(on_circle(a,0.61),on_circle(a,0.68),Color(BONE,opacity*fill*0.83),1.45,true)
		var node := on_circle(a,0.968)
		draw_circle(node,2.7,Color(BONE,lock*0.66),true)

	if lock>0.0:
		var starts := [-0.79,-0.53,-0.31,0.34,0.58,0.79]
		for i in range(starts.size()):
			var field_x: float = starts[i]*radius
			var root := Vector2(field_x,-radius*0.055-float(i%3)*3.0)
			var height := (72.0+float((i*7)%4)*17.0)*clampf(radius/90.0,0.74,1.16)
			var lift := Vector2(-field_x*0.12,-height)
			var width := 6.5+float(i%3)*3.8
			var column := PackedVector2Array([root+Vector2(-width,3),root+Vector2(width,3),
				root+lift+Vector2(width*0.21,0),root+lift-Vector2(width*0.28,0)])
			var base := Color(VIOLET,lock*0.20)
			draw_polygon(column,PackedColorArray([base,Color(BONE,lock*0.25),Color(VIOLET,0.0),Color(VIOLET,0.0)]))
	for i in range(37):
		var born := 0.19+float((i*7)%13)*0.043
		var drift := clampf((t-born)/0.38,0.0,1.0)
		var life := smoothstep(0.0,0.15,drift)*(1.0-smoothstep(0.50,1.0,drift))
		if life<=0.0: continue
		var a := float(i)*2.399
		var point := on_circle(a,0.32+float(i%6)*0.13+drift*0.17)
		point += Vector2(sin(a+drift)*10.0,-(26.0+float(i%7)*6.0)*drift)
		var shade := Color(BONE if i%3==0 else VIOLET,life*0.84)
		draw_line(point,point+Vector2(0.1,-2.0-float(i%3)),shade,1.1,true)
