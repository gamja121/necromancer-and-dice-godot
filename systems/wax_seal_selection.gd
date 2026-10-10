extends Control
## A visual-only selection marker for one parchment action button.
## The caller decides whether a click selects or executes the original action.
## A subtle glow and seal only reflect transient selection. Game state is unchanged.

const WAX_SEAL = preload("res://assets/map/ui/wax_skull_seal.webp")
const SEAL_SIZE := Vector2(32.0, 32.0)

var _selected := false
var _seal: TextureRect
var _glow_style: StyleBoxFlat


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    focus_mode = Control.FOCUS_NONE
    clip_contents = false
    var button := get_parent() as Button
    if button == null:
        push_warning("WaxSealSelection must be attached to a Button.")
        return

    # Sits over the outer right edge of the existing parchment without
    # intercepting mouse, touch, keyboard or controller inputs.
    size = button.size
    # Hollow border and soft crimson shadow leave the parchment and label readable.
    _glow_style = StyleBoxFlat.new()
    _glow_style.draw_center = false
    _glow_style.bg_color = Color.TRANSPARENT
    _glow_style.set_border_width_all(1)
    _glow_style.border_color = Color(0.68, 0.09, 0.08, 0.34)
    _glow_style.set_corner_radius_all(8)
    _glow_style.shadow_color = Color(0.70, 0.06, 0.07, 0.22)
    _glow_style.shadow_size = 9
    _glow_style.shadow_offset = Vector2.ZERO
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


func _draw() -> void:
    if _selected and _glow_style != null:
        draw_style_box(_glow_style, Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0)))


# Selection is exclusive to the current parchment-button panel.
# This deliberately has no global state or save-game effect.
static func clear_panel_selections(panel: Node, except_marker: Node = null) -> void:
    if panel == null:
        return
    for child in panel.get_children():
        if child is Button:
            var marker = child.get_node_or_null("WaxSealSelection")
            if marker != null and marker != except_marker:
                marker.call("clear_selection")


func clear_selection() -> void:
    if not _selected:
        return
    _selected = false
    if is_instance_valid(_seal):
        _seal.hide()
    queue_redraw()


func confirm_selection() -> bool:
    # False = select this button; True = execute its unchanged action.
    if _selected:
        return true
    var button := get_parent() as Button
    if button != null:
        clear_panel_selections(button.get_parent(), self)
    _selected = true
    if is_instance_valid(_seal):
        _seal.show()
    queue_redraw()
    return false
