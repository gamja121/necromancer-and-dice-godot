extends Control
## Gather the original 21 map stones into TWO rings, rotate exactly ONE
## tooth, then physically exchange two pairs of stones before scattering.
## The same source -> destination permutation owns the saved board and
## every animation frame. Rule-mandated new tile kinds materialize visibly
## while gathered, never as a surprise after a stone has landed.
const Layout = preload("res://systems/map_shuffle_layout.gd")
const StoneInertia = preload("res://systems/map_shuffle_gather.gd")
const AudioSettings = preload("res://systems/audio_settings.gd")
const GATHER_SFX = preload("res://assets/battle/sfx/move.ogg")
const ROTATE_SFX = preload("res://assets/battle/sfx/magic.ogg")
const LAND_SFX = preload("res://assets/battle/sfx/heavy.ogg")
const GATHER_DURATION = 0.44
const ROTATE_DURATION = 0.86
const SWAP_DURATION = 0.50
const SCATTER_DURATION = 0.52
const SETTLE_DURATION = 0.11
const RING_GAP = 0.06
const SWAP_PAIR_COUNT = 2
const BOARD_CENTER = Layout.DICE_CENTER
const SHADOW_OFFSET = Vector2(4.0,7.0)

var sources: Array[TextureButton] = []
var source_visibility: Array[bool] = []
var visuals: Array[TextureRect] = []
var slots: Array[Dictionary] = []
var source_indices: Array[int] = []
var target_indices: Array[int] = []
var source_centers: Array[Vector2] = []
var gather_centers: Array[Vector2] = []
var rotated_centers: Array[Vector2] = []
var swapped_centers: Array[Vector2] = []
var ring_scales: Array[float] = []
var swapped_scales: Array[float] = []
var destination_centers: Array[Vector2] = []
var swap_pairs: Array[Dictionary] = []
var conversions: Array[int] = []
var gathering_tween: Tween
var rotation_tween: Tween
var swap_tween: Tween
var scatter_tween: Tween
var finished: bool = false
var gathered: bool = false
var rotated: bool = false
var swapped: bool = false
var phase: String = ""
var last_progress: float = 0.0
var played_audio_cues: Array[String] = []
var cue_players: Dictionary = {}

## A deterministic bijection over 21 movable slots. Fixed oracle/village/
## home never enter the rings. Inner ring clicks +1; outer clicks -1.
## Two extra disjoint inner-vs-outer pairs really EXCHANGE destinations.
## Boss always stays in its dedicated slot 23, even after contamination 20.
static func route_plan(previous: Array, generated: Array, map_serial: int) -> Dictionary:
	if previous.size()!=Layout.BOARD_TILE_COUNT or generated.size()!=Layout.BOARD_TILE_COUNT:
		return {}
	var targets: Dictionary = {}
	var inner: Array = Layout.INNER_ORIGIN_ORDER
	var outer: Array = Layout.OUTER_ORIGIN_ORDER
	for i in range(inner.size()):
		targets[int(inner[i])] = int(inner[(i+1)%inner.size()])
	for i in range(outer.size()):
		targets[int(outer[i])] = int(outer[(i-1+outer.size())%outer.size()])
	# Always reserve source 23 for the boss destination. Before the first
	# boss appears, it can visibly transform into the boss while gathered.
	if str(generated[23])=="boss":
		var displaced: int = -1
		for source in targets:
			if int(targets[source])==23:
				displaced=int(source)
				break
		if displaced<0: return {}
		var old_target: int=int(targets[23])
		targets[23]=23
		targets[displaced]=old_target
	var pairs: Array[Dictionary] = []
	var used: Dictionary = {}
	for pair_id in range(SWAP_PAIR_COUNT):
		var a: int=-1
		var b: int=-1
		for offset in range(inner.size()):
			var candidate: int=int(inner[(map_serial+pair_id*3+offset)%inner.size()])
			if not used.has(candidate):
				a=candidate
				break
		if a<0: continue
		# Prefer visibly different tile kinds so the swap is immediately
		# understandable (rather than exchanging two identical roads).
		for offset in range(outer.size()):
			var candidate: int=int(outer[(map_serial*2+pair_id*5+offset)%outer.size()])
			if candidate==23 and str(generated[23])=="boss": continue
			if used.has(candidate): continue
			if b<0: b=candidate
			if str(previous[a])!=str(previous[candidate]):
				b=candidate
				break
		if b<0: continue
		used[a]=true
		used[b]=true
		var target_a: int=int(targets[a])
		targets[a]=targets[b]
		targets[b]=target_a
		pairs.append({"a":a,"b":b})
	return {"targets":targets,"pairs":pairs}

