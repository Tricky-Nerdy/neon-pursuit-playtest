extends Button
class_name TouchHoldButton

signal held_changed(active: bool)

var pointer_index := -1

func _input(event: InputEvent) -> void:
    if not is_visible_in_tree() or disabled:
        return
    if event is InputEventScreenTouch:
        if event.pressed and pointer_index == -1 and get_global_rect().has_point(event.position):
            pointer_index = event.index
            held_changed.emit(true)
        elif not event.pressed and event.index == pointer_index:
            pointer_index = -1
            held_changed.emit(false)

func _exit_tree() -> void:
    if pointer_index != -1:
        pointer_index = -1
        held_changed.emit(false)
