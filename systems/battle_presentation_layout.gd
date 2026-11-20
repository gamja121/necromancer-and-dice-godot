extends RefCounted
# Render-only stage perspective. The player's confirmed deck order stays
# left-to-right (ally slots 0..3). Allies stand diagonally from the LEFT/front
# toward the CENTER/back; enemies mirror this from the RIGHT/front to center.
# Rear units are slightly smaller, higher on the floor and always draw behind
# nearer units. These arrays never alter targeting, turn order or save data.
const ALLY_DEPTH = [1.06,1.02,0.98,0.94,0.88]
const ENEMY_DEPTH = [1.06,1.02,0.98,0.94,0.88]
const ALLY_OFFSET = [0.06,0.025,-0.01,-0.045,-0.08]
const ENEMY_OFFSET = [0.06,0.025,-0.01,-0.045,-0.08]
const ALLY_Z = [18,17,16,15,14]
const ENEMY_Z = [18,17,16,15,14]
# Sprite, HP bar and bottom deck card keep horizontal_center() fixed.
# Summoned slot 4 remains a rear-side auxiliary slot for both teams.
const ALLY_COLUMNS = [1,2,3,4,5]
const ENEMY_COLUMNS = [5,4,3,2,1]
const RATIOS = {"bone-golem":1.5,"death-knight":1.0,"plague-frog":0.5,"grave-worm":0.5,"spider-knight":2.0,"stone-golem":2.0,"flesh-golem":1.5,"skeleton-cavalry":1.5,"spiderling":0.5,"guardian-seed":0.5,"goblin-chief":1.5,"kraken":2.0,"minotaur":1.5,"goblin-rider":1.0,"yeti":1.5,"orc-warrior":1.5,"hydra":2.0,"boulder-ogre":1.5,"abyss-claw-hunter":1.5,"corpse-slime":1.0}
const BAR_HEIGHT := 5.0
const STATUS_BOTTOM := 23.0
const HUD_CLEARANCE := 6.0
const WORLD_SHAKE := 2.0
const OUTER_BAR_MINIMUM := 155.0
const IDLE_SWAY := PI * 1.65 / 180.0
var _sprite_envelopes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_sprite_envelopes.json"))
var _geometry_cache: Dictionary = {}
var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_visual_metrics.json"))

func frames(slug: String, motion: String) -> Array:
	return metrics.get(slug,{}).get(motion,[1])

func horizontal_center(unit: Dictionary, surface: Vector2) -> float:
	var slot: int = clampi(int(unit.get("slot",0)),0,4)
	var ally: bool = str(unit.get("team","ally"))=="ally"
	if str(unit.get("slug",""))=="dragon" and not ally:
		return surface.x*0.78
	var column: int = ALLY_COLUMNS[slot] if ally else ENEMY_COLUMNS[slot]
	return (0.0 if ally else surface.x*0.52)+(float(column)-0.5)*(surface.x*0.48/5.0)

func geometry(unit: Dictionary, surface: Vector2) -> Dictionary:
	var key := "%s/%s/%d/%s" % [unit.slug,unit.get("team","ally"),int(unit.get("slot",0)),surface]
	if not _geometry_cache.has(key):
		_geometry_cache[key] = _resolve_geometry(unit,surface)
	return _geometry_cache[key]

# Render envelopes are measured from normalized opaque source pixels once.
# Attack lunge is horizontal/downward; impacts can shake the world, not the HUD.
func _resolve_geometry(unit: Dictionary, surface: Vector2) -> Dictionary:
	var result := _base_geometry(unit,surface)
	var authored := _motion_bounds(unit,result)
	var foot: Vector2 = result.foot
	var fit := 1.0
	if is_boss_bar(unit):
		var width := surface.x*0.225
		result.bar = Rect2(surface.x-width-26.0,86.0,width,8.0)
	else:
		var width := _bar_width(surface)
		var baseline := _slot_bar_y(unit,surface)
		var top := foot.y+authored.position.y-WORLD_SHAKE
		var reserve := STATUS_BOTTOM+HUD_CLEARANCE
		var y := clampf(top-reserve,minf(baseline,OUTER_BAR_MINIMUM),baseline)
		result.bar = Rect2(foot.x-width*0.5,y,width,BAR_HEIGHT)
		var minimum_top := y+reserve
		# Allow for a later summon and for lunges reaching into the next column.
		# Other bars can only move up from their original slot baseline.
		var direction := -1.0 if unit.get("team","ally")=="enemy" else 1.0
		var travel: float = result.wrap.x*0.36*direction
		var left := foot.x+minf(authored.position.x,0.0)+minf(0.0,travel)-8.0
		var right := foot.x+maxf(authored.end.x,0.0)+maxf(0.0,travel)+8.0
		for team in ["ally","enemy"]:
			for slot in range(5):
				if team==unit.get("team","ally") and slot==int(unit.get("slot",0)): continue
				var neighbor := {"slot":slot,"team":team}
				var center := horizontal_center(neighbor,surface)
				if left<center+width*0.5 and right>center-width*0.5:
					minimum_top=maxf(minimum_top,_slot_bar_y(neighbor,surface)+reserve)
		if top < minimum_top:
			fit = clampf((foot.y-minimum_top-WORLD_SHAKE)/maxf(-authored.position.y,1.0),0.05,1.0)
	result.size *= fit
	result.pivot *= fit
	if fit != 1.0: result.position = foot-result.pivot
	result.scale *= fit
	result.body_fit = fit
	var silhouette := Rect2(foot+authored.position*fit,authored.size*fit)
	var strike: Vector2 = result.wrap*Vector2(-0.36 if unit.get("team","ally")=="enemy" else 0.36,0.05)
	result.silhouette = silhouette.merge(Rect2(silhouette.position+strike,silhouette.size)).grow_individual(8.0,WORLD_SHAKE,8.0,WORLD_SHAKE)
	return result

