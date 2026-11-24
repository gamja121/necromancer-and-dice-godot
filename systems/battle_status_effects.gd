extends RefCounted

const GUARD_FLASH_SECONDS := 0.42
const ICE_FORM_SECONDS := 0.45
const ICE_BREAK_SECONDS := 0.59
const ICE_OFFSETS := [Vector2(-62,-19),Vector2(-34,-62),Vector2(-50,25),Vector2(11,-45),Vector2(43,3),Vector2(20,43)]
const ICE_RADII := [22.0,15.0,17.5,16.5,17.5,13.0]
const OCTAGON := [Vector2(-0.52,-1),Vector2(0.52,-1),Vector2(1,-0.52),Vector2(1,0.52),
	Vector2(0.52,1),Vector2(-0.52,1),Vector2(-1,0.52),Vector2(-1,-0.52)]

static func draw_guard(canvas: CanvasItem, center: Vector2, extent: Vector2, time: float, block_age: float) -> void:
	var progress := clampf(block_age/GUARD_FLASH_SECONDS,0.0,1.0)
	var blocking := block_age>=0.0
	var strength := (0.80+0.20*sin(time*3.6)) if not blocking else pow(1.0-progress,1.4)*1.72
	for ring in range(3):
		var spread := (0.68+float(ring)*0.205)*(1.0+0.25*ease(progress,0.45))
		var size := extent*spread
		var opacity := strength*(0.63+float(2-ring)*0.12)
		for i in range(OCTAGON.size()):
			var a: Vector2 = OCTAGON[i]*size
			var b: Vector2 = OCTAGON[(i+1)%OCTAGON.size()]*size
			var light := 0.58+0.42*maxf(0.0,-(a.y+b.y)/(size.y*2.0))
			var ember := Color(0.89,0.31,0.12,0.0)
			var gold := Color(1.0,0.66+0.17*light,0.36+0.22*light,minf(1.0,opacity*light*0.62))
			var rim := Color(1.0,0.86,0.59,minf(1.0,opacity*light*0.75))
			var band := PackedVector2Array([center+a*0.72,center+a,center+b,center+b*0.72])
			canvas.draw_polygon(band,PackedColorArray([ember,gold,gold,ember]))
			canvas.draw_line(center+a,center+b,Color(gold,opacity*0.14),5.0,true)
			canvas.draw_line(center+a,center+b,rim,1.55,true)

static func draw_ice(canvas: CanvasItem, center: Vector2, size: float, age: float) -> void:
	for i in range(ICE_OFFSETS.size()):
		var stagger := float(i)*0.035
		var formed := smoothstep(stagger,stagger+ICE_FORM_SECONDS-0.175,age)
		if formed<=0.0: continue
		var origin: Vector2 = center+ICE_OFFSETS[i]*size
		var radius: float = ICE_RADII[i]*size*lerpf(0.74,1.0,formed)
		_draw_ice_cell(canvas,origin,radius,formed*(0.92+0.08*sin(age*3.0+i)),0.0)

static func draw_ice_shatter(canvas: CanvasItem, center: Vector2, size: float, age: float) -> void:
	const CRACK_SECONDS := 0.08
	if age<CRACK_SECONDS:
		for i in range(ICE_OFFSETS.size()):
			_draw_ice_cell(canvas,center+ICE_OFFSETS[i]*size,ICE_RADII[i]*size,1.0,1.0-age*4.0)
		return
	var t := clampf((age-CRACK_SECONDS)/(ICE_BREAK_SECONDS-CRACK_SECONDS),0.0,1.0)
	var fade := pow(1.0-t,1.65)
	for i in range(ICE_OFFSETS.size()):
		var offset: Vector2 = ICE_OFFSETS[i]*size
		var origin := center+offset
		var outline := _ice_outline(origin,ICE_RADII[i]*size)
		for j in range(outline.size()):
			var a := outline[j]
			var b := outline[(j+1)%outline.size()]
			var centroid := (origin+a+b)/3.0
			var kick := offset.normalized()*(34.0+float(i%3)*9)
			kick += Vector2.RIGHT.rotated(float(j)*TAU/6.0+float(i)*0.47)*(43.0+float((i+j)%4)*8.0)
			var shift := (kick*ease(t,0.5)+Vector2(0,34.0*t*t))*size
			var spin := (0.7+float(j%3)*0.41)*t*(-1.0 if j%2==0 else 1.0)
			var chip := PackedVector2Array()
			for point: Vector2 in [origin,a,b]:
				chip.append(centroid+shift+(point-centroid).rotated(spin)*lerpf(0.90,0.48,t))
			canvas.draw_colored_polygon(chip,Color(0.32,0.72,1.0,fade*0.39))
			canvas.draw_line(chip[1],chip[2],Color(0.55,0.88,1.0,fade*0.86),1.25,true)

static func _ice_outline(origin: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(6):
		var offset := Vector2.RIGHT.rotated(PI/6.0+float(i)*TAU/6.0)*radius
		points.append(origin+offset*Vector2(1.06,1.0))
	return points

static func _draw_ice_cell(canvas: CanvasItem, origin: Vector2, radius: float, strength: float, flash: float) -> void:
	var points := _ice_outline(origin,radius)
	var colors := PackedColorArray()
	for i in range(points.size()):
		var alpha := (0.11+0.055*sin((i+1)*1.1)+0.14*flash)*strength
		colors.append(Color(0.22+0.17*flash,0.62+0.20*flash,1.0,alpha))
	canvas.draw_polygon(points,colors)
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var edge := (0.62+0.14*sin(float(i)*1.6)+0.22*flash)*strength
		canvas.draw_line(a,b,Color(0.22,0.58,0.96,edge*0.24),4.0,true)
		canvas.draw_line(a,b,Color(0.39+0.23*flash,0.74+0.18*flash,1.0,edge),1.35,true)
	canvas.draw_line(points[3].lerp(points[4],0.12),points[3].lerp(points[4],0.75),Color(0.79,0.94,1.0,strength*0.57),1.55,true)
	if flash>0.0:
		var split := PackedVector2Array([points[3],origin+Vector2(-0.16,-0.15)*radius,origin+Vector2(0.2,0.24)*radius,points[0]])
		canvas.draw_polyline(split,Color(0.80,0.95,1.0,flash*0.95),1.65,true)
