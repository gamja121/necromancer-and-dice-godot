extends Control
## Presentation only. The owner commits and resumes the real graveyard reward.
## Uses the original front texture throughout; no reverse, flip, RNG or audio.
signal ready_to_collect
signal finished
signal _reveal_settled(success: bool)
signal _delivery_settled(success: bool)

const SIZE = Vector2(156,234)
const PAINTING_RECT = Rect2(150,148,980,406)
const REVEAL_TIME = 2.16
const DELIVERY_TIME = 0.98
const DIRT_SHADER = """
shader_type canvas_item;
render_mode unshaded;
uniform float shed=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),f.x),f.y);
}
void fragment(){
 vec4 paper=texture(TEXTURE,UV);
 float lumps=noise(UV*vec2(6.0,8.0)+vec2(1.9,3.1))*0.72+noise(UV*vec2(15.0,19.0))*0.28;
 float detach=0.20+noise(UV*vec2(7.0,9.0)+vec2(22.0,11.0))*0.69;
 float remain=1.0-smoothstep(detach-0.055,detach+0.085,shed);
 float grain=noise(UV*vec2(110.0,158.0));
 float thickness=smoothstep(0.40,0.67,lumps);
 vec3 earth=mix(vec3(0.16,0.090,0.034),vec3(0.43,0.29,0.13),0.22+grain*0.43+thickness*0.25);
 float ridge=1.0-smoothstep(0.0,0.065,abs(lumps-0.46));
 earth*=1.0-ridge*0.19;
 COLOR=vec4(earth,paper.a*remain);
}
"""

class Soil extends Control:
	var age: float = -1.0
	var ground := Vector2.ZERO
	func _draw() -> void:
		if age<0.0 or age>1.15: return
		for i in range(28):
			draw_set_transform(Vector2.ZERO)
			var seed: float = float(i)
			var life: float = (age-seed*0.006)/0.90
			if life<0.0 or life>1.0: continue
			var spread: float = sin(seed*2.71)*(30.0+seed*1.8)
			var point: Vector2 = ground+Vector2(spread*life,-sin(life*PI)*(29.0+float(i%7)*5.0)+life*11.0)
			var alpha: float = (1.0-life)*0.42
			var side: float = 3.0+float(i%4)*1.9
			if i%3==0:
				var points := PackedVector2Array([point+Vector2(-side,0),point+Vector2(0,-side*0.7),point+Vector2(side,1),point+Vector2(1,side*0.5)])
				draw_colored_polygon(points,Color(0.24,0.16,0.08,alpha*1.8))
			else:
				draw_set_transform(point,seed,Vector2(1.0,0.58))
				draw_circle(Vector2.ZERO,side*2.3,Color(0.56,0.40,0.20,alpha*0.60))
		draw_set_transform(Vector2.ZERO)

class DirtBits extends Control:
	var age: float = -1.0
	func _draw() -> void:
		if age<0.98 or age>2.16: return
		for i in range(46):
			draw_set_transform(Vector2.ZERO)
			var seed: float = float(i)
			var born: float = (1.03 if i<23 else 1.33)+fmod(seed*0.037,0.17)
			var life: float = (age-born)/0.62
			if life<0.0 or life>1.0: continue
			var initial := Vector2(10.0+fmod(seed*41.37,136.0),12.0+fmod(seed*59.71,202.0))
			var point: Vector2 = initial+Vector2(sin(seed*3.17)*24.0*life,14.0*life+79.0*life*life)
			var opacity: float = sin(life*PI)*(1.0-smoothstep(0.63,1.0,life))
			var side: float = 3.1+float(i%4)*0.90
			if i%3!=0:
				var shape := PackedVector2Array([point+Vector2(-side,-side*0.25),point+Vector2(-side*0.1,-side),point+Vector2(side,0),point+Vector2(side*0.4,side),point+Vector2(-side*0.7,side*0.55)])
				draw_colored_polygon(shape,Color(0.24,0.15,0.065,opacity*0.95))
				draw_line(point+Vector2(-side*0.4,-side*0.3),point+Vector2(side*0.5,side*0.2),Color(0.50,0.34,0.15,opacity*0.7),0.9,true)
			else:
				draw_set_transform(point,seed,Vector2(1.0,0.66))
				draw_circle(Vector2.ZERO,side*2.4,Color(0.58,0.43,0.24,opacity*0.24))
		draw_set_transform(Vector2.ZERO)

var phase: String = "idle"
var age: float = 0.0
var visual: Control
var front: TextureRect
var dirt: TextureRect
var dirt_material: ShaderMaterial
var soil: Soil
var crumbs: DirtBits
var painting_layer: Control
var source_center := Vector2(491,438)
var display_center := Vector2(638,313)
var _configured := false
var _reparenting := false
var _waiting_reveal := false
var _waiting_delivery := false
var _delivery_start := Vector2.ZERO
var _delivery_end := Vector2.ZERO
var _delivery_control := Vector2.ZERO
var _delivery_scale := Vector2.ONE

