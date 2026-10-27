extends RefCounted
## Shared prophet/cemetery parchment. Keep the approved original geometry.
const TEXTURE=preload("res://assets/map/ui/fortune_parchment_strip.webp")
const RECT=Rect2(340,423,600,150)
const TEXT_RECT=Rect2(394,465,492,30)
const DETAIL_RECT=Rect2(393,500,494,24)

static func build(parent:Control,existing_label:Label=null) -> Dictionary:
	var strip:=TextureRect.new()
	strip.name="LocationNoticeStrip"
	strip.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	strip.texture=TEXTURE
	strip.position=RECT.position
	strip.size=RECT.size
	strip.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	strip.z_index=2
	parent.add_child(strip)
	var notice:Label=existing_label
	if not is_instance_valid(notice):
		notice=Label.new()
		notice.name="LocationNoticeText"
		parent.add_child(notice)
	notice.position=TEXT_RECT.position
	notice.size=TEXT_RECT.size
	notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	notice.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	notice.add_theme_font_size_override("font_size",20)
	notice.add_theme_color_override("font_color",Color("48301d"))
	notice.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	notice.z_index=3
	var detail:=Label.new()
	detail.name="LocationNoticeDetail"
	detail.position=DETAIL_RECT.position
	detail.size=DETAIL_RECT.size
	detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	detail.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail.mouse_filter=Control.MOUSE_FILTER_IGNORE
	detail.add_theme_font_size_override("font_size",14)
	detail.add_theme_color_override("font_color",Color("5b412d"))
	detail.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	detail.z_index=3
	detail.hide()
	parent.add_child(detail)
	return {"strip":strip,"text":notice,"detail":detail}
