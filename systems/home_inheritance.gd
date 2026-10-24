extends "res://systems/reward_ui.gd"
const Sound = preload("res://systems/game_audio.gd")
const CardDepthMotion = preload("res://systems/card_depth_motion.gd")
const PanelDepthMotion = preload("res://systems/panel_depth_motion.gd")
const SacrificeEffect = preload("res://systems/inheritance_sacrifice_effect.gd")
# Transparent, unlettered and undivided backdrop; all roster text and cards are live UI.
const ROSTER_FRAME = "res://assets/map/ui/inheritance_roster_frame.webp"
const ROSTER_COLUMNS = 10
const ROSTER_CAPACITY = 10
const ROSTER_SLOT_WIDTH = 98.0
const ROSTER_CARD_GAP = 8.0
signal closed
const BrandInheritance = preload("res://systems/brand_inheritance.gd")
var session
var map_scene
var closing_depth := false
var depth_panels: Array[Control] = []
var material_id = ""
var receiver_id = ""
var completed = false
var busy = false
var notice = ""
var material_art: TextureRect
var receiver_art: TextureRect
var material_marks: Label
var material_hint: Label
var receiver_hint: Label
var status: Label
var sacrifice_warning: Label
var inherited_brand: Dictionary = {}
var details: VBoxContainer
var confirm_button: Button
var hand: Control
var unit_options: Dictionary = {}
var unit_hand_scroll: ScrollContainer
var inheritance_frame: TextureRect
var interface_data: Dictionary

func setup(run_session, map_scene: Control = null) -> void:
	session = run_session
	self.map_scene = map_scene
	z_index = 85
	interface_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/interface.json"))
	backdrop()
	# Optional map reference keeps direct tests/backwards callers compatible.
	if map_scene != null:
		map_scene.location_scene_image(self,"res://assets/map/events/home-interior.jpg")
	label_at(self,"낙인 계승",Vector2(450,7),Vector2(380,30),24)
	var close_action=button(self,"닫기",Vector2(1129,29),Vector2(92,38),func(): if not busy: close_depth())
	close_action.set_meta("sfx_manual",true)
	# Web prototype shows three adjacent columns and two simultaneous card sources.
	panel_slot(Vector2(198,38),true)
	panel_slot(Vector2(814,38),false)
	inheritance_frame=art(self,"res://assets/map/ui/inheritance_info.webp",Vector2(471,62),Vector2(338,352))
	inheritance_frame.stretch_mode=TextureRect.STRETCH_SCALE
	PanelDepthMotion.shadow(inheritance_frame)
	PanelDepthMotion.enter(inheritance_frame)
	depth_panels.append(inheritance_frame)
	var title=label_at(self,"계승 정보",Vector2(497,104),Vector2(286,27),20)
	title.add_theme_color_override("font_color",Color("34251c"))
	title.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	var scroll=ScrollContainer.new()
	scroll.name="InheritanceDetailsScroll"
	scroll.position=Vector2(498,144)
	scroll.size=Vector2(284,173)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	details=VBoxContainer.new()
	details.name="InheritanceDetails"
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",9)
	scroll.add_child(details)
	# Warning and progress remain fully inside the parchment, never stretched
	# across the neighboring donor / recipient cards.
	sacrifice_warning=label_at(self,"",Vector2(502,318),Vector2(276,28),16)
	sacrifice_warning.name="InheritanceSacrificeWarning"
	sacrifice_warning.add_theme_color_override("font_color",Color("782b22"))
	sacrifice_warning.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	status=label_at(self,"",Vector2(498,346),Vector2(284,39),16)
	status.name="InheritanceStepStatus"
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color",Color("5b3526"))
	status.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	confirm_button=button(self,"계승",Vector2(552,389),Vector2(176,40),confirm)
	confirm_button.add_theme_font_size_override("font_size",17)
	var parchment=StyleBoxTexture.new()
	parchment.texture=load("res://assets/map/ui/parchment_button_variant_01.png")
	for state in ["normal","hover","pressed","focus","disabled"]:
		confirm_button.add_theme_stylebox_override(state,parchment)
	confirm_button.add_theme_color_override("font_color",Color("40291c"))
	render_hand()
	render_selection()

