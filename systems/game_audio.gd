extends Node
## Shared presentation audio. Never changes game rules, RNG, or saved progress.
signal cue_started(kind: String)
const Settings = preload("res://systems/audio_settings.gd")
const MAX_VOICES := 14
const UI_NAMES := ["ui_select","ui_confirm","ui_cancel","ui_blocked","card_use"]
var profiles: Dictionary = {}
var streams: Dictionary = {}
var voices: Array[Dictionary] = []
var last_started: Dictionary = {}
var paused_owners: Dictionary = {}

static func cue(context: Node, kind: String) -> bool:
	if not is_instance_valid(context) or not context.is_inside_tree(): return false
	var service := context.get_node_or_null("/root/GameAudio")
	return service.play_cue(kind,context) if service != null else false

static func stop(context: Node) -> void:
	if not is_instance_valid(context) or not context.is_inside_tree(): return
	var service := context.get_node_or_null("/root/GameAudio")
	if service != null: service.stop_owner(context)

static func pause(context: Node, paused: bool) -> void:
	if not is_instance_valid(context) or not context.is_inside_tree(): return
	var service := context.get_node_or_null("/root/GameAudio")
	if service != null: service.set_owner_paused(context,paused)

func _ready() -> void:
	Settings.ensure_buses()
	_build_profiles()
	get_tree().node_added.connect(_on_node_added)
	_hook_tree(get_tree().root)

func _build_profiles() -> void:
	for kind in ["arrow","attack","claw","death","dice-land","dice-tick","freeze","heavy","hit","magic","move","poison","summon","ui","victory","permanent-death","book-cards-open","treasure-chest-open"]:
		var extension := "mp3" if kind in ["book-cards-open","treasure-chest-open"] else ("wav" if kind=="permanent-death" else "ogg")
		var file_kind: String = "permanent_death" if kind=="permanent-death" else kind
		var group := "dice" if kind.begins_with("dice-") else ("map" if kind=="move" else "battle")
		_register(kind,"res://assets/battle/sfx/"+file_kind+"."+extension,-12.0,group,0.07 if group in ["dice","map"] else 0.045,3 if group in ["dice","map"] else 6,1.0,2)
	for kind in UI_NAMES:
		_register(kind,"res://assets/audio/sfx/"+kind+".wav",-18.0,"ui",0.065,2,1.0,1)
	for kind in ["book_close","book_stamp","book_confirm","reward_gain","capture_success","capture_fail","recovery","cleanse","swamp_hit","battle_critical","battle_block","battle_miss","battle_heal","shop_trade","ritual_complete","inheritance_complete","grave_dig","prayer_bless","prayer_fail","prophecy_bless","prophecy_curse","dragon_intro","dragon_roar","dragon_impact","dragon_attack","dragon_hit","dragon_critical","dragon_death","final_clear"]:
		var group := "book" if kind.begins_with("book_") else ("dragon" if kind.begins_with("dragon_") else ("battle" if kind.begins_with("battle_") else "result"))
		var loud: bool = kind in ["dragon_roar","dragon_impact","dragon_critical","dragon_death","final_clear"]
		_register(kind,"res://assets/audio/sfx/"+kind+".wav",-14.0 if loud else -17.0,group,0.10,2 if group=="book" else (3 if group!="battle" else 6),1.0,4 if loud else 2)
	_register("defeat_crack","res://assets/battle/sfx/heavy.ogg",-12.0,"terminal",0.10,2,0.72,4)
	_register("defeat_echo","res://assets/battle/sfx/death.ogg",-16.0,"terminal",0.10,2,0.92,3)
	_register("book_open","res://assets/battle/sfx/book-cards-open.mp3",-15.0,"book",0.12,2,0.88,2)
	_register("book_page","res://assets/battle/sfx/book-cards-open.mp3",-19.0,"book",0.12,2,1.0,2)

func _register(kind: String,path: String,db: float,group: String,gap: float,limit: int,pitch: float,priority: int) -> void:
	profiles[kind]={"path":path,"db":db,"group":group,"gap":gap,"limit":limit,"pitch":pitch,"priority":priority}