## Generated board retains every original tile COUNT rule and RNG choice.
## Prefer the real moved source face at its new slot; only replace faces
## when the rules require a changed count (graveyard, patrol, corruption)
## or a new fixed boss at 23. No changes happen after the landing frame.
static func compose_board(previous: Array, generated: Array, map_serial: int = 0) -> Array:
	var plan: Dictionary=route_plan(previous,generated,map_serial)
	if plan.is_empty(): return generated.duplicate()
	var targets: Dictionary=plan["targets"]
	var result: Array=generated.duplicate()
	var remaining: Dictionary={}
	for index in Layout.moving_indices():
		var kind: String=str(generated[index])
		remaining[kind]=int(remaining.get(kind,0))+1
	if str(generated[23])=="boss":
		result[23]="boss"
		remaining["boss"]=int(remaining["boss"])-1
	var unresolved: Array[int]=[]
	for source in Layout.moving_indices():
		var destination: int=int(targets[source])
		if destination==23 and str(generated[23])=="boss":
			continue
		var old_kind: String=str(previous[source])
		if old_kind!="boss" and int(remaining.get(old_kind,0))>0:
			result[destination]=old_kind
			remaining[old_kind]=int(remaining[old_kind])-1
		else:
			unresolved.append(destination)
	for destination in unresolved:
		var kind: String=str(generated[destination])
		if int(remaining.get(kind,0))<=0:
			for choice in Layout.moving_indices():
				var option: String=str(generated[choice])
				if int(remaining.get(option,0))>0:
					kind=option
					break
		result[destination]=kind
		remaining[kind]=int(remaining.get(kind,0))-1
	return result

static func changed_count(previous: Array, saved: Array, map_serial: int = 0) -> int:
	var plan: Dictionary=route_plan(previous,saved,map_serial)
	if plan.is_empty(): return -1
	var changed: int=0
	var targets: Dictionary=plan["targets"]
	for source in Layout.moving_indices():
		if previous[source]!=saved[int(targets[source])]:
			changed+=1
	return changed

func _ready() -> void:
	name="GatherOneNotchGear"
	size=Vector2(1280.0,720.0)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=5
	AudioSettings.ensure_buses()
	for cue in ["gather","rotate","land"]:
		var sound: AudioStream = GATHER_SFX if cue=="gather" else (ROTATE_SFX if cue=="rotate" else LAND_SFX)
		var player:=AudioStreamPlayer.new()
		player.name="GearSfx_"+cue
		player.bus="SFX"
		player.stream=sound
		player.max_polyphony=1
		player.volume_db=-23.0 if cue=="gather" else (-28.0 if cue=="rotate" else -20.0)
		player.pitch_scale=0.73 if cue!="land" else 0.77
		add_child(player)
		cue_players[cue]=player

func _sound(cue: String) -> void:
	played_audio_cues.append(cue)
	if DisplayServer.get_name()=="headless": return
	for player in cue_players.values():
		if player.playing: player.stop()
	var player: AudioStreamPlayer=cue_players[cue]
	player.play()

