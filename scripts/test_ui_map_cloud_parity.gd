extends SceneTree
## Stage 5H: original four-silhouette map transition parity and progression isolation.
const MapPresentation = preload("res://systems/map_presentation.gd")
var passed: int = 0
var failed: int = 0
var board_calls: int = 0
var finished: bool = false
var finished_ok: bool = false

func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS ui-map-cloud: ",description)
	else:
		failed += 1
		printerr("FAIL ui-map-cloud: ",description)

func _initialize() -> void:
	call_deferred("_run")

func _swap_board() -> bool:
	board_calls += 1
	return true

func _complete_cloud(presenter: Node) -> void:
	finished_ok = await presenter.cloud_refresh(Callable(self,"_swap_board"))
	finished = true

func _run() -> void:
	var map = Control.new()
	map.name = "CloudMapParityHost"
	map.size = Vector2(1280,720)
	root.add_child(map)
	var existing_button = Button.new()
	existing_button.name = "ExistingMapRollButton"
	map.add_child(existing_button)
	var presenter = MapPresentation.new()
	map.add_child(presenter)
	presenter.setup(map)
	var keys: Array = []
	var images: Array = []
	var unique_rids: Dictionary = {}
	for variant in range(1,5):
		var suffix = "" if variant==1 else "_%d" % variant
		var name: String = "map_cloud_transition%s.png" % suffix
		keys.append(name)
		var path: String = "res://assets/map/ui/"+name
		var image: Texture2D = presenter.textures.get(name)
		check(image!=null,"original cloud %d imports as Godot texture" % variant)
		if image!=null:
			check(image.resource_path==path,"cloud %d uses its own unchanged source file" % variant)
			check(image.get_width()>0 and image.get_height()>0,"cloud %d image dimensions decode" % variant)
			images.append(image)
			unique_rids[image.get_rid()] = true
	check(unique_rids.size()==4,"four original cloud silhouettes are separate GPU resources")
	check(presenter.textures.get("swamp_damage_minus1.png")!=null,"existing swamp effect asset unchanged")
	check(not existing_button.disabled,"map controls available before transition")
	call_deferred("_complete_cloud",presenter)
	await create_timer(0.28).timeout
	check(existing_button.disabled,"input blocks during tile shuffle cloud transition")
	var overlay: Control
	for child in map.get_children():
		if child is Control and child.z_index==250:
			overlay = child
	check(overlay!=null,"transition creates its own temporary effect layer")
	var counts: Dictionary = {}
	if overlay!=null:
		for child in overlay.get_children():
			if child is TextureRect:
				var texture: Texture2D = child.texture
				var key: String = texture.resource_path.get_file() if texture!=null else "missing"
				counts[key] = int(counts.get(key,0))+1
	var eight: int = 0
	for name in keys:
		check(int(counts.get(name,0))==2,"two visible clouds use original "+name)
		eight += int(counts.get(name,0))
	check(eight==8,"transition instantiates exactly eight clouds")
	check(board_calls==0,"tile board does not change before covered transition")
	await create_timer(3.0).timeout
	check(finished and finished_ok,"cloud transition reaches final reveal successfully")
	check(board_calls==1,"tile board mutation callback executes once")
	check(not existing_button.disabled,"map controls recover after cloud layer cleanup")
	var leftover: int = 0
	for child in map.get_children():
		if child is Control and child.z_index==250: leftover += 1
	check(leftover==0,"temporary clouds and input blocker are fully removed")
	map.queue_free()
	await process_frame
	print("UI_MAP_CLOUD_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
