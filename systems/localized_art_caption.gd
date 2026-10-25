extends Control
## Live lettering over unlettered samples of the existing painted texture.
## The original art, frame, aspect ratio and all card hitboxes are unchanged.
var source: Texture2D
var board := false
var image_key := ""
var pieces: Array[Dictionary] = []

static func install(target: Control, texture: Texture2D) -> void:
	if texture==null or target.has_node("EnglishArtCaption"): return
	var path := texture.resource_path
	if not path.contains("dice-control-ko-") and not path.ends_with("battle-deck-selection-board.png"): return
	var caption = load("res://systems/localized_art_caption.gd").new()
	caption.name="EnglishArtCaption"
	caption.source=texture
	caption.board=path.ends_with("battle-deck-selection-board.png")
	caption.image_key=path.get_file().trim_prefix("dice-control-ko-").trim_suffix(".png")
	target.add_child(caption)

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	if board:
		add_caption(Rect2(0.434,0.119,0.132,0.057),Rect2(0.300,0.119,0.10,0.057),"BATTLE DECK",Color("f7d491"))
	else:
		add_caption(Rect2(0.15,0.070,0.70,0.085),Rect2(0.095,0.065,0.080,0.10),"DICE CONTROL",Color("09210c"))
		add_caption(Rect2(0.14,0.760,0.72,0.14),Rect2(0.095,0.065,0.080,0.10),dice_description(),Color("09210c"))
	get_parent().resized.connect(layout)
	layout()
	refresh_language()

func dice_description() -> String:
	if image_key.is_valid_int(): return "Roll "+image_key
	if image_key.begins_with("exclude-"): return "Roll any face\nexcept "+image_key.trim_prefix("exclude-")
	return {"low":"Roll 1, 2 or 3","high":"Roll 4, 5 or 6","odd":"Roll 1, 3 or 5","even":"Roll 2, 4 or 6","repeat":"Repeat the\nprevious roll","echo":"Repeat the last\ncard's effect"}.get(image_key,"")

func add_caption(bounds: Rect2, sample: Rect2, value: String, ink: Color) -> void:
	var patch := TextureRect.new()
	patch.name="PaintedLetteringPatch"
	var atlas := AtlasTexture.new()
	atlas.atlas=source
	atlas.region=Rect2(sample.position*source.get_size(),sample.size*source.get_size())
	atlas.filter_clip=true
	patch.texture=atlas
	patch.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	patch.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(patch)
	var label := Label.new()
	label.text=value
	label.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color",ink)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.set_meta("ui_font_preserve",true)
	label.add_theme_font_override("font",preload("res://assets/fonts/NanumBarunGothic.ttf"))
	add_child(label)
	pieces.append({"patch":patch,"label":label,"bounds":bounds})

func layout() -> void:
	var box: Vector2=get_parent().size
	var fit := minf(box.x/source.get_width(),box.y/source.get_height())
	var drawn := source.get_size()*fit
	position=(box-drawn)*0.5
	size=drawn
	for piece in pieces:
		var bounds: Rect2=piece.bounds
		piece.patch.position=bounds.position*drawn
		piece.patch.size=bounds.size*drawn
		piece.label.position=piece.patch.position
		piece.label.size=piece.patch.size
		var points := maxi(8,int(drawn.y*(0.029 if board else 0.050)))
		var font: Font=piece.label.get_theme_font("font")
		for line in str(piece.label.text).split("\n"):
			while points>7 and font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,points).x>piece.patch.size.x-2: points-=1
		piece.label.add_theme_font_size_override("font_size",points)

func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree(): refresh_language()

func refresh_language() -> void:
	visible=TranslationServer.get_locale().get_slice("_",0)=="en"
