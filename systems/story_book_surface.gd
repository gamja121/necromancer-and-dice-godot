extends Control
## Approved cover and paper mesh. Orthographic rotation keeps page height fixed.
const SPREAD := Rect2(40,60,1200,600)
var open_texture: Texture2D = preload("res://assets/map/ui/story_book_open.png")
var cover_texture: Texture2D = preload("res://assets/map/ui/story_book_cover.png")
var progress := 0.0
func _leaf_uv(u: float,v: float) -> Vector2:
	# Every turning sheet uses the same paper outline and the exact UVs
	# of the stationary page. The gutter curves, but the sheet never scales.
	var crease := pow(1.0-u,7.0)
	var top := lerpf(0.112,0.137,crease)
	var bottom := lerpf(0.878,0.902,crease)
	return Vector2(lerpf(0.5,0.055,u),lerpf(top,bottom,v))

func _point(u: float,v: float,angle: float,leaf: bool) -> Vector2:
	var lift := sin(angle)
	if leaf:
		var uv := _leaf_uv(u,v)
		var radius := (0.5-uv.x)*SPREAD.size.x
		var curl := sin(u*PI)*lift*12.0
		# Orthographic rotation: only the horizontal projection changes.
		# At PI these coordinates land exactly on the original open-book art.
		return Vector2(640.0+cos(angle)*radius+curl,SPREAD.position.y+uv.y*SPREAD.size.y)
	# The cover keeps the same physical height throughout its rotation.
	# Do not divide by perspective depth: it made the book shrink and regrow.
	var radius := u*590.4
	return Vector2(640.0+cos(angle)*radius,360.0+(v-0.5)*534.0)

func _face(angle: float,leaf: bool,alpha: float=1.0) -> void:
	var front := cos(angle)>=0.0 and not leaf
	var texture := cover_texture if front else open_texture
	var segments := 32 if leaf else 20
	for i in range(segments):
		var u := float(i)/float(segments)
		var next := float(i+1)/float(segments)
		# Keep the complete outer spine on the same hinged mesh as the cover.
		# Its 20-pixel overhang sits outside the hinge instead of being cropped.
		var bound_u := lerpf(-20.0/590.4,1.0,u) if front else u
		var bound_next := lerpf(-20.0/590.4,1.0,next) if front else next
		var vertices := PackedVector2Array([
			_point(bound_u,0,angle,leaf),_point(bound_next,0,angle,leaf),
			_point(bound_next,1,angle,leaf),_point(bound_u,1,angle,leaf)])
		var uv: PackedVector2Array
		if front:
			# Crop transparent padding only; preserve the whole leather spine,
			# binding ribs, brass corners and the face as one continuous object.
			uv = PackedVector2Array([
				Vector2(lerpf(53.0/1340.0,1282.0/1340.0,u),34.0/1174.0),
				Vector2(lerpf(53.0/1340.0,1282.0/1340.0,next),34.0/1174.0),
				Vector2(lerpf(53.0/1340.0,1282.0/1340.0,next),1122.0/1174.0),
				Vector2(lerpf(53.0/1340.0,1282.0/1340.0,u),1122.0/1174.0)])
		elif leaf:
			uv = PackedVector2Array([
				_leaf_uv(u,0),_leaf_uv(next,0),_leaf_uv(next,1),_leaf_uv(u,1)])
		else:
			# Same physical hinge and silhouette on both sides of the cover.
			# This crop maps exactly back to SPREAD when the cover lies flat.
			uv = PackedVector2Array([
				Vector2(lerpf(0.5,0.008,u),0.055),Vector2(lerpf(0.5,0.008,next),0.055),
				Vector2(lerpf(0.5,0.008,next),0.945),Vector2(lerpf(0.5,0.008,u),0.945)])
		var light := 0.80+0.20*absf(cos(angle))
		if leaf: light = 0.77+0.23*absf(cos(angle))-sin(angle)*sin((u+next)*0.5*PI)*0.06
		draw_polygon(vertices,PackedColorArray([Color(light,light,light,alpha)]),uv,texture)
	if leaf:
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		for i in range(33):
			top.append(_point(float(i)/32.0,0,angle,true))
			bottom.append(_point(float(i)/32.0,1,angle,true))
		draw_polyline(top,Color(0.43,0.30,0.16,0.3*alpha*sin(angle)),0.9,true)
		draw_polyline(bottom,Color(0.38,0.24,0.12,0.4*alpha*sin(angle)),1.0,true)

func _draw() -> void:
	if open_texture == null or cover_texture == null: return
	var front_ratio := clampf((progress-0.025)/0.79,0,1)
	var front_angle := PI*smoothstep(0.0,1.0,front_ratio)
	var shift := Vector2(-295.2*(1.0+minf(cos(front_angle),0.0)),0)
	draw_set_transform(shift)
	var left := 640.0+minf(cos(front_angle),0.0)*585.0
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.015,0.01,0.005,0.34)
	shadow.set_corner_radius_all(16)
	draw_style_box(shadow,Rect2(left+5,103,1234-left,529))
	if progress>=0.9999:
		draw_texture_rect(open_texture,SPREAD,false)
		return
	var source_size := open_texture.get_size()
	draw_texture_rect_region(open_texture,Rect2(640,60,600,600),
		Rect2(source_size.x*0.5,0,source_size.x*0.5,source_size.y))
	# Moving shadow on the stationary right-hand leaf.
	var sweep := sin(front_angle)
	if sweep>0.01:
		var shade := PackedVector2Array([Vector2(638,121),Vector2(640+170*sweep,135),
			Vector2(640+170*sweep,593),Vector2(638,605)])
		draw_colored_polygon(shade,Color(0.12,0.07,0.025,0.18*sweep))
	# Leaves exist behind the front cover from the start. They must never
	# suddenly pop in above its outside face before it passes edge-on.
	if cos(front_angle)>=0.0:
		_draw_leaves()
		_face(front_angle,false)
	else:
		_face(front_angle,false)
		_draw_leaves()
	# The closed book shows leather along the spine. Reveal its inner gutter
	# only after the outer face turns away, keeping the same physical hinge.
	if cos(front_angle)<0.0:
		draw_texture_rect_region(open_texture,Rect2(626,60,28,600),
			Rect2(source_size.x*(0.5-14.0/1200.0),0,source_size.x*28.0/1200.0,source_size.y))

func _draw_leaves() -> void:
	for i in range(3):
		var start := 0.12+float(i)*0.045
		var leaf_ratio := clampf((progress-start)/(0.79-float(i)*0.015),0,1)
		if leaf_ratio<=0.01: continue
		var angle := PI*smoothstep(0.0,1.0,leaf_ratio)
		_face(angle,true)
