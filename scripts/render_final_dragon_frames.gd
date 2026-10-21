extends SceneTree
## Render-only deformation of the owner's dragon art. No gameplay RNG.
const SOURCE = "res://assets/battle/final_dragon/final_dragon.png"
const DEST = "res://assets/battle/frames/final-dragon"
const CANVAS = Vector2i(1024,640)
const PICTURE = Vector2(734,506)
const ORIGIN = Vector2(145,76)
var viewport: SubViewport
var mesh_node: MeshInstance2D
var texture_size: Vector2
var used: Rect2
var original: Image
var summaries: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func smooth(a: float,b: float,t: float) -> float:
	var f: float = clampf((t-a)/(b-a),0.0,1.0)
	return f*f*(3.0-2.0*f)

func posed_mesh(pose: Dictionary) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	const COLUMNS: int = 40
	const ROWS: int = 26
	var wing: float = deg_to_rad(float(pose.get("wing",0.0)))
	var neck: float = float(pose.get("neck",0.0))
	var tail: float = float(pose.get("tail",0.0))
	var breathing: float = float(pose.get("breathing",0.0))
	var lunge: float = float(pose.get("lunge",0.0))
	var collapse: float = float(pose.get("collapse",0.0))
	for row in range(ROWS+1):
		for col in range(COLUMNS+1):
			var q := Vector2(float(col)/float(COLUMNS),float(row)/float(ROWS))
			var point: Vector2 = q*PICTURE
			var wing_weight: float = (1.0-smooth(0.52,0.76,q.x))*(1.0-smooth(0.40,0.70,q.y))
			var pivot: Vector2 = PICTURE*Vector2(0.64,0.47)
			point = pivot+(point-pivot).rotated(wing*wing_weight)
			var neck_weight: float = smooth(0.72,0.88,q.x)*(1.0-smooth(0.36,0.63,q.y))
			point += Vector2(neck,neck*0.11)*neck_weight
			var tail_weight: float = (1.0-smooth(0.32,0.61,q.x))*smooth(0.59,0.78,q.y)
			point.y += tail*tail_weight
			var body_weight: float = (1.0-smooth(0.75,0.97,q.y))*smooth(0.42,0.70,q.x)
			point.x += (point.x-PICTURE.x*0.73)*breathing*body_weight
			point.y -= breathing*90.0*body_weight
			# Feet remain planted; the torso leans toward the actual target.
			point.x += lunge*(1.0-smooth(0.72,0.97,q.y))
			point.y += collapse*pow(1.0-q.y,1.1)
			point.x -= collapse*0.18*(1.0-q.y)
			vertices.append(Vector3(point.x,point.y,0))
			uv.append((used.position+q*used.size)/texture_size)
	for row in range(ROWS):
		for col in range(COLUMNS):
			var a: int = row*(COLUMNS+1)+col
			var b: int = a+1
			var c: int = a+COLUMNS+1
			var d: int = c+1
			indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

func save_frame(motion: String,index: int,pose: Dictionary) -> void:
	mesh_node.mesh = posed_mesh(pose)
	mesh_node.modulate = Color(1,1,1,float(pose.get("alpha",1.0)))
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	var target: String = DEST+"/%s-%02d.png" % [motion,index]
	var saved: Error = img.save_png(target)
	if saved!=OK:
		push_error("Cannot save "+target)
		quit(1)
		return
	var bounds: Rect2i = img.get_used_rect()
	if not summaries.has(motion): summaries[motion]=[]
	summaries[motion].append({"frame":index,"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]})

func run() -> void:
	original = Image.load_from_file(SOURCE)
	if original==null or original.is_empty() or not original.has_mipmaps() and original.get_width()<1:
		push_error("Missing dragon source")
		quit(1)
		return
	if original.get_format()!=Image.FORMAT_RGBA8: original.convert(Image.FORMAT_RGBA8)
	# Ignore almost invisible alpha-1 extraction dust when calculating framing.
	# This changes the mesh's source rectangle, not the preserved source PNG.
	var low := Vector2i(original.get_width(), original.get_height())
	var high := Vector2i.ZERO
	for y in range(original.get_height()):
		for x in range(original.get_width()):
			if original.get_pixel(x, y).a > 0.03:
				low = low.min(Vector2i(x, y))
				high = high.max(Vector2i(x + 1, y + 1))
	used = Rect2(Rect2i(low, high - low))
	texture_size = Vector2(original.get_size())
	viewport = SubViewport.new()
	viewport.size = CANVAS
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	mesh_node = MeshInstance2D.new()
	mesh_node.position = ORIGIN
	mesh_node.texture = ImageTexture.create_from_image(original)
	viewport.add_child(mesh_node)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	for i in range(6):
		var phase: float = float(i)/6.0*TAU
		await save_frame("idle",i+1,{"wing":sin(phase)*1.0,"tail":sin(phase+0.6)*5.0,"neck":sin(phase)*1.2,"breathing":sin(phase)*0.009})
	var attacks: Array = [
		{},{"wing":-1.4,"neck":-4.0,"tail":-3.0},
		{"wing":-3.0,"neck":-10.0,"tail":-7.0,"lunge":-7.0},
		{"wing":-4.0,"neck":-15.0,"tail":-9.0,"lunge":-14.0},
		{"wing":-0.5,"neck":3.0,"tail":-2.0,"lunge":7.0},
		{"wing":2.6,"neck":24.0,"tail":8.0,"lunge":34.0},
		{"wing":2.0,"neck":15.0,"tail":5.0,"lunge":22.0},
		{"wing":1.0,"neck":7.0,"tail":3.0,"lunge":10.0},
		{"wing":0.2,"neck":2.0,"tail":1.0,"lunge":3.0},{}
	]
	for i in range(attacks.size()): await save_frame("attack",i+1,attacks[i])
	var hits: Array = [
		{"wing":-1.3,"neck":-9.0,"lunge":-6.0},
		{"wing":-2.1,"neck":-14.0,"lunge":-10.0},
		{"wing":-0.8,"neck":-4.0,"lunge":-3.0},{}
	]
	for i in range(hits.size()): await save_frame("hit",i+1,hits[i])
	for i in range(8):
		var t: float = float(i)/7.0
		await save_frame("death",i+1,{"wing":-4.0*t,"neck":-22.0*t,"tail":11.0*t,"collapse":145.0*t,"alpha":1.0-t*0.62})
	print("FINAL_DRAGON_RENDER: "+JSON.stringify(summaries))
	print("FINAL_DRAGON_FRAMES: 28 native frames at 1024x640; original source retained")
	viewport.queue_free()
	await process_frame
	quit(0)