func is_boss_bar(unit: Dictionary) -> bool:
	return unit.get("slug","")=="dragon" and unit.get("team","")=="enemy"

func _bar_width(surface: Vector2) -> float:
	return surface.x*0.48/5.0*0.86

func _motion_bounds(unit: Dictionary, base: Dictionary) -> Rect2:
	var profile: Dictionary = _sprite_envelopes.get(unit.slug,{})
	var size: Vector2 = base.size
	var pivot: Vector2 = base.pivot
	var hull := Rect2()
	for motion in ["idle","attack","hit","death"]:
		var values: Array = profile.get(motion,[0.0,0.0,1.0,1.0])
		var start := Vector2(float(values[0]),float(values[1]))
		var finish := Vector2(float(values[2]),float(values[3]))
		if unit.get("team","ally")=="enemy":
			var mirrored_left := 1.0-finish.x
			finish.x = 1.0-start.x
			start.x = mirrored_left
		var bounds := Rect2(start*size-pivot,(finish-start)*size)
		if motion=="idle":
			var breath := Vector2.ONE if metrics.get(unit.slug,{}).get("rigid_idle",false) else Vector2(1.025,1.08)
			for angle in [-IDLE_SWAY,IDLE_SWAY]:
				bounds = bounds.merge(Transform2D(angle,breath,0.0,Vector2.ZERO)*Rect2(start*size-pivot,(finish-start)*size))
		hull = hull.merge(bounds) if hull.has_area() else bounds
	return hull

func _base_geometry(unit: Dictionary, surface: Vector2) -> Dictionary:
	if str(unit.get("slug",""))=="dragon" and str(unit.get("team",""))=="enemy":
		return _dragon_geometry(unit,surface)
	var m: Dictionary = metrics.get(unit.slug,{"width":320,"height":320,"top":0,"bottom":319})
	var slot: int = clampi(int(unit.get("slot",0)),0,4)
	var ally: bool = str(unit.get("team","ally"))=="ally"
	var depth: float = (ALLY_DEPTH if ally else ENEMY_DEPTH)[slot]
	var offset: float = (ALLY_OFFSET if ally else ENEMY_OFFSET)[slot]
	var layer_z: int = (ALLY_Z if ally else ENEMY_Z)[slot]
	var cell = surface.x*0.48/5.0
	var wrap = Vector2(cell*1.56,surface.y*0.69*0.87)
	var image_size = wrap*Vector2(1.16,0.96)
	var fit = minf(image_size.x/float(m.width),image_size.y/float(m.height))
	var body = maxi(int(m.bottom)-int(m.top)+1,1)
	var factor = image_size.x*(210.0/320.0)*RATIOS.get(unit.slug,1.0)/body*depth
	var local_foot = wrap.y-image_size.y+(image_size.y-float(m.height)*fit)/2.0+(float(m.bottom)+1.0)*fit
	var foot = surface.y*(0.22+0.69*0.13)+wrap.y/2.0+(local_foot-wrap.y/2.0)*depth+wrap.y*offset
	var x = horizontal_center(unit,surface)
	var dimensions = Vector2(m.width,m.height)*factor
	var pivot = Vector2(dimensions.x/2.0,(float(m.bottom)+1.0)*factor)
	return {"size":dimensions,"pivot":pivot,"position":Vector2(x,foot)-pivot,"scale":factor,"foot":Vector2(x,foot),"wrap":wrap,"z":layer_z,"effect":Vector2(x,surface.y*(0.22+0.69*0.13)+wrap.y/2.0-wrap.y*0.05*depth+wrap.y*offset)}

