extends CharacterBody3D
class_name HoverShip

signal hit_wall

const CRAFT := [
    {"name":"VECTOR", "color":Color(0.0, 0.95, 1.0), "speed":62.0, "turn":2.25, "accel":48.0},
    {"name":"RAPTOR", "color":Color(1.0, 0.25, 0.65), "speed":78.0, "turn":1.75, "accel":43.0},
    {"name":"COMET", "color":Color(1.0, 0.77, 0.12), "speed":53.0, "turn":2.9, "accel":58.0}
]

var craft_index := 0
var heading := 0.0
var forward_speed := 0.0
var side_speed := 0.0
var boost_fuel := 70.0
var input_accel := false
var input_brake := false
var input_left := false
var input_right := false
var input_boost := false
var input_drift := false
var steer_axis := 0.0
var drive_axis := 0.0
var surface_factor := 1.0
var steering_actual := 0.0
var hover_time := 0.0
var human_controlled := true
var mouse_steer_axis := 0.0
var visuals: Node3D
var engine_glow: MeshInstance3D
var engine_light: OmniLight3D

func _ready() -> void:
    collision_layer = 2 if human_controlled else 4
    collision_mask = 7
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(2.8, 1.0, 5.0)
    shape.shape = box
    add_child(shape)
    visuals = Node3D.new()
    add_child(visuals)
    engine_light = OmniLight3D.new()
    engine_light.position = Vector3(0, 0, 2.8)
    engine_light.omni_range = 8.0
    engine_light.light_energy = 0.8
    engine_light.shadow_enabled = false
    add_child(engine_light)
    _rebuild_visuals()

func _physics_process(delta: float) -> void:
    var stats: Dictionary = CRAFT[craft_index]
    var pad_steer := Input.get_axis("pad_left","pad_right") if human_controlled else 0.0
    var steer := clampf(steer_axis + mouse_steer_axis + pad_steer + float(int(input_right or (human_controlled and Input.is_action_pressed("right"))) - int(input_left or (human_controlled and Input.is_action_pressed("left")))), -0.8, 0.8)
    steering_actual = move_toward(steering_actual,steer,delta*6.0)
    steer = steering_actual
    var throttle_amount := maxf(maxf(float(input_accel or (human_controlled and (Input.is_action_pressed("accelerate") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)))),maxf(0.0,-drive_axis)),Input.get_action_strength("pad_accelerate") if human_controlled else 0.0)
    var throttle := throttle_amount > 0.01
    var brake_amount := maxf(maxf(float(input_brake or (human_controlled and (Input.is_action_pressed("brake") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)))),maxf(0.0,drive_axis)),Input.get_action_strength("pad_brake") if human_controlled else 0.0)
    var braking := brake_amount > 0.01
    var drifting := input_drift or (human_controlled and Input.is_action_pressed("drift"))
    var boosting := (input_boost or (human_controlled and (Input.is_action_pressed("boost") or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)))) and throttle and boost_fuel > 0.0
    var speed_cap: float = stats.speed * (1.52 if boosting else 1.0) * surface_factor
    if boosting:
        boost_fuel = maxf(0.0, boost_fuel - 33.0 * delta)
    else:
        boost_fuel = minf(100.0, boost_fuel + (17.0 if absf(forward_speed) > 10.0 else 10.0) * delta)
    if braking:
        forward_speed = move_toward(forward_speed, 0.0 if throttle else -18.0, 88.0 * brake_amount * delta)
    elif throttle:
        forward_speed = move_toward(forward_speed, speed_cap, (stats.accel + (27.0 if boosting else 0.0)) * throttle_amount * delta)
    else:
        forward_speed = move_toward(forward_speed, 0.0, 16.0 * delta)
    var steer_scale := clampf(absf(forward_speed) / 25.0, 0.15, 1.0)
    heading -= steer * stats.turn * steer_scale * (1.35 if drifting else 1.0) * delta * (1.0 if forward_speed >= 0.0 else -1.0)
    rotation.y = heading
    var desired_side := -steer * forward_speed * (0.30 if drifting else 0.02)
    side_speed = move_toward(side_speed, desired_side, (25.0 if drifting else 48.0) * delta)
    var forward := Vector3(-sin(heading), 0.0, -cos(heading))
    var right_axis := Vector3(cos(heading), 0.0, -sin(heading))
    velocity = forward * forward_speed + right_axis * side_speed
    move_and_slide()
    if get_slide_collision_count() > 0:
        var impact := 0.0
        for i in get_slide_collision_count():
            var normal := get_slide_collision(i).get_normal()
            impact = maxf(impact,-forward.dot(normal))
        forward_speed *= 1.0-clampf(impact,0.0,1.0)*0.24
        hit_wall.emit()
    # Keep the collision body and camera anchor level; bob only the hull.
    position.y = 2.15
    hover_time += delta
    visuals.position.y = sin(hover_time * 3.0) * 0.055
    visuals.rotation.z = lerpf(visuals.rotation.z, -steer * (0.22 if drifting else 0.12), delta * 5.0)
    visuals.rotation.x = lerpf(visuals.rotation.x, (0.12 if braking else -0.05 if boosting else 0.0), delta * 4.0)
    engine_glow.scale = Vector3(1.0, 1.0, 1.45 if boosting else 0.8)
    engine_light.light_energy = 1.55 if boosting else 0.8

