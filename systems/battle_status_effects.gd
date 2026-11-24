extends RefCounted

const GUARD_FLASH_SECONDS := 0.42
const ICE_FORM_SECONDS := 0.45
const ICE_BREAK_SECONDS := 0.59
# Coordinates from the approved 165 px body reference: torso, pauldron, forearm.
const ICE_PLATES := [
	{"offset":Vector2(-7,0),"extent":Vector2(36.52,44.66),"rotation":-0.31,"contact":Vector2(10,33)},
	{"offset":Vector2(22,-46),"extent":Vector2(17.85,16.50),"rotation":0.20,"contact":Vector2(-16,16)},
	{"offset":Vector2(-57,19),"extent":Vector2(16.45,16.275),"rotation":-1.33,"contact":Vector2(12,-18)},
]
const ICE_SHEET := [
	Vector2(-1.0,0.06),Vector2(-0.84,-0.33),Vector2(-0.65,-0.38),Vector2(-0.53,-0.58),
	Vector2(-0.25,-0.59),Vector2(-0.12,-0.67),Vector2(0.22,-0.61),Vector2(0.43,-0.52),
	Vector2(0.60,-0.62),Vector2(0.85,-0.39),Vector2(1.0,-0.05),Vector2(0.90,0.24),
	Vector2(0.61,0.43),Vector2(0.28,0.43),Vector2(0.09,0.66),Vector2(-0.30,0.62),
	Vector2(-0.40,0.49),Vector2(-0.71,0.51),
]
const ICE_CHIP := [
	Vector2(-0.98,-0.08),Vector2(-0.32,-0.70),Vector2(0.42,-0.44),
	Vector2(0.86,-0.10),Vector2(0.44,0.45),Vector2(-0.21,0.46),
]
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

static func draw_ice(canvas: CanvasItem, pose: Transform2D, age: float) -> void:
	canvas.draw_set_transform_matrix(pose)
	for i in range(ICE_PLATES.size()):
		var stagger := float(i)*0.038
		var formed := smoothstep(stagger,stagger+0.29,age)
		if formed>0.0:
			_draw_ice_plate(canvas,i,lerpf(0.72,1.0,formed),formed,0.0)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_ice_shatter(canvas: CanvasItem, pose: Transform2D, age: float) -> void:
	const CRACK_SECONDS := 0.08
	canvas.draw_set_transform_matrix(pose)
	if age<CRACK_SECONDS:
		for i in range(ICE_PLATES.size()):
			_draw_ice_plate(canvas,i,1.0,1.0,0.96-age*4.2)
	else:
		var progress := clampf((age-CRACK_SECONDS)/(ICE_BREAK_SECONDS-CRACK_SECONDS),0.0,1.0)
		_draw_ice_shards(canvas,progress)
	canvas.draw_set_transform(Vector2.ZERO)


static func _draw_ice_shards(canvas: CanvasItem, progress: float) -> void:
	var fade := pow(1.0-progress,1.53)
	var scatter := ease(progress,0.47)
	for i in range(ICE_PLATES.size()):
		var offset: Vector2 = ICE_PLATES[i].offset
		var count := 6 if i==0 else 4
		for j in range(count):
			var direction := Vector2.RIGHT.rotated(float(i)*0.47+float(j)*TAU/count)
			var speed := offset.normalized()*(22.0+float(i)*8.0)+direction*(40.0+float((i+j)%4)*8.0)
			var shift := speed*scatter+Vector2(0,43.0*progress*progress)
			var origin := offset+direction*(4.0+float(j%3)*4.0)+shift
			var size := ((9.0 if i==0 else 5.0)+float((i+j)%4)*2.2)*lerpf(1.0,0.59,progress)
			var spin := float(i+j)*0.68+progress*(1.75 if j%2==0 else -1.55)
			var chip := PackedVector2Array()
			for point: Vector2 in ICE_CHIP:
				chip.append(origin+(point*Vector2(size,size*0.55)).rotated(spin))
			canvas.draw_colored_polygon(chip,Color(0.31,0.67,0.88,fade*0.48))
			_frost_face(canvas,[chip[0],chip[1],chip[2]],Color(0.75,0.94,1.0,fade*0.39))
			_frost_stroke(canvas,chip[0],chip[1],fade*0.87,1.15)


