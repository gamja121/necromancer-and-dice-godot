extends Node
const ContaminationHud = preload("res://systems/contamination_hud.gd")
const CloudFog = preload("res://systems/cloud_transition_fog.gd")
const HEAL = [[8,18,22,0,1080,-4],[18,30,26,70,1020,4],[29,22,21,140,1120,-3],[40,43,29,40,1060,4],[52,27,24,180,1160,-4],[64,38,28,100,1040,3],[75,20,21,230,1100,-3],[87,34,25,150,1060,4],[93,51,20,290,1080,-3],[12,57,24,330,1040,3],[25,69,22,220,1140,-4],[37,60,27,390,1020,4],[49,74,20,450,1100,-3],[61,64,25,300,1060,3],[73,78,22,500,1120,-4],[84,69,28,410,1040,4],[94,82,21,540,1080,-3],[56,50,20,580,1000,3]]
# Fixed CSS source positions/speeds: v2-map-practice.css lines 705–748.
# Bottom lanes are anchored from the screen bottom, not from a top percentage.
const CLOUD_LANES = [
	{"variant":1,"width":0.75,"anchor":-0.21,"bottom":false,"y":-0.05,"rot":-4.0,"scale":1.22,"duration":0.72,"delay":0.0},
	{"variant":2,"width":0.67,"anchor":-0.10,"bottom":false,"y":0.03,"rot":3.0,"scale":1.14,"duration":1.12,"delay":0.165},
	{"variant":3,"width":0.78,"anchor":0.06,"bottom":false,"y":0.05,"rot":2.0,"scale":1.20,"duration":0.98,"delay":0.115},
	{"variant":4,"width":0.71,"anchor":0.18,"bottom":false,"y":-0.04,"rot":-3.0,"scale":1.16,"duration":0.85,"delay":0.065},
	{"variant":2,"width":0.76,"anchor":0.39,"bottom":false,"y":-0.03,"rot":3.0,"scale":1.20,"duration":1.12,"delay":0.165},
	{"variant":1,"width":0.69,"anchor":0.48,"bottom":false,"y":0.04,"rot":-2.0,"scale":1.15,"duration":0.72,"delay":0.0},
	{"variant":4,"width":0.80,"anchor":-0.18,"bottom":true,"y":0.04,"rot":-3.0,"scale":1.24,"duration":0.85,"delay":0.065},
	{"variant":3,"width":0.72,"anchor":-0.09,"bottom":true,"y":-0.04,"rot":3.0,"scale":1.17,"duration":0.98,"delay":0.115}
]
var map
var gauge: Control
var corruption: ColorRect
var textures: Dictionary = {}
func setup(scene) -> void:
	map = scene
	# The frozen web effect uses four different cloud silhouettes. Keep each imported
	# texture distinct; the earlier placeholder accidentally reused variant 3 four times.
	for variant in range(1,5):
		var suffix: String = "" if variant==1 else "_%d" % variant
		var cloud_name: String = "map_cloud_transition%s.png" % suffix
		textures[cloud_name] = load("res://assets/map/ui/"+cloud_name)
	textures["swamp_damage_minus1.png"] = load("res://assets/map/ui/swamp_damage_minus1.png")
	textures["heal"] = load("res://assets/battle/effects/heal-cross.png")

func install(stage: Control) -> void:
	corruption = ColorRect.new()
	corruption.size = stage.size
	corruption.color = Color.WHITE
	corruption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corruption.z_index = 2
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float level = 0.0;
varying vec2 p;
void vertex() { p = VERTEX/vec2(1280.0,720.0); }
void fragment() {
	float tint = level/100.0*0.72;
	float cracks = clamp((level-25.0)/75.0*0.62,0.0,0.62);
	float fog = clamp((level-45.0)/55.0*0.72,0.0,0.72);
	float edge = smoothstep(0.3,0.8,length((p-vec2(0.5,0.4))*vec2(1.0,0.75)));
	float line = 1.0-smoothstep(0.002,0.006,abs(fract(p.x*3.0+p.y*1.6)-0.48));
	vec2 drift = vec2(sin(TIME*0.31)*0.015,cos(TIME*0.31)*0.01);
	float mist = exp(-length((p+drift-vec2(0.16,0.78))*vec2(2.7,2.0)))*0.34+exp(-length((p-drift-vec2(0.82,0.68))*vec2(2.5,2.0)))*0.28;
	COLOR = vec4(mix(vec3(0.28,0.07,0.09),vec3(0.15,0.06,0.16),fog),tint*(0.08+edge*0.32)+cracks*line*0.18+fog*mist);
}
"""
	var material = ShaderMaterial.new()
	material.shader = shader
	corruption.material = material
	stage.add_child(corruption)
	gauge = ContaminationHud.new()
	stage.add_child(gauge)
	refresh(true)

func refresh(instant: bool = false) -> void:
	if is_instance_valid(gauge): gauge.set_value(map.world.contamination,instant)
	if is_instance_valid(corruption): corruption.material.set_shader_parameter("level",float(map.world.contamination))

func effect(block_input: bool = false) -> Control:
	var layer = Control.new()
	layer.size = Vector2(1280,720)
	layer.z_index = 250
	layer.mouse_filter = Control.MOUSE_FILTER_STOP if block_input else Control.MOUSE_FILTER_IGNORE
	map.add_child(layer)
	if block_input:
		for node in map.find_children("*","BaseButton",true,false):
			var was_disabled: bool = node.disabled
			var reference = weakref(node)
			node.disabled = true
			layer.tree_exiting.connect(func():
				var button = reference.get_ref()
				if is_instance_valid(button): button.disabled = was_disabled)
	return layer

func art(parent: Control, texture: Texture2D, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var node = TextureRect.new()
	node.texture = texture
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = pos
	node.size = dimensions
	node.pivot_offset = dimensions/2.0
	parent.add_child(node)
	return node

func full_heal() -> void:
	var layer = effect(true)
	var flash = ColorRect.new()
	flash.size = layer.size
	flash.color = Color(0.3,1.0,0.42,0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	var tween = layer.create_tween()
	tween.tween_property(flash,"color:a",0.38,0.05)
	tween.tween_property(flash,"color:a",0.0,0.37)
	for entry in HEAL:
		var dimensions = Vector2.ONE*float(entry[2])
		var origin = layer.size*Vector2(entry[0]/100.0,entry[1]/100.0)-dimensions/2.0
		var cross = art(layer,textures.heal,origin,dimensions)
		cross.modulate.a = 0.0
		cross.scale = Vector2.ONE*0.94
		var motion = cross.create_tween().set_parallel(true)
		var delay = float(entry[3])/1000.0
		var duration = float(entry[4])/1000.0
		motion.tween_property(cross,"modulate:a",0.95,duration*0.18).set_delay(delay)
		motion.tween_property(cross,"scale",Vector2.ONE,duration*0.18).set_delay(delay)
		motion.tween_property(cross,"position",origin+Vector2(entry[5],-14),duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		motion.tween_property(cross,"modulate:a",0.0,duration*0.38).set_delay(delay+duration*0.62)
	await map.get_tree().create_timer(2.2).timeout
	layer.free()

func swamp_hit() -> void:
	var layer = effect(true)
	var dimensions = Vector2(384,192)
	var node = art(layer,textures["swamp_damage_minus1.png"],(layer.size-dimensions)/2.0,dimensions)
	node.scale = Vector2.ONE*0.42
	node.modulate.a = 0.0
	var motion = layer.create_tween().set_parallel(true)
	motion.tween_property(node,"scale",Vector2.ONE*1.14,0.125).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.tween_property(node,"modulate:a",1.0,0.125)
	motion.chain().tween_property(node,"scale",Vector2.ONE,0.2)
	motion.chain().tween_property(node,"position:y",node.position.y-25,0.455)
	motion.parallel().tween_property(node,"modulate:a",0.0,0.455)
	var hero = map.hero
	var tint = hero.create_tween()
	for color in [Color(1.6,0.3,0.25),Color(0.75,0.3,0.3),Color(1.65,0.35,0.25),Color.WHITE]:
		tint.tween_property(hero,"modulate",color,0.155)
	await motion.finished
	hero.modulate = Color.WHITE
	layer.free()

func warp(hero: TextureRect, destination: Vector2) -> void:
	var layer = effect(true)
	map.sound("magic")
	var fade = hero.create_tween()
	fade.tween_property(hero,"modulate:a",0.0,0.36)
	await fade.finished
	hero.position = destination
	var reveal = hero.create_tween()
	reveal.tween_property(hero,"modulate:a",1.0,0.42)
	await reveal.finished
	layer.free()

# Translate source % widths, left/right offscreen origin, lane bottom anchors,
# CSS translateY and covered/opening transforms into 1280×720 Godot coordinates.
func cloud_lane_geometry(index: int, texture: Texture2D) -> Dictionary:
	var lane: Dictionary = CLOUD_LANES[index]
	var w: float = 1280.0 * float(lane["width"])
	var h: float = w * float(texture.get_height()) / float(texture.get_width())
	var dimensions = Vector2(w,h)
	var anchor: float = float(lane["anchor"])
	var baseline: float = (720.0 * (1.0 - anchor) - h) if bool(lane["bottom"]) else (720.0 * anchor)
	var shift: float = h * float(lane["y"])
	var left: bool = index%2==0
	var start_x: float = -998.4 - w*0.22 if left else 2278.4-w*0.78
	var covered_x: float = -998.4+w*1.08 if left else 2278.4-w*2.08
	var opening_x: float = -998.4+w*2.35 if left else 2278.4-w*3.35
	var rot: float = float(lane["rot"]) * (1.0 if left else -1.0)
	var base_scale: float = float(lane["scale"])
	return {
		"dimensions":dimensions,
		"start":Vector2(start_x,baseline+shift),
		"covered":Vector2(covered_x,baseline+shift*0.18),
		"opening":Vector2(opening_x,baseline-shift*1.5),
		"start_rotation":rot,
		"covered_rotation":rot*0.22,
		"opening_rotation":-rot*1.6,
		"start_scale":base_scale,
		"covered_scale":base_scale*1.02,
		"opening_scale":base_scale*1.08,
		"duration":float(lane["duration"]),
		"delay":float(lane["delay"])
	}

func cloud_refresh(change_board: Callable) -> bool:
	var layer = effect(true)
	layer.clip_contents = true
	# Frozen CSS: parent wash + ::before/::after cloud banks + central mist.
	# All ignore input; the existing effect layer itself owns the button lock.
	var wash = ColorRect.new()
	wash.name = "CloudBackdropWash"
	wash.size = layer.size
	wash.color = Color(224.0/255.0,228.0/255.0,225.0/255.0,0.0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(wash)
	var front_fog = CloudFog.create(layer,0)
	var veil = CloudFog.create(layer,1)
	var mist = CloudFog.create(layer,2)
	var sweep = layer.create_tween().set_parallel(true)
	sweep.tween_property(wash,"color:a",0.18,0.24)
	sweep.tween_property(front_fog.material,"shader_parameter/coverage",0.82,0.36)
	sweep.tween_property(front_fog,"scale",Vector2.ONE*1.05,0.72)
	sweep.tween_property(veil.material,"shader_parameter/coverage",0.95,0.26).set_delay(0.36)
	sweep.tween_property(veil,"scale",Vector2.ONE*1.08,0.56).set_delay(0.25)
	sweep.tween_property(mist.material,"shader_parameter/coverage",0.98,0.30).set_delay(0.43)
	sweep.tween_property(mist,"scale",Vector2.ONE*1.04,0.64).set_delay(0.26)
	var clouds: Array = []
	var geometries: Array = []
	for i in range(CLOUD_LANES.size()):
		var lane: Dictionary = CLOUD_LANES[i]
		var variant: int = int(lane["variant"])
		var suffix: String = "" if variant==1 else "_%d" % variant
		var key: String = "map_cloud_transition%s.png" % suffix
		var texture: Texture2D = textures[key]
		var geometry: Dictionary = cloud_lane_geometry(i,texture)
		var left: bool = i%2==0
		var cloud = art(layer,texture,geometry["start"],geometry["dimensions"])
		cloud.name = "CloudLane_%d" % (i+1)
		cloud.flip_h = not left
		cloud.scale = Vector2.ONE*float(geometry["start_scale"])
		cloud.rotation_degrees = float(geometry["start_rotation"])
		cloud.modulate.a = 0.08
		var duration: float = float(geometry["duration"])
		var delay: float = float(geometry["delay"])
		sweep.tween_property(cloud,"position",geometry["covered"],duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		sweep.tween_property(cloud,"rotation_degrees",geometry["covered_rotation"],duration).set_delay(delay)
		sweep.tween_property(cloud,"scale",Vector2.ONE*float(geometry["covered_scale"]),duration).set_delay(delay)
		sweep.tween_property(cloud,"modulate:a",0.97,0.26).set_delay(delay)
		clouds.append(cloud)
		geometries.append(geometry)
	await map.get_tree().create_timer(1.32).timeout
	var ok: bool = change_board.call()
	await map.get_tree().create_timer(0.22).timeout
	var reveal = layer.create_tween().set_parallel(true)
	reveal.tween_property(wash,"color:a",0.0,0.52)
	reveal.tween_property(front_fog.material,"shader_parameter/coverage",0.0,0.52)
	reveal.tween_property(front_fog,"scale",Vector2.ONE*1.16,0.52)
	reveal.tween_property(veil.material,"shader_parameter/coverage",0.0,0.42).set_delay(0.09)
	reveal.tween_property(veil,"scale",Vector2.ONE*1.22,0.42).set_delay(0.09)
	reveal.tween_property(mist.material,"shader_parameter/coverage",0.0,0.52).set_delay(0.13)
	reveal.tween_property(mist,"scale",Vector2.ONE*1.12,0.52).set_delay(0.13)
	for i in range(clouds.size()):
		var geometry: Dictionary = geometries[i]
		var opening_duration: float = float(geometry["duration"])*0.82
		var opening_delay: float = float(geometry["delay"])*0.35
		reveal.tween_property(clouds[i],"position",geometry["opening"],opening_duration).set_delay(opening_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		reveal.tween_property(clouds[i],"rotation_degrees",geometry["opening_rotation"],opening_duration).set_delay(opening_delay)
		reveal.tween_property(clouds[i],"scale",Vector2.ONE*float(geometry["opening_scale"]),opening_duration).set_delay(opening_delay)
		reveal.tween_property(clouds[i],"modulate:a",0.0,0.42).set_delay(0.08)
	await map.get_tree().create_timer(1.12).timeout
	layer.free()
	return ok