func panel_slot(pos: Vector2, material: bool) -> void:
	var node = Control.new()
	node.position = pos
	node.size = Vector2(266,390)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	PanelDepthMotion.shadow(node)
	PanelDepthMotion.enter(node)
	depth_panels.append(node)
	var board = TextureRect.new()
	var atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/map/events/inheritance-board.png")
	atlas.region = Rect2(342 if material else 997,30,570,780)
	board.texture = atlas
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.size = node.size
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(board)
	label_at(node,"재료" if material else "결과",Vector2(21,32),Vector2(225,31),20)
	var preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.position = Vector2(38,92)
	preview.size = Vector2(191,233)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(preview)
	var hint = label_at(node,"",Vector2(27,336),Vector2(214,34),13)
	if material:
		material_art = preview
		material_marks = label_at(preview,"",Vector2(18,164),Vector2(114,32),13)
		material_marks.add_theme_color_override("font_color",Color("101b2c"))
		material_marks.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		material_hint = hint
	else:
		receiver_art = preview
		receiver_hint = hint

func set_preview(node: TextureRect, kind: String, item: Dictionary) -> void:
	if kind=="unit":
		LayeredUnitCard.sync_preview(node,item)
	else:
		node.texture = load(Catalog.image(kind,item)) if not item.is_empty() else null
	AltarUpgradeBadge.sync(node,item if kind=="unit" else {})

func detail(value: String, color: Color = Color("34251c"), font_size: int = 14) -> Label:
	var line = Label.new()
	line.text = value
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_font_size_override("font_size",font_size)
	line.add_theme_color_override("font_color",color)
	line.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(line)
	return line

func section_heading(value: String) -> void:
	var title := detail(value,Color("63432f"),16)
	title.name="InheritanceSectionHeading"

func append_brands(brands: Array, show_curse: bool = true) -> void:
	for brand in brands:
		if not (brand is Dictionary): continue
		var brand_name: String = str(interface_data.brands[brand.type].name).replace("의 낙인","")
		var faces: String = ", ".join(brand.bless.map(func(n): return str(int(n))))
		var card_row := HBoxContainer.new()
		card_row.name="InheritanceBrandRow"
		card_row.add_theme_constant_override("separation",7)
		details.add_child(card_row)
		var name_label := Label.new()
		name_label.text=brand_name
		name_label.name="InheritanceBrandName"
		name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size",19)
		name_label.add_theme_color_override("font_color",Color("39251c"))
		name_label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card_row.add_child(name_label)
		var faces_label := Label.new()
		faces_label.name="InheritanceBlessingFaces"
		faces_label.text="축복 " + (faces if not faces.is_empty() else "없음")
		faces_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		faces_label.add_theme_font_size_override("font_size",16)
		faces_label.add_theme_color_override("font_color",Color("6c4327"))
		faces_label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
		faces_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card_row.add_child(faces_label)
		# Compact selection summary: full blessing effects are already
		# accessible in the monster/brand information screens. These
		# values are die faces, never +2 or +3 damage bonuses.
		if show_curse and not brand.curse.is_empty():
			# Cursed faces belong to this existing brand. They are not copied
			# to the recipient by the inheritance rule.
			var cursed: String = ", ".join(brand.curse.map(func(n): return str(int(n))))
			var curse_label := Label.new()
			curse_label.name="InheritanceCurseFaces"
			curse_label.text="저주 " + cursed
			curse_label.add_theme_font_size_override("font_size",16)
			curse_label.add_theme_color_override("font_color",Color("903c32"))
			curse_label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
			curse_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
			card_row.add_child(curse_label)

