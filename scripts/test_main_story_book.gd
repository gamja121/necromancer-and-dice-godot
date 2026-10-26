extends "res://scripts/test_p4_full_source_story_chain.gd"
## Exercise the production story chain while checking the approved book bounds.
## Optional native captures and final-story handoff are written only to user args.
const MainBook = preload("res://systems/main_story_book.gd")
## Independent acceptance list: each approved scene must reach the real book.
## The already integrated cemetery and final dragon retain their own artwork.
const MANUSCRIPT_BASES = {
	"마을 소문":"manuscript_village_base.png",
	"기사단장":"manuscript_commander_base.png",
	"마물 사냥꾼":"manuscript_hunter_base.png",
	"광신도 소문":"manuscript_cultist_rumor_base.png",
	"광신도의 의식":"manuscript_altar_base.png",
	"마물의 왕 부활 의식":"manuscript_portal_base.png",
	"마물의 왕 추적":"manuscript_hunt_base.png"
}
var book_views := 0
var titles: Dictionary = {}
var manuscript_families: Dictionary = {}
var manuscript_foreground_families: Dictionary = {}
var visual_failures: Dictionary = {}
var output := ""
var export_story := ""

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="): output=argument.trim_prefix("--screenshots=")
		if argument.begins_with("--export-story="): export_story=argument.trim_prefix("--export-story=")
	super._initialize()

func check(ok: bool, description: String) -> void:
	if description.begins_with("all PID-isolated full-chain save files removed"):
		super.check(book_views>30 and titles.size()>=8,"production book is used through all eight main events and their branches")
		super.check(manuscript_families.size()==7,"all seven approved manuscript backgrounds reach their actual saved story chapters")
		super.check(manuscript_foreground_families.size()==7,"all seven manuscript chapters reveal their new foreground during actual story actions")
		super.check(visual_failures.is_empty(),"book/page/art dimensions, page text and plain choices remain within approved bounds")
	super.check(ok,description)

func _visual_check(ok: bool, message: String) -> void:
	if ok or visual_failures.has(message): return
	visual_failures[message]=true
	super.check(false,message)

func inspect_book(panel: Control) -> void:
	_visual_check(panel is MainBook,"main story action belongs to the production book")
	if not panel is MainBook: return
	book_views+=1
	var session: Node=root.get_node("RunSession")
	var before: Dictionary=session.world.snapshot().duplicate(true)
	if panel.opening: panel.skip_opening()
	_visual_check(session.world.snapshot()==before,"opening/skipping book never changes gameplay, RNG or receipts")
	_visual_check(panel.scale==MainBook.DISPLAY_SCALE and panel.position==MainBook.DISPLAY_POSITION,"book has the fixed approved screen transform")
	_visual_check(panel.page_frame.size==Vector2(1200,600),"loaded paper texture cannot expand to its source pixel dimensions")
	_visual_check(panel.art.size==Vector2(360,202.5) and panel.art.clip_contents,"all story illustrations share the approved clipped size")
	var prose: Array[Label]=[]
	var buttons: Array[Button]=[]
	var chapter_title := ""
	for child in panel.get_children():
		if child is Label and child.has_meta("book_copy_role") and not child.has_meta("book_skip"):
			_visual_check(Rect2(690,124,490,475).encloses(Rect2(child.position,child.size)),"book text remains on the right page: "+str(child.get_meta("book_copy_role")))
			if child.get_meta("book_copy_role")=="title":
				titles[child.text]=true
				chapter_title=child.text
			if child.get_meta("book_copy_role") in ["narration","speech"]: prose.append(child)
		if child is Button:
			buttons.append(child)
			_visual_check(Rect2(690,124,490,475).encloses(Rect2(child.position,child.size)),"choice remains on right page: "+child.text)
			_visual_check(child.get_theme_stylebox("normal") is StyleBoxEmpty,"choice uses text with an ink marker: "+child.text)
	for label in prose:
		for action in buttons:
			_visual_check(not Rect2(label.position,label.size).intersects(Rect2(action.position,action.size)),"story copy does not overlap choice: "+action.text)
	inspect_manuscript_art(panel,chapter_title)

func inspect_manuscript_art(panel: Control, chapter_title: String) -> void:
	if not MANUSCRIPT_BASES.has(chapter_title): return
	var expected_base: String="res://assets/map/events/"+str(MANUSCRIPT_BASES[chapter_title])
	var found_base := false
	var found_foreground := false
	# Inspect the live illustration subtree on every production action, not
	# only arrival: base-only arrivals are valid, later layers must also occur.
	for child in panel.art.find_children("*","TextureRect",true,false):
		if not child is TextureRect or child.texture==null: continue
		var resource_path: String=child.texture.resource_path
		_visual_check(resource_path.begins_with("res://assets/map/events/manuscript_"),"approved manuscript chapter never displays old event art: "+chapter_title+" / "+resource_path)
		if resource_path==expected_base:
			found_base=true
		elif resource_path.begins_with("res://assets/map/events/manuscript_"):
			found_foreground=true
	_visual_check(found_base,"actual chapter renders its own approved background: "+chapter_title)
	if found_base: manuscript_families[expected_base]=true
	if found_base and found_foreground: manuscript_foreground_families[expected_base]=true

func press_story_action(action: Button) -> void:
	if action!=null: inspect_book(action.get_parent())
	super.press_story_action(action)

func arrive(session: Node, kind: String, label: String, expected_first_button: String="계속") -> Dictionary:
	var arrival: Dictionary=await super.arrive(session,kind,label,expected_first_button)
	if not arrival.is_empty() and arrival.map.overlay is MainBook:
		inspect_book(arrival.map.overlay)
		arrival.map.overlay.typewriter.reveal_all()
		if not output.is_empty() and DisplayServer.get_name()!="headless":
			DirAccess.make_dir_recursive_absolute(output)
			await create_timer(0.75).timeout
			await RenderingServer.frame_post_draw
			var file:=output.path_join(label.replace(":","_")+".png")
			check(root.get_texture().get_image().save_png(file)==OK,"native connected story capture "+label)
	return arrival

func rescue_and_king(session: Node, victor: String) -> void:
	await super.rescue_and_king(session,victor)
	if victor=="ally" and failed==0 and not export_story.is_empty():
		var file:=FileAccess.open(export_story,FileAccess.WRITE)
		check(file!=null,"export completed actual story for final book handoff")
		if file!=null: file.store_string(JSON.stringify(session.world.snapshot(),"\t"))
