extends RefCounted
class_name RaceInputBindings

# Runtime additions preserve the uploaded project.godot verbatim.
static func install() -> void:
    # Keep every authored key binding and add an all-device copy where necessary.
    # Android physical keyboard device IDs can change after reconnecting or docking.
    for action in ["accelerate","brake","left","right","boost","drift"]:
        for event in InputMap.action_get_events(action):
            if event is InputEventKey and event.device != -1:
                var portable := event.duplicate() as InputEventKey
                portable.device = -1
                if not _has_key(action,portable.physical_keycode):
                    InputMap.action_add_event(action,portable)
    _axis("pad_left",JOY_AXIS_LEFT_X,-1,0.18)
    _axis("pad_right",JOY_AXIS_LEFT_X,1,0.18)
    _axis("pad_accelerate",JOY_AXIS_TRIGGER_RIGHT,1,0.08)
    _axis("pad_brake",JOY_AXIS_TRIGGER_LEFT,1,0.08)
    _button("pad_left",JOY_BUTTON_DPAD_LEFT)
    _button("pad_right",JOY_BUTTON_DPAD_RIGHT)
    _button("pad_accelerate",JOY_BUTTON_RIGHT_SHOULDER)
    _button("pad_brake",JOY_BUTTON_LEFT_SHOULDER)
    _button("boost",JOY_BUTTON_A)
    _button("drift",JOY_BUTTON_X)
    _button("race_menu",JOY_BUTTON_START)
    _button("race_retry",JOY_BUTTON_Y)
    _button("race_craft",JOY_BUTTON_BACK)
    _button("race_back",JOY_BUTTON_B)
    Input.use_accumulated_input = false

static func _has_key(action: String, physical: int) -> bool:
    for event in InputMap.action_get_events(action):
        if event is InputEventKey and event.device == -1 and event.physical_keycode == physical:
            return true
    return false

static func _axis(action: String, axis: int, value: float, deadzone: float) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action,deadzone)
    var event := InputEventJoypadMotion.new()
    event.device = -1
    event.axis = axis
    event.axis_value = value
    if not InputMap.action_has_event(action,event):
        InputMap.action_add_event(action,event)

static func _button(action: String, button: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var event := InputEventJoypadButton.new()
    event.device = -1
    event.button_index = button
    if not InputMap.action_has_event(action,event):
        InputMap.action_add_event(action,event)

static func release_pad() -> void:
    for action in ["pad_left","pad_right","pad_accelerate","pad_brake","boost","drift"]:
        Input.action_release(action)
