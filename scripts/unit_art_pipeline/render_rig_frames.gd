extends SceneTree

var config: Dictionary
var sprites: Dictionary = {}
var nodes: Dictionary = {}
var viewport: SubViewport

func _initialize() -> void:
	call_deferred("render_frames")

func v(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func render_frames() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		fail("Pass a rig JSON after --")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not parsed is Dictionary:
		fail("Invalid rig JSON")
		return
	config = parsed
	var directory := args[0].get_base_dir()
	var atlas_path: String = directory.path_join(config.atlas)
	var source := Image.load_from_file(atlas_path)
	if source == null or source.is_empty():
		fail("Cannot load rig atlas")
		return
	var texture := ImageTexture.create_from_image(source)
	viewport = SubViewport.new()
	viewport.size = Vector2i(int(config.canvas[0]), int(config.canvas[1]))
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rig := Node2D.new()
	rig.position = v(config.origin)
	rig.scale = Vector2.ONE * float(config.get("scale", 1.0))
	viewport.add_child(rig)
	nodes["root"] = rig
	for part in config.parts:
		var node := Node2D.new()
		node.name = part.id
		node.position = v(part.position)
		var parent_id: String = part.get("parent", "root")
		if not nodes.has(parent_id):
			fail("Rig parent must precede child: " + parent_id)
			return
		nodes[parent_id].add_child(node)
		node.z_index = int(part.get("z", 0))
		nodes[part.id] = node
		var region: Array = part.region
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
		atlas.filter_clip = true
		var picture := Sprite2D.new()
		picture.texture = atlas
		picture.centered = false
		var factor := float(part.get("scale", 1.0))
		picture.scale = Vector2.ONE * factor
		picture.position = -v(part.pivot) * factor
		node.add_child(picture)
		sprites[part.id] = picture
	var output_path: String = directory.path_join(config.output)
	DirAccess.make_dir_recursive_absolute(output_path)
	for pose in config.poses:
		rig.position = v(config.origin) + v(pose.get("offset", [0, 0]))
		rig.rotation = deg_to_rad(float(pose.get("body_rotation", 0.0)))
		for part in config.parts:
			var angle := float(pose.get("angles", {}).get(part.id, 0.0))
			nodes[part.id].rotation = deg_to_rad(angle)
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		var result := rendered.save_png(output_path.path_join(pose.name + ".png"))
		if result != OK:
			fail("PNG save failed for " + pose.name)
			return
	print("RIG_RENDER_READY frames=%d fixed_parts=%s" % [config.poses.size(), config.get("fixed_parts", [])])
	quit(0)
