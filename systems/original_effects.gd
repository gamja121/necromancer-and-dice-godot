extends RefCounted

const ROOT = "res://assets/battle/effects/"
var metadata: Dictionary
var images: Dictionary = {}
var cache: Dictionary = {}
var materials: Dictionary = {}
var shader: Shader

func _init() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"original_effects.json"))
	shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform int mode = 0;
uniform vec3 backdrop = vec3(0.0, 0.823529, 0.0);
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 p = c.rgb * 255.0;
	float excess = p.g - max(p.r, p.b);
	if (mode == 2) {
		c.a *= clamp((distance(p,vec3(33.0,217.0,7.0))-18.0)/55.0,0.0,1.0);
	} else if (mode == 3) {
		float magenta = min(p.r,p.b)-p.g;
		if (magenta>20.0) {
			c.a *= 1.0-clamp((magenta-20.0)/90.0,0.0,1.0);
			c.r = min(c.r,c.g+20.0/255.0);
			c.b = min(c.b,c.g+20.0/255.0);
		}
	} else if (mode == 4) {
		if (excess>45.0) c.a=0.0;
		else if (excess>0.0) c.g=max(c.r,c.b);
	} else if (mode == 5) {
		if (p.r>110.0 && p.b>75.0 && p.r-p.g>35.0 && p.b-p.g>15.0) c.a=0.0;
	} else if (mode == 6 && excess>8.0) {
		float a = excess>=215.0 ? 0.0 : 1.0-excess/255.0;
		if (a>0.0) c.rgb=clamp(vec3(c.r/a,(p.g-excess)/255.0/a,c.b/a),vec3(0.0),vec3(1.0));
		c.a *= a;
	} else if (excess>20.0) {
		if (mode == 1) {
			float a = max(0.0,max((c.r-backdrop.r)/(1.0-backdrop.r),(c.b-backdrop.b)/(1.0-backdrop.b)));
			if (a<12.0/255.0) a=0.0;
			if (a>0.0) c.rgb=clamp((c.rgb-backdrop*(1.0-a))/a,vec3(0.0),vec3(1.0));
			c.a *= a;
		} else {
			c.a *= 1.0-clamp((excess-20.0)/90.0,0.0,1.0);
			c.g = min(c.g,max(c.r,c.b)+20.0/255.0);
		}
	}
	COLOR = c*tint;
}
"""

func image(name: String) -> Image:
	if not images.has(name):
		var texture: Texture2D = load(ROOT+name)
		var value = texture.get_image()
		value.convert(Image.FORMAT_RGBA8)
		images[name] = value
	return images[name]

func material(kind: String) -> ShaderMaterial:
	if materials.has(kind): return materials[kind]
	var result = ShaderMaterial.new()
	result.shader = shader
	var mode = 0
	if kind in ["claw","slash","wind","music"]: mode = 1
	elif kind=="poison": mode = 2
	elif kind=="toxicLiquid": mode = 3
	elif kind in ["damage","label"]: mode = 4
	elif kind=="healing": mode = 5
	elif kind=="summon": mode = 6
	result.set_shader_parameter("mode",mode)
	if metadata.effects.has(kind):
		var background: Array = metadata.effects[kind].get("background",[0,210,0])
		result.set_shader_parameter("backdrop",Vector3(background[0],background[1],background[2])/255.0)
	materials[kind] = result
	return result

func hit_kind(slug: String) -> String:
	return metadata.attacks.get(slug,"physical")

func hit_frames(kind: String) -> Array:
	if cache.has(kind): return cache[kind]
	var config: Dictionary = metadata.effects[kind]
	var sheet = image(String(config.sheet).get_file())
	var frames: Array = []
	for i in range(config.centers.size()):
		var start: int = int(config.starts[i]) if config.has("starts") else int(config.centers[i]-config.width/2)
		var width: int = int(config.widths[i]) if config.has("widths") else int(config.width)
		var top: int = int(config.tops[i]) if config.has("tops") else int(config.get("top",0))
		var size: int = int(config.size)
		var frame = Image.create(size,size,false,Image.FORMAT_RGBA8)
		frame.blit_rect(sheet,Rect2i(start,top,width,int(config.height)),Vector2i(int(size/2+start-config.centers[i]),0))
		frames.append(ImageTexture.create_from_image(frame))
	cache[kind] = frames
	return frames

func crop(sheet: String, cell: Array) -> Texture2D:
	var key = sheet+str(cell)
	if not cache.has(key):
		cache[key] = ImageTexture.create_from_image(image(sheet).get_region(Rect2i(int(cell[0]),int(cell[1]),int(cell[2]),int(cell[3]))))
	return cache[key]

func sprite(parent: Control, texture: Texture2D, kind: String, dimensions: Vector2) -> TextureRect:
	var node = TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture = texture
	node.size = dimensions
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind!="cross": node.material = material(kind)
	parent.add_child(node)
	return node

func number(parent: Control, amount: int) -> Control:
	var node = Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.z_index = 12
	parent.add_child(node)
	var healing = amount>0
	var cells: Array = metadata.healing if healing else metadata.damage
	var sheet = "healing-digits-sheet.jpg" if healing else "damage-digits-sheet.jpg"
	var string_value = ("+" if healing else "-")+str(absi(amount))
	var x = 0.0
	for character in string_value:
		var index = 0 if character=="+" else (10 if character=="-" else int(character)+(1 if healing else 0))
		var cell: Array = cells[index]
		var height = 42.0 if healing else (11.0 if character=="-" else 38.0)
		var dimensions = Vector2(float(cell[2])/cell[3]*height,height)
		var glyph = sprite(node,crop(sheet,cell),"healing" if healing else "damage",dimensions)
		glyph.position = Vector2(x,(42-height)/2)
		x += dimensions.x+(-4 if healing else 1)
	node.size = Vector2(x,42)
	return node

func label(parent: Control, kind: String) -> Control:
	var config: Dictionary = metadata.labels if metadata.labels.has(kind) else metadata.status
	if not config.has(kind): return null
	var cell: Array = config[kind]
	var width = 78.0 if kind=="critical" else (130.0 if kind=="miss" else 98.0)
	var node = sprite(parent,crop("combat-labels-sheet.jpg" if metadata.labels.has(kind) else "status-labels-sheet.jpg",cell),"label",Vector2(width,width*float(cell[3])/cell[2]))
	node.z_index = 13
	return node

func summon_frames() -> Array:
	if cache.has("summon"): return cache.summon
	var frames: Array = []
	for i in range(8):
		frames.append(crop("summon-effect-sheet.jpg",[i%4*320,0 if i<4 else 288,320,288 if i<4 else 287]))
	cache.summon = frames
	return frames
