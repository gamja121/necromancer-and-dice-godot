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
var active: Dictionary = {}
var flashes: Dictionary = {}
var particles: Array = []
var numbers: Array = []
var missiles: Array = []
var removed: Dictionary = {}
var presentation_hold = false
var clock = 0.0
var shake_left = 0.0
var shake_strength = 0.0
var duck_until = 0.0
var shader: Shader

func setup(battle_scene, parent: Control) -> void:
	scene = battle_scene
	for kind in original.metadata.effects: original.hit_frames(kind)
	world_layer = parent
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 3
	shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 source = COLOR;
	COLOR = vec4(mix(source.rgb, vec3(1.0, 0.88, 0.63), flash), source.a);
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
		var sprite: TextureRect = scene.sprites[unit.id]
		homes[unit.id] = sprite.position
		sprite.pivot_offset = Vector2(sprite.size.x/2,sprite.size.y)
		if sprite.material == null:
			var material = ShaderMaterial.new()
			material.shader = shader
			sprite.material = material

func _process(delta: float) -> void:
	if scene == null: return
	var dt: float = 0.0 if scene.paused or presentation_hold else delta*scene.speed_values[scene.speed_index]
	clock += dt
	scene.audio.volume_db = lerpf(scene.audio.volume_db,-19.0 if clock<duck_until else -15.0,minf(1,dt*12))
	for id in states:
		var sprite: TextureRect = scene.sprites[id]
		var unit: Dictionary = states[id]
		if not active.has(id):
			sprite.position = homes[id]
			if unit.alive and not unit.frozen:
				var breath = sin(clock*2.4+unit.slot*1.7)
				sprite.scale = Vector2(1.0+breath*0.004,1.0+breath*0.008)
			else: sprite.scale = Vector2.ONE
		sprite.material.set_shader_parameter("flash",0.6 if flashes.get(id,0.0)>clock else 0.0)
	for i in range(art_items.size()-1,-1,-1):
		var item: Dictionary = art_items[i]
		item.age += dt
		var age: float = item.age-item.delay
		item.node.visible = age>=0
		if age<0: continue
		if age>=item.life:
			item.node.queue_free()
			art_items.remove_at(i)
			continue
		item.node.position = item.origin+item.velocity*age
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
	return sprite.position+Vector2(sprite.size.x*0.5,sprite.size.y*0.48)

func draw_ground(canvas: Control) -> void:
	for id in states:
		if removed.has(id): continue
		var unit: Dictionary = states[id]
		var sprite: TextureRect = scene.sprites[id]
		var foot: Vector2 = homes[id]+Vector2(sprite.size.x/2,sprite.size.y-3)
		var radius = clampf(sprite.size.x*0.22,27,65)
		canvas.draw_set_transform(foot,0,Vector2(1,0.19))
		for ring in range(3):
			canvas.draw_circle(Vector2.ZERO,radius*(1.0-ring*0.16),Color(0.02,0.015,0.035,0.065 if unit.alive else 0.025))
		if unit.alive and active.has(id):
			canvas.draw_set_transform(foot,0,Vector2(1,0.24))
			canvas.draw_arc(Vector2.ZERO,radius+5,0,TAU,48,Color(0.87,0.68,0.35,0.45),2,true)
		canvas.draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	for id in states:
		var unit: Dictionary = states[id]
		if not unit.alive: continue
		var center = center_of(id)
		var sprite: TextureRect = scene.sprites[id]
		var foot: Vector2 = homes[id]+Vector2(sprite.size.x/2,sprite.size.y-10)
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

