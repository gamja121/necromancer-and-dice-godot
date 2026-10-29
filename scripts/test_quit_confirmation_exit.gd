extends SceneTree
## Run in a separate process: exercise the real quit, rather than mock it.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var manager:Node=root.get_node("QuitConfirmation")
	manager.quit_requested.connect(func():print("QUIT_CONFIRMATION_EXIT: confirmed"))
	manager.request_quit()
	await process_frame
	manager.dialog.get_ok_button().pressed.emit()
