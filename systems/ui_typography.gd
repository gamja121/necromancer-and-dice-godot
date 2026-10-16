extends Node
## B = NanumSquareRound Regular (body); D = NanumBarunGothic Regular (titles).
## Both are NAVER SIL OFL 1.1 fonts bundled under assets/fonts.
const BODY_PATH = "res://assets/fonts/NanumSquareRoundR.ttf"
const HEADING_PATH = "res://assets/fonts/NanumBarunGothic.ttf"
var body_font: Font
var heading_font: Font

func _enter_tree() -> void:
	body_font = load(BODY_PATH) if ResourceLoader.exists(BODY_PATH) else null
	heading_font = load(HEADING_PATH) if ResourceLoader.exists(HEADING_PATH) else null
	if body_font==null or heading_font==null:
		push_warning("Selected B/D fonts missing; keeping existing Nanum Gothic.")
		return
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is Control:
		_apply_after_setup.call_deferred(node)

func _apply_after_setup(node: Node) -> void:
	if is_instance_valid(node) and body_font!=null and heading_font!=null:
		apply_ui_font(node,body_font,heading_font)

static func is_narrative(node: Node) -> bool:
	var current: Node=node
	while current!=null:
		if current.get_meta("ui_font_preserve",false): return true
		if str(current.get_meta("ui_story_copy_role","")) in ["speech","narration"]: return true
		if current.name=="Intro": return true
		var script: Script=current.get_script() as Script
		if script!=null and script.resource_path=="res://systems/intro_scene.gd": return true
		current=current.get_parent()
	var key: String=str(node.name).to_lower()
	return node.name=="EventDiscoveryDescription" or key.contains("dialoguetext") or key.contains("narration") or key.contains("storyspeaker")

static func is_heading(node: Node) -> bool:
	var role: String=str(node.get_meta("ui_font_role","")).to_lower()
	if role in ["title","heading","emphasis"]: return true
	if role in ["body","info"]: return false
	if not node is Label: return false
	var key: String=str(node.name).to_lower()
	if key.ends_with("title") or key.contains("heading") or key.contains("header") or key.contains("subtitle") or key.ends_with("category"):
		return true
	# Large Korean text without an explicit role is generally a panel heading.
	# Never classify large numerical battle/dice status values as a heading.
	var label: Label=node as Label
	if label.get_theme_font_size("font_size")<22 or label.text.length()>42: return false
	for i in range(label.text.length()):
		var code: int=label.text.unicode_at(i)
		if code>=0xAC00 and code<=0xD7A3: return true
	return false

static func apply_ui_font(node: Node, info: Font, heading: Font) -> bool:
	if info==null or heading==null or not node is Control or is_narrative(node): return false
	var target: Font=heading if is_heading(node) else info
	if node is RichTextLabel:
		var rich: RichTextLabel=node as RichTextLabel
		rich.add_theme_font_override("normal_font",info)
		rich.add_theme_font_override("bold_font",heading)
		rich.add_theme_font_override("italics_font",info)
		rich.add_theme_font_override("bold_italics_font",heading)
	elif node is Label or node is Button or node is LineEdit or node is TextEdit:
		(node as Control).add_theme_font_override("font",target)
	else: return false
	return true
