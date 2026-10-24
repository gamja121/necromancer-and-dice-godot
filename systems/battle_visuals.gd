extends Control
const OriginalEffects = preload("res://systems/original_effects.gd")
const PermanentDeath = preload("res://systems/permanent_death.gd")
const Accent = preload("res://systems/presentation_accent.gd")

class Ground extends Control:
	var effects
	func _draw() -> void:
		effects.draw_ground(self)

var original = OriginalEffects.new()
var art_items: Array = []
var scene
var world_layer: Control
var ground: Control
var _ground_removed: Dictionary = {}
var _ground_had_circles: bool = false
var _had_overlay_content: bool = false
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
# Presentation-only opening summon: no combat RNG, unit swaps, or saved state.
var entry_circles: Dictionary = {}

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
uniform float entry_reveal : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 source = COLOR;
	float gray = dot(source.rgb,vec3(0.2126,0.7152,0.0722));
	vec3 shaded = mix(source.rgb,mix(vec3(gray),source.rgb,0.72)*0.48,dim);
	vec3 original_look = mix(shaded, vec3(1.0, 0.18, 0.1), flash);
	COLOR = vec4(mix(vec3(0.012,0.011,0.020), original_look, entry_reveal), source.a);
}
"""
	ground = Ground.new()
	ground.effects = self
	ground.size = size
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.z_index = 0
	parent.add_child(ground)

func displayed_unit(unit: Dictionary) -> Dictionary:
	if states.has(unit.id) and is_seed_bloom(states[unit.id],unit):
		return states[unit.id]
	return unit

func sync(values: Array) -> void:
	for value in values:
		var unit: Dictionary = displayed_unit(value)
		states[unit.id] = unit.duplicate(true)
		layouts[unit.id] = scene.presentation_layout.geometry(unit,scene.surface_size)
		var sprite: TextureRect = scene.sprites[unit.id]
		homes[unit.id] = sprite.position
		sprite.pivot_offset = layouts[unit.id].pivot
		if sprite.material == null:
			var material = ShaderMaterial.new()
			material.shader = shader
			sprite.material = material
	ground.queue_redraw()

# Store only visual states: the already-confirmed roster's own slot order.
func prepare_entry_summon() -> Array:
	entry_circles.clear()
	var ids: Array = []
	for unit in scene.rules.units:
		if unit.team!="ally" or not unit.alive or int(unit.slot)>=4: continue
		var sprite: TextureRect = scene.sprites[unit.id]
		if not (sprite.material is ShaderMaterial): continue
		sprite.material.set_shader_parameter("entry_reveal",0.0)
		sprite.modulate.a = 0.0
		scene.bars[unit.id].modulate.a = 0.0
		ids.append(str(unit.id))
	return ids

func play_entry_summon_unit(id: String) -> void:
	if not scene.sprites.has(id) or not homes.has(id): return
	var sprite: TextureRect = scene.sprites[id]
	var material: ShaderMaterial = sprite.material as ShaderMaterial
	if material == null: return
	# The circle is painted on the battlefield ground UNDER the monster art.
	entry_circles[id] = 1.0
	var frames: Array = original.summon_frames()
	var effect = original.sprite(self,frames[0],"summon",Vector2(190,92))
	effect.z_index = -2
	add_art(effect,homes[id]+sprite.pivot_offset-Vector2(95,62),0.75,Vector2.ZERO,frames,0.09)
	scene.sound("summon")
	sprite.modulate.a = 1.0
	await get_tree().create_timer(0.20).timeout
	if not is_instance_valid(sprite) or not is_inside_tree(): return
	# The sprite's original texture is always present under a shader mask:
	# fully BLACK silhouette -> full source artwork without a duplicated unit.
	var reveal = create_tween()
	reveal.tween_method(func(t: float):
		if is_instance_valid(material):
			material.set_shader_parameter("entry_reveal",t)
		entry_circles[id] = 1.0-t
	,0.0,1.0,0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await reveal.finished
	if not is_instance_valid(sprite) or not is_inside_tree(): return
	material.set_shader_parameter("entry_reveal",1.0)
	scene.bars[id].modulate.a = 1.0
	entry_circles.erase(id)

func clear_entry_summon() -> void:
	for id in entry_circles:
		if scene.sprites.has(id) and is_instance_valid(scene.sprites[id]):
			scene.sprites[id].material.set_shader_parameter("entry_reveal",1.0)
			scene.sprites[id].modulate.a = 1.0
			scene.bars[id].modulate.a = 1.0
	entry_circles.clear()

func _process(delta: float) -> void:
	if scene == null: return
	var dt: float = 0.0 if scene.paused or presentation_hold else delta*scene.speed_values[scene.speed_index]
	clock += dt
	if not scene.paused and not presentation_hold: idle_clock += delta
	scene.audio.volume_db = lerpf(scene.audio.volume_db,-19.0 if clock<duck_until else -15.0,minf(1,dt*12))
	var status_content: bool = false
	for id in states:
		var sprite: TextureRect = scene.sprites[id]
		var unit: Dictionary = states[id]
		if unit.alive and (unit.frozen or not unit.poison.is_empty() or unit.get("shields",0)>0): status_content = true
		var desired: Vector2 = homes[id]
		if id==focus_actor:
			var wrap: Vector2 = layouts[id].wrap
			desired += Vector2(wrap.x*0.36*(1.0 if unit.team=="ally" else -1.0),wrap.y*0.05)
		sprite.position = sprite.position.lerp(desired,minf(1.0,dt*18.0))
		# All 47 monsters breathe/sway while waiting, including the 43 rigid
		# hand-drawn portraits. Rigid art ROTATES around the original foot
		# pivot instead of being stretched (preserving its exact proportions).
		# Only the visual TextureRect moves: no battle or save state changes.
		var current: Dictionary = scene.rules.find_id(id)
		var can_idle: bool = unit.alive and not unit.frozen and not active.has(id) and not hit_motions.has(id)
		can_idle = can_idle and id!=focus_actor and id!=focus_target and not scene.entry_summon_active
		can_idle = can_idle and not current.is_empty() and str(current.slug)==str(unit.slug)
		can_idle = can_idle and sprite.texture == scene.texture(scene.frame_path(unit,"attack",1))
		if can_idle:
			var period: float = 1.80 + float(int(unit.slot)%3)*0.17
			var phase: float = float(int(unit.slot))*0.73 + (0.44 if unit.team=="enemy" else 0.0)
			sprite.rotation = sin(idle_clock*TAU/period+phase)*deg_to_rad(1.65)
			if not scene.presentation_layout.metrics.get(unit.slug,{}).get("rigid_idle",false):
				# Keep the established non-rigid four-species breathing motion.
				var t: float = fposmod(idle_clock/(1.36 if unit.slot%3==0 else (1.58 if unit.slot%2==0 else 1.45))+float(unit.slot)*0.29,1.0)
				var keys: Array = [0.0,0.38,0.58,0.76,1.0]
				var scales: Array = [Vector2.ONE,Vector2(1.025,1.08),Vector2(0.975,0.94),Vector2(1.015,1.055),Vector2.ONE]
				for k in range(4):
					if t>=keys[k] and t<keys[k+1]:
						var blend: float = (t-keys[k])/(keys[k+1]-keys[k])
						sprite.scale = scales[k].lerp(scales[k+1],blend*blend*(3.0-2.0*blend))
						break
			else:
				sprite.scale = Vector2.ONE
		else:
			sprite.rotation = 0.0
			sprite.scale = Vector2.ONE
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
			original.release_art(item.node)
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
	# Static shadows reuse cached commands. Keep the existing circle/shadow
	# draw order, and clear the last circle frame when the intro ends.
	var circles_active: bool = not entry_circles.is_empty()
	var removed_changed: bool = removed != _ground_removed
	if circles_active or _ground_had_circles or removed_changed:
		ground.queue_redraw()
	_ground_had_circles = circles_active
	if removed_changed: _ground_removed = removed.duplicate()
	var overlay_content: bool = status_content or not particles.is_empty() or not numbers.is_empty() or not missiles.is_empty()
	if overlay_content or _had_overlay_content: queue_redraw()
	_had_overlay_content = overlay_content

func center_of(id: String) -> Vector2:
	var sprite: TextureRect = scene.sprites[id]
	return layouts[id].effect+(sprite.position-homes[id])

func draw_ground(canvas: Control) -> void:
	for id in entry_circles:
		if not homes.has(id) or not scene.sprites.has(id): continue
		var strength: float=clampf(float(entry_circles[id]),0.0,1.0)
		if strength<=0.0: continue
		var sprite: TextureRect=scene.sprites[id]
		var foot: Vector2=homes[id]+sprite.pivot_offset
		var radius: float=clampf(sprite.size.x*0.28,35.0,65.0)
		var spin: float=clock*1.65
		canvas.draw_set_transform(foot,spin,Vector2(1.0,0.28))
		canvas.draw_circle(Vector2.ZERO,radius*0.97,Color(0.08,0.46,0.70,0.18*strength))
		for r in [0.58,0.77,1.0]:
			canvas.draw_arc(Vector2.ZERO,radius*r,0.0,TAU,64,Color(0.37,0.84,1.0,0.87*strength),2.0,true)
		for k in range(8):
			var angle: float=TAU*float(k)/8.0
			var p: Vector2=Vector2.RIGHT.rotated(angle)
			canvas.draw_line(p*radius*0.61,p*radius*0.93,Color(0.65,0.94,1.0,0.82*strength),2.0,true)
		canvas.draw_set_transform(Vector2.ZERO)
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
		# Keep the actual ground-plane depth even during attack focus: a rear
		# combatant must never draw over a nearer ally or enemy.
		sprite.z_index = int(geometry.z)
		sprite.material.set_shader_parameter("dim",0.0 if actor_id.is_empty() or id in [actor_id,target_id] else 1.0)

func play_action(action: Dictionary) -> void:
	show_reports(action.before_effects)
	if not action.before_effects.is_empty(): await scene.wait_time(0.18)
	scene.render_units(action.prepared)
	var cancelled = action.target.is_empty() or not action.attack_allowed
	if not cancelled:
		set_focus(action.actor,action.target)
		# Forecast confirmed damage only; shields/blocks are already resolved.
		var forecasts: Dictionary = {}
		for hit in action.visual_hits:
			if hit.get("type", "") != "damage" or hit.get("blocked", false): continue
			var target_id: String = str(hit.get("target", ""))
			if not scene.bars.has(target_id): continue
			forecasts[target_id] = int(forecasts.get(target_id, 0)) + maxi(0, int(hit.get("amount", 0)))
		for target_id in forecasts:
			scene.bars[target_id].preview(int(forecasts[target_id]))
		await scene.cues.play_intent(action.actor,action.target)
		var played = false
		for report in action.visual_hits:
			if report.type=="damage" and report.get("kind","") in ["attack","counter"]:
				var source_id: String = report.get("source",action.actor)
				if not states.has(source_id) or not states.has(report.target): continue
				set_focus(source_id,report.target)
				if scene.bars.has(report.target) and not report.get("blocked", false):
					scene.bars[report.target].consume_hit(int(report.get("amount", 0)), int(report.get("hp", 0)))
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
		if action.miss and not action.target.is_empty():
			scene.sound("battle_miss")
			show_label(action.target,"miss")
		await scene.wait_presentation(0.2)
	set_focus()
	for bar in scene.bars.values(): bar.clear_preview()
	hit_motions.clear()
	active.clear()
	scene.render_units(action.after)
	await play_deaths(action.before,action.after)

func play_strike(actor_id: String, target_id: String, report: Dictionary) -> void:
	var actor: Dictionary = states[actor_id]
	if actor.slug=="guardian-seed": return
	var sprite: TextureRect = scene.sprites[actor_id]
	active[actor_id] = true
	sprite.scale = Vector2.ONE
	var frames: Array = scene.motion_frames(actor,"attack")
	var motion_profile: Dictionary = scene.presentation_layout.metrics.get(actor.slug,{})
	var impact_frame = clampi(int(motion_profile.get("impact_frame",ceil(frames.size()/2.0)))-1,0,frames.size()-1)
	var speed: float = scene.speed_values[scene.speed_index]
	scene.sound("dragon_attack" if actor.slug=="dragon" else attack_kind(actor))
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
					play_species_accent(actor_id,target_id)
					var hit_cue: String = "battle_critical" if bool(report.get("critical",false)) else ("dragon_impact" if actor.slug=="dragon" else ("heavy" if attack_kind(actor)=="heavy" else "hit"))
					if str(states[target_id].slug)=="dragon": hit_cue="dragon_hit"
					scene.sound(hit_cue)
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
			else:
				scene.sound("battle_miss")
				show_label(target_id,"miss")
		var delay = maxf(0.13,0.19/speed) if i==impact_frame else maxf(0.045,(0.16 if i==0 else 0.09)/speed)
		var custom_delays: Array = motion_profile.get("attack_delays",[])
		if i<custom_delays.size(): delay = maxf(0.045,float(custom_delays[i])/speed)
		await scene.wait_presentation(delay*minf(speed,1.2))
	await scene.wait_presentation(maxf(0.045,0.09/speed)*0.35*minf(speed,1.2))
	while hit_motions.has(target_id): await scene.wait_presentation(0.01)
	active.erase(actor_id)
	sprite.texture = scene.texture(scene.frame_path(actor,"attack",1))

func play_species_accent(actor_id: String, target_id: String) -> void:
	var actor: Dictionary = states[actor_id]
	var effect_kind := ""
	var points: Array[Vector2] = []
	var color := Color("9f927d")
	if actor.slug=="spider-knight":
		effect_kind = "silk"
		color = Color("d0cbb7")
		points = [center_of(actor_id),center_of(target_id)]
	elif "skeleton" in actor.legions:
		effect_kind = "bone"
		color = Color("c7bca3")
		points = [center_of(target_id)]
	elif attack_kind(actor)=="heavy":
		effect_kind = "dust"
		points = [Vector2(center_of(target_id).x,scene.unit_floor_y())]
	if effect_kind.is_empty(): return
	var reference = weakref(self)
	Accent.create(self,effect_kind,points,color,0.65,func():
		var live = reference.get_ref()
		return float(live.clock) if is_instance_valid(live) else 999999.0)

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
	var healing_sound_played := false
	for report in reports:
		var id: String = report.target
		if not scene.sprites.has(id): continue
		var offset: int = count.get(id,0)
		count[id] = offset+1
		var delay = offset*0.09
		if report.type=="damage" and report.get("blocked",false):
			scene.sound("battle_block")
			show_label(id,"immune",delay)
		if report.amount<=0: continue
		var healing = report.type=="heal"
		var node = original.number(self,report.amount if healing else -report.amount)
		add_art(node,center_of(id)+Vector2(-node.size.x/2,-25-offset*12),0.72,Vector2.ZERO,[],0.065,delay)
		node.pivot_offset = node.size/2.0
		art_items[-1]["pop"] = true
		if healing or scene.bars[id].preview_damage <= 0:
			scene.bars[id].value = report.hp
		if healing:
			if not healing_sound_played:
				scene.sound("battle_heal")
				healing_sound_played = true
			heal_crosses(id,report.amount)
		elif report.get("critical",false): show_label(id,"critical",delay)

func heal_crosses(id: String, amount: int) -> void:
	var pattern = [[-34,24,34,0,760,-10],[-18,2,28,70,720,-5],[0,18,38,35,820,2],[20,-8,30,120,760,8],[36,22,34,160,840,12],[-5,-24,26,210,700,-3],[27,-32,29,250,780,7]]
	var count = 4 if amount<=1 else (6 if amount==2 else 7)
	for i in range(count):
		var entry: Array = pattern[i]
		var size = float(entry[2])
		var node = original.sprite(self,original.sheet_texture("heal-cross.png"),"cross",Vector2(size,size))
		add_art(node,center_of(id)+Vector2(entry[0],entry[1])-node.size/2,float(entry[4])/1000,Vector2(entry[5],-48),[],0.065,float(entry[3])/1000)


# Seed evolution is already decided by BattleRules. Only render its growth here.
func is_seed_bloom(previous: Dictionary, current: Dictionary) -> bool:
	return previous.get("slug","")=="guardian-seed" and current.get("slug","")=="crystal-devourer"

func play_seed_blooms(before: Array, after: Array) -> void:
	var blooming: Array = []
	for current in after:
		if not current.alive or not scene.sprites.has(current.id): continue
		for previous in before:
			if previous.id!=current.id or not is_seed_bloom(previous,current): continue
			blooming.append({"seed":previous,"adult":current})
			var geometry: Dictionary = scene.presentation_layout.geometry(previous,scene.surface_size)
			var sprite: TextureRect = scene.sprites[current.id]
			active[current.id] = true
			states[current.id] = previous.duplicate(true)
			layouts[current.id] = geometry
			homes[current.id] = geometry.position
			sprite.size = geometry.size
			sprite.position = geometry.position
			sprite.pivot_offset = geometry.pivot
			sprite.scale = Vector2.ONE
			sprite.modulate.a = 1.0
	if blooming.is_empty(): return
	ground.queue_redraw()
	var profile: Dictionary = scene.presentation_layout.metrics["guardian-seed"]
	var frames: Array = scene.presentation_layout.frames("guardian-seed","attack")
	var delays: Array = profile.get("attack_delays",[])
	for i in range(frames.size()):
		for pair in blooming:
			var sprite: TextureRect = scene.sprites[pair.seed.id]
			sprite.texture = scene.texture(scene.frame_path(pair.seed,"attack",int(frames[i])))
		await scene.wait_time(float(delays[i]) if i<delays.size() else 0.16)
	for pair in blooming:
		var current: Dictionary = pair.adult
		var geometry: Dictionary = scene.presentation_layout.geometry(current,scene.surface_size)
		var sprite: TextureRect = scene.sprites[current.id]
		sprite.texture = scene.texture(scene.frame_path(current,"attack",1))
		sprite.size = geometry.size
		sprite.position = geometry.position
		sprite.pivot_offset = geometry.pivot
		sprite.scale = Vector2.ONE
		states[current.id] = current.duplicate(true)
		layouts[current.id] = geometry
		homes[current.id] = geometry.position
		active.erase(current.id)
		ground.queue_redraw()

func play_round(before: Array, after: Array, reports: Array) -> void:
	await play_seed_blooms(before,after)
	show_reports(reports)
	var arriving: Array = []
	for unit in after:
		if not unit.alive: continue
		var previous: Dictionary = {}
		for old in before:
			if old.id==unit.id: previous = old
		if not previous.is_empty() and previous.slug==unit.slug and previous.hp!=unit.hp and not reports.any(func(report): return report.target==unit.id):
			show_reports([{"type":"damage" if unit.hp<previous.hp else "heal","target":unit.id,"amount":absi(unit.hp-previous.hp),"kind":"cost","blocked":false,"critical":false,"hp":unit.hp}])
		if previous.is_empty() or (previous.slug!=unit.slug and not is_seed_bloom(previous,unit)):
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
