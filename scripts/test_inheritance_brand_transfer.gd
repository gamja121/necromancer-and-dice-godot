extends SceneTree
## Verify that the visual transfer follows the committed random result,
## including filtered faces and a new slot for an already-owned brand type.
const Home=preload("res://systems/home_inheritance.gd")
const FX=preload("res://systems/inheritance_sacrifice_effect.gd")
const Cards=preload("res://systems/layered_unit_card.gd")
const Brands=preload("res://systems/brand_inheritance.gd")
var passed:int=0
var failed:int=0
var stamp_count:int=0

func _initialize() -> void: call_deferred("run")

func check(ok:bool,label:String) -> void:
	if ok: passed+=1
	else: failed+=1; printerr("FAIL inheritance-transfer: ",label)

func wait_for(predicate:Callable,limit:int=3500) -> bool:
	var deadline:int=Time.get_ticks_msec()+limit
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return bool(predicate.call())

func icon_row(preview:Control) -> Control:
	return preview.find_child(Cards.BRAND_ROW_NAME,true,false) as Control

func global_center(control:Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*0.5)

func seed_for(index:int,count:int) -> int:
	var candidate:=RandomNumberGenerator.new()
	for value in range(1,2000):
		candidate.seed=value
		if candidate.randi_range(0,count-1)==index: return value
	return -1

func on_cue(kind:String) -> void:
	if kind=="book_stamp": stamp_count+=1

