extends SceneTree
## Capture the actual merged production monster overflow UI via a real graphical Godot renderer.
## Disposable session data only; no save writes and no production UI changes.
const Overflow = preload("res://systems/reward_overflow.gd")

class PreviewSession:
	extends RefCounted
	var world: Dictionary = {}
	func claim_reward(_discard_id: String = "") -> Dictionary:
		return {"ok": false, "error": "Screenshot fixture must not commit rewards"}

func _initialize() -> void:
	call_deferred("_run")

func specimen(index: int, slug: String, name: String, hp: int) -> Dictionary:
	return {
		"id": "preview-monster-%02d" % index,
		"slug": slug,
		"name": name,
		"brands": [],
		"altar_enhancements": 0,
		"current_hp": hp, "max_hp": hp,
		"attack": 2 + index % 3, "speed": 2 + index % 2
	}

func capture(kind: String) -> bool:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = root.get_texture()
	if texture == null:
		printerr("SWAP_SCREENSHOT_FAILURE: viewport not rendered ",kind)
		return false
	var img: Image = texture.get_image()
	if img == null or img.is_empty():
		printerr("SWAP_SCREENSHOT_FAILURE: image empty ",kind)
		return false
	if img.get_width() != 1280 or img.get_height() != 720:
		printerr("SWAP_SCREENSHOT_FAILURE: unexpected dimensions ",img.get_size())
		return false
	var unique: Dictionary = {}
	for y in range(18):
		for x in range(28):
			unique[img.get_pixel((x*43+23)%1280,(y*39+17)%720).to_html(false)] = true
	if unique.size() < 25:
		printerr("SWAP_SCREENSHOT_FAILURE: likely empty frame: ",unique.size())
		return false
	var path: String = ProjectSettings.globalize_path("res://monster_swap_%s.webp" % kind)
	var err: Error = img.save_webp(path,false,0.82)
	if err != OK:
		printerr("SWAP_SCREENSHOT_FAILURE: webp save error ",err)
		return false
	print("SWAP_SCREENSHOT_SAVED: ",kind," ",path," colors=",unique.size()," bytes=",FileAccess.get_file_as_bytes(path).size())
	return true

func _run() -> void:
	root.size = Vector2i(1280,720)
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/nanum_gothic_regular.ttf")
	theme.default_font_size = 15
	var map_bg := TextureRect.new()
	map_bg.name = "ExistingGameMapBackground"
	map_bg.texture = load("res://assets/map/maps/default-map.jpg")
	map_bg.position = Vector2.ZERO
	map_bg.size = Vector2(1280,720)
	map_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_bg.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(map_bg)

	var names: Array = [
		["skeleton-spear","해골 창병",10],
		["skeleton-archer","해골 궁수",9],
		["ghoul","구울",12],
		["death-knight","죽음의 기사",20],
		["mushroom-soldier","버섯 병사",8],
		["goblin-soldier","고블린 병사",8],
		["bone-hound","해골 사냥개",12],
		["flesh-golem","살덩이 골렘",18],
		["plague-doctor","역병 의사",10],
		["forest-fairy","숲의 요정",7]
	]
	var owned: Array = []
	for i in range(names.size()):
		owned.append(specimen(i,str(names[i][0]),str(names[i][1]),int(names[i][2])))
	var fresh: Dictionary = specimen(10,"skeleton-cavalry","해골 기병",14)
	var preview := PreviewSession.new()
	preview.world = {"roster":owned,"dice_cards":[],"pending_reward":{"kind":"capture","reward":{"kind":"unit","item":fresh}}}
	var panel := Overflow.new()
	panel.theme = theme
	root.add_child(panel)
	panel.setup(preview)
	if not panel.is_monster_swap or panel.monster_grid.get_child_count() != 10:
		printerr("SWAP_SCREENSHOT_FAILURE: production overlay did not initialize")
		quit(1)
		return
	await create_timer(0.8).timeout
	if not await capture("unselected"):
		quit(1)
		return
	panel.select_card(str(owned[3].id))
	await create_timer(0.35).timeout
	if not await capture("selected"):
		quit(1)
		return
	print("SWAP_SCREENSHOT_REAL_GODOT: 2 rendered, 1280x720, 0 failures")
	quit(0)
