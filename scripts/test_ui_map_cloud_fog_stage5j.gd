extends SceneTree
## Stage 5J: three original web fog banks, their coverage phases and one-shot tile swap.
const Presenter = preload("res://systems/map_presentation.gd")
var passed: int = 0
var failed: int = 0
var board_calls: int = 0
var complete: bool = false
var result: bool = false

func check(value: bool, description: String) -> void:
	if value:
		passed += 1
		print("PASS ui-cloud-fog: ",description)
	else:
		failed += 1
		printerr("FAIL ui-cloud-fog: ",description)

func _initialize() -> void:
	call_deferred("_run")

func _change_board() -> bool:
	board_calls += 1
	return true

func _play(presentation: Node) -> void:
	result = await presentation.cloud_refresh(Callable(self,"_change_board"))
	complete = true

func opacity(node: ColorRect) -> float:
	if node==null or node.material==null:
		return -1.0
	return float((node.material as ShaderMaterial).get_shader_parameter("coverage"))

func _run() -> void:
	var map = Control.new()
	map.size = Vector2(1280,720)
	root.add_child(map)
	var dice_button = Button.new()
	dice_button.name = "MapRollButton"
	map.add_child(dice_button)
	var presenter = Presenter.new()
	map.add_child(presenter)
	presenter.setup(map)
	call_deferred("_play",presenter)
	await create_timer(0.13).timeout
	var overlay: Control
	for node in map.get_children():
		if node is Control and node.z_index==250:
			overlay = node
	check(overlay!=null,"transition has an input-blocking overlay")
	var wash: ColorRect
	var banks: Array[ColorRect] = []
	if overlay!=null:
		wash = overlay.get_node_or_null("CloudBackdropWash") as ColorRect
		for name in ["CloudFrontBank","CloudCentralVeil","CloudCenterMist"]:
			banks.append(overlay.get_node_or_null(name) as ColorRect)
	check(wash!=null,"original translucent background wash exists")
	check(banks.size()==3,"original before, after, mist layers are instantiated")
	for i in range(banks.size()):
		var bank: ColorRect = banks[i]
		check(bank!=null,"fog layer %d exists" % (i+1))
		if bank==null: continue
		check(bank.mouse_filter==Control.MOUSE_FILTER_IGNORE,"fog layer %d cannot steal clicks" % (i+1))
		check(bank.material is ShaderMaterial,"fog layer %d uses a gradient shader" % (i+1))
		var material: ShaderMaterial = bank.material as ShaderMaterial
		check(int(material.get_shader_parameter("bank_kind"))==i,"fog layer %d selects its unique radial treatment" % (i+1))
		check(material.shader.code.contains("soft_ellipse") and material.shader.code.contains("fog_color"),"fog layer %d uses multi-stop radial colors" % (i+1))
		var expected_inset: float = 0.08 if i==2 else 0.12
		check(absf(bank.position.x+1280.0*expected_inset)<0.01 and absf(bank.position.y+720.0*expected_inset)<0.01,"fog layer %d respects source CSS inset" % (i+1))
	if wash!=null:
		check(wash.mouse_filter==Control.MOUSE_FILTER_IGNORE,"wash cannot steal input")
	check(dice_button.disabled,"map dice is locked while the old tile route is covered")
	check(board_calls==0,"board does not mutate at fog-in start")
	await create_timer(1.06).timeout
	if wash!=null:
		check(absf(wash.color.a-0.18)<0.04,"source background wash reaches 0.18 coverage")
	if banks.size()==3:
		check(opacity(banks[0])>0.77,"::before source fog opacity reaches 0.82")
		check(opacity(banks[1])>0.90,"::after source fog opacity reaches 0.95")
		check(opacity(banks[2])>0.92,"center mist reaches original 0.98 opacity")
	check(board_calls==0,"board replacement waits for 1320ms fully-covered interval")
	await create_timer(0.30).timeout
	check(board_calls==1,"one replacement under opaque fog after 1320ms")
	check(dice_button.disabled,"buttons stay locked throughout the 220ms hold")
	await create_timer(0.70).timeout
	if banks.size()==3:
		check(opacity(banks[0])<0.1,"opening makes front cloud bank transparent")
		check(opacity(banks[1])<0.1,"opening makes central veil transparent")
		check(opacity(banks[2])<0.3,"opening fades center mist after its original delay")
	await create_timer(0.65).timeout
	check(complete and result,"cloud transition returns success after 1120ms reveal")
	check(board_calls==1,"tile board callback never duplicates during reveal")
	check(not dice_button.disabled,"user controls recover when clouds clear")
	var effects: int = 0
	for child in map.get_children():
		if child is Control and child.z_index==250: effects += 1
	check(effects==0,"temporary shader and cloud layers are fully freed")
	map.queue_free()
	await process_frame
	print("UI_CLOUD_FOG_PARITY: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