func render_selection() -> void:
	var material: Dictionary = session.owned_unit(material_id)
	var receiver: Dictionary = session.owned_unit(receiver_id)
	set_preview(material_art,"unit",material)
	set_preview(receiver_art,"unit",receiver)
	material_marks.text = ""
	material_hint.text = "소모 완료" if completed else str(material.get("name","아래에서 재료 선택"))
	receiver_hint.text = str(receiver.get("name","받는 마물 선택"))
	for child in details.get_children():
		details.remove_child(child)
		child.queue_free()

	# Both selected monsters already display their names on the side cards.
	# The parchment only needs brand names, die faces, and the one real risk.
	if completed:
		if not inherited_brand.is_empty():
			section_heading("획득한 낙인")
			append_brands([inherited_brand],false)
	elif material.is_empty():
		section_heading("① 재료 마물 선택")
		detail("② 받을 마물 선택",Color("694c38"),16)
	else:
		section_heading("재료 낙인")
		var source_brands: Array = BrandInheritance.normalize(material,session.world.definitions)
		if source_brands.is_empty():
			detail("계승할 낙인 없음",Color("853a31"),15)
		else:
			# Material may carry a curse, but the inheritance preview only
			# exposes transferable blessings. Existing receiver curses stay visible.
			append_brands(source_brands,false)
		if not receiver.is_empty():
			# Give the donor's blessings and the recipient's existing brands
			# visual breathing room. The scroll view keeps long lists contained.
			var section_gap := Control.new()
			section_gap.name="InheritanceSectionGap"
			section_gap.custom_minimum_size=Vector2(0,20)
			section_gap.mouse_filter=Control.MOUSE_FILTER_IGNORE
			details.add_child(section_gap)
			section_heading("기존 낙인 · %d/3칸" % receiver.brands.size())
			var existing_brands: Array = BrandInheritance.normalize(receiver,session.world.definitions)
			if existing_brands.is_empty():
				detail("없음",Color("694c38"),16)
			else:
				append_brands(existing_brands)

	# A single unmistakable permanent-sacrifice warning. Never repeat
	# the same sentence in the step text or the confirm button.
	if completed:
		sacrifice_warning.text = "계승 완료"
	elif not material.is_empty():
		sacrifice_warning.text = "재료 마물 영구 소멸"
	else:
		sacrifice_warning.text = ""

	if not notice.is_empty():
		status.text = notice
	elif completed:
		status.text = "받는 마물 · 낙인 %d/3칸" % receiver.brands.size()
	elif material.is_empty():
		status.text = ""
	elif receiver.is_empty():
		status.text = "② 받을 마물 선택"
	else:
		var material_cursed: bool = false
		for brand in BrandInheritance.normalize(material,session.world.definitions):
			if not brand.curse.is_empty():
				material_cursed=true
				break
		status.text = "축복만 무작위 계승" if material_cursed else "낙인 1개 무작위 계승"

	var eligible: bool = not receiver.is_empty() and receiver.brands.size()<3 and not material.is_empty() and not material.brands.is_empty() and material_id!=receiver_id
	confirm_button.disabled = busy or completed or not eligible or not session.home_action_allowed().ok
	confirm_button.text = "계승 완료" if completed else "계승 확정"
	for id in unit_options:
		var option: TextureButton = unit_options[id]
		option.modulate = Color(1.14,1.08,0.87) if id in [material_id,receiver_id] else Color.WHITE
		option.get_child(0).text = str(session.owned_unit(id).get("name",""))+("\n재료" if id==material_id else ("\n받는 마물" if id==receiver_id else ""))
		option.disabled = busy or completed

