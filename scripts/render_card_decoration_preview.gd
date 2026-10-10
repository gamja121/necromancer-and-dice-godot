extends SceneTree
## Capture real Godot UI art (not a drawn mockup) for card border/altar plaque review.
## Run via Xvfb: godot --path . --script res://scripts/render_card_decoration_preview.gd

const InventoryPanel = preload("res://systems/inventory_panel.gd")

class PreviewSession:
	extends RefCounted
	var world: Dictionary
	func _init() -> void:
		var owned: Array = []
		for i in range(8):
			var marks: Array = []
			for j in range(2 if i%2==0 else 3):
				marks.append({"type":"guard","bless":[1],"curse":[5]})
			owned.append({
				"id":"frame-preview-%d" % i,"slug":"skeleton-archer",
				"name":"해골 궁수","brands":marks,"altar_enhancements":3,
				"current_hp":8,"max_hp":8,"attack":2,"speed":3
			})
		world = {"roster":owned,"dice_cards":[],"brand_cards":[]}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,720)
	var ui = InventoryPanel.new()
	root.add_child(ui)
	ui.setup(PreviewSession.new())
	await create_timer(1.45).timeout
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if picture == null or picture.is_empty():
		printerr("CARD_PREVIEW_FAILED: no GPU image available")
		quit(1)
		return
	picture.resize(800,450,Image.INTERPOLATE_LANCZOS)
	var output: String = ProjectSettings.globalize_path("res://card_preview.webp")
	var err: Error = picture.save_webp(output,false,0.82)
	if err != OK:
		printerr("CARD_PREVIEW_FAILED: save_webp returned ",err)
		quit(1)
		return
	print("CARD_PREVIEW_SAVED: ",output)
	quit(0)