func committed_case(session:Node,pick:int,filter_curse:bool=false) -> void:
	session.start_new_world()
	var world=session.world
	var donor:Dictionary=world.roster[0]
	var recipient:Dictionary=world.roster[1]
	if filter_curse:
		# These are the starters' real base types, so normalize keeps their
		# curses. Source face 6 must be removed by the receiver's base curse.
		donor.brands=[{"type":"vampire","bless":[2,6],"curse":[4]}]
		recipient.brands=[{"type":"combo","bless":[3],"curse":[6]},{"type":"vampire","bless":[5],"curse":[]}]
	else:
		donor.brands=[{"type":"guard","bless":[2],"curse":[]},{"type":"poison","bless":[5],"curse":[]},{"type":"critical","bless":[4],"curse":[]}]
		recipient.brands=[{"type":"critical","bless":[1],"curse":[]},{"type":"guard","bless":[3],"curse":[]}]
	var donor_before:Dictionary=donor.duplicate(true)
	var receiver_before:Dictionary=recipient.duplicate(true)
	var candidates:Array=Brands.normalize(donor_before,world.definitions)
	var seed:int=seed_for(pick,candidates.size())
	check(seed>0,"a deterministic real draw exists for source icon %d"%pick)
	world.rng.seed=seed
	var expected_rng:=RandomNumberGenerator.new()
	expected_rng.state=world.rng.state
	var selected:int=expected_rng.randi_range(0,candidates.size()-1)
	var expected:Dictionary=Brands.blessing(receiver_before,candidates[selected],world.definitions)
	check(session.save_world(),"isolated source-choice fixture saves")
	var scene=Home.new()
	root.add_child(scene)
	scene.setup(session)
	# A translated/scaled UI host catches local/global coordinate mistakes
	# without demanding any particular pixel path or visual timing curve.
	scene.position=Vector2(23,19)
	scene.scale=Vector2(0.86,0.86)
	await create_timer(0.35).timeout
	scene.select_unit(str(donor.id))
	scene.select_unit(str(recipient.id))
	var donor_icons:Control=icon_row(scene.material_art)
	var old_icons:Control=icon_row(scene.receiver_art)
	check(donor_icons!=null and donor_icons.get_child_count()==candidates.size(),"all donor brand candidates have distinct card icons")
	check(old_icons!=null and old_icons.get_child_count()==2,"receiver initially renders only its two existing slots")
	var source:TextureRect=donor_icons.get_child(selected) as TextureRect
	var source_center:Vector2=global_center(source)
	var stamp_before:int=stamp_count
	scene.confirm()
	var transfer:Control=scene.find_child("InheritanceBrandTransfer",true,false) as Control
	# confirm() refreshes the original card nodes while locking selection.
	# Compare with the live selected glyph after that refresh.
	source=icon_row(scene.material_art).get_child(selected) as TextureRect
	source_center=global_center(source)
	check(transfer!=null,"successful saved inheritance starts one transfer")
	check(scene.inherited_brand==expected,"awarded brand equals the independently predicted saved draw")
	check(world.rng.state==expected_rng.state,"commit consumes one brand draw and no presentation RNG")
	check(scene.inherited_brand.get("curse",[99]).is_empty(),"transferred brand never copies the donor curse")
	if filter_curse: check(scene.inherited_brand.get("bless",[])==[2],"receiver curse filters source face 6 before the visual transfer")
	var committed:Dictionary=world.snapshot().duplicate(true)
	var saved:PackedByteArray=FileAccess.get_file_as_bytes(session.save_file_path)
	if transfer!=null:
		check(int(transfer.source_icon_index)==selected,"exact committed donor icon is selected among multiple candidates")
		check(transfer.source_icon==source,"transfer originates from the chosen donor icon rather than an arbitrary brand")
		check((transfer.get_global_transform_with_canvas()*transfer.origin).distance_to(source_center)<2.0,"transfer origin follows transformed donor icon coordinates")
		check(transfer.emblem is AtlasTexture and transfer.emblem.atlas==source.texture.atlas and transfer.emblem.region==source.texture.region,"traveling emblem uses the actual selected icon atlas")
		check(not transfer.stamped and icon_row(scene.receiver_art).get_child_count()==2,"new recipient slot is visually withheld until landing")
	var first_material:String=scene.material_id
	var first_receiver:String=scene.receiver_id
	scene.confirm()
	scene.select_unit(first_material)
	check(scene.busy and scene.material_id==first_material and scene.receiver_id==first_receiver,"duplicate confirmation and reselection are locked during transfer")
	check(scene.find_children("InheritanceBrandTransfer","",true,false).size()==1 and world.snapshot()==committed,"double confirmation cannot duplicate transfer, receipt or award")
	if transfer!=null:
		check(await wait_for(func(): return not is_instance_valid(transfer) or bool(transfer.stamped)),"visual transfer reaches a landing within its bound")
		if is_instance_valid(transfer) and transfer.stamped:
			var final_icons:Control=icon_row(scene.receiver_art)
			check(final_icons!=null and final_icons.get_child_count()==3,"landing reveals exactly one appended third slot")
			if final_icons!=null and final_icons.get_child_count()==3:
				var final_icon:Control=final_icons.get_child(2)
				check((transfer.get_global_transform_with_canvas()*transfer.landing).distance_to(global_center(final_icon))<2.0,"landing follows the new slot in transformed receiver coordinates")
	check(await wait_for(func(): return not scene.busy),"transfer completes and releases the interaction lock")
	check(scene.find_child("InheritanceBrandTransfer",true,false)==null,"temporary effect node cleans up after landing")
	check(stamp_count==stamp_before+1,"landing stamps once rather than replaying at completion")
	var actual:Dictionary=session.owned_unit(str(receiver_before.id))
	check(actual.brands.size()==3 and actual.brands[0]==receiver_before.brands[0] and actual.brands[1]==receiver_before.brands[1] and actual.brands[2]==expected,"existing brands remain separate and the award occupies a new slot")
	if pick==0 or filter_curse:
		var repeated_type:String=str(expected.type)
		check(actual.brands.filter(func(item): return str(item.type)==repeated_type).size()==2,"same-type inheritance does not merge away the new brand slot")
	check(world.snapshot()==committed and world.rng.state==expected_rng.state and FileAccess.get_file_as_bytes(session.save_file_path)==saved,"animation and cleanup do not modify committed world, RNG or saved bytes")
	check(scene.receiver_art.scale==Vector2.ONE and scene.receiver_art.modulate==Color.WHITE,"recipient presentation transforms finish at their original values")
	var donor_id:String=str(donor_before.id)
	var receiver_id:String=str(receiver_before.id)
	scene.queue_free()
	await process_frame
	session.reload_world()
	check(session.owned_unit(donor_id).is_empty() and session.owned_unit(receiver_id).brands.size()==3,"donor removal and appended slot survive a real save reload")

func wait_for_effect(host:Control,preview:TextureRect,hand:Control,receiver:TextureRect,context:Dictionary,finished:Array) -> void:
	await FX.play(host,preview,hand,receiver,context)
	finished[0]=true

