extends Control
## Temporary ink strokes only. No gameplay state, random draws or new props.
var progress:float=1.0:
	set(value):
		progress=value
		queue_redraw()
var active:bool=false
var face:int=0
var tone:Color=Color("a37a35")
var cue:Control
var motion:Tween

class DieCue extends Control:
	var phase:float=0.0
	func _process(delta:float) -> void:
		phase+=delta
		queue_redraw()
	func _draw() -> void:
		var ink:=Color("e5bf76")
		ink.a=0.28+0.19*(0.5+0.5*sin(phase*2.4))
		for corner in [Vector2(0,0),Vector2(size.x,0),Vector2(0,size.y),size]:
			var dx:float=1.0 if corner.x==0 else -1.0
			var dy:float=1.0 if corner.y==0 else -1.0
			var points:=PackedVector2Array([corner+Vector2(0,dy*13),corner+Vector2(dx,dy*3),corner+Vector2(dx*12,dy)])
			draw_polyline(points,ink,1.6,true)

func setup(die:TextureButton) -> void:
	name="FortuneInkEffect"
	position=Vector2(394,457)
	size=Vector2(492,72)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=4
	cue=DieCue.new()
	cue.name="FortuneDieCue"
	cue.position=Vector2(-7,-7)
	cue.size=die.size+Vector2(14,14)
	cue.mouse_filter=Control.MOUSE_FILTER_IGNORE
	die.add_child(cue)
	set_available(false)

func set_available(value:bool) -> void:
	if not is_instance_valid(cue): return
	cue.visible=value
	cue.set_process(value)

func play(notice:Label,detail:Label,result_face:int) -> void:
	if is_instance_valid(motion) and motion.is_running(): motion.kill()
	face=result_face
	tone=Color("573e39") if face==1 else (Color("657b4c") if face==2 else Color("ad8135"))
	if face==6: tone=Color("c18d2b")
	progress=0.0
	active=true
	set_available(false)
	notice.visible_ratio=0.0
	detail.visible_ratio=0.0
	notice.modulate.a=0.35
	detail.modulate.a=0.35
	var duration:float=0.84 if face==6 else 0.62
	motion=create_tween().set_parallel(true)
	motion.tween_property(self,"progress",1.0,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	motion.tween_property(notice,"visible_ratio",1.0,duration*0.70)
	motion.tween_property(notice,"modulate:a",1.0,duration*0.70)
	motion.tween_property(detail,"visible_ratio",1.0,duration*0.62).set_delay(duration*0.18)
	motion.tween_property(detail,"modulate:a",1.0,duration*0.62).set_delay(duration*0.18)
	motion.chain().tween_callback(func(): active=false)

func _draw() -> void:
	if progress>=1.0: return
	var ink:Color=tone
	ink.a=sin(progress*PI)*(0.56 if face==6 else 0.38)
	var width:float=430.0*minf(progress*1.8,1.0)
	var left:float=(size.x-width)*0.5
	for stroke in range(3 if face==6 else 2):
		var points:=PackedVector2Array()
		for sample in range(26):
			var x:float=left+width*float(sample)/25.0
			var y:float=3.0 if stroke==0 else (39.0 if stroke==1 else 66.0)
			y+=sin(float(sample)*0.81+float(stroke)*2.1)*0.75
			points.append(Vector2(x,y))
		draw_polyline(points,ink,1.3 if stroke==0 else 0.85,true)
		for hatch in range(6):
			var x:float=left+width*float(hatch+1)/7.0
			draw_line(Vector2(x,4),Vector2(x+3,7),Color(ink,ink.a*0.48),0.7,true)

func _exit_tree() -> void:
	if is_instance_valid(motion) and motion.is_running(): motion.kill()
	if is_instance_valid(cue):
		if cue.get_parent()!=null: cue.get_parent().remove_child(cue)
		cue.queue_free()