func prepare(buttons: Array, destination_textures: Array, previous: Array, saved: Array, map_serial: int) -> bool:
	if get_parent()==null or not visuals.is_empty(): return false
	if buttons.size()!=Layout.BOARD_TILE_COUNT or destination_textures.size()!=Layout.BOARD_TILE_COUNT:
		return false
	var plan: Dictionary=route_plan(previous,saved,map_serial)
	if plan.is_empty(): return false
	for i in range(Layout.BOARD_TILE_COUNT):
		if not buttons[i] is TextureButton or not destination_textures[i] is Texture2D:
			return false
		if not is_instance_valid(buttons[i]) or buttons[i].texture_normal==null or buttons[i].get_parent()!=get_parent():
			return false
	for fixed in Layout.FIXED_INDICES:
		if previous[fixed]!=saved[fixed] or buttons[fixed].texture_normal!=destination_textures[fixed]:
			return false
	var targets: Dictionary=plan["targets"]
	swap_pairs=plan["pairs"].duplicate(true)
	for slot in Layout.ring_slots():
		var source_index: int=int(slot["tile_index"])
		var destination: int=int(targets[source_index])
		var source: TextureButton=buttons[source_index]
		var face:=TextureRect.new()
		face.name="Stone_%d_to_%d" % [source_index,destination]
		face.texture=source.texture_normal
		face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter=Control.MOUSE_FILTER_IGNORE
		face.size=source.size
		face.pivot_offset=source.size*0.5
		face.position=source.position
		var shadow:=TextureRect.new()
		shadow.name="StoneShadow"
		shadow.texture=face.texture
		shadow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shadow.size=source.size
		shadow.position=SHADOW_OFFSET
		shadow.modulate=Color(0.03,0.02,0.03,0.27)
		shadow.mouse_filter=Control.MOUSE_FILTER_IGNORE
		shadow.show_behind_parent=true
		face.add_child(shadow)
		add_child(face)
		sources.append(source)
		source_visibility.append(source.visible)
		source.visible=false
		visuals.append(face)
		slots.append(slot)
		source_indices.append(source_index)
		target_indices.append(destination)
		source_centers.append(source.position+source.size*0.5)
		gather_centers.append(Layout.orbit_position(slot,0.0))
		ring_scales.append(float(slot["scale"]))
		destination_centers.append(buttons[destination].position+buttons[destination].size*0.5)
		if previous[source_index]!=saved[destination]:
			conversions.append(visuals.size()-1)
	for i in range(visuals.size()):
		rotated_centers.append(_one_notch_center(i,1.0))
		swapped_centers.append(rotated_centers[i])
		swapped_scales.append(ring_scales[i])
	for pair in swap_pairs:
		var ia: int=source_indices.find(int(pair["a"]))
		var ib: int=source_indices.find(int(pair["b"]))
		if ia<0 or ib<0: continue
		swapped_centers[ia]=rotated_centers[ib]
		swapped_centers[ib]=rotated_centers[ia]
		swapped_scales[ia]=ring_scales[ib]
		swapped_scales[ib]=ring_scales[ia]
	return visuals.size()==Layout.INNER_COUNT+Layout.OUTER_COUNT

func _pose(i: int, center: Vector2, factor: float) -> void:
	var face: TextureRect=visuals[i]
	face.position=center-face.size*0.5
	face.scale=Vector2.ONE*factor

func _one_notch_center(i: int, progress: float) -> Vector2:
	var slot: Dictionary=slots[i]
	var teeth: int=Layout.INNER_COUNT if int(slot["ring"])==0 else Layout.OUTER_COUNT
	var direction: float=1.0 if int(slot["ring"])==0 else -1.0
	var radius: Vector2=Layout.INNER_RADIUS if int(slot["ring"])==0 else Layout.OUTER_RADIUS
	var angle: float=float(slot["start_angle"])+direction*TAU/float(teeth)*progress
	return BOARD_CENTER+Vector2(cos(angle)*radius.x,sin(angle)*radius.y)

func _gather_frame(raw: float) -> void:
	var p: float=raw*raw*(3.0-2.0*raw)
	for i in range(visuals.size()):
		_pose(i,source_centers[i].lerp(gather_centers[i],p),lerpf(1.0,ring_scales[i],p))

func _notch_frame(raw: float) -> void:
	var p: float=StoneInertia.stone_rotation_progress(raw)
	last_progress=p
	for i in range(visuals.size()):
		_pose(i,_one_notch_center(i,p),ring_scales[i])

