extends SceneTree
## Restore the ORIGINAL V2 allied perspective columns [4,3,2,1,5].
## Confirmed selection identity remains stable and each bottom card follows
## its actual battlefield creature, not a newly invented left-to-right line.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
const LAYOUT = preload("res://systems/battle_presentation_layout.gd")
var passed := 0
var failed := 0

func check(ok: bool, name: String) -> void:
	if ok:
		passed += 1
		print("PASS battle-formation-order: ",name)
	else:
		failed += 1
		printerr("FAIL battle-formation-order: ",name)

func until_ready(condition: Callable, msec: int = 13000) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < msec:
		if condition.call(): return true
		await process_frame
	return bool(condition.call())

func scenario(session: Node, count: int) -> void:
	session.start_new_world()
	var world = session.world
	var starter: Array=world.roster.duplicate(true)
	# Four owned cards with unique IDs, using legitimate starter unit stats.
	# These are test-only disposable save fixtures, never a game reward.
	while world.roster.size()<4:
		var extra: Dictionary=starter[world.roster.size()%starter.size()].duplicate(true)
		extra.id="test-owned-slot-%d" % world.roster.size()
		world.roster.append(extra)
	var target: int=world.tiles.find("monster")
	check(target>=0,"%d cards: normal battle tile exists" % count)
	if target<0: return
	world.position=target
	check(session.save_world(),"%d cards: test-only four-card roster saved" % count)
	var map: Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	map.show_battle_deck(target)
	var deck: Control=map.overlay
	var indices: Array = [3,1,2,0].slice(0,count)
	var ids: Array=[]
	for index in indices:
		var id: String=str(world.roster[index].id)
		ids.append(id)
		deck.toggle_unit(id)
	check(deck.selected_ids==ids,"%d cards: selected deck order is authoritative" % count)
	for i in range(count):
		check(is_instance_valid(deck.lineup.get_node_or_null("SelectedUnit_%d" % (i+1))),"%d cards: deck position %d is visually occupied" % [count,i+1])
	deck.confirm_button.pressed.emit()
	var entered: bool=await until_ready(func(): return is_instance_valid(map.embedded_battle) and not map.embedded_battle.rules.units.is_empty())
	check(entered,"%d cards: confirmed order enters actual embedded battle" % count)
	if not entered:
		map.queue_free()
		await process_frame
		return
	var battle: Control=map.embedded_battle
	check(battle.rules.units.filter(func(u): return u.team=="ally").size()==count,"%d cards: exactly selected monsters spawn" % count)
	check(session.encounter.allies.map(func(u): return str(u.id))==ids,"%d cards: encounter save retains same 1-to-%d deck order" % [count,count])
	var centers: Array[float]=[]
	var dock_centers: Array[float]=[]
	var same_unit_ids: bool=true
	var geometry_matches: bool=true
	var dock_matches: bool=true
	var card_inside_board: bool=true
	var old_columns: Array=[4,3,2,1,5]
	var original_positions: bool=true
	var original_depth: bool=true
	var enemies_unaltered: bool=true
	var layout=LAYOUT.new()
	for i in range(count):
		var u: Dictionary=battle.rules.find_id(str(ids[i]))
		same_unit_ids = same_unit_ids and not u.is_empty() and int(u.get("slot",-1))==i and str(u.get("team",""))=="ally"
		if u.is_empty(): continue
		var unit_center: float=battle.unit_x(u)
		var geometry: Dictionary=layout.geometry(u,battle.surface_size)
		var sprite: TextureRect=battle.sprites[u.id]
		geometry_matches=geometry_matches and absf(unit_center-float(geometry.foot.x))<0.2
		geometry_matches=geometry_matches and absf(sprite.position.x+sprite.pivot_offset.x-unit_center)<7.0
		centers.append(unit_center)
		var slot_cell: float=battle.surface_size.x*0.48/5.0
		var old_x: float=(float(old_columns[i])-0.5)*slot_cell
		original_positions=original_positions and absf(unit_center-old_x)<0.2
		original_depth=original_depth and absf(float(geometry.z)-float([13,15,17,18,12][i]))<0.01
		var card: TextureButton=battle.cards[u.id]
		dock_centers.append(card.position.x+card.size.x*0.5)
		var local_to_canvas: Vector2=battle.get_global_transform_with_canvas()*Vector2(unit_center,0)
		var canvas_to_map: Vector2=map.stage.get_global_transform_with_canvas().affine_inverse()*local_to_canvas
		dock_matches=dock_matches and card.get_parent()==map.stage and absf(card.position.x+card.size.x*0.5-canvas_to_map.x)<0.5
		dock_matches=dock_matches and absf(card.position.y-battle.MAP_BOTTOM_TILE_CARD_Y)<0.5
		card_inside_board=card_inside_board and card.position.x>=0.0 and card.position.x+card.size.x<=map.stage.size.x and card.position.y>=0.0 and card.position.y+card.size.y<=map.stage.size.y
	for u in battle.rules.units:
		if u.team=="enemy":
			var enemy_columns: Array=[2,3,4,5,1]
			var original_x: float=665.6+(float(enemy_columns[mini(int(u.slot),4)])-0.5)*122.88
			enemies_unaltered=enemies_unaltered and absf(battle.unit_x(u)-original_x)<0.2
	check(same_unit_ids,"%d cards: battle slot ID order exactly matches clicked deck order" % count)
	var descending: bool=true
	for i in range(1,centers.size()):
		descending=descending and centers[i]<centers[i-1]
	check(centers.size()==count and descending,"%d cards: original V2 slots stagger back toward left 1->%d" % [count,count])
	check(original_positions,"%d cards: original source columns [4,3,2,1] used without newly invented spread" % count)
	check(original_depth,"%d cards: original perspective layer values retained" % count)
	check(geometry_matches,"%d cards: monster sprite center agrees with battle slot geometry" % count)
	check(dock_matches,"%d cards: each bottom card is exactly under its summoned unit" % count)
	var descending_dock: bool=true
	for i in range(1,dock_centers.size()):
		descending_dock=descending_dock and dock_centers[i]<dock_centers[i-1]
	check(dock_centers.size()==count and descending_dock,"%d cards: lower cards retain original V2 staggered order" % count)
	check(card_inside_board,"%d cards: all allied cards remain inside playable board bounds" % count)
	check(enemies_unaltered,"%d cards: original enemy formation is unchanged" % count)
	var fifth: Dictionary={"slot":4,"team":"ally"}
	check(absf(layout.horizontal_center(fifth,battle.surface_size)-(4.5*battle.surface_size.x*0.48/5.0))<0.2,
		"%d cards: independent fifth/summoned ally uses original V2 column 5" % count)
	map.queue_free()
	await process_frame

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session: Node=root.get_node_or_null("RunSession")
	var created: bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var old_path: String=session.save_file_path
	var scratch: String="user://deck_formation_order_%d.json" % OS.get_process_id()
	session.save_file_path=scratch
	for count in [1,2,4]:
		await scenario(session,count)
	session.save_file_path=old_path
	if created: session.queue_free()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	print("BATTLE_FORMATION_ORDER: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
