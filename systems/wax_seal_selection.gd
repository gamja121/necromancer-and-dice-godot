extends Control
## A visual-only selection marker for one parchment action button.
## The caller decides whether a click selects or executes the original action.
## No animation, glow, save data, or global button behavior is changed in step 1.

const WAX_SEAL = preload("res://assets/map/ui/wax_skull_seal.webp")
const SEAL_SIZE := Vector2(32.0, 32.0)

var _selected := false
var _seal: TextureRect


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    focus_mode = Control.FOCUS_NONE
    var button := get_parent() as Button
    if button == null:
        push_warning("WaxSealSelection must be attached to a Button.")
        return

    # Sits over the outer right edge of the existing parchment without
    # intercepting mouse, touch, keyboard or controller inputs.
    size = button.size
    _seal = TextureRect.new()
    _seal.name = "SkullWaxSeal"
    _seal.texture = WAX_SEAL
    _seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _seal.position = Vector2(button.size.x - SEAL_SIZE.x * 0.60, (button.size.y - SEAL_SIZE.y) * 0.5)
    _seal.size = SEAL_SIZE
    _seal.visible = false
    add_child(_seal)


func confirm_selection() -> bool:
    # False = selection click consumed; True = caller may execute the action.
    if _selected:
        return true
    _selected = true
    if is_instance_valid(_seal):
        _seal.show()
    return false