func _swap_frame(raw: float) -> void:
	var p: float=StoneInertia.stone_rotation_progress(raw)
	for i in range(visuals.size()):
		var a: Vector2=rotated_centers[i]
		var b: Vector2=swapped_centers[i]
		var center: Vector2=a.lerp(b,p)
		# Exchange partners move on opposite sides of the crossing so
		# both pieces remain individually visible during their real swap.
		if a.distance_to(b)>0.01:
			var transverse: Vector2=(b-a).orthogonal().normalized()
			var sign: float=1.0 if i%2==0 else -1.0
			center+=transverse*24.0*sin(p*PI)*sign
		_pose(i,center,lerpf(ring_scales[i],swapped_scales[i],p))

func _scatter_frame(raw: float) -> void:
	var p: float=raw*raw*(3.0-2.0*raw)
	for i in range(visuals.size()):
		_pose(i,swapped_centers[i].lerp(destination_centers[i],p),lerpf(swapped_scales[i],1.0,p))

func _reveal_real_changes(destination_textures: Array) -> void:
	# A mandatory change (e.g. new graveyard or boss) happens *while the
	# stones are gathered*, BEFORE any rotation/swaps, never on landing.
	for i in conversions:
		var face: TextureRect=visuals[i]
		var dest: int=target_indices[i]
		face.texture=destination_textures[dest]
		var shadow: TextureRect=face.get_node("StoneShadow")
		shadow.texture=face.texture

func play_once(destination_textures: Array) -> void:
	if visuals.size()!=Layout.INNER_COUNT+Layout.OUTER_COUNT or gathering_tween!=null:
		return
	phase="gather"
	_sound("gather")
	gathering_tween=create_tween()
	gathering_tween.tween_method(_gather_frame,0.0,1.0,GATHER_DURATION).set_trans(Tween.TRANS_LINEAR)
	await gathering_tween.finished
	_gather_frame(1.0)
	gathered=true
	_reveal_real_changes(destination_textures)
	await get_tree().create_timer(RING_GAP).timeout
	phase="rotate"
	_sound("rotate")
	rotation_tween=create_tween()
	rotation_tween.tween_method(_notch_frame,0.0,1.0,ROTATE_DURATION).set_trans(Tween.TRANS_LINEAR)
	await rotation_tween.finished
	_notch_frame(1.0)
	rotated=true
	phase="swap"
	swap_tween=create_tween()
	swap_tween.tween_method(_swap_frame,0.0,1.0,SWAP_DURATION).set_trans(Tween.TRANS_LINEAR)
	await swap_tween.finished
	_swap_frame(1.0)
	swapped=true
	phase="scatter"
	scatter_tween=create_tween()
	scatter_tween.tween_method(_scatter_frame,0.0,1.0,SCATTER_DURATION).set_trans(Tween.TRANS_LINEAR)
	await scatter_tween.finished
	_scatter_frame(1.0)
	phase="land"
	_sound("land")
	await get_tree().create_timer(SETTLE_DURATION).timeout
	finished=true
	phase="finished"

func clean_up() -> void:
	for tween in [gathering_tween,rotation_tween,swap_tween,scatter_tween]:
		if tween!=null and tween.is_running(): tween.kill()
	for i in range(sources.size()):
		if is_instance_valid(sources[i]): sources[i].visible=source_visibility[i]
	for face in visuals:
		if is_instance_valid(face): face.queue_free()
	sources.clear()
	source_visibility.clear()
	visuals.clear()
	slots.clear()
	source_indices.clear()
	target_indices.clear()
	source_centers.clear()
	gather_centers.clear()
	rotated_centers.clear()
	swapped_centers.clear()
	destination_centers.clear()
	ring_scales.clear()
	swapped_scales.clear()
	swap_pairs.clear()
	conversions.clear()

func _exit_tree() -> void:
	for i in range(sources.size()):
		if is_instance_valid(sources[i]): sources[i].visible=source_visibility[i]