# Colossal boss occupies the enemy half; head lunge stays inside the stage.
# Cards/HP retain one logical enemy slot. No targeting or rule changes.
func _dragon_geometry(unit: Dictionary,surface: Vector2) -> Dictionary:
	var m: Dictionary=metrics.dragon
	var foot_y: float=surface.y*0.82
	var factor: float=minf(surface.x*0.72/float(m.width),(foot_y-surface.y*0.225)/float(m.bottom-m.top+1))
	var dimensions: Vector2=Vector2(m.width,m.height)*factor
	var x: float=horizontal_center(unit,surface)
	var position: Vector2=Vector2(surface.x-18.0-966.0*factor,foot_y-575.0*factor)
	return {"size":dimensions,"pivot":Vector2(x-position.x,575.0*factor),"position":position,"scale":factor,"foot":Vector2(x,foot_y),"wrap":Vector2(surface.x*0.32,surface.y*0.6),"z":14,"effect":Vector2(x,surface.y*0.55)}

# Follow the ground-plane diagonal without moving the HUD/card row.
# The health indicator is HUD chrome (above sprites), not a depth layer.
func health_bar_y(unit: Dictionary, surface: Vector2) -> float:
	return geometry(unit,surface).bar.position.y

func _slot_bar_y(unit: Dictionary, surface: Vector2) -> float:
	var slot: int = clampi(int(unit.get("slot",0)),0,4)
	# A full-height dragon lunge crosses the center reserve slot. Keep both
	# auxiliary HUDs above that arc, below the combat cue rail.
	if slot==4 and surface.y>=720.0:
		return 134.0
	var ally: bool = str(unit.get("team","ally"))=="ally"
	var offset: float = (ALLY_OFFSET if ally else ENEMY_OFFSET)[slot]
	return surface.y*0.3028 + surface.y*0.69*0.87*offset*0.65


class HealthBar extends Range:
	# Each HP is one cell; the white forecast is removed one actual hit at a time.
	var preview_damage: int = 0
	var forecast_hp: int = 0
	var white_cells: float = 0.0:
		set(next):
			white_cells = next
			queue_redraw()
	var damage_tween: Tween
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		value_changed.connect(func(_value): queue_redraw())
	func preview(amount: int) -> void:
		if is_instance_valid(damage_tween): damage_tween.kill()
		forecast_hp = int(value)
		preview_damage = clampi(amount, 0, maxi(0, forecast_hp))
		white_cells = float(preview_damage)
		queue_redraw()
	func consume_hit(amount: int, remaining_hp: int) -> void:
		var lost: int = mini(preview_damage, maxi(0, amount))
		if lost <= 0: return
		if is_instance_valid(damage_tween): damage_tween.kill()
		var next_white: float = float(preview_damage-lost)
		damage_tween = create_tween()
		damage_tween.tween_property(self, "white_cells", next_white, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		damage_tween.tween_callback(func():
			preview_damage -= lost
			forecast_hp = maxi(0, remaining_hp)
			value = remaining_hp
			white_cells = float(preview_damage)
			queue_redraw())
	func clear_preview() -> void:
		if is_instance_valid(damage_tween): damage_tween.kill()
		preview_damage = 0
		forecast_hp = int(value)
		white_cells = 0.0
		queue_redraw()
	func _draw() -> void:
		var count: int = maxi(1, int(max_value))
		var hp: int = clampi(forecast_hp if preview_damage > 0 else int(value), 0, count)
		var width: float = size.x / float(count)
		draw_rect(Rect2(Vector2.ZERO, size), Color("100b0c"))
		for i in range(count):
			var rect := Rect2(Vector2(i * width + 0.55, 0.4), Vector2(maxf(0.1, width - 1.1), maxf(1.0, size.y - 0.8)))
			draw_rect(rect, Color("e44932") if i < hp and hp <= count / 2 else (Color("ed9c42") if i < hp else Color("35262a")))
		# The rightmost predicted cells disappear toward the left.
		var full: int = int(floor(white_cells))
		var partial: float = white_cells-float(full)
		for j in range(full):
			var index: int = hp-1-j
			if index < 0: break
			draw_rect(Rect2(Vector2(index*width+0.55,0.4),Vector2(maxf(0.1,width-1.1),maxf(1.0,size.y-0.8))),Color.WHITE)
		if partial > 0.001 and hp-full-1 >= 0:
			var index: int = hp-full-1
			draw_rect(Rect2(Vector2(index*width+0.55,0.4),Vector2(maxf(0.1,width-1.1)*partial,maxf(1.0,size.y-0.8))),Color.WHITE)