func select_craft(index: int) -> void:
    craft_index = posmod(index, CRAFT.size())
    forward_speed *= 0.82
    boost_fuel = 100.0
    steering_actual = 0.0
    reset_physics_interpolation()
    if visuals != null:
        _rebuild_visuals()
        visuals.reset_physics_interpolation()
        engine_light.light_color = CRAFT[craft_index].color

func reset_to(location: Vector3, angle: float) -> void:
    global_position = location
    heading = angle
    rotation.y = heading
    forward_speed = 0.0
    side_speed = 0.0
    velocity = Vector3.ZERO
    boost_fuel = 100.0
    steering_actual = 0.0
    get_global_transform_interpolated()
    reset_physics_interpolation()

func _material(color: Color, glow := false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.55
    mat.roughness = 0.3
    if glow:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 2.0
    return mat

func _part(mesh: Mesh, offset: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = offset
    parent.add_child(instance)
    return instance

func _box(size: Vector3) -> BoxMesh:
    var mesh := BoxMesh.new()
    mesh.size = size
    return mesh

func _rebuild_visuals() -> void:
    for child in visuals.get_children():
        child.queue_free()
    var color: Color = CRAFT[craft_index].color
    var hull := _material(Color(0.08, 0.12, 0.2))
    var trim := _material(color, true)
    var canopy := _material(Color(0.1, 0.42, 0.58))
    _part(_box(Vector3(2.2, 0.65, 4.3)), Vector3.ZERO, hull, visuals)
    _part(_box(Vector3(1.3, 0.5, 1.7)), Vector3(0, 0.55, -0.45), canopy, visuals)
    _part(_box(Vector3(5.2, 0.2, 1.35)), Vector3(0, -0.08, 0.65), hull, visuals)
    _part(_box(Vector3(0.16, 0.1, 3.8)), Vector3(-1.5, 0.0, 0.3), trim, visuals)
    _part(_box(Vector3(0.16, 0.1, 3.8)), Vector3(1.5, 0.0, 0.3), trim, visuals)
    _part(_box(Vector3(0.45, 0.1, 1.2)), Vector3(0, 0.38, -1.7), trim, visuals)
    engine_glow = _part(_box(Vector3(1.6, 0.18, 0.4)), Vector3(0, -0.15, 2.35), trim, visuals)
    engine_light.light_color = color
    var optional_asset := "res://assets/ship_%d.glb" % craft_index
    if ResourceLoader.exists(optional_asset):
        for child in visuals.get_children():
            child.visible = false
        var packed := load(optional_asset) as PackedScene
        if packed != null:
            var custom := packed.instantiate()
            visuals.add_child(custom)
