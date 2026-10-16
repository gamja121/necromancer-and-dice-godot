extends SceneTree
## Verify bundled B/D fonts and functional/story separation.
const Policy=preload("res://systems/ui_typography.gd")
var passed:=0
var failed:=0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, title: String) -> void:
	if ok:
		passed+=1
		print("PASS ui-typography: ",title)
	else:
		failed+=1
		printerr("FAIL ui-typography: ",title)

func _run() -> void:
	var info: Font=load(Policy.BODY_PATH)
	var head: Font=load(Policy.HEADING_PATH)
	check(info!=null and head!=null,"both approved fonts bundled")
	if info==null or head==null:
		print("UI_TYPOGRAPHY_PREVIEW: %d passed, %d failed" % [passed,failed+1])
		quit(1)
		return
	check(info.has_char("낙".unicode_at(0)) and head.has_char("낙".unicode_at(0)),"both fonts support Korean")
	var normal=Label.new()
	normal.name="BattleHudStatus"
	root.add_child(normal)
	check(Policy.apply_ui_font(normal,info,head) and normal.get_theme_font("font")==info,"B for normal information")
	var title=Label.new()
	title.name="EventDiscoveryTitle"
	root.add_child(title)
	check(Policy.apply_ui_font(title,info,head) and title.get_theme_font("font")==head,"D for explicit title")
	var large=Label.new()
	large.text="영혼 수확"
	large.add_theme_font_size_override("font_size",28)
	root.add_child(large)
	check(Policy.apply_ui_font(large,info,head) and large.get_theme_font("font")==head,"D for large unnamed Korean title")
	var numbers=Label.new()
	numbers.text="250"
	numbers.add_theme_font_size_override("font_size",28)
	root.add_child(numbers)
	check(Policy.apply_ui_font(numbers,info,head) and numbers.get_theme_font("font")==info,"B remains on large numbers")
	var btn=Button.new()
	root.add_child(btn)
	check(Policy.apply_ui_font(btn,info,head) and btn.get_theme_font("font")==info,"B on buttons")
	var rich=RichTextLabel.new()
	root.add_child(rich)
	check(Policy.apply_ui_font(rich,info,head) and rich.get_theme_font("normal_font")==info and rich.get_theme_font("bold_font")==head,"B regular + D emphasized rich text")
	var story=Label.new()
	story.set_meta("ui_story_copy_role","narration")
	root.add_child(story)
	check(not Policy.apply_ui_font(story,info,head),"story narration preserved")
	var speech=Label.new()
	speech.set_meta("ui_story_copy_role","speech")
	root.add_child(speech)
	check(not Policy.apply_ui_font(speech,info,head),"story dialogue preserved")
	var intro=Control.new()
	intro.name="Intro"
	root.add_child(intro)
	var intro_line=Label.new()
	intro.add_child(intro_line)
	check(not Policy.apply_ui_font(intro_line,info,head),"intro dialogue preserved")
	var discovery=Label.new()
	discovery.name="EventDiscoveryDescription"
	root.add_child(discovery)
	check(not Policy.apply_ui_font(discovery,info,head),"event narrative preserved")
	var special=Label.new()
	special.set_meta("ui_font_role","emphasis")
	root.add_child(special)
	check(Policy.apply_ui_font(special,info,head) and special.get_theme_font("font")==head,"manual emphasis uses D")
	check(FileAccess.file_exists("res://assets/fonts/OFL.txt"),"OFL license notice included")
	check(not FileAccess.file_exists("res://assets/fonts/UnYetgul.ttf"),"GPL font not included")
	for n in [normal,title,large,numbers,btn,rich,story,speech,intro,discovery,special]: n.queue_free()
	print("UI_TYPOGRAPHY_PREVIEW: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
