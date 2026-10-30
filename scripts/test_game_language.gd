extends SceneTree
## Focused, isolated language settings and production UI regressions.
const English = preload("res://systems/english_translation.gd")
const Settings = preload("res://systems/audio_settings.gd")
const Book = preload("res://systems/main_story_book.gd")
const RewardUI = preload("res://systems/reward_ui.gd")
const Catalog = preload("res://systems/reward_catalog.gd")
const Original = preload("res://systems/original_effects.gd")
var passed := 0
var failed := 0
var language: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if ok: passed+=1; print("PASS language: ",description)
	else: failed+=1; printerr("FAIL language: ",description)
func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func check_catalog() -> void:
	var catalog: Dictionary=language.english.catalog
	check(catalog.size()>=977,"complete runtime UI, unit and story catalog")
	var problems: Array[String]=[]
	for source in catalog:
		if English.has_korean(str(catalog[source])): problems.append(str(source))
	check(problems.is_empty(),"all English catalog values are translated: "+str(problems.slice(0,3)))
	var dynamic_problems: Array[String]=[]
	for source in catalog:
		if language.english.placeholder.search(str(source))==null: continue
		var sample: String=source
		var slots=language.english.placeholder.search_all(sample)
		for i in range(slots.size()-1,-1,-1):
			var slot: RegExMatch=slots[i]
			var token:=slot.get_string()
			var value: String="구울" if token.ends_with("s") else ("1.5" if token.ends_with("f") else ("%" if token=="%%" else "3"))
			sample=sample.left(slot.get_start())+value+sample.substr(slot.get_end())
		var shown: String=language.english.translate_message(sample)
		if English.has_korean(shown): dynamic_problems.append(sample+" => "+shown)
	check(dynamic_problems.is_empty(),"formatted runtime catalog translate: "+str(dynamic_problems.slice(0,4)))
	check(tr("구울 · 체력 3/10")=="Ghoul · HP 3/10","formatted stats translate nested canonical monster name")
	check(not English.has_korean(tr("빙결 독 보호 2")),"joined status captions translate")
	check(tr("My Ghoul 17")=="My Ghoul 17","Latin player nickname passes through unchanged")

func check_options() -> void:
	var title=load("res://title.tscn").instantiate()
	root.add_child(title)
	await settle()
	var map_options:=Settings.new()
	root.add_child(Control.new())
	var holder: Control=root.get_child(root.get_child_count()-1)
	map_options.setup(holder)
	await settle()
	check(title.language_picker.item_count==2 and map_options.language_picker.item_count==2,"title and in-game options offer Korean and English")
	check(title.language_picker.get_item_text(0)=="한국어" and title.language_picker.get_item_text(1)=="English","language names remain recognizable in both locales")
	var audio_before:=FileAccess.get_file_as_bytes(Settings.SAVE) if FileAccess.file_exists(Settings.SAVE) else PackedByteArray()
	var session=root.get_node("RunSession")
	var before: Variant=session.world.snapshot().duplicate(true) if session.world!=null else null
	title.language_picker.item_selected.emit(0)
	await settle()
	check(language.locale=="ko" and tr("설정")=="설정" and map_options.language_picker.selected==0,"title selection switches and synchronizes in-game picker")
	map_options.language_picker.item_selected.emit(1)
	await settle()
	check(language.locale=="en" and title.language_picker.selected==1,"in-game selection switches and synchronizes title picker")
	check(map_options.panel.size.x==256 and map_options.panel.get_global_rect().end.y<720,"language row fits painted settings panel")
	check(title.options_dialog.size.x==410,"title options retain their width")
	check((session.world==null and before==null) or (session.world!=null and session.world.snapshot()==before),"language switching leaves game progress and RNG untouched")
	var audio_after:=FileAccess.get_file_as_bytes(Settings.SAVE) if FileAccess.file_exists(Settings.SAVE) else PackedByteArray()
	check(audio_before==audio_after,"language selection leaves audio preferences untouched")
	title.queue_free()
	holder.queue_free()
	await settle()

func check_story() -> void:
	var book:=Book.new()
	book.instant=true
	root.add_child(book)
	var longest: Array=[]
	var longest_key: String=""
	for key in language.english.catalog:
		if str(key).length()>longest_key.length() and not str(key).contains("%") and not str(key).contains("\n"):
			longest_key=str(key)
	var label=book.add_source_label(longest_key,Rect2(200,535,700,70),24)
	book.arrange_actions()
	await settle()
	book.typewriter.reveal_all()
	check(label.get_total_character_count()==tr(longest_key).length(),"typewriter counts the full English translation")
	check(label.get_line_count()*label.get_line_height()<=label.size.y+1,"long story copy fits its page without enlarging book")
	check(book.scale==Book.DISPLAY_SCALE and book.art.size==Vector2(360,202.5),"language selection preserves approved book and illustration sizes")
	language.set_language("ko",false)
	await settle()
	language.set_language("en",false)
	await settle()
	check(label.visible_characters==-1,"switching language never truncates revealed narration")
	book.queue_free()
	await settle()

func collect_beats(value: Variant, result: Array) -> void:
	if value is Dictionary:
		if value.has("effect") and value.has("dialogue"): result.append(value)
		else:
			for child in value.values(): collect_beats(child,result)
	elif value is Array:
		for child in value: collect_beats(child,result)

