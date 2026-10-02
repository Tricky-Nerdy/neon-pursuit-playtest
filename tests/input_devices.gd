extends SceneTree
var game
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, name: String) -> void:
    checks += 1
    print("PASS " if ok else "FAIL ",name)
    if not ok: failures += 1
func key(code: int, down: bool, device := 0) -> void:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.keycode = code
    event.device = device
    event.pressed = down
    Input.parse_input_event(event)
func axis(code: int, value: float) -> void:
    var event := InputEventJoypadMotion.new()
    event.axis = code
    event.axis_value = value
    event.device = 0
    Input.parse_input_event(event)
func button(code: int, down: bool) -> void:
    var event := InputEventJoypadButton.new()
    event.button_index = code
    event.device = 0
    event.pressed = down
    Input.parse_input_event(event)
func settle(frames := 1) -> void:
    for i in frames: await physics_frame
func _run() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    game.save_path = "user://input_device_test.cfg"
    game.telemetry.path = "user://input_device_test.log"
    root.add_child(game)
    await settle()
    game._select_mode(0)
    for brain in game.brains: brain.active = false
    for rival in game.traffic: rival.set_physics_process(false)
    var current_settings := FileAccess.get_file_as_string("res://project.godot")
    var uploaded_settings := FileAccess.get_file_as_string("res://docs/merge/uploaded_project.godot.txt")
    # Releases may change version metadata; the live-camera plugin adds one
    # editor-only section. Keep all uploaded gameplay/input/display settings exact.
    var version_lines := RegEx.new()
    version_lines.compile("(?m)^config/(version|map_version)=.*\\n")
    current_settings = version_lines.sub(current_settings, "", true)
    uploaded_settings = version_lines.sub(uploaded_settings, "", true)
    current_settings = current_settings.replace('[editor_plugins]\\n\\nenabled=PackedStringArray("res://addons/live_editor_camera/plugin.cfg")\\n\\n', "")
    check(current_settings == uploaded_settings, "uploaded gameplay settings preserved with explicit version and editor-plugin exceptions")
    check(not Input.use_accumulated_input,"input events are not accumulated until the render frame")
    check(game.player.CRAFT[0].speed == 62 and game.player.CRAFT[1].speed == 78 and game.player.CRAFT[2].speed == 53,"all three user craft speeds retained")
    game.touch_active = true
    game._refresh_touch_controls()
    var visible_controls := 0
    for item in game.driving_buttons:
        if item.visible: visible_controls += 1
    check(visible_controls == 1 and game.touch_layout == "compact","user compact touch layout remains the default")
    game._cycle_touch_layout()
    visible_controls = 0
    for item in game.driving_buttons:
        if item.visible: visible_controls += 1
    check(visible_controls == 4,"full touch layout is available as an explicit option")
    key(KEY_W,true,0)
    await settle(10)
    check(game.player.forward_speed > 3,"ordinary PC keyboard device zero accelerates physically")
    check(not game.virtual_stick.visible,"keyboard use hides touch driving controls")
    key(KEY_W,false,0)
    key(KEY_W,true,7)
    await settle()
    check(Input.is_action_pressed("accelerate"),"different docked keyboard device IDs still work")
    key(KEY_W,false,7)
    game.player.mouse_steer_axis = 0
    var mouse_throttle := InputEventMouseButton.new()
    mouse_throttle.button_index = MOUSE_BUTTON_LEFT
    mouse_throttle.pressed = true
    Input.parse_input_event(mouse_throttle)
    var mouse_motion := InputEventMouseMotion.new()
    mouse_motion.relative = Vector2(35,0)
    game._input(mouse_motion)
    check(game.player.mouse_steer_axis > 0,"mouse drag steers right while left button drives")
    await settle(10)
    check(game.player.forward_speed > 1,"mouse left button accelerates")
    mouse_throttle.pressed = false
    Input.parse_input_event(mouse_throttle)
    game.player.reset_to(game.coast.sample(0),game.coast.heading_at(0))
    axis(JOY_AXIS_LEFT_X,0.1)
    await settle()
    check(is_zero_approx(Input.get_axis("pad_left","pad_right")),"small stick noise stays inside the deadzone")
    axis(JOY_AXIS_LEFT_X,0.5)
    await settle()
    var half: float = Input.get_axis("pad_left","pad_right")
    check(half > 0.1 and half < 0.6,"partial stick input remains analog")
    axis(JOY_AXIS_LEFT_X,-1.0)
    await settle()
    check(Input.get_axis("pad_left","pad_right") < -0.9,"left stick direction is correct")
    axis(JOY_AXIS_LEFT_X,0)
    Input.action_press("pad_accelerate",0.5)
    var partial_strength := Input.get_action_strength("pad_accelerate")
    check(partial_strength > 0.4 and partial_strength < 0.6,"controller trigger preserves half throttle")
    Input.action_release("pad_accelerate")
    Input.action_press("pad_accelerate",1.0)
    check(Input.get_action_strength("pad_accelerate") > partial_strength*1.5,"full trigger provides full acceleration")
    Input.action_press("pad_brake",1.0)
    check(Input.get_action_strength("pad_brake") > 0.9,"left trigger provides analog braking")
    Input.action_release("accelerate")
    Input.action_release("pad_accelerate")
    Input.action_release("pad_brake")
    game._set_hud_visible(false)
    game.player.mouse_steer_axis = 0.0
    game.player.reset_to(game.coast.sample(400),game.coast.heading_at(400))
    game.player.surface_factor = 1.0
    game.player.drive_axis = -0.5
    await settle(20)
    var partial_speed: float = game.player.forward_speed
    check(partial_speed > 0.2 and partial_speed < 10,"analog steering throttle accelerates the actual ship")
    game.player.drive_axis = -1.0
    await settle(20)
    check(game.player.forward_speed > partial_speed*1.5,"full analog throttle accelerates more than half throttle")
    game.player.drive_axis = 0
    game.player.forward_speed = 50
    game.player.input_brake = true
    await settle(20)
    check(game.player.forward_speed < 40,"left trigger brake slows the actual ship")
    game.player.input_brake = false
    Input.action_release("pad_brake")
    Input.action_release("pad_accelerate")
    button(JOY_BUTTON_A,true)
    await settle()
    check(Input.is_action_pressed("boost"),"south face button activates boost")
    button(JOY_BUTTON_A,false)
    button(JOY_BUTTON_X,true)
    await settle()
    check(Input.is_action_pressed("drift"),"west face button activates drift")
    button(JOY_BUTTON_X,false)
    axis(JOY_AXIS_TRIGGER_RIGHT,0)
    game._set_hud_visible(false)
    var start_event := InputEventJoypadButton.new()
    start_event.button_index = JOY_BUTTON_START
    start_event.device = 0
    start_event.pressed = true
    game._input(start_event)
    await settle()
    check(game.hud_visible and not game.player.is_physics_processing(),"controller Start opens menu and pauses driving")
    check(game.resume_button.visible and game.resume_button.focus_mode == Control.FOCUS_ALL,"menu opens with a visible focusable Resume button")
    var rect: Rect2 = game.menu.get_global_rect()
    game._layout_menu(Vector2(853,480))
    rect = game.menu.get_global_rect()
    check(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 853 and rect.end.y <= 480,"menu fits the user's scaled 720p viewport")
    button(JOY_BUTTON_START,false)
    button(JOY_BUTTON_B,true)
    await settle()
    check(not game.hud_visible and game.player.is_physics_processing(),"controller Back closes menu and resumes")
    button(JOY_BUTTON_B,false)
    button(JOY_BUTTON_BACK,true)
    await settle()
    check(game.player.craft_index == 1,"controller View/Select hot-swaps the craft")
    button(JOY_BUTTON_BACK,false)
    axis(JOY_AXIS_TRIGGER_RIGHT,1)
    await settle()
    game._on_joy_connection_changed(0,false)
    check(game.hud_visible and is_zero_approx(Input.get_action_strength("pad_accelerate")),"controller disconnect clears throttle and pauses")
    game._layout_menu(Vector2(640,360))
    var scaled_rect := Rect2(game.menu.position,game.menu.size*game.menu.scale)
    check(Rect2(Vector2.ZERO,Vector2(640,360)).encloses(scaled_rect),"menu remains usable at a small cast window size")
    game._set_hud_visible(false)
    game._select_mode(1)
    button(JOY_BUTTON_Y,true)
    await settle()
    check(game.event_active and game.event_time < 0.1,"controller north button retries instantly")
    button(JOY_BUTTON_Y,false)
    # Generic shoulder fallback for controllers without analog triggers.
    button(JOY_BUTTON_RIGHT_SHOULDER,true)
    await settle()
    check(Input.get_action_strength("pad_accelerate") > 0.9,"right shoulder provides a digital throttle fallback")
    button(JOY_BUTTON_RIGHT_SHOULDER,false)
    print("RESULT %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
