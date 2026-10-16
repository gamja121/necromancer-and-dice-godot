extends SceneTree
## Optional typography preview must be safe without redistributing UnYetgul.
const Policy = preload("res://systems/ui_typography.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(result: bool, title: String) -> void:
	if result:
		passed += 1
		print("PASS ui-typography: ",title)
	else:
		failed += 1
		printerr("FAIL ui-typography: ",title)

func _run() -> void:
	var regular: Font = load("res://assets/fonts/nanum_gothic_regular.ttf")
	check(regular!=null,"existing fallback font loads")
	var info=Label.new()
	info.name="BattleHudStatus"
	root.add_child(info)
	check(Policy.apply_info_font(info,regular),"battle HUD text accepts shared informational font")
	check(info.get_theme_font("font")==regular,"informational label resolves the requested font")
	var button=Button.new()
	root.add_child(button)
	check(Policy.apply_info_font(button,regular),"action buttons accept shared informational font")
	check(button.get_theme_font("font")==regular,"button resolves shared font")
	var rich=RichTextLabel.new()
	root.add_child(rich)
	check(Policy.apply_info_font(rich,regular),"rich information text accepts shared font")
	check(rich.get_theme_font("normal_font")==regular,"rich text uses regular not forced bold")
	var story=Label.new()
	story.set_meta("ui_story_copy_role","narration")
	root.add_child(story)
	check(not Policy.apply_info_font(story,regular),"map narration remains untouched")
	var speech=Label.new()
	speech.set_meta("ui_story_copy_role","speech")
	root.add_child(speech)
	check(not Policy.apply_info_font(speech,regular),"map dialogue remains untouched")
	var intro=Control.new()
	intro.name="Intro"
	root.add_child(intro)
	var intro_speech=Label.new()
	intro.add_child(intro_speech)
	check(not Policy.apply_info_font(intro_speech,regular),"intro scene keeps existing font")
	var discovery=Label.new()
	discovery.name="EventDiscoveryDescription"
	root.add_child(discovery)
	check(not Policy.apply_info_font(discovery,regular),"discovery narration keeps existing font")
	var discovery_title=Label.new()
	discovery_title.name="EventDiscoveryTitle"
	root.add_child(discovery_title)
	check(Policy.apply_info_font(discovery_title,regular),"discovery heading still adopts info font")
	check(not FileAccess.file_exists("res://assets/fonts/UnYetgul.ttf"),"GPL font is never shipped inside the repository")
	var project=FileAccess.get_file_as_string("res://project.godot")
	check(project.contains('UiTypography="*res://systems/ui_typography.gd"'),"font preview is initialized before the map UI")
	var code=FileAccess.get_file_as_string("res://systems/ui_typography.gd")
	check(code.contains('user://fonts/UnYetgul.ttf') and code.contains("node_added"),"local user font and future UI controls are supported")
	check(code.contains("ui_story_copy_role"),"shared map story-role metadata explicitly protects dialogue and narration")
	info.queue_free()
	button.queue_free()
	rich.queue_free()
	story.queue_free()
	speech.queue_free()
	intro.queue_free()
	discovery.queue_free()
	discovery_title.queue_free()
	print("UI_TYPOGRAPHY_PREVIEW: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
