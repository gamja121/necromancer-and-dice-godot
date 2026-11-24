extends Node2D
## Copies the starting pose only. The real combatant follows its normal motion.

const DURATION := 0.245
static var _ink: ShaderMaterial

var age := 0.0
var _source: TextureRect
var _clock: Callable
var _started := 0.0
var _tempo := 1.0
var _foot := Vector2.ZERO
var _direction := 1.0
var _echoes: Array[TextureRect] = []


func begin(sprite: TextureRect, clock: Callable, tempo: float) -> void:
	_source = sprite
	_clock = clock
	_started = float(clock.call())
	_tempo = tempo
	_foot = sprite.position+sprite.pivot_offset-Vector2(0,6)
	_direction = -1.0 if sprite.flip_h else 1.0
	z_index = 52
	for i in range(2):
		var echo := TextureRect.new()
		echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		echo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		echo.stretch_mode = sprite.stretch_mode
		echo.texture = sprite.texture
		echo.flip_h = sprite.flip_h
		echo.size = sprite.size
		echo.z_as_relative = false
		echo.z_index = sprite.z_index-2+i
		echo.material = ink_material()
		echo.modulate.a = 0.0
		add_child(echo)
		echo.position = sprite.position+Vector2(_direction*(-13.0 if i==0 else 18.0),1.0)
		_echoes.append(echo)


static func ink_material() -> ShaderMaterial:
	if _ink==null:
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 art = COLOR;
	float ink = dot(art.rgb,vec3(0.28,0.55,0.17));
	vec3 blue = mix(vec3(0.14,0.40,0.59),vec3(0.76,0.93,1.0),pow(ink,0.69));
	COLOR = vec4(blue,art.a);
}
"""
		_ink = ShaderMaterial.new()
		_ink.shader = shader
	return _ink


func _process(_delta: float) -> void:
	if not is_instance_valid(_source) or not _clock.is_valid():
		retire()
		return
	age = (float(_clock.call())-_started)/_tempo
	if age>=DURATION:
		retire()
		return
	for i in range(_echoes.size()):
		var phase := maxf(0.0,age-float(i)*0.017)
		var fade := smoothstep(0.0,0.036,phase)*(1.0-smoothstep(0.071,0.225,phase))
		_echoes[i].modulate.a = fade*(0.26 if i==0 else 0.51)
	queue_redraw()


func retire() -> void:
	hide()
	queue_free()


func _draw() -> void:
	if not is_instance_valid(_source): return
	var fade := smoothstep(0.0,0.045,age)*(1.0-smoothstep(0.076,0.232,age))
	var foot := _source.position+_source.pivot_offset-Vector2(0,6)
	for i in range(5):
		var y := -4.0-float(i)*4.5
		var x := _direction*(14.0-13.0*float(i%3))
		var lead := foot+Vector2(_direction*(19.0+8.0*float(i%3)),y-5.0)
		var tail := _foot+Vector2(x-_direction*(20.0+float(i%3)*9.0),y+4.0)
		draw_line(tail,lead,Color(0.35,0.72,0.94,fade*0.29),3.7 if i==1 else 2.1,true)
		draw_line(tail.lerp(lead,0.45),lead,Color(0.75,0.94,1.0,fade*(0.91 if i==1 else 0.55)),1.3,true)
	for i in range(7):
		var spark := _foot+Vector2(-_direction*(10.0+float(i%4)*13.0+age*52.0),-6.0-float(i%3)*8.0)
		draw_line(spark,spark+Vector2(_direction*(5.0+float(i%3)*3.0),-1.8),Color(0.53,0.84,1.0,fade*0.65),1.2,true)
