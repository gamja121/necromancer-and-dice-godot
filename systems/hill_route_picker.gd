extends "res://systems/reward_ui.gd"
## Presentation only: real forward tile art, ink path and selected flag.
## The owning action screen validates and saves movement through RunSession.
signal step_selected(steps:int)
const State=preload("res://systems/map_state.gd")
const CURVE_Y=[349.0,341.0,335.0,338.0,346.0,350.0]
var choice_buttons:Array[Button]=[]
var pictures:Array[TextureRect]=[]
var captions:Array[Label]=[]
var distance_labels:Array[Label]=[]
var centers:Array[Vector2]=[]
var path:InkPath
var flag:Flag
var selected_steps:int=0
var max_steps:int=6
var available:bool=true
var locked:bool=false
class InkPath extends Control:
	var points:=PackedVector2Array()
	var selected:int=0
	func _draw() -> void:
		if points.size()<2: return
		for i in range(points.size()-1):
			var from:Vector2=points[i]
			var to:Vector2=points[i+1]
			var segment:=PackedVector2Array()
			for j in range(13):
				var t:float=float(j)/12.0
				segment.append(from.lerp(to,t)+Vector2(0,sin(t*PI*2.0+float(i))*1.6))
			draw_polyline(segment,Color("281f15a8"),5.2,true)
			draw_polyline(segment,Color("b7a17b86"),1.9,true)
			if selected>0 and i<selected:
				draw_polyline(segment,Color("32200e"),5.8,true)
				draw_polyline(segment,Color("e2bd70"),2.8,true)
		draw_circle(points[0],5.0,Color("281c13"))
		draw_circle(points[0],2.0,Color("ddbb75"))

class Flag extends Control:
	func _draw() -> void:
		draw_line(Vector2.ZERO,Vector2(-3,-54),Color("23180f"),3.5,true)
		draw_line(Vector2(1,-2),Vector2(-2,-54),Color("c2a06b"),0.9,true)
		var cloth:=PackedVector2Array([Vector2(-2,-51),Vector2(29,-48),Vector2(22,-37),Vector2(30,-28),Vector2(-1,-33)])
		draw_colored_polygon(cloth,Color("6a3024"))
		var edge:=cloth.duplicate()
		edge.append(cloth[0])
		draw_polyline(edge,Color("27190f"),1.8,true)
		draw_line(Vector2(1,-48),Vector2(24,-45),Color("be8755"),0.8,true)
		for i in range(5):
			draw_line(Vector2(3+float(i)*3,-43),Vector2(6+float(i)*3,-38),Color("a1674280"),0.8,true)
		draw_circle(Vector2.ZERO,3.7,Color("2e1b12"))


func caption(value:String,pos:Vector2,dimensions:Vector2,font_size:int=16) -> Label:
	var text:Label=label_at(self,value,pos,dimensions,font_size)
	text.z_index=6
	text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_constant_override("outline_size",3)
	text.add_theme_color_override("font_outline_color",Color("261b12"))
	return text

func setup(tiles:Array,index:int,limit:int,enabled:bool,origin_text:String="현재") -> void:
	name="HillRoutePicker"
	size=Vector2(1280,720)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	max_steps=clampi(limit,1,6)
	available=enabled
	path=InkPath.new()
	path.name="HillInkPath"
	path.size=size
	path.z_index=1
	path.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(path)
	path.points.append(Vector2(183,371))
	for i in range(6):
		var point:=Vector2(270+108*i,float(CURVE_Y[i]))
		centers.append(point)
		path.points.append(point)
		var step:int=i+1
		var destination:int=(index+step)%tiles.size()
		var kind:String=str(tiles[destination])
		var tile_name:String=str(State.NAMES.get(kind,"알 수 없는 장소"))
		var hit:=Button.new()
		hit.name="HillStep%d"%step
		hit.position=point-Vector2(52,70)
		hit.size=Vector2(104,140)
		hit.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for state in ["normal","hover","pressed","focus","disabled"]: hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		hit.z_index=4
		hit.tooltip_text="앞으로 %d칸 · %d번 %s"%[step,destination+1,tile_name] if step<=max_steps else "집을 지나서는 이동할 수 없습니다."
		hit.pressed.connect(func():
			if not hit.disabled and not locked: step_selected.emit(step))
		add_child(hit)
		choice_buttons.append(hit)
		var picture_path:String="res://assets/map/tiles/%s.png"%kind
		if not ResourceLoader.exists(picture_path): picture_path="res://assets/map/tiles/basic.png"
		var picture:TextureRect=art(hit,picture_path,Vector2(7,36),Vector2(90,68))
		picture.name="HillDestinationPreview"
		picture.pivot_offset=picture.size*0.5
		pictures.append(picture)
		var distance:Label=caption("%d칸"%step,point+Vector2(-52,-68),Vector2(104,24),17)
		distance_labels.append(distance)
		var long_name:bool=tile_name.length()>6
		var text:Label=caption(tile_name,point+Vector2(-52,37 if long_name else 43),Vector2(104,34 if long_name else 24),14 if long_name else 16)
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		captions.append(text)
	caption(origin_text,Vector2(158,384),Vector2(50,25),14)
	flag=Flag.new()
	flag.name="HillDestinationFlag"
	flag.size=Vector2(38,58)
	flag.z_index=8
	flag.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(flag)
	flag.hide()
	_refresh()

func set_available(value:bool) -> void:
	available=value
	_refresh()

func set_locked(value:bool) -> void:
	locked=value
	_refresh()

func set_selection(step:int) -> void:
	selected_steps=clampi(step,0,max_steps)
	_refresh()

func _refresh() -> void:
	for i in range(choice_buttons.size()):
		var allowed:bool=available and i+1<=max_steps
		var chosen:bool=selected_steps==i+1
		choice_buttons[i].disabled=locked or not allowed
		pictures[i].scale=Vector2.ONE*(1.16 if chosen else 1.0)
		pictures[i].modulate=Color.WHITE if chosen else Color(0.9,0.9,0.9,1.0)
		if not allowed: pictures[i].modulate=Color(0.55,0.55,0.55,0.45)
		captions[i].add_theme_color_override("font_color",Color("ffe5a6") if chosen else Color("f2dfb5"))
		captions[i].modulate.a=1.0 if allowed or chosen else 0.45
		distance_labels[i].modulate.a=1.0 if allowed or chosen else 0.45
	if is_instance_valid(flag):
		flag.visible=selected_steps>0
		if selected_steps>0: flag.position=centers[selected_steps-1]+Vector2(36,-25)
	if is_instance_valid(path):
		path.selected=selected_steps
		path.queue_redraw()
