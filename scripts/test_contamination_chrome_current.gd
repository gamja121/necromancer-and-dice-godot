extends SceneTree
## New crow HUD must remain visible on the real board and under the
## inventory-book hand (current game contract), but hidden under all
## location/event modals. Previous Stage5R test assumed a book was an event.
const MAP = preload("res://map.tscn")
const SESSION = preload("res://systems/run_session.gd")
var successes:int=0
var failures:int=0
func check(ok:bool,note:String)->void:
	if ok:
		successes+=1
		print("PASS contamination-chrome: ",note)
	else:
		failures+=1
		printerr("FAIL contamination-chrome: ",note)
func _initialize()->void:
	call_deferred("_run")
func _run()->void:
	var session:Node=root.get_node_or_null("RunSession")
	var created:bool=session==null
	if created:
		session=SESSION.new()
		session.name="RunSession"
		root.add_child(session)
	var prior_path:String=session.save_file_path
	var temp_path:String="user://contamination_chrome_%d.json"%OS.get_process_id()
	session.save_file_path=temp_path
	session.start_new_world()
	var map:Control=MAP.instantiate()
	root.add_child(map)
	await process_frame
	var gauge:Control=map.presentation.gauge
	var before:Dictionary=session.world.snapshot().duplicate(true)
	check(gauge!=null and gauge.uses_approved_art,"real map has the crow-frame contamination gauge")
	check(gauge.visible and gauge.is_visible_in_tree(),"board gauge initially visible")
	map.modal()
	check(not gauge.visible and not gauge.is_visible_in_tree(),"generic event modal hides contamination meter")
	map.close_overlay()
	check(gauge.visible,"closing event returns contamination meter")
	var forest:int=session.world.tiles.find("forest")
	if forest>=0:
		map.show_location(forest)
		check(not gauge.visible,"real location art hides gauge behind story artwork")
		map.close_overlay()
		check(gauge.visible,"closing real location restores gauge")
	# The active map contract keeps the original books and gauge visible
	# behind the transparent card-hand input shield.
	map.show_inventory("unit")
	check(is_instance_valid(map.overlay) and gauge.visible,"inventory hand is a board overlay, not a location modal")
	map.close_overlay()
	check(gauge.visible,"closing card hand keeps the same gauge")
	check(before==session.world.snapshot(),"all tested UI panels are save-neutral")
	map.queue_free()
	await process_frame
	session.save_file_path=prior_path
	for suffix in ["",".tmp"]:
		var p:String=temp_path+suffix
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if created: session.queue_free()
	print("CONTAMINATION_CHROME_CURRENT: %d passed, %d failed"%[successes,failures])
	quit(0 if failures==0 else 1)