func disposal_case(session:Node) -> void:
	session.start_new_world()
	var donor:Dictionary=session.world.roster[0].duplicate(true)
	var before:Dictionary=session.world.roster[1].duplicate(true)
	donor.brands=[{"type":"guard","bless":[2],"curse":[]}]
	before.brands=[{"type":"critical","bless":[3],"curse":[]}]
	var applied:Dictionary={"type":"guard","bless":[2],"curse":[]}
	var after:Dictionary=before.duplicate(true)
	after.brands.append(applied.duplicate(true))
	var host:=Control.new()
	host.size=Vector2(800,600)
	root.add_child(host)
	var preview:TextureRect=Cards.make_preview(host,donor,Vector2(40,30),Vector2(144,210))
	var receiver:TextureRect=Cards.make_preview(host,before,Vector2(400,30),Vector2(144,210))
	var hand:=TextureButton.new()
	hand.size=Vector2(96,139)
	host.add_child(hand)
	Cards.install(hand,str(donor.slug),str(donor.name),false,donor.brands)
	var context:Dictionary={"donor":donor,"receiver_before":before,"receiver":after,"brand":applied,"definitions":session.world.definitions}
	var finished:Array=[false]
	wait_for_effect(host,preview,hand,receiver,context,finished)
	await create_timer(0.25).timeout
	check(host.find_child("InheritanceBrandTransfer",true,false)!=null,"scene-disposal fixture removes an effect that is actually in flight")
	host.queue_free()
	await process_frame
	check(await wait_for(func(): return bool(finished[0])),"scene removal releases the awaiting effect without hanging")
	check(root.find_child("InheritanceBrandTransfer",true,false)==null,"scene removal leaves no orphan transfer or stamp node")

class ObservedHome extends "res://systems/home_inheritance.gd":
	var hand_witness:Array=[]
	func render_hand() -> void:
		if not hand_witness.is_empty(): hand_witness[0]+=1
		super.render_hand()

func home_disposal_case(session:Node,queued:bool) -> void:
	session.start_new_world()
	var donor:Dictionary=session.world.roster[0]
	var recipient:Dictionary=session.world.roster[1]
	donor.brands=[{"type":"guard","bless":[2],"curse":[]}]
	recipient.brands=[{"type":"critical","bless":[3],"curse":[]}]
	check(session.save_world(),"home disposal fixture saves")
	var donor_id:String=str(donor.id)
	var receiver_id:String=str(recipient.id)
	var witness:Array=[0]
	var scene:=ObservedHome.new()
	scene.hand_witness=witness
	root.add_child(scene)
	scene.setup(session)
	scene.select_unit(donor_id)
	scene.select_unit(receiver_id)
	scene.confirm()
	await create_timer(0.25).timeout
	check(scene.busy and scene.completed and scene.find_child("InheritanceBrandTransfer",true,false)!=null,"real Home confirmation is in flight before owner removal")
	var committed:Dictionary=session.world.snapshot().duplicate(true)
	var saved:PackedByteArray=FileAccess.get_file_as_bytes(session.save_file_path)
	var renders_before:int=int(witness[0])
	var stamps_before:int=stamp_count
	if queued:
		scene.queue_free()
		await process_frame
		await process_frame
	else:
		root.remove_child(scene)
		check(not scene.is_inside_tree(),"owner can be removed without being deleted first")
		scene.free()
		await process_frame
	check(int(witness[0])==renders_before,"cancelled Home await never rebuilds its exiting hand")
	check(root.find_child("InheritanceBrandTransfer",true,false)==null and root.find_child("InheritanceLandingProbe",true,false)==null,"owner removal cleans effect and landing probe")
	check(stamp_count==stamps_before,"cancelled flight does not play a landing stamp")
	check(session.world.snapshot()==committed and FileAccess.get_file_as_bytes(session.save_file_path)==saved,"owner removal leaves the committed world and save unchanged")
	session.reload_world()
	check(session.owned_unit(donor_id).is_empty() and session.owned_unit(receiver_id).brands.size()==2,"cancelled presentation retains the persisted inheritance")

func run() -> void:
	var session:Node=root.get_node("RunSession")
	var old_path:String=session.save_file_path
	var scratch:String="user://inheritance_transfer_%d.json"%OS.get_process_id()
	session.save_file_path=scratch
	var audio:Node=root.get_node_or_null("GameAudio")
	AudioServer.set_bus_mute(0,false)
	var sfx:int=AudioServer.get_bus_index("SFX")
	if sfx>=0: AudioServer.set_bus_mute(sfx,false)
	if audio!=null: audio.cue_started.connect(on_cue)
	for choice in range(3): await committed_case(session,choice)
	await committed_case(session,0,true)
	await disposal_case(session)
	await home_disposal_case(session,true)
	await home_disposal_case(session,false)
	check(await wait_for(func(): return audio==null or audio.voices.is_empty(),5000),"all test audio finishes before service teardown")
	if audio!=null:
		audio.cue_started.disconnect(on_cue)
		audio.queue_free()
	await create_timer(0.10).timeout
	session.save_file_path=old_path
	session.world=null
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(scratch+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch+suffix))
	check(not FileAccess.file_exists(scratch),"isolated transfer save is removed")
	print("INHERITANCE_BRAND_TRANSFER: %d passed, %d failed"%[passed,failed])
	quit(0 if failed==0 else 1)