func check_story_beats() -> void:
	var beats: Array=[]
	for file in ["graveyard_story_beats","village_rumor_beats","knight_commander_beats","monster_hunter_beats","cultist_rumor_beats","cultist_altar_beats","village_mistrust_beats","ritual_portal_beats","monster_king_hunt_beats"]:
		collect_beats(load("res://systems/"+file+".gd").get_script_constant_map(),beats)
	var problems: Array[String]=[]
	for beat in beats:
		var book:=Book.new()
		book.instant=true
		root.add_child(book)
		book.add_source_label(str(beat.effect),Rect2(0,535,700,70),20)
		if not str(beat.dialogue).is_empty():
			book.add_source_label(str(beat.get("speaker",""))+": "+str(beat.dialogue),Rect2(0,595,700,70),24)
		var action:=Button.new()
		action.text="계속"
		action.set_meta("story_button_primary",true)
		book.add_child(action)
		book.arrange_actions()
		await settle()
		for label in book.get_children():
			if not label is Label or not label.has_meta("book_copy_role"): continue
			if label.get_line_count()*label.get_line_height()>label.size.y+1:
				problems.append(str(label.get_meta("book_copy_role"))+": "+label.tr(label.text))
		book.queue_free()
		await settle()
	check(beats.size()>=30,"checks authored scenes across eight main story events")
	check(problems.is_empty(),"English narration and dialogue fit fixed book pages: "+str(problems.slice(0,3)))

func check_unit_names() -> void:
	var ui:=RewardUI.new()
	root.add_child(ui)
	var units: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/units.json")).units
	var problems: Array[String]=[]
	for unit in units.values():
		var card=ui.card(ui,"unit",unit,Vector2.ZERO,Vector2(148,224),Callable())
		await settle()
		var caption: Label=card.get_node("LayeredCardTitle")
		var width=caption.get_theme_font("font").get_string_size(caption.tr(caption.text),HORIZONTAL_ALIGNMENT_LEFT,-1,caption.get_theme_font_size("font_size")).x
		if width>caption.size.x+1: problems.append(str(unit.name))
		card.queue_free()
	check(problems.is_empty(),"all English monster names fit existing card ribbons: "+str(problems))
	var session=root.get_node("RunSession")
	var unit: Dictionary=session.world.roster[0]
	var before: Dictionary=unit.duplicate(true)
	unit.name="전투"
	unit.nickname="전투"
	var card=ui.card(ui,"unit",unit,Vector2.ZERO,Vector2(148,224),Callable())
	await settle()
	check(card.get_node("LayeredCardTitle").auto_translate_mode==Node.AUTO_TRANSLATE_MODE_DISABLED,"custom Korean monster names bypass automatic card translation")
	check(tr("전투 · 체력 3/10")=="전투 · HP 3/10","custom names stay exact inside translated stats")
	check(tr("전투")=="Battle","a custom name does not disable ordinary UI translation")
	unit.clear()
	unit.merge(before)
	ui.queue_free()
	await settle()

func check_cards() -> void:
	var ui:=RewardUI.new()
	root.add_child(ui)
	for item in Catalog.dice_cards():
		var card=ui.card(ui,"dice",item,Vector2.ZERO,Vector2(148,224),Callable())
		await settle()
		var caption=card.get_node_or_null("EnglishArtCaption")
		check(caption!=null and caption.visible and not caption.dice_description().is_empty(),"English painted card lettering: "+str(item.card_id))
		if caption!=null:
			check(Rect2(Vector2.ZERO,card.size).encloses(Rect2(caption.position,caption.size)),"lettering stays within aspect-preserved card")
		language.set_language("ko",false)
		await settle()
		check(caption!=null and not caption.visible,"Korean card art restored without replacing texture")
		language.set_language("en",false)
		card.queue_free()
	var board:=TextureRect.new()
	board.texture=load("res://assets/battle/ui/battle-deck-selection-board.png")
	board.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	board.size=Vector2(1164.8,522.95)
	ui.add_child(board)
	await settle()
	check(board.has_node("EnglishArtCaption") and board.get_node("EnglishArtCaption").visible,"descending battle deck has English title")
	var original:=Original.new()
	for kind in ["critical","miss","poison","immune"]:
		var effect=original.label(ui,kind)
		check(effect is Label and not English.has_korean(effect.text),"English combat effect "+kind)
	ui.queue_free()
	await settle()

func run() -> void:
	language=root.get_node("GameLanguage")
	var session=root.get_node("RunSession")
	session.save_file_path="user://language_world_test.json"
	session.start_new_world()
	check(language.locale=="ko","first launch defaults to Korean")
	language.save_file_path="user://language_test.cfg"
	check(language.set_language("en"),"English preference saves")
	language.set_language("ko",false)
	language.load_settings()
	check(language.locale=="en" and TranslationServer.get_locale()=="en","saved English preference reloads")
	check(not language.set_language("fr") and language.locale=="en","unsupported locale cannot replace valid preference")
	var label:=Label.new()
	label.text="설정"
	root.add_child(label)
	await settle()
	check(label.text=="설정" and label.tr(label.text)=="Settings" and label.get_total_character_count()==8,"Godot renders English while canonical source text is unchanged")
	label.queue_free()
	check_catalog()
	await check_options()
	await check_story()
	await check_cards()
	await check_story_beats()
	await check_unit_names()
	language.set_language("ko",false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(language.save_file_path))
	print("GAME_LANGUAGE: ",passed," passed, ",failed," failed")
	quit(1 if failed>0 else 0)