func impact(action: Dictionary, kind: String) -> void:
	var hit_count = 0
	var special = false
	var strong = false
	var effect = original.hit_kind(states[action.actor].slug)
	for report in action.visual_hits:
		if report.type=="damage" and report.kind=="attack" and report.amount>0:
			play_hit(report.target,effect,hit_count*0.09)
			hit_count += 1
			strong = strong or report.critical or report.amount>=states[action.actor].attack*1.5
		if report.type=="heal": special = true
	show_reports(action.visual_hits)
	for prior in action.prepared:
		for current in action.after:
			if prior.id!=current.id: continue
			if current.poison.size()>prior.poison.size():
				show_label(current.id,"poison")
				scene.sound("poison")
				special = true
			if current.frozen and not prior.frozen:
				scene.sound("freeze")
				special = true
	if hit_count>0:
		scene.sound("heavy" if kind=="heavy" else "hit")
		for report in action.visual_hits:
			if report.type=="damage" and report.amount>0: flashes[report.target] = clock+0.07
	if hit_count>0 and (strong or special or hit_count>1 or kind=="heavy"):
		duck_until = clock+0.25
		shake_left = 0.15
		shake_strength = 2.0 if special else 3.0

func play_action(action: Dictionary) -> void:
	show_reports(action.before_effects)
	if not action.before_effects.is_empty(): await scene.wait_time(0.18)
	scene.render_units(action.prepared)
	var actor: Dictionary = states[action.actor]
	var kind = attack_kind(actor)
	var target_id: String = action.target
	var cancelled = target_id.is_empty() or not action.attack_allowed

	active[action.actor] = true
	var sprite: TextureRect = scene.sprites[action.actor]
	var home: Vector2 = homes[action.actor]
	var direction = 1.0 if actor.team=="ally" else -1.0
	sprite.scale = Vector2.ONE
	sprite.position.x = home.x-direction*9
	await scene.wait_time(0.12)
	if not cancelled:
		scene.sound(kind)
		if kind in ["arrow","magic"]:
			missiles.append({"origin":center_of(action.actor),"target":center_of(target_id),"color":Color("c0a0ff") if kind=="magic" else Color("ffe6a5"),"age":0.0,"life":0.38})
		var target: TextureRect = scene.sprites[target_id]
		var target_home: Vector2 = homes[target_id]
		active[target_id] = true
		target.scale = Vector2.ONE
		for frame in range(1,11):
			var tex = scene.texture(scene.frame_path(actor,"attack",frame))
			if tex!=null: sprite.texture = tex
			sprite.position.x = home.x+direction*sin(float(frame)/10*PI)*(8 if kind in ["arrow","magic"] else 35)
			if frame==5:
				impact(action,kind)
				var special = action.visual_hits.any(func(report): return report.type=="heal")
				var strong = action.visual_hits.any(func(report): return report.get("critical",false))
				await scene.wait_time(0.076 if special or action.visual_hits.size()>1 else (0.054 if strong else 0.022))
			if frame>=5:
				var hit = scene.texture(scene.frame_path(states[target_id],"hit",frame-4))
				if hit!=null: target.texture = hit
				target.position.x = target_home.x+direction*sin(float(frame-4)/6*PI)*10
			await scene.wait_time(0.095)
		target.position = target_home
		active.erase(target_id)
	else:
		show_reports(action.visual_hits)
		if action.miss and not target_id.is_empty(): show_label(target_id,"miss")
		await scene.wait_time(0.2)
	sprite.position = home
	active.erase(action.actor)
	scene.render_units(action.after)
	await play_deaths(action.before,action.after)

func add_art(node: Control, origin: Vector2, life: float, velocity: Vector2 = Vector2.ZERO, frames: Array = [], interval: float = 0.065, delay: float = 0.0) -> void:
	node.position = origin
	art_items.append({"node":node,"origin":origin,"velocity":velocity,"frames":frames,"interval":interval,"delay":delay,"life":life,"age":0.0})
	node.visible = delay<=0

func play_hit(id: String, kind: String, delay: float = 0.0) -> void:
	var frames = original.hit_frames(kind)
	var node = original.sprite(self,frames[0],kind,Vector2(160,160))
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
		add_art(node,center_of(id)+Vector2(-node.size.x/2,-25-offset*12),0.85,Vector2(0,-46),[],0.065,delay)
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
			add_art(node,homes[unit.id]+Vector2(sprite.size.x/2,sprite.size.y-12)-node.size/2,0.8,Vector2.ZERO,frames,0.09)
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