func play_cue(kind: String, owner: Node = null) -> bool:
	if not profiles.has(kind):
		push_warning("Unknown sound cue: "+kind)
		return false
	var p: Dictionary=profiles[kind]
	var now := Time.get_ticks_usec()
	if now-int(last_started.get(kind,-10000000)) < int(float(p.gap)*1000000.0): return false
	var bus := AudioServer.get_bus_index("SFX")
	if bus<0 or AudioServer.is_bus_mute(bus) or AudioServer.is_bus_mute(0): return false
	if not streams.has(p.path):
		if not ResourceLoader.exists(p.path):
			push_warning("Missing sound asset: "+str(p.path))
			return false
		streams[p.path]=load(p.path)
	var same: Array[Dictionary]=[]
	for voice in voices:
		if voice.group==p.group: same.append(voice)
	if same.size()>=int(p.limit):
		var victim: Dictionary={}
		for previous in same:
			if int(previous.priority)<=int(p.priority):
				victim=previous
				break
		if victim.is_empty(): return false
		_release(victim)
	if voices.size()>=MAX_VOICES:
		var oldest: Dictionary={}
		for voice in voices:
			if int(voice.priority)<=int(p.priority):
				oldest=voice
				break
		if oldest.is_empty(): return false
		_release(oldest)
	var player:=AudioStreamPlayer.new()
	player.name="Cue_"+kind.replace("-","_")
	player.stream=streams[p.path]
	player.bus="SFX"
	player.volume_db=float(p.db)
	player.pitch_scale=float(p.pitch)
	add_child(player)
	var scope := _scope(owner)
	var voice: Dictionary={"player":player,"kind":kind,"group":p.group,"priority":p.priority,"owner":weakref(owner) if is_instance_valid(owner) else null,"scope":weakref(scope) if scope!=null else null,"detached":kind in UI_NAMES,"track_owner":p.group in ["battle","dragon"]}
	voices.append(voice)
	player.finished.connect(_release.bind(voice),CONNECT_ONE_SHOT)
	last_started[kind]=now
	player.play()
	if not kind in UI_NAMES and is_instance_valid(owner):
		for reference in paused_owners.values():
			var paused_owner: Node=reference.get_ref()
			if is_instance_valid(paused_owner) and (owner==paused_owner or paused_owner.is_ancestor_of(owner)): player.stream_paused=true
	cue_started.emit(kind)
	return true

func _scope(node: Node) -> Node:
	if not is_instance_valid(node): return null
	var current := node
	while current.get_parent()!=null and current.get_parent()!=get_tree().root: current=current.get_parent()
	return current

func _matches(voice: Dictionary, owner: Node) -> bool:
	var target: Node=voice.owner.get_ref() if voice.owner!=null else null
	return is_instance_valid(target) and (target==owner or owner.is_ancestor_of(target))

func stop_owner(owner: Node) -> void:
	paused_owners.erase(owner.get_instance_id())
	for voice in voices.duplicate():
		if _matches(voice,owner): _release(voice)

func set_owner_paused(owner: Node,paused: bool) -> void:
	if paused: paused_owners[owner.get_instance_id()]=weakref(owner)
	else: paused_owners.erase(owner.get_instance_id())
	for voice in voices:
		if not voice.detached and _matches(voice,owner): voice.player.stream_paused=paused

func _release(voice: Dictionary) -> void:
	voices.erase(voice)
	var player: AudioStreamPlayer=voice.player
	if is_instance_valid(player):
		player.stop()
		player.stream=null
		player.queue_free()

func _process(_delta: float) -> void:
	for identity in paused_owners.keys():
		var node: Node=paused_owners[identity].get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree(): paused_owners.erase(identity)
	for voice in voices.duplicate():
		if voice.track_owner and voice.owner!=null:
			var owner: Node=voice.owner.get_ref()
			if not is_instance_valid(owner) or not owner.is_inside_tree():
				_release(voice)
				continue
		if voice.detached or voice.scope==null: continue
		var scope: Node=voice.scope.get_ref()
		if not is_instance_valid(scope) or not scope.is_inside_tree(): _release(voice)

func _hook_tree(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children(): _hook_tree(child)

func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("sfx_hooked"):
		node.set_meta("sfx_hooked",true)
		node.button_down.connect(_button_down.bind(weakref(node)))
		node.gui_input.connect(_blocked_input.bind(weakref(node)))

func _button_down(reference: WeakRef) -> void:
	var button: BaseButton=reference.get_ref() as BaseButton
	if not is_instance_valid(button) or button.disabled or not button.is_visible_in_tree(): return
	var kind := _button_kind(button)
	if not kind.is_empty(): play_cue(kind,button)

func _button_kind(button: BaseButton) -> String:
	if button.get_meta("sfx_manual",false): return ""
	if button.has_meta("sfx_kind"): return str(button.get_meta("sfx_kind"))
	if button is TextureButton and button.texture_normal!=null and "/dice/" in button.texture_normal.resource_path: return ""
	var text := str(button.name).to_lower()
	if button is Button: text+=" "+button.text
	for word in ["취소","닫기","돌아가기","거절","나가기","close","cancel","backdrop","outside"]:
		if word in text: return "ui_cancel"
	for word in ["확정","확인","수락","전투 시작","구매","교환","계승","진행","출발","사용","confirm","start"]:
		if word in text: return "ui_confirm"
	return "ui_select"

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed): return
	var control := get_viewport().gui_get_hovered_control()
	while control!=null and not control is BaseButton: control=control.get_parent() as Control
	if control is BaseButton and control.disabled and control.is_visible_in_tree() and not control.get_meta("sfx_manual",false):
		play_cue("ui_blocked",control)

func _exit_tree() -> void:
	for voice in voices.duplicate(): _release(voice)
	streams.clear()
	paused_owners.clear()

func _blocked_input(event: InputEvent, reference: WeakRef) -> void:
	var button: BaseButton=reference.get_ref() as BaseButton
	if not is_instance_valid(button) or not button.disabled or not button.is_visible_in_tree() or button.get_meta("sfx_manual",false): return
	var press: bool=(event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if press: play_cue("ui_blocked",button)