func render_hand() -> void:
	if is_instance_valid(hand):
		remove_child(hand)
		hand.queue_free()
	unit_options.clear()
	hand=Control.new()
	hand.name="InheritanceRosterPanel"
	add_child(hand)
	# The approved art contains one continuous empty surface and an EMPTY
	# title plaque: no fixed wording, slots, card outlines or dividers.
	var frame := TextureRect.new()
	frame.name="InheritanceRosterFrame"
	frame.texture=load(ROSTER_FRAME)
	frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode=TextureRect.STRETCH_SCALE
	# The top preview boards are symmetrical around x=640. Keep the
	# lower frame and its contents centered on that same 1280px canvas.
	frame.position=Vector2(90,439)
	frame.size=Vector2(1100,271)
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hand.add_child(frame)
	var unit_label=label_at(hand,"보유 마물 (%d/%d)" % [session.world.roster.size(),ROSTER_CAPACITY],Vector2(490,446),Vector2(300,30),18)
	unit_label.name="InheritanceRosterCount"
	unit_label.add_theme_color_override("font_color",Color("efcc91"))
	# Keep the old viewport API for existing callers; a full ten-card roster
	# fits in one row. Smaller rosters are centered rather than left-aligned.
	unit_hand_scroll=ScrollContainer.new()
	unit_hand_scroll.name="InheritanceRosterViewport"
	var card_count: int = mini(session.world.roster.size(),ROSTER_CAPACITY)
	var row_width: float = float(card_count)*ROSTER_SLOT_WIDTH + float(maxi(0,card_count-1))*ROSTER_CARD_GAP
	unit_hand_scroll.position=Vector2((size.x-row_width)*0.5,496)
	unit_hand_scroll.size=Vector2(row_width,178)
	unit_hand_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	unit_hand_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	hand.add_child(unit_hand_scroll)
	var unit_grid=GridContainer.new()
	unit_grid.name="InheritanceRosterGrid"
	unit_grid.columns=ROSTER_COLUMNS
	unit_grid.add_theme_constant_override("h_separation",int(ROSTER_CARD_GAP))
	unit_grid.add_theme_constant_override("v_separation",0)
	unit_hand_scroll.add_child(unit_grid)
	if session.world.roster.is_empty():
		label_at(hand,"보유한 마물이 없습니다",Vector2(390,570),Vector2(500,29),16)
	for item in session.world.roster:
		var box=Control.new()
		box.custom_minimum_size=Vector2(ROSTER_SLOT_WIDTH,172)
		unit_grid.add_child(box)
		var id=str(item.id)
		var option=card(box,"unit",item,Vector2(2,10),Vector2(94,151),func(): select_unit(id))
		option.name="InheritanceRosterCard_%d" % (unit_grid.get_child_count()-1)
		CardDepthMotion.install(option)
		# Layered cards draw their names on their own parchment ribbons.
		# No duplicate caption beneath the single compact card row.
		option.get_child(0).hide()
		unit_options[id]=option
	render_selection()
	# The existing entry motion and dissolve only move visual controls.
	hand.position.y=48
	hand.modulate.a=0.0
	var rise=create_tween().set_parallel(true)
	rise.tween_property(hand,"position:y",0.0,0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(hand,"modulate:a",1.0,0.24)

func select_unit(id: String) -> void:
	if completed or busy: return
	notice = ""
	var unit = session.owned_unit(id)
	if unit.is_empty(): return
	if id==material_id:
		material_id = ""
		receiver_id = ""
	elif id==receiver_id: receiver_id = ""
	elif material_id.is_empty(): material_id = id
	elif unit.brands.size()>=3: notice = "낙인 3칸이 찬 마물은 받는 마물이 될 수 없습니다."
	else: receiver_id = id
	render_selection()

func confirm() -> void:
	if busy or completed or confirm_button.disabled: return
	busy = true
	render_selection()
	var consumed_id: String = material_id
	# Persist the real inheritance BEFORE starting any animation. A failed
	# transaction leaves both cards exactly where they were.
	var result = session.inherit_at_home(receiver_id,consumed_id)
	if not result.ok:
		busy = false
		notice = result.reason
		render_selection()
		return
	completed = true
	# Reuse the source parchment bitmap; do not interfere with the separate
	# sacrificial-card dissolve already owned by this functional screen.
	if is_instance_valid(map_scene):
		map_scene.animate_used_location_paper(self,session.MapState.HOME,"inheritance")
	Sound.cue(self,"inheritance_complete")
	inherited_brand = result.brand.duplicate(true)
	notice = ""
	# The screen stays locked and both original card nodes stay visible until
	# the sacrificial dissolve has finished; don't re-render prematurely.
	var source_card: Control = unit_options.get(consumed_id,null) as Control
	await SacrificeEffect.play(material_art,source_card)
	if not is_inside_tree(): return
	material_id = ""
	render_hand()
	# render_hand/render_selection clears the donor's picture. Reset its
	# transient canvas transform so reused preview slots remain canonical.
	material_art.scale = Vector2.ONE
	material_art.rotation_degrees = 0.0
	material_art.modulate = Color.WHITE
	busy = false
	render_selection()
	Sound.cue(self,"book_stamp")
	var flash = create_tween()
	receiver_art.modulate = Color(1.3,1.15,0.85)
	flash.tween_property(receiver_art,"modulate",Color.WHITE,0.28)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not busy:
		get_viewport().set_input_as_handled()
		close_depth()

func close_depth() -> void:
	if busy or closing_depth: return
	Sound.cue(self,"ui_cancel")
	closing_depth = true
	for panel in depth_panels:
		if is_instance_valid(panel): PanelDepthMotion.exit(panel, Callable())
	get_tree().create_timer(0.14).timeout.connect(func():
		if is_instance_valid(self): closed.emit())
