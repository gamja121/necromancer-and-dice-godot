extends Control
## Four atlas frames from the supplied book chain sheet. Battle state is inferred, never saved.
signal transition_finished
const SHEET = preload("res://assets/map/ui/book_battle_lock_sheet.png")
const REGIONS = [Rect2(30,68,522,576),Rect2(552,68,526,576),Rect2(1078,68,538,576),Rect2(1616,68,526,576)]
@export_range(0.05,0.25,0.01) var frame_duration: float = 0.10
var button: TextureButton
var frames: Array[Texture2D] = []
var original_texture: Texture2D
var original_disabled_texture: Texture2D
var original_disabled = false
var locked = false
var transitioning = false
var motion: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button = get_parent() as TextureButton
	if button == null:
		push_warning("BookBattleLock requires a TextureButton parent.")
		return
	original_texture = button.texture_normal
	original_disabled_texture = button.texture_disabled
	for region in REGIONS:
		var atlas = AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = region
		# Uniform display canvas: do not rescale the book as chains are added.
		atlas.margin = Rect2((540-region.size.x)*0.5,0,540-region.size.x,0)
		atlas.filter_clip = true
		frames.append(atlas)

func set_locked(value: bool, animated: bool = true) -> void:
	if button == null: return
	if locked==value and not transitioning: return
	if motion != null and motion.is_valid(): motion.kill()
	if value and not locked: original_disabled = button.disabled
	locked = value
	transitioning = animated
	button.disabled = true
	if not animated:
		apply_frame(3 if value else 0)
		finish()
		return
	apply_frame(0 if value else 3)
	motion = create_tween()
	for index in ([1,2,3] if value else [2,1,0]):
		motion.tween_interval(frame_duration)
		motion.tween_callback(apply_frame.bind(index))
	motion.tween_interval(frame_duration*0.5)
	motion.tween_callback(finish)

func apply_frame(index: int) -> void:
	if not is_instance_valid(button): return
	button.texture_normal = frames[index]
	button.texture_disabled = frames[index]

func finish() -> void:
	transitioning = false
	if is_instance_valid(button):
		if not locked:
			button.texture_normal = original_texture
			button.texture_disabled = original_disabled_texture
		button.disabled = locked or original_disabled
		button.tooltip_text = "전투 중에는 마물 책을 열 수 없습니다" if locked else "보유 마물"
	transition_finished.emit()

func _exit_tree() -> void:
	if motion != null and motion.is_valid(): motion.kill()
