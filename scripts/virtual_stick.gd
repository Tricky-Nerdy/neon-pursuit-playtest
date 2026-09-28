extends Control
class_name VirtualStick

signal axis_changed(steer: float, drive: float)

var axis := Vector2.ZERO
var active_pointer := -1
var mouse_active := false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and active_pointer == -1 and get_global_rect().has_point(event.position):
            active_pointer = event.index
            _set_axis(event.position)
        elif not event.pressed and event.index == active_pointer:
            active_pointer = -1
            _release()
    elif event is InputEventScreenDrag and event.index == active_pointer:
        _set_axis(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and get_global_rect().has_point(event.position):
            mouse_active = true
            _set_axis(event.position)
        elif not event.pressed and mouse_active:
            mouse_active = false
            _release()
    elif event is InputEventMouseMotion and mouse_active:
        _set_axis(event.position)

func _set_axis(screen_position: Vector2) -> void:
    var center := global_position + size * 0.5
    axis = ((screen_position - center) / (size.x * 0.40)).limit_length(1.0)
    axis_changed.emit(axis.x, axis.y)
    queue_redraw()

func _release() -> void:
    axis = Vector2.ZERO
    axis_changed.emit(0.0, 0.0)
    queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    var radius := size.x * 0.41
    draw_circle(center, radius + 8.0, Color(0.01, 0.025, 0.04, 0.48))
    draw_arc(center, radius, 0.0, TAU, 64, Color(0.52, 0.86, 1.0, 0.65), 3.0, true)
    draw_circle(center, radius * 0.48, Color(0.45, 0.8, 0.98, 0.13))
    var knob := center + axis * radius
    draw_circle(knob, 37.0, Color(0.05, 0.13, 0.2, 0.9))
    draw_arc(knob, 35.0, 0.0, TAU, 48, Color(0.85, 0.95, 1.0, 0.85), 3.0, true)
