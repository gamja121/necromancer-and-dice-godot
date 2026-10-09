extends Control
const OriginalEffects = preload("res://systems/original_effects.gd")
const PermanentDeath = preload("res://systems/permanent_death.gd")

class Ground extends Control:
	var effects
	func _draw() -> void:
		effects.draw_ground(self)

var original = OriginalEffects.new()
var art_items: Array = []
var scene
var world_layer: Control
var ground: Control
var states: Dictionary = {}
var homes: Dictionary = {}
var layouts: Dictionary = {}
var active: Dictionary = {}
var flashes: Dictionary = {}
var particles: Array = []
var numbers: Array = []
var missiles: Array = []
var removed: Dictionary = {}
var presentation_hold = false
var clock = 0.0
var idle_clock = 0.0
var focus_actor = ""
var focus_target = ""
var hit_motions: Dictionary = {}
var shake_left = 0.0
var shake_strength = 0.0
var duck_until = 0.0
var shader: Shader

func setup(battle_scene, parent: Control) -> void:
	scene = battle_scene
	for kind in original.metadata.effects: original.hit_frames(kind)
	world_layer = parent
	size = scene.surface_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float dim = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 source = COLOR;
	float gray = dot(source.rgb,vec3(0.2126,0.7152,0.0722));
	vec3 shaded = mix(source.rgb,mix(vec3(gray),source.rgb,0.72)*0.48,dim);
	COLOR = vec4(mix(shaded, vec3(1.0, 0.18, 0.1), flash), source.a);
}
"""
	ground = Ground.new()
	ground.effects = self
	ground.size = size
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.z_index = 0
	parent.add_child(ground)

func sync(values: Array) -> void:
	for unit in values:
		states[unit.id] = unit.duplicate(true)
		layouts[unit.id] = scene.presentation_layout.geometry(unit,scene.surface_size)
		var sprite: TextureRect = scene.sprites[unit.id]
		homes[unit.id] = sprite.position
		sprite.pivot_offset = layouts[unit.id].pivot
		if sprite.material == null:
			var material = ShaderMaterial.new()
			material.shader = shader
			sprite.material = material

func _process(delta: float) -> void:
	if scene == null: return
	var dt: float = 0.0 if scene.paused or presentation_hold else delta*scene.speed_values[scene.speed_index]
	clock += dt
	if not scene.paused and not presentation_hold: idle_clock += delta
	scene.audio.volume_db = lerpf(scene.audio.volume_db,-19.0 if clock<duck_until else -15.0,minf(1,dt*12))
	for id in states:
		var sprite: TextureRect = scene.sprites[id]
		var unit: Dictionary = states[id]
		var desired: Vector2 = homes[id]
		if id==focus_actor:
			var wrap: Vector2 = layouts[id].wrap
			desired += Vector2(wrap.x*0.36*(1.0 if unit.team=="ally" else -1.0),wrap.y*0.05)
		sprite.position = sprite.position.lerp(desired,minf(1.0,dt*18.0))
		if not active.has(id) and unit.alive and not unit.frozen:
			var period = 1.36 if unit.slot%3==0 else (1.58 if unit.slot%2==0 else 1.45)
			var t = fposmod(idle_clock/period+unit.slot*0.29,1.0)
			var keys = [0.0,0.38,0.58,0.76,1.0]
			var scales = [Vector2.ONE,Vector2(1.025,1.08),Vector2(0.975,0.94),Vector2(1.015,1.055),Vector2.ONE]
			for k in range(4):
				if t>=keys[k] and t<keys[k+1]:
					var blend = (t-keys[k])/(keys[k+1]-keys[k])
					sprite.scale = scales[k].lerp(scales[k+1],blend*blend*(3.0-2.0*blend))
					break
		else: sprite.scale = Vector2.ONE
		if hit_motions.has(id):
			var motion: Dictionary = hit_motions[id]
			var index = int((idle_clock-motion.started)/motion.interval)
			if index>=motion.frames.size():
				hit_motions.erase(id)
				active.erase(id)
				sprite.texture = scene.texture(scene.frame_path(unit,"attack",1))
			else:
				var tex = scene.texture(scene.frame_path(unit,"hit",int(motion.frames[index])))
				if tex!=null: sprite.texture = tex
				sprite.position.x += sin((idle_clock-motion.started)/motion.interval*PI)*6.0*(1.0 if unit.team=="enemy" else -1.0)
		sprite.material.set_shader_parameter("flash",0.35 if flashes.get(id,0.0)>clock and sin((flashes[id]-clock)*48.0)>0.0 else 0.0)
	for i in range(art_items.size()-1,-1,-1):
		var item: Dictionary = art_items[i]
		item.age += (0.0 if scene.paused or presentation_hold else delta) if item.get("pop",false) else dt
		var age: float = item.age-item.delay
		item.node.visible = age>=0
		if age<0: continue
		if age>=item.life:
			item.node.queue_free()
			art_items.remove_at(i)
			continue
		if item.get("pop",false):
			var t: float = age/item.life
			var times = [0.0,0.22,0.72,1.0]
			var heights = [12.0,-3.0,-26.0,-43.0]
			var sizes = [0.72,1.18,1.0,0.9]
			for k in range(3):
				if t>=times[k] and t<times[k+1]:
					var blend = (t-times[k])/(times[k+1]-times[k])
					item.node.position = item.origin+Vector2(0,lerpf(heights[k],heights[k+1],blend))
					item.node.scale = Vector2.ONE*lerpf(sizes[k],sizes[k+1],blend)
					break
		else: item.node.position = item.origin+item.velocity*age
		item.node.modulate.a = minf(1,(item.life-age)/0.2)
		if not item.frames.is_empty():
			item.node.texture = item.frames[mini(item.frames.size()-1,int(age/item.interval))]
	for list in [particles,numbers,missiles]:
		for i in range(list.size()-1,-1,-1):
			list[i].age += dt
			if list[i].age>=list[i].life: list.remove_at(i)
	if shake_left>0:
		shake_left = maxf(0,shake_left-dt)
		world_layer.position = Vector2(sin(clock*113),cos(clock*97))*shake_strength*minf(1,shake_left/0.12)
	else: world_layer.position = Vector2.ZERO
	ground.queue_redraw()
	queue_redraw()

func center_of(id: String) -> Vector2:
	var sprite: TextureRect = scene.sprites[id]
	return layouts[id].effect+(sprite.position-homes[id])

func draw_ground(canvas: Control) -> void:
	for id in states:
		if removed.has(id): continue
		var unit: Dictionary = states[id]
		var sprite: TextureRect = scene.sprites[id]
		var foot: Vector2 = homes[id]+sprite.pivot_offset
		var radius = clampf(sprite.size.x*0.22,27,65)
		canvas.draw_set_transform(foot,0,Vector2(1,0.19))
		for ring in range(3):
			canvas.draw_circle(Vector2.ZERO,radius*(1.0-ring*0.16),Color(0.02,0.015,0.035,0.065 if unit.alive else 0.025))
		canvas.draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	for id in states:
		var unit: Dictionary = states[id]
		if not unit.alive: continue
		var center = center_of(id)
		var sprite: TextureRect = scene.sprites[id]
		var foot: Vector2 = homes[id]+sprite.pivot_offset-Vector2(0,10)
		if unit.get("shields",0)>0:
			draw_arc(center,clampf(sprite.size.y*0.43,40,83),0,TAU,64,Color(0.65,0.78,1.0,0.27+sin(clock*3)*0.08),2,true)
		if unit.frozen:
			for i in range(5):
				var p = foot+Vector2((i-2)*12,-absf(sin(float(i)+1))*17)
				draw_colored_polygon(PackedVector2Array([p+Vector2(-5,0),p+Vector2(0,-21),p+Vector2(5,0)]),Color(0.5,0.85,1,0.65))
		if not unit.poison.is_empty():
			for i in range(4):
				var phase = fmod(clock*0.55+i*0.25,1.0)
				draw_circle(foot+Vector2(sin(i*2.3+clock)*22,-phase*50),2.5,Color(0.45,0.85,0.25,(1-phase)*0.7))
		var badges = ""
		if unit.frozen: badges += "빙결 "
		if not unit.poison.is_empty(): badges += "독 "
		if unit.get("shields",0)>0: badges += "보호 %d" % unit.shields
		if not badges.is_empty():
			draw_string(scene.get_theme_default_font(),Vector2(scene.unit_x(unit)-28,scene.bars[id].position.y+31),badges,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("dfedce"))
	for particle in particles:
		var t: float = particle.age/particle.life
		var p: Vector2 = particle.origin+particle.velocity*particle.age+Vector2(0,45*particle.age*particle.age)
		var color: Color = particle.color
		color.a *= 1-t
		draw_line(p,p-particle.velocity*0.035,color,2.5,true)
	for missile in missiles:
		var t: float = clampf(missile.age/missile.life,0,1)
		var p: Vector2 = missile.origin.lerp(missile.target,t)
		var direction: Vector2 = (missile.target-missile.origin).normalized()
		draw_line(p-direction*35,p,missile.color,3,true)
		draw_line(p,p-direction.rotated(0.55)*10,missile.color,2,true)
		draw_line(p,p-direction.rotated(-0.55)*10,missile.color,2,true)
	for number in numbers:
		var t: float = number.age/number.life
		var color: Color = number.color
		color.a = minf(1,(1-t)*3)
		var p: Vector2 = number.origin+Vector2(0,-46*t)
		draw_string(scene.get_theme_default_font(),p+Vector2(2,2),number.text,HORIZONTAL_ALIGNMENT_CENTER,80,28,Color(0,0,0,color.a))
		draw_string(scene.get_theme_default_font(),p,number.text,HORIZONTAL_ALIGNMENT_CENTER,80,28,color)

func attack_kind(actor: Dictionary) -> String:
	if actor.slug=="skeleton-archer": return "arrow"
	var effect = original.hit_kind(actor.slug)
	if effect in ["poison","toxicLiquid"]: return "poison"
	if effect in ["music","magic","wind"]: return "magic"
	if actor.slug in ["boulder-ogre","orc-warrior","ancient-treant","minotaur"]: return "heavy"
	if effect in ["claw","bite"]: return "claw"
	return "attack"

func burst(id: String, color: Color, count: int = 12) -> void:
	var origin = center_of(id)
	for i in range(count):
		var direction = Vector2.RIGHT.rotated(float(i)*TAU/count+0.3)
		particles.append({"origin":origin,"velocity":direction*(65+i%4*27),"color":color,"age":0.0,"life":0.4+i%3*0.06})
	flashes[id] = clock+0.09

func set_focus(actor_id: String = "", target_id: String = "") -> void:
	focus_actor = actor_id
	focus_target = target_id
	scene.layer.get_node("BattleShade").material.set_shader_parameter("cinematic",0.0 if actor_id.is_empty() else 1.0)
	for id in states:
		var sprite: TextureRect = scene.sprites[id]
		var geometry: Dictionary = layouts[id]
		sprite.z_index = 42 if id==actor_id else (41 if id==target_id else int(geometry.z))
		sprite.material.set_shader_parameter("dim",0.0 if actor_id.is_empty() or id in [actor_id,target_id] else 1.0)

func play_action(action: Dictionary) -> void:
	show_reports(action.before_effects)
	if not action.before_effects.is_empty(): await scene.wait_time(0.18)
	scene.render_units(action.prepared)
	var cancelled = action.target.is_empty() or not action.attack_allowed
	if not cancelled:
		set_focus(action.actor,action.target)
		await scene.cues.play_intent(action.actor,action.target)
		var played = false
		for report in action.visual_hits:
			if report.type=="damage" and report.get("kind","") in ["attack","counter"]:
				var source_id: String = report.get("source",action.actor)
				if not states.has(source_id) or not states.has(report.target): continue
				set_focus(source_id,report.target)
				await play_strike(source_id,report.target,report)
				played = true
			else:
				show_reports([report])
		if not played: await play_strike(action.actor,action.target,{})
		for prior in action.prepared:
			for current in action.after:
				if prior.id!=current.id: continue
				if current.poison.size()>prior.poison.size():
					show_label(current.id,"poison")
					scene.sound("poison")
				if current.frozen and not prior.frozen: scene.sound("freeze")
		await scene.wait_presentation(0.24,0.16)
	else:
		show_reports(action.visual_hits)
		if action.miss and not action.target.is_empty(): show_label(action.target,"miss")
		await scene.wait_presentation(0.2)
	set_focus()
	hit_motions.clear()
	active.clear()
	scene.render_units(action.after)
	await play_deaths(action.before,action.after)

func play_strike(actor_id: String, target_id: String, report: Dictionary) -> void:
	var actor: Dictionary = states[actor_id]
	var sprite: TextureRect = scene.sprites[actor_id]
	active[actor_id] = true
	sprite.scale = Vector2.ONE
	var frames: Array = scene.motion_frames(actor,"attack")
	var motion_profile: Dictionary = scene.presentation_layout.metrics.get(actor.slug,{})
	var impact_frame = clampi(int(motion_profile.get("impact_frame",ceil(frames.size()/2.0)))-1,0,frames.size()-1)
	var speed: float = scene.speed_values[scene.speed_index]
	scene.sound(attack_kind(actor))
	scene.cues.show_attack(actor.name)
	for i in range(frames.size()):
		var tex = scene.texture(scene.frame_path(actor,"attack",int(frames[i])))
		if tex!=null: sprite.texture = tex
		if i==impact_frame:
			if not report.is_empty():
				show_reports([report])
				scene.cues.show_damage(report.amount)
				if report.amount>0:
					play_hit(target_id,original.hit_kind(actor.slug))
					scene.sound("heavy" if attack_kind(actor)=="heavy" else "hit")
					flashes[target_id] = clock+0.26*speed
					var target_profile: Dictionary = scene.presentation_layout.metrics.get(states[target_id].slug,{})
					hit_motions[target_id] = {"started":idle_clock,"frames":scene.motion_frames(states[target_id],"hit"),"interval":maxf(0.045,float(target_profile.get("hit_interval",0.135))/speed)}
					active[target_id] = true
					var strong: bool = report.get("critical",false) or report.amount>=actor.attack*1.5
					if strong:
						shake_left = 0.15*speed
						shake_strength = 2.0
						duck_until = clock+0.25
					presentation_hold = true
					await scene.wait_presentation(0.054 if strong else 0.022)
					presentation_hold = false
			else: show_label(target_id,"miss")
		var delay = maxf(0.13,0.19/speed) if i==impact_frame else maxf(0.045,(0.16 if i==0 else 0.09)/speed)
		var custom_delays: Array = motion_profile.get("attack_delays",[])
		if i<custom_delays.size(): delay = maxf(0.045,float(custom_delays[i])/speed)
		await scene.wait_presentation(delay*minf(speed,1.2))
	await scene.wait_presentation(maxf(0.045,0.09/speed)*0.35*minf(speed,1.2))
	while hit_motions.has(target_id): await scene.wait_presentation(0.01)
	active.erase(actor_id)
	sprite.texture = scene.texture(scene.frame_path(actor,"attack",1))

func add_art(node: Control, origin: Vector2, life: float, velocity: Vector2 = Vector2.ZERO, frames: Array = [], interval: float = 0.065, delay: float = 0.0) -> void:
	node.position = origin
	art_items.append({"node":node,"origin":origin,"velocity":velocity,"frames":frames,"interval":interval,"delay":delay,"life":life,"age":0.0})
	node.visible = delay<=0

func play_hit(id: String, kind: String, delay: float = 0.0) -> void:
	var frames = original.hit_frames(kind)
	var node = original.sprite(self,frames[0],kind,Vector2.ONE*minf(180.0,layouts[id].wrap.x*0.85))
	add_art(node,center_of(id)-node.size/2,frames.size()*0.065,Vector2.ZERO,frames,0.065,delay)

func show_label(id: String, kind: String, delay: float = 0.0) -> void:
	var node = original.label(self,kind)
	if node!=null:
		add_art(node,center_of(id)-Vector2(node.size.x/2,68 if kind=="critical" else 42),1.0,Vector2(0,-24),[],0.065,delay)

func show_reports(reports: Array) -> void:
	var count: Dictionary = {}
	for report in reports:
		var id: String = report.target
		if not scene.sprites.has(id): continue
		var offset: int = count.get(id,0)
		count[id] = offset+1
		var delay = offset*0.09
		if report.type=="damage" and report.get("blocked",false):
			show_label(id,"immune",delay)
		if report.amount<=0: continue
		var healing = report.type=="heal"
		var node = original.number(self,report.amount if healing else -report.amount)
		add_art(node,center_of(id)+Vector2(-node.size.x/2,-25-offset*12),0.72,Vector2.ZERO,[],0.065,delay)
		node.pivot_offset = node.size/2.0
		art_items[-1]["pop"] = true
		scene.bars[id].value = report.hp
		if healing: heal_crosses(id,report.amount)
		elif report.get("critical",false): show_label(id,"critical",delay)

func heal_crosses(id: String, amount: int) -> void:
	var pattern = [[-34,24,34,0,760,-10],[-18,2,28,70,720,-5],[0,18,38,35,820,2],[20,-8,30,120,760,8],[36,22,34,160,840,12],[-5,-24,26,210,700,-3],[27,-32,29,250,780,7]]
	var count = 4 if amount<=1 else (6 if amount==2 else 7)
	for i in range(count):
		var entry: Array = pattern[i]
		var size = float(entry[2])
		var node = original.sprite(self,load(OriginalEffects.ROOT+"heal-cross.png"),"cross",Vector2(size,size))
		add_art(node,center_of(id)+Vector2(entry[0],entry[1])-node.size/2,float(entry[4])/1000,Vector2(entry[5],-48),[],0.065,float(entry[3])/1000)

func play_round(before: Array, after: Array, reports: Array) -> void:
	show_reports(reports)
	var arriving: Array = []
	for unit in after:
		if not unit.alive: continue
		var previous: Dictionary = {}
		for old in before:
			if old.id==unit.id: previous = old
		if not previous.is_empty() and previous.slug==unit.slug and previous.hp!=unit.hp and not reports.any(func(report): return report.target==unit.id):
			show_reports([{"type":"damage" if unit.hp<previous.hp else "heal","target":unit.id,"amount":absi(unit.hp-previous.hp),"kind":"cost","blocked":false,"critical":false,"hp":unit.hp}])
		if previous.is_empty() or previous.slug!=unit.slug:
			arriving.append(unit.id)
			scene.sprites[unit.id].modulate.a = 0
			scene.bars[unit.id].modulate.a = 0
			scene.cards[unit.id].modulate.a = 0
			var frames = original.summon_frames()
			var node = original.sprite(self,frames[0],"summon",Vector2(190,92))
			node.z_index = -2
			var sprite: TextureRect = scene.sprites[unit.id]
			add_art(node,homes[unit.id]+sprite.pivot_offset-Vector2(0,12)-node.size/2,0.8,Vector2.ZERO,frames,0.09)
	if not arriving.is_empty():
		scene.sound("summon")
		await scene.wait_time(0.27)
		for id in arriving:
			scene.sprites[id].modulate.a = 1
			scene.bars[id].modulate.a = 1
			scene.cards[id].modulate.a = 1
		await scene.wait_time(0.45)
	await play_deaths(before,after)

func play_deaths(before: Array, after: Array) -> void:
	var fallen: Array = []
	for prior in before:
		for current in after:
			if prior.id==current.id and prior.alive and not current.alive:
				fallen.append(current)
	if fallen.is_empty(): return
	var effect = PermanentDeath.new()
	scene.layer.add_child(effect)
	await effect.play(scene,fallen)
