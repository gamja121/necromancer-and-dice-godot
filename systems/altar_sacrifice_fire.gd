extends Control
signal finished
const Cards=preload("res://systems/layered_unit_card.gd")
const DURATION:=1.22
const BURN_SHADER="""
shader_type canvas_item;
render_mode unshaded;
uniform float progress=0.0;
uniform float clock=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment(){
vec4 paper=texture(TEXTURE,UV);
float ragged=(noise(UV*19.0)-0.5)*0.13+(noise(UV*47.0)-0.5)*0.035;
float field=UV.y+ragged;
float edge=1.12-progress*1.30;
float alive=1.0-smoothstep(edge-0.005,edge+0.009,field);
float charred=smoothstep(edge-0.13,edge-0.01,field);
float heat=exp(-abs(field-edge)*52.0)*alive;
float ignition=max(0.0,1.0-clock/0.14)*0.52;
vec3 burned=mix(paper.rgb,vec3(0.075,0.025,0.009),charred*0.90);
burned=burned*(1.0+ignition)+vec3(1.0,0.30,0.015)*heat*2.4;
COLOR=vec4(burned,paper.a*alive);
}
"""
var age:=0.0
var active:=false
var ended:=false
var completed:=false
var region:Rect2
var surface:TextureRect
var material_burn:ShaderMaterial
var viewport:SubViewport
var fire_atlas:Texture2D

func play(source:TextureRect,entry:Dictionary) -> void:
	size=Vector2(1280,720)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=300
	region=Rect2(source.position,source.size)
	fire_atlas=load("res://assets/map/ui/altar_fire_inkpaint_8frames.png")
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	if DisplayServer.get_name()=="headless":
		source.hide()
		active=true
		set_process(true)
		return
	var pad:=Vector2(24,28)
	viewport=SubViewport.new()
	viewport.size=Vector2i(source.size+pad*2.0)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(viewport)
	var holder:=Control.new()
	holder.size=Vector2(viewport.size)
	viewport.add_child(holder)
	var baked_card=Cards.make_preview(holder,entry,pad,source.size)
	preload("res://systems/altar_upgrade_badge.gd").sync(baked_card,entry)
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self) or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(source): return
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self) or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(source): return
	var image:Image=viewport.get_texture().get_image()
	var baked:=ImageTexture.create_from_image(image)
	surface=TextureRect.new()
	surface.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	surface.stretch_mode=TextureRect.STRETCH_SCALE
	surface.texture=baked
	surface.show_behind_parent=true
	surface.position=source.position-pad
	surface.size=source.size+pad*2.0
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code=BURN_SHADER
	material_burn=ShaderMaterial.new()
	material_burn.shader=shader
	surface.material=material_burn
	add_child(surface)
	viewport.queue_free()
	source.hide()
	active=true
	set_process(true)


func _process(delta:float) -> void:
	if not active: return
	age+=delta
	var progress:float=clampf((age-0.055)/0.86,0.0,1.0)
	if is_instance_valid(material_burn): material_burn.set_shader_parameter("progress",progress)
	if is_instance_valid(material_burn): material_burn.set_shader_parameter("clock",age)
	queue_redraw()
	if age>=DURATION:
		active=false
		if is_instance_valid(surface): surface.hide()
		queue_redraw()
		finish(true)

func _draw() -> void:
	if not active: return
	var fire:float=smoothstep(0.01,0.11,age)*(1.0-smoothstep(0.77,1.10,age))
	var progress:float=clampf((age-0.055)/0.86,0.0,1.0)
	var front:float=region.end.y+9.0-region.size.y*progress
	var center:Vector2=region.get_center()
	for i in range(4):
		draw_circle(Vector2(center.x,front-18.0),95.0+i*22.0,Color(1.0,0.27,0.015,fire*0.025))
	for i in range(14):
		var seed:float=float(i)
		var drift:float=fmod(age*66.0+seed*24.0,170.0)
		var x:float=center.x+sin(seed*5.73+age*1.6)*(35.0+seed*3.0)
		var y:float=region.position.y+145.0-drift
		var opacity:float=sin(clampf(drift/170.0,0.0,1.0)*PI)*0.14*(1.0-smoothstep(0.85,1.22,age))
		draw_set_transform(Vector2(x,y),0,Vector2(1.0,0.60))
		draw_circle(Vector2.ZERO,16.0+seed*1.7,Color(0.18,0.16,0.14,opacity))
	draw_set_transform(Vector2.ZERO)
	# Eight original painted frames; alpha blending preserves the ink outlines.
	if fire_atlas!=null and fire>0.001:
		var frame_index:int=int(floor(age*13.0))%8
		var source_rect:=Rect2(float(frame_index%4)*443.5,14.0 if frame_index<4 else 434.0,443.5,402.0)
		var width:float=(region.size.x+54.0)*lerpf(0.82,1.0,fire)
		var height:float=minf(188.0*lerpf(0.24,1.0,fire),maxf(6.0,(front-118.0)*402.0/390.0))
		var dest:=Rect2(Vector2(center.x-width*0.5,front-height*390.0/402.0),Vector2(width,height))
		draw_texture_rect_region(fire_atlas,dest,source_rect,Color(1.0,1.0,1.0,fire),false,true)
	for i in range(65):
		var seed:float=float(i)
		var born:float=0.045+fmod(seed*0.037,0.64)
		var life:float=(age-born)/0.64
		if life<0 or life>1: continue
		var x:float=region.position.x+fmod(seed*37.17,region.size.x)+sin(seed*4.2+life*6.0)*28.0*life
		var y:float=region.end.y-region.size.y*(born/0.87)-life*(65.0+fmod(seed*17.1,105.0))
		var alpha:float=sin(life*PI)*(1.0-smoothstep(1.04,1.22,age))
		var side:float=1.7+float(i%3)*0.65
		var ink:Color=Color(1.0,0.62,0.08,alpha) if i%3 else Color(0.30,0.27,0.23,alpha*0.9)
		draw_set_transform(Vector2(x,y),life*2.5+seed,Vector2.ONE)
		draw_rect(Rect2(Vector2(-side,-side),Vector2(side*2,side)),ink)
	draw_set_transform(Vector2.ZERO)


func finish(success:bool=false) -> void:
	if ended: return
	completed=success
	ended=true
	active=false
	set_process(false)
	hide()
	finished.emit()

func _exit_tree() -> void:
	finish()