func setup(picture: String, source_point: Vector2 = Vector2(491,438), display_point: Vector2 = Vector2(638,313)) -> bool:
	if _configured or not ResourceLoader.exists(picture): return false
	var texture := load(picture) as Texture2D
	if texture==null: return false
	_configured = true
	name = "GraveyardRewardMotion"
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	source_center = source_point
	display_center = display_point
	painting_layer = Control.new()
	painting_layer.name = "GraveyardPaintingClip"
	painting_layer.position = PAINTING_RECT.position
	painting_layer.size = PAINTING_RECT.size
	painting_layer.clip_contents = true
	painting_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(painting_layer)
	soil = Soil.new()
	soil.name = "GraveyardGroundSoil"
	soil.size = PAINTING_RECT.size
	soil.ground = source_center-PAINTING_RECT.position
	soil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painting_layer.add_child(soil)
	visual = Control.new()
	visual.name = "GraveyardFoundDiceCard"
	visual.size = SIZE
	visual.pivot_offset = SIZE*0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.z_index = 4
	painting_layer.add_child(visual)
	front = TextureRect.new()
	front.name = "GraveyardOriginalFront"
	front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	front.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	front.size = SIZE
	front.texture = texture
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(front)
	dirt = TextureRect.new()
	dirt.name = "RemovableSoilCover"
	dirt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dirt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dirt.texture = texture
	dirt.position = Vector2(-2,-2)
	dirt.size = SIZE+Vector2(4,4)
	dirt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = DIRT_SHADER
	dirt_material = ShaderMaterial.new()
	dirt_material.shader = shader
	dirt.material = dirt_material
	front.add_child(dirt)
	crumbs = DirtBits.new()
	crumbs.name = "FallingCardSoil"
	crumbs.size = SIZE
	crumbs.z_index = 8
	crumbs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(crumbs)
	visual.hide()
	set_process(false)
	return true

func reveal() -> bool:
	if not _configured or phase!="idle" or not is_inside_tree(): return false
	phase = "digging"
	age = 0.0
	_waiting_reveal = true
	dirt_material.set_shader_parameter("shed",0.0)
	dirt.show()
	crumbs.show()
	soil.show()
	visual.show()
	_update_reveal()
	set_process(true)
	var success: bool = await _reveal_settled
	return success

## Restore a saved reward directly, without replaying excavation or emitting it again.
func show_ready() -> void:
	if not _configured or phase not in ["idle","ready"]: return
	_set_ready()

func _set_ready() -> void:
	phase = "ready"
	age = REVEAL_TIME
	set_process(false)
	visual.position = display_center-PAINTING_RECT.position-SIZE*0.5
	visual.scale = Vector2.ONE
	visual.rotation_degrees = 0.0
	visual.modulate = Color.WHITE
	visual.show()
	front.show()
	dirt_material.set_shader_parameter("shed",1.0)
	dirt.hide()
	soil.hide()
	crumbs.hide()

## A supplied parent safely lifts the card out of the closing location panel.
## target is in delivery_parent coordinates; without it, target is motion-local.
func deliver(target: Vector2, delivery_parent: Control = null) -> bool:
	if phase!="ready" or not is_inside_tree(): return false
	if delivery_parent!=null:
		if not is_instance_valid(delivery_parent) or not delivery_parent.is_inside_tree(): return false
		if get_parent()!=delivery_parent:
			_reparenting = true
			reparent(delivery_parent,true)
			_reparenting = false
		target = get_global_transform_with_canvas().affine_inverse()*(delivery_parent.get_global_transform_with_canvas()*target)
	# The discovery layers remain clipped; only the cleaned card flies to the deck.
	visual.reparent(self,true)
	soil.hide()
	crumbs.hide()
	dirt.hide()
	phase = "collecting"
	age = 0.0
	_waiting_delivery = true
	_delivery_start = visual.position
	_delivery_end = target-SIZE*0.5
	_delivery_control = _delivery_start.lerp(_delivery_end,0.45)+Vector2(0,-155)
	_delivery_scale = visual.scale
	set_process(true)
	var success: bool = await _delivery_settled
	return success

func _process(delta: float) -> void:
	if phase=="digging":
		age += delta
		_update_reveal()
		if age>=REVEAL_TIME:
			_set_ready()
			ready_to_collect.emit()
			if _waiting_reveal:
				_waiting_reveal = false
				_reveal_settled.emit(true)
	elif phase=="collecting":
		age += delta
		var t: float = smoothstep(0.04,DELIVERY_TIME,age)
		var q: float = 1.0-t
		visual.position = _delivery_start*q*q+_delivery_control*2.0*q*t+_delivery_end*t*t
		visual.scale = _delivery_scale.lerp(Vector2.ONE*0.10,t)
		visual.rotation_degrees = lerpf(0.0,20.0,t)
		visual.modulate.a = 1.0-smoothstep(0.89,1.0,t)
		if age>=DELIVERY_TIME:
			phase = "done"
			visual.hide()
			set_process(false)
			finished.emit()
			if _waiting_delivery:
				_waiting_delivery = false
				_delivery_settled.emit(true)

func _update_reveal() -> void:
	soil.age = age
	soil.queue_redraw()
	var rise: float = 1.0-pow(1.0-clampf((age-0.14)/0.74,0.0,1.0),3.0)
	var point: Vector2 = source_center.lerp(display_center,rise)
	var shake: float = exp(-pow((age-1.13)/0.13,2.0))+0.78*exp(-pow((age-1.43)/0.13,2.0))
	point += Vector2(sin(age*62.0)*3.4*shake,sin(age*54.0)*1.5*shake)
	visual.position = point-PAINTING_RECT.position-SIZE*0.5
	visual.scale = Vector2.ONE*lerpf(0.20,1.0,rise)
	visual.rotation_degrees = lerpf(-12.0,0.0,rise)+sin(age*52.0)*3.2*shake
	visual.modulate.a = smoothstep(0.14,0.38,age)
	dirt_material.set_shader_parameter("shed",smoothstep(0.98,1.97,age))
	crumbs.age = age
	crumbs.queue_redraw()

func cancel() -> void:
	if phase=="cancelled": return
	var revealing: bool = _waiting_reveal
	var delivering: bool = _waiting_delivery
	_waiting_reveal = false
	_waiting_delivery = false
	phase = "cancelled"
	set_process(false)
	hide()
	if revealing: _reveal_settled.emit(false)
	elif delivering: _delivery_settled.emit(false)

func _exit_tree() -> void:
	if not _reparenting: cancel()
