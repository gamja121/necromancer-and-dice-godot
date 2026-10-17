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
var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_visual_metrics.json"))

func frames(slug: String, motion: String) -> Array:
	return metrics.get(slug,{}).get(motion,[1])

func horizontal_center(unit: Dictionary, surface: Vector2) -> float:
	var slot: int = clampi(int(unit.get("slot",0)),0,4)
	var ally: bool = str(unit.get("team","ally"))=="ally"
	var column: int = ALLY_COLUMNS[slot] if ally else ENEMY_COLUMNS[slot]
	return (0.0 if ally else surface.x*0.52)+(float(column)-0.5)*(surface.x*0.48/5.0)

func geometry(unit: Dictionary, surface: Vector2) -> Dictionary:
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

# Follow the ground-plane diagonal without moving the HUD/card row.
# The health indicator is HUD chrome (above sprites), not a depth layer.
func health_bar_y(unit: Dictionary, surface: Vector2) -> float:
	var slot: int = clampi(int(unit.get("slot",0)),0,4)
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
