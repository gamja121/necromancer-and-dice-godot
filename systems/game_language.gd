extends Node
## Language preferences are separate from world progress and audio preferences.
signal language_changed(locale: String)
const LocalizedArt = preload("res://systems/localized_art_caption.gd")
const EnglishTranslation = preload("res://systems/english_translation.gd")
const SAVE = "user://language_settings.cfg"
const SUPPORTED = ["ko","en"]
var locale: String = "ko"
var save_file_path: String = SAVE
var english: Translation

func _ready() -> void:
	english = EnglishTranslation.new()
	TranslationServer.add_translation(english)
	load_settings()
	get_tree().node_added.connect(_on_node_added)

func load_settings() -> void:
	var settings := ConfigFile.new()
	settings.load(save_file_path)
	var saved := str(settings.get_value("language","locale","ko"))
	set_language(saved if saved in SUPPORTED else "ko",false)

func set_language(value: String, persist: bool = true) -> bool:
	if not value in SUPPORTED: return false
	if persist:
		var settings := ConfigFile.new()
		settings.set_value("language","locale",value)
		if settings.save(save_file_path)!=OK: return false
	locale=value
	TranslationServer.set_locale(locale)
	language_changed.emit(locale)
	return true

func setup_picker(picker: OptionButton) -> void:
	picker.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	picker.clear()
	picker.add_item("한국어",0)
	picker.add_item("English",1)
	picker.select(SUPPORTED.find(locale))
	picker.item_selected.connect(func(index: int):
		if not set_language(SUPPORTED[index]): picker.select(SUPPORTED.find(locale)))
	var sync := func(_locale: String):
		if is_instance_valid(picker): picker.select(SUPPORTED.find(locale))
	language_changed.connect(sync)
	picker.tree_exiting.connect(func():
		if language_changed.is_connected(sync): language_changed.disconnect(sync),CONNECT_ONE_SHOT)


func _on_node_added(node: Node) -> void:
	if node is TextureRect or node is TextureButton:
		call_deferred("_install_art_caption",weakref(node))

func _install_art_caption(reference: WeakRef) -> void:
	var node = reference.get_ref()
	if node==null or not node.is_inside_tree(): return
	# Caption patches also use TextureRects; only the original path is eligible.
	var texture: Texture2D = node.texture if node is TextureRect else node.texture_normal
	LocalizedArt.install(node,texture)

func _exit_tree() -> void:
	# Native translation lookups must not outlive the scripted resource at shutdown.
	if english!=null: TranslationServer.remove_translation(english)
	english=null
