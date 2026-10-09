extends RefCounted
# Ported from V2UnitSize and the web battlefield slot CSS.
const DEPTH = [0.94,1.01,1.08,1.14,0.88]
const OFFSET = [-0.03,0.02,0.07,0.11,-0.06]
const Z = [13,15,17,18,12]
const RATIOS = {"bone-golem":1.5,"death-knight":1.0,"plague-frog":0.5,"grave-worm":0.5,"spider-knight":2.0,"stone-golem":2.0,"flesh-golem":1.5,"skeleton-cavalry":1.5,"spiderling":0.5,"guardian-seed":0.5,"goblin-chief":1.5,"kraken":2.0,"minotaur":1.5,"goblin-rider":1.0,"yeti":1.5,"orc-warrior":1.5,"hydra":2.0,"boulder-ogre":1.5,"abyss-claw-hunter":1.5,"corpse-slime":1.0}
var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_visual_metrics.json"))

func frames(slug: String, motion: String) -> Array:
	return metrics.get(slug,{}).get(motion,[1])

func geometry(unit: Dictionary, surface: Vector2) -> Dictionary:
	var m: Dictionary = metrics.get(unit.slug,{"width":320,"height":320,"top":0,"bottom":319})
	var slot = mini(int(unit.slot),4)
	var cell = surface.x*0.48/5.0
	var wrap = Vector2(cell*1.56,surface.y*0.69*0.87)
	var image_size = wrap*Vector2(1.16,0.96)
	var fit = minf(image_size.x/float(m.width),image_size.y/float(m.height))
	var body = maxi(int(m.bottom)-int(m.top)+1,1)
	var factor = image_size.x*(210.0/320.0)*RATIOS.get(unit.slug,1.0)/body*DEPTH[slot]
	var local_foot = wrap.y-image_size.y+(image_size.y-float(m.height)*fit)/2.0+(float(m.bottom)+1.0)*fit
	var foot = surface.y*(0.22+0.69*0.13)+wrap.y/2.0+(local_foot-wrap.y/2.0)*DEPTH[slot]+wrap.y*OFFSET[slot]
	var columns = [4,3,2,1,5] if unit.team=="ally" else [2,3,4,5,1]
	var x = (0.0 if unit.team=="ally" else surface.x*0.52)+(columns[slot]-0.5)*cell
	var dimensions = Vector2(m.width,m.height)*factor
	var pivot = Vector2(dimensions.x/2.0,(float(m.bottom)+1.0)*factor)
	return {"size":dimensions,"pivot":pivot,"position":Vector2(x,foot)-pivot,"scale":factor,"foot":Vector2(x,foot),"wrap":wrap,"z":Z[slot],"effect":Vector2(x,surface.y*(0.22+0.69*0.13)+wrap.y/2.0-wrap.y*0.05*DEPTH[slot]+wrap.y*OFFSET[slot])}


class HealthBar extends Range:
	var fill_texture: Texture2D
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gradient = Gradient.new()
		gradient.colors = PackedColorArray([Color("7c1717"),Color("e44932"),Color("ffb34d")])
		gradient.offsets = PackedFloat32Array([0.0,0.55,1.0])
		var image = GradientTexture2D.new()
		image.gradient = gradient
		image.width = 128
		image.height = 5
		fill_texture = image
		value_changed.connect(func(_value): queue_redraw())
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("100b0c"))
		if fill_texture!=null and value>0:
			draw_texture_rect(fill_texture,Rect2(Vector2.ZERO,Vector2(size.x*clampf(value/maxf(max_value,1.0),0,1),size.y)),false)
