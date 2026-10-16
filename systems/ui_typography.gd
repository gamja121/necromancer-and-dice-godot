extends Node
## Optional, local-only font preview. No UnYetgul font bytes are distributed.
## CTAN unfonts-extra uses GPLv2 without a font-embedding exception. Keep the
## original font out of the public game's source/package until licensing is resolved.
const USER_FONT_PATH = "user://fonts/UnYetgul.ttf"
const PROJECT_PREVIEW_PATH = "res://assets/fonts/UnYetgul.ttf"
var info_font: Font = null

func _enter_tree() -> void:
	info_font = load_local_font()
	if info_font == null:
		# Missing preview font must never break the shipped UI or saved games.
		return
	get_tree().node_added.connect(_on_node_added)

func load_local_font() -> Font:
	for path in [USER_FONT_PATH, PROJECT_PREVIEW_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if bytes.size()<1024: continue
		var file := FontFile.new()
		file.data = bytes
		if file.has_char("낙".unicode_at(0)) and file.has_char("1".unicode_at(0)):
			return file
		push_warning("Optional UI preview font is invalid or missing Korean glyphs: "+path)
	return null

func _on_node_added(node: Node) -> void:
	if not node is Control: return
	# Defer until label names, explicit story-copy metadata and theme overrides
	# have been assigned by the owner (often immediately after add_child).
	_apply_after_setup.call_deferred(node)

func _apply_after_setup(node: Node) -> void:
	if info_font != null and is_instance_valid(node):
		apply_info_font(node,info_font)

static func is_narrative(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if current.get_meta("ui_font_preserve",false):
			return true
		if str(current.get_meta("ui_story_copy_role","")) in ["speech","narration"]:
			return true
		# The introduction uses its own Nanum Gothic theme for all story beats.
		if current.name=="Intro":
			return true
		var script: Script = current.get_script() as Script
		if script != null and script.resource_path=="res://systems/intro_scene.gd":
			return true
		current=current.get_parent()
	# Event/discovery descriptions are narrative prose, not functional HUD text.
	return node.name in ["EventDiscoveryDescription"]

static func apply_info_font(node: Node, font: Font) -> bool:
	if font == null or not node is Control or is_narrative(node):
		return false
	if node is RichTextLabel:
		var rich := node as RichTextLabel
		rich.add_theme_font_override("normal_font",font)
		rich.add_theme_font_override("bold_font",font)
	elif node is Label or node is Button or node is LineEdit or node is TextEdit:
		(node as Control).add_theme_font_override("font",font)
	else:
		return false
	return true