static func _draw_ice_plate(canvas: CanvasItem, index: int, size: float, opacity: float, flash: float) -> void:
	var plate: Dictionary = ICE_PLATES[index]
	var origin: Vector2 = plate.offset
	var extent: Vector2 = plate.extent*size
	var rotation: float = plate.rotation
	var points := PackedVector2Array()
	for i in range(ICE_SHEET.size()):
		var edge: Vector2 = ICE_SHEET[i]
		var cut := 0.98+0.16*sin(float((i+1)*(index+3))*1.13)
		var shear := 0.22*cos(float(index)*1.61)
		var skewed := Vector2(edge.x+edge.y*shear,edge.y)
		points.append(origin+(skewed*cut*extent).rotated(rotation))

	var contact: Vector2 = plate.contact
	var normal := contact.orthogonal().normalized()
	var elbow := origin+contact*0.71+normal*2.2
	var root := PackedVector2Array([origin+contact*0.43,elbow,origin+contact])
	canvas.draw_polyline(root,Color(0.31,0.59,0.74,opacity*0.43),4.2,true)
	canvas.draw_polyline(root,Color(0.66,0.85,0.93,opacity*(0.53+flash*0.23)),1.15,true)
	_frost_stroke(canvas,elbow,elbow+normal*5.2+contact*0.13,opacity*0.47,0.95)

	canvas.draw_colored_polygon(points,Color(0.40,0.69,0.81,opacity*(0.20+flash*0.25)))
	var vein := origin.lerp(points[10],0.16)
	_frost_face(canvas,[points[0],points[3],points[4],vein,points[16]],Color(0.62,0.83,0.94,opacity*0.19))
	_frost_face(canvas,[points[5],points[8],points[10],vein],Color(0.28,0.64,0.79,opacity*0.16))
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var frost := Color(0.81,0.94,1.0,opacity*(0.50+float(i%3)*0.10))
		var clear := Color(frost,0.02)
		var edge := PackedVector2Array([a,b,b.lerp(origin,0.47),a.lerp(origin,0.48)])
		canvas.draw_polygon(edge,PackedColorArray([frost,frost,clear,clear]))
		for j in range(3):
			var inset := 0.04+0.38*absf(sin(float(i*3+j+index)*3.1))
			var fleck := a.lerp(b,(float(j)+0.5)/3.0).lerp(origin,inset)
			canvas.draw_circle(fleck,0.42+0.28*float((i+j)%3),Color(0.88,0.97,1.0,opacity*(0.28+0.14*float(j))),true)

	var rim := points.duplicate()
	rim.append(points[0])
	canvas.draw_polyline(rim,Color(0.045,0.12,0.21,opacity*0.70),1.85,true)
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var highlight := 0.73 if i<2 else (0.48 if i%3==0 else 0.29)
		_frost_stroke(canvas,a,b,opacity*highlight*0.81,1.15)
		if i<3: _frost_stroke(canvas,a.lerp(b,0.18),a.lerp(b,0.80),opacity*0.52,1.8)

	var crack_tip := origin.lerp(points[2],0.16)
	var crack_joint := origin.lerp(points[5],0.22)
	var seam := PackedVector2Array([points[1].lerp(points[2],0.38),crack_tip,crack_joint,points[9]])
	canvas.draw_polyline(seam,Color(0.79,0.95,1.0,opacity*(0.37+flash*0.58)),1.25+flash,true)
	var branch := PackedVector2Array([crack_joint,origin.lerp(points[-1],0.38),points[-2].lerp(points[-1],0.56)])
	canvas.draw_polyline(branch,Color(0.73,0.91,1.0,opacity*(0.27+flash*0.60)),1.0,true)
	if flash>0.0: _frost_stroke(canvas,crack_tip,origin.lerp(points[4],0.56),opacity*flash*0.90,1.3)


static func _frost_face(canvas: CanvasItem, points: Array, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array(points),color)


static func _frost_stroke(canvas: CanvasItem, a: Vector2, b: Vector2, alpha: float, width: float) -> void:
	canvas.draw_line(a,b,Color(0.76,0.94,1.0,alpha),width,true)
