@tool
extends EditorPlugin

const Flight = preload("res://addons/live_editor_camera/flight.gd")
var flight = Flight.new()
var toolbar: HBoxContainer
var fly_button: Button
var follow_button: Button
var active := false
var looking := false
var viewport: SubViewport
var native_camera: Camera3D
var camera_rid := RID()

func _enter_tree() -> void:
	toolbar = HBoxContainer.new()
	fly_button = Button.new()
	fly_button.text = "Live fly camera"
	fly_button.toggle_mode = true
	fly_button.tooltip_text = "Main editor viewport: hold RMB + WASD, Q/E up/down, Shift fast, wheel speed, Escape exit."
	fly_button.toggled.connect(_set_active)
	toolbar.add_child(fly_button)
	var frame_button := Button.new()
	frame_button.text = "View racers"
	frame_button.pressed.connect(_frame_racer)
	toolbar.add_child(frame_button)
	follow_button = Button.new()
	follow_button.text = "Follow racer"
	follow_button.toggle_mode = true
	follow_button.toggled.connect(_follow_toggled)
	toolbar.add_child(follow_button)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, toolbar)
	set_input_event_forwarding_always_enabled()
	scene_changed.connect(_scene_changed)
	main_screen_changed.connect(_screen_changed)
	set_process(true)

func _exit_tree() -> void:
	_set_active(false)
	if is_instance_valid(toolbar):
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, toolbar)
		toolbar.queue_free()

func _scene_changed(_scene: Node) -> void:
	_set_active(false)

func _screen_changed(screen: String) -> void:
	if screen != "3D":
		_set_active(false)

func _racer() -> Node3D:
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		return null
	return scene.get_node_or_null("Vehicles/EditorRacer1") as Node3D

func _set_active(enabled: bool) -> void:
	if enabled == active:
		return
	if enabled:
		viewport = EditorInterface.get_editor_viewport_3d(0)
		native_camera = viewport.get_camera_3d() if is_instance_valid(viewport) else null
		if not is_instance_valid(native_camera) or _racer() == null:
			fly_button.set_pressed_no_signal(false)
			follow_button.set_pressed_no_signal(false)
			return
		flight.pose = native_camera.global_transform
		camera_rid = RenderingServer.camera_create()
		RenderingServer.camera_set_perspective(camera_rid, 75.0, 0.5, 12000.0)
		RenderingServer.camera_set_cull_mask(camera_rid, native_camera.cull_mask)
		active = true
		_present_camera()
	else:
		# Restore the native editor camera before freeing the temporary render camera.
		if is_instance_valid(viewport) and is_instance_valid(native_camera):
			RenderingServer.viewport_attach_camera(viewport.get_viewport_rid(), native_camera.get_camera_rid())
		if camera_rid.is_valid():
			RenderingServer.free_rid(camera_rid)
		camera_rid = RID()
		active = false
		looking = false
		viewport = null
		native_camera = null
		follow_button.set_pressed_no_signal(false)
	fly_button.set_pressed_no_signal(active)

func _present_camera() -> void:
	RenderingServer.camera_set_transform(camera_rid, flight.pose)
	RenderingServer.viewport_attach_camera(viewport.get_viewport_rid(), camera_rid)

func _frame_racer() -> void:
	_set_active(true)
	var racer := _racer()
	if active and is_instance_valid(racer):
		flight.frame_racer(racer)
		_present_camera()

func _follow_toggled(enabled: bool) -> void:
	if enabled:
		_frame_racer()
		if not active:
			follow_button.set_pressed_no_signal(false)

func _process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(viewport) or not is_instance_valid(native_camera) or _racer() == null:
		_set_active(false)
		return
	# Losing focus or releasing RMB outside the viewport must stop motion.
	looking = looking and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and DisplayServer.window_is_focused()
	if looking:
		var direction := Vector3(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		flight.move(direction, minf(delta, 0.1), Input.is_physical_key_pressed(KEY_SHIFT))
	elif follow_button.button_pressed:
		flight.frame_racer(_racer())
	_present_camera()

func _forward_3d_gui_input(editor_camera: Camera3D, event: InputEvent) -> int:
	if not active or editor_camera != native_camera:
		return AFTER_GUI_INPUT_PASS
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_set_active(false)
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			looking = event.pressed
			if looking:
				follow_button.set_pressed_no_signal(false)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			flight.speed = clampf(flight.speed * (1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), 5.0, 1000.0)
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion:
		if looking:
			flight.look(event.relative)
		return AFTER_GUI_INPUT_STOP
	if looking and event is InputEventKey:
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS
