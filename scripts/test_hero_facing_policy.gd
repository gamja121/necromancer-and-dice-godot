extends SceneTree
const Policy = preload("res://systems/hero_facing_policy.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func expect_pose(delta: Vector2, expected_name: String, expected_flip: bool, case_name: String) -> void:
	var result: Dictionary = Policy.for_travel(delta)
	check(str(result.get("pose", "")) == expected_name and bool(result.get("flip_h", not expected_flip)) == expected_flip, case_name)

func expect_step_arrival(delta: Vector2, final_step: bool, expected_name: String, expected_flip: bool, case_name: String) -> void:
	var result: Dictionary = Policy.for_step_arrival(delta, final_step)
	check(str(result.get("pose", "")) == expected_name and bool(result.get("flip_h", not expected_flip)) == expected_flip, case_name)

func check(condition: bool, case_name: String) -> void:
	if condition:
		passed += 1
		print("PASS hero-facing: ",case_name)
	else:
		failed += 1
		printerr("FAIL hero-facing: ",case_name)

func run() -> void:
	expect_pose(Vector2(128,0),"side",false,"right travel uses right-facing side art")
	expect_pose(Vector2(-128,0),"side",true,"left travel horizontally mirrors side art")
	expect_pose(Vector2(0,-90),"back",false,"upward travel uses rear view")
	expect_pose(Vector2(0,90),"front",false,"downward travel uses front view")
	expect_pose(Vector2(179,-21),"side",false,"top-left corner follows next rightward leg")
	expect_pose(Vector2(-192,100),"side",true,"bottom-right corner follows leftward leg")
	expect_pose(Vector2(0,0),"front",false,"no travel defaults to front view")
	var landed: Dictionary = Policy.for_arrival()
	check(landed.pose == "front" and landed.flip_h == false,"final arrival uses unmirrored front")
	# Multiple tiles per roll: never turn to the camera at an intermediate tile.
	expect_step_arrival(Vector2(100,0),false,"side",false,"top row keeps right-facing side through intermediate tiles")
	expect_step_arrival(Vector2(-100,0),false,"side",true,"bottom row keeps mirrored side through intermediate tiles")
	expect_step_arrival(Vector2(0,90),false,"front",false,"right vertical row stays front while travelling down")
	expect_step_arrival(Vector2(0,-90),false,"back",false,"left vertical row stays back while travelling up")
	for delta in [Vector2(100,0),Vector2(-100,0),Vector2(0,90),Vector2(0,-90)]:
		expect_step_arrival(delta,true,"front",false,"only final route destination turns toward player: %s" % str(delta))
	print("HERO_FACING: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
