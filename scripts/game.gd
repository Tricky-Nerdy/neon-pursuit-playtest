extends Node3D
const InputBindings = preload("res://scripts/input_bindings.gd")

const ShipScene = preload("res://scenes/vehicles/hover_ship.tscn")
const TelemetryScript = preload("res://scripts/telemetry.gd")
const StickScript = preload("res://scripts/virtual_stick.gd")
const HoldScript = preload("res://scripts/touch_hold_button.gd")
const MapScript = preload("res://scripts/coast_map.gd")
const Rules = preload("res://scripts/mission_rules.gd")
const BrainScript = preload("res://scripts/race_brain.gd")
const MODES = Rules.NAMES
const DESCRIPTIONS = Rules.DETAILS
var brains: Array[RaceBrain] = []
var selected_route := 0
var active_route_index := 0
var active_route: Curve3D
var route_length := 1.0
var gate_spacing := 80.0
var player_progress := 0.0
var progress_offset := 0.0
var progress_delta := 0.0
var drift_pending := 0.0
var drift_goal := 2300.0
var drift_peak_progress := 0.0
var bank_timer := 0.0
var speed_traps_hit := 0
var speed_total := 0.0
var elimination_next := 20.0
var last_warning := 0
var route_button: Button
var level_button: Button
var selected_level := 0
var save_path := "user://progress.cfg"
var telemetry = TelemetryScript.new()
var player: HoverShip
var camera: Camera3D
var coast: CoastMap
var ui: Control
var menu: Panel
var title: Label
var details: Label
var center_notice: Label
var virtual_stick: VirtualStick
var driving_buttons: Array[Button] = []
var touch_layout := "compact"
var touch_active := false
var touch_option: Button
var resume_button: Button
var last_pad_device := -1
var hud_visible := false
var gate_visual: Node3D
var gate_text: Label3D
var guidance: Array[Node3D] = []
var traffic: Array[Node3D] = []
var rival_distances: Array[float] = []
var mode := 0
var last_mode := 1
var gate_index := 0
var passed := 0
var target_count := 0
var mission_level := 1
var event_time := 0.0
var event_start := Vector3.ZERO
var event_heading := 0.0
var event_offset := 0.0
var best_times: Dictionary = {}
var medals: Dictionary = {}
var rank_points := 0
var notice_timer := 0.0
var pursuit_heat := 0.0
var crash_cooldown := 0.0
var pad_cooldown := 0.0
var rush_time := 0.0
var drift_score := 0.0
var drift_combo := 1.0
var clean_time := 0.0
var last_result := ""
var race_position := 4
var previous_position := Vector3.ZERO
var event_active := false
var session_crashes := 0
var frame_samples := 0
var frame_total := 0.0
var vehicles_root: Node3D
var gameplay_root: Node3D
var ui_layer: CanvasLayer
var free_roam_spawn: Marker3D

func _ready() -> void:
    InputBindings.install()
    Input.joy_connection_changed.connect(_on_joy_connection_changed)
    # Update mission simulation after the ship's physics movement.
    process_physics_priority = 1
    telemetry.start()
    telemetry.record("INFO", "session_start", {"build":"Aurora Bay 4.1 / user merge", "godot":Engine.get_version_info().string})
    _load_progress()
    coast = get_node_or_null("World") as CoastMap
    if coast == null:
        coast = MapScript.new()
        coast.name = "World"
        add_child(coast)
    vehicles_root = get_node_or_null("Vehicles") as Node3D
    if vehicles_root == null:
        vehicles_root = self
    gameplay_root = get_node_or_null("Gameplay") as Node3D
    if gameplay_root == null:
        gameplay_root = self
    ui_layer = get_node_or_null("UI") as CanvasLayer
    var spawn_root := coast.get_node_or_null("FreeRoamSpawns")
    if spawn_root != null and spawn_root.get_child_count() > 0:
        free_roam_spawn = spawn_root.get_child(randi() % spawn_root.get_child_count()) as Marker3D
    player = ShipScene.instantiate()
    vehicles_root.add_child(player)
    if free_roam_spawn != null:
        player.reset_to(free_roam_spawn.global_position, free_roam_spawn.global_rotation.y)
    else:
        player.reset_to(coast.sample(0), coast.heading_at(0))
    previous_position = player.position
    player.hit_wall.connect(_on_hit_wall)
    camera = get_node_or_null("Camera") as Camera3D
    if camera == null:
        camera = Camera3D.new()
        camera.name = "Camera"
        camera.current = true
        camera.fov = 75
        camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
        add_child(camera)
    _make_rivals()
    _make_gate()
    _make_ui()
    active_route = coast.curve
    route_length = coast.length
    _start_patrols(true)
    _camera_follow(1.0)
    telemetry.record("INFO", "world_ready", {"route_meters":coast.length,"checkpoints":coast.route.size(),"landmarks":coast.landmark_count})

func _process(delta: float) -> void:
    if coast:
        coast.advance_day_night(delta)
    _camera_follow(delta)
    player.mouse_steer_axis = move_toward(player.mouse_steer_axis,0.0,delta*1.8)
    notice_timer = maxf(0.0,notice_timer-delta)
    center_notice.visible = notice_timer > 0
    if hud_visible:
        title.text = "AURORA BAY 4.1  /  %s" % _rank_name()
        details.text = "%s  •  %d RP  •  %s\n%s" % [MODES[mode],rank_points,HoverShip.CRAFT[player.craft_index].name,last_result if not event_active else _event_status()]
    frame_samples += 1
    frame_total += delta
    if frame_total >= 10:
        telemetry.record("INFO","performance",{"fps":roundi(frame_samples/frame_total),"position":str(player.position),"mode":mode})
        frame_total = 0
        frame_samples = 0

func _physics_process(delta: float) -> void:
    if hud_visible:
        return
    crash_cooldown = maxf(0.0,crash_cooldown-delta)
    pad_cooldown = maxf(0.0,pad_cooldown-delta)
    _move_traffic(delta)
    _update_pads()
    var off_road := coast.road_distance(player.position) > 78.0
    player.surface_factor = 0.55 if off_road else 1.0
    if not coast.is_driveable_land(player.position):
        var road_point := coast.closest_road_point(player.position)
        player.reset_to(road_point+Vector3.UP*2.15,player.heading)
        telemetry.record("INFO","coast_recovery",{})
    if event_active:
        _update_player_progress(delta)
        _update_event(delta)
    _update_gate()
    previous_position = player.position

func _event_status() -> String:
    if mode == 5:
        return "%d / %d  +%d unbanked  •  x%.1f  •  %.0fs" % [drift_score,drift_goal,drift_pending,drift_combo,maxf(0,60-event_time)]
    if mode == 4:
        return "ROUTE %d/%d  •  HEAT %d%%  •  CLEAR %.1f/6s" % [passed,target_count,pursuit_heat,clean_time]
    if mode == 3:
        return "%d/%d  •  %.1fs remaining" % [passed,target_count,rush_time]
    if mode == 6:
        return "PLACE %d  •  ELIMINATION IN %.0fs" % [race_position,maxf(0,elimination_next-event_time)]
    if mode == 7:
        return "TRAPS %d/6  •  TARGET %.0f KM/H" % [speed_traps_hit,Rules.speed_target(mission_level,passed)]
    return "%d/%d  •  %.1fs  •  PLACE %d" % [passed,target_count,event_time,race_position]

func _update_event(delta: float) -> void:
    event_time += delta
    _update_standings()
    if mode == 5:
        _update_drift(delta)
        return
    if mode == 6:
        if event_time >= elimination_next:
            _eliminate_last()
        return
    if mode == 3:
        rush_time -= delta
        if rush_time <= 0:
            _finish(false)
            return
    if mode == 4:
        var nearest := INF
        for rival in traffic:
            if rival.visible:
                nearest = minf(nearest,player.position.distance_to(rival.position))
        pursuit_heat = clampf(pursuit_heat+delta*(7.0 if nearest < 25 else -3.0 if nearest > 75 else 0.2),0,100)
        if pursuit_heat >= 100:
            _finish(false)
            return
        if passed >= target_count:
            if nearest > 100 and pursuit_heat < 25:
                clean_time += delta
            else:
                clean_time = 0
            if clean_time >= 6:
                _finish(true)
            return
    var gate := _gate_position()
    var nearest_point := Geometry3D.get_closest_point_to_segment(gate,previous_position,player.position)
    # Direction and progress prevent reverse crossings or donuts from scoring.
    var route_direction := (_route_sample(event_offset+gate_spacing*(passed+1)+5)-gate).normalized()
    var forward_crossing := (player.position-previous_position).dot(route_direction) > 0
    if nearest_point.distance_to(gate) < 24 and forward_crossing and player_progress > gate_spacing*(passed+1)-45:
        _pass_gate()
    if (mode == 1 or mode == 2) and event_active:
        var all_finished := true
        for brain in brains:
            if brain.active and not brain.finished:
                all_finished = false
        if all_finished:
            _finish(false)

func _unhandled_key_input(event: InputEvent) -> void:
    if not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_F3, KEY_ESCAPE:
            _toggle_hud()
        KEY_E, KEY_TAB:
            _next_mode()
        KEY_Q:
            _next_craft()
        KEY_R:
            _restart()
        KEY_F11:
            _toggle_fullscreen()

func _camera_follow(delta: float) -> void:
    var pose := player.get_global_transform_interpolated()
    var back := pose.basis.z.normalized()
    # Sample the same pose rendered for the ship. A positional lerp here
    # adds a speed-dependent gap and makes the ship move against the camera.
    camera.global_position = pose.origin + back*9.0 + Vector3.UP*4.2
    camera.look_at(pose.origin + Vector3.UP*1.1 - back*8.0,Vector3.UP)
    camera.fov = lerpf(camera.fov,68.0+clampf(player.forward_speed,0,150)*0.065,1.0-exp(-3.0*delta))

func _next_mode() -> void:
    _select_mode((mode+1)%MODES.size())

func _select_mode(index: int) -> void:
    mode = clampi(index,0,MODES.size()-1)
    _set_hud_visible(false)
    if mode == 0:
        event_active = false
        gate_visual.visible = false
        _start_patrols()
        _message("FREE ROAM")
        telemetry.record("INFO","mode_free_roam",{})
    else:
        last_mode = mode
        _begin_event()

func _begin_event() -> void:
    active_route_index = selected_route
    active_route = coast.circuits[active_route_index]
    route_length = active_route.get_baked_length()
    event_offset = active_route.get_closest_offset(Vector3(player.position.x,0,player.position.z))
    var start_point := _route_sample(event_offset)
    if start_point.distance_to(player.position) > 50:
        player.reset_to(start_point,_route_heading(event_offset))
    elif absf(player.forward_speed) < 4:
        player.reset_to(player.position,_route_heading(event_offset))
    event_start = player.position
    event_heading = player.heading
    previous_position = player.position
    progress_offset = event_offset
    player_progress = 0
    progress_delta = 0
    gate_index = 0
    event_time = 0
    passed = 0
    pursuit_heat = 0
    clean_time = 0
    drift_score = 0
    drift_pending = 0
    drift_peak_progress = 0
    drift_combo = 1
    bank_timer = 0
    speed_traps_hit = 0
    speed_total = 0
    elimination_next = 20
    last_warning = 0
    var unlocked := mini(5,1+rank_points/350)
    mission_level = unlocked if selected_level == 0 else clampi(selected_level,1,unlocked)
    gate_spacing = route_length/maxi(8,ceili(route_length/105.0))
    if mode == 7:
        gate_spacing = route_length/8
    target_count = Rules.gate_count(mode,route_length)
    rush_time = 6.0+Rules.checkpoint_seconds(gate_spacing,mission_level)
    drift_goal = Rules.drift_target(route_length,mission_level)
    event_active = true
    race_position = 1
    for i in traffic.size():
        var job := "police" if mode == 4 else "race"
        var start_gap := -18.0-i*17
        if mode == 6:
            start_gap = 12.0+i*10
        var location := _route_sample(event_offset+start_gap)
        var angle := _route_heading(event_offset+start_gap)
        location += Vector3(cos(angle),0,-sin(angle))*(i-1.5)*3.0
        traffic[i].reset_to(location,angle)
        brains[i].begin(active_route,event_offset+start_gap,job,mission_level)
        brains[i].progress = start_gap
        brains[i].last_seen = player.position
        var enabled := mode == 2 or mode == 4 or mode == 6 or (mode == 1 and i < 2)
        brains[i].active = enabled
        traffic[i].visible = enabled
        traffic[i].set_physics_process(enabled)
        traffic[i].collision_layer = 4 if enabled else 0
        traffic[i].get_node("PoliceLights").visible = mode == 4
        rival_distances[i] = start_gap
    _message(MODES[mode]+" / "+coast.circuit_names[active_route_index],1.2)
    telemetry.record("INFO","event_start",{"mode":MODES[mode],"route":coast.circuit_names[active_route_index],"level":mission_level,"target":target_count})

func _pass_gate() -> void:
    if not event_active or passed >= target_count:
        return
    if mode == 7:
        var speed := absf(player.forward_speed)*3.6
        speed_total += speed
        if speed >= Rules.speed_target(mission_level,passed):
            speed_traps_hit += 1
            _message("%.0f KM/H  /  HIT" % speed,0.8)
        else:
            _message("%.0f KM/H  /  BOOST EARLIER" % speed,0.8)
    passed += 1
    gate_index = passed
    player.boost_fuel = minf(100,player.boost_fuel+8)
    if mode == 3:
        rush_time += Rules.checkpoint_seconds(gate_spacing,mission_level)
    if mode == 4:
        pursuit_heat = maxf(0,pursuit_heat-5)
    telemetry.record("INFO","gate",{"passed":passed,"time":event_time})
    if passed >= target_count:
        if mode == 4:
            _message("ROUTE CLEAR / LOSE THE TAIL",2)
        else:
            _finish(speed_traps_hit >= 4 if mode == 7 else true)

func _finish(success: bool) -> void:
    if not event_active:
        return
    var finished_mode := mode
    var medal := 0
    var rp := 0
    if success:
        if mode == 1 or mode == 2:
            race_position = 1
            for brain in brains:
                if brain.active and brain.finished:
                    race_position += 1
        medal = Rules.medal(mode,event_time,gate_spacing*target_count,race_position,drift_score,drift_goal,pursuit_heat,speed_traps_hit)
        rp = 60+medal*40+mission_level*15
        rank_points += rp
        var key := "%s:%s:%d" % [MODES[mode],coast.circuit_names[active_route_index],mission_level]
        medals[key] = maxi(int(medals.get(key,0)),medal)
        var record_value := drift_score if mode == 5 else speed_total if mode == 7 else event_time
        if mode == 5 or mode == 7:
            best_times[key] = maxf(float(best_times.get(key,0)),record_value)
        else:
            best_times[key] = minf(float(best_times.get(key,INF)),record_value)
        _save_progress()
        last_result = "%s  •  +%d RP  •  %.1fs" % [["","BRONZE","SILVER","GOLD"][medal],rp,event_time]
        _message(last_result,3)
        telemetry.record("INFO","event_finish",{"mode":MODES[mode],"route":active_route_index,"seconds":event_time,"medal":medal,"rp":rp})
    else:
        last_result = "INTERCEPTED" if mode == 4 else "ELIMINATED" if mode == 6 else "TARGET MISSED" if mode == 7 or mode == 5 else "TIME UP" if mode == 3 else "RIVALS FINISHED"
        _message(last_result+" / RETRY IN MENU",2.5)
        telemetry.record("WARN","event_failed",{"mode":MODES[mode],"route":active_route_index,"seconds":event_time})
    event_active = false
    last_mode = finished_mode
    mode = 0
    gate_visual.visible = false
    _start_patrols()

func _restart() -> void:
    _set_hud_visible(false)
    mode = last_mode
    selected_route = active_route_index
    player.reset_to(event_start if event_start != Vector3.ZERO else coast.sample(0),event_heading if event_start != Vector3.ZERO else coast.heading_at(0))
    _begin_event()
    telemetry.record("INFO","event_restart",{"mode":mode})

func _next_craft() -> void:
    player.select_craft(player.craft_index+1)
    _message(HoverShip.CRAFT[player.craft_index].name)
    telemetry.record("INFO","craft_swap",{"craft":player.craft_index})

func _rank_name() -> String:
    return "LEGEND" if rank_points >= 2800 else "ACE" if rank_points >= 1300 else "ELITE" if rank_points >= 500 else "RACER" if rank_points >= 150 else "ROOKIE"

func _on_hit_wall() -> void:
    if crash_cooldown > 0:
        return
    crash_cooldown = 0.6
    drift_combo = 1
    drift_pending = 0
    session_crashes += 1
    if mode == 4:
        pursuit_heat = minf(100,pursuit_heat+12)
    telemetry.record("WARN","wall_hit",{"position":str(player.position),"speed":player.forward_speed})

func _save_progress() -> void:
    var config := ConfigFile.new()
    config.set_value("player","rank_points",rank_points)
    config.set_value("player","best_times",best_times)
    config.set_value("player","medals",medals)
    var error := config.save(save_path)
    telemetry.record("INFO" if error == OK else "ERROR","progress_saved",{"code":error,"rank_points":rank_points})

func _load_progress() -> void:
    var config := ConfigFile.new()
    if config.load(save_path) == OK:
        rank_points = int(config.get_value("player","rank_points",0))
        best_times = config.get_value("player","best_times",{})
        medals = config.get_value("player","medals",{})

func _make_rivals() -> void:
    for i in 4:
        var rival := ShipScene.instantiate()
        rival.human_controlled = false
        rival.craft_index = i%3
        vehicles_root.add_child(rival)
        rival.visible = false
        var strobes := Node3D.new()
        strobes.name = "PoliceLights"
        rival.add_child(strobes)
        for side in [-1,1]:
            var light_mesh := MeshInstance3D.new()
            var box := BoxMesh.new()
            box.size = Vector3(0.65,0.16,1.2)
            light_mesh.mesh = box
            light_mesh.position = Vector3(side*1.3,0.48,0.3)
            light_mesh.material_override = coast.material(Color(1,0.025,0.035) if side < 0 else Color(0.025,0.2,1),true)
            strobes.add_child(light_mesh)
        var brain := BrainScript.new()
        brain.setup(rival,coast,i)
        brains.append(brain)
        traffic.append(rival)
        rival_distances.append(0)

func _move_traffic(delta: float) -> void:
    for i in traffic.size():
        var brain := brains[i]
        if not brain.active:
            continue
        brain.tick(delta,traffic,player)
        if brain.role == "police":
            var strobes := traffic[i].get_node("PoliceLights")
            for side in 2:
                strobes.get_child(side).visible = (int(event_time*7)+side)%2 == 0
        rival_distances[i] = brain.progress
        if event_active and (mode == 1 or mode == 2) and not brain.finished and brain.progress >= gate_spacing*target_count:
            brain.finished = true
            brain.finish_time = event_time
            telemetry.record("INFO","rival_finish",{"driver":RaceBrain.PROFILES[i].name,"seconds":event_time})
        if brain.state != brain.last_state:
            telemetry.record("INFO","ai_state",{"driver":i,"from":brain.last_state,"to":brain.state})
            brain.last_state = brain.state
        if event_active and mode == 4 and player.position.distance_to(traffic[i].position) < 7 and crash_cooldown <= 0:
            pursuit_heat = minf(100,pursuit_heat+15)
            crash_cooldown = 1
            telemetry.record("WARN","pursuit_contact",{"heat":pursuit_heat})
        if brain.contact_cooldown <= 0:
            for pad in coast.boost_pads:
                if traffic[i].position.distance_to(pad) < 10:
                    traffic[i].boost_fuel = minf(100,traffic[i].boost_fuel+45)
                    brain.contact_cooldown = 1.5
                    break

func _update_pads() -> void:
    if pad_cooldown > 0:
        return
    for pad in coast.boost_pads:
        if player.position.distance_to(pad) < 10:
            player.boost_fuel = minf(100,player.boost_fuel+45)
            player.forward_speed = maxf(player.forward_speed,100)
            pad_cooldown = 1.5
            telemetry.record("INFO","boost_pad",{})
            break

func _make_gate() -> void:
    gate_visual = Node3D.new()
    gameplay_root.add_child(gate_visual)
    for position_value in [Vector3(-22,5,0),Vector3(22,5,0),Vector3(0,12,0)]:
        var node := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(0.6,14,0.6) if position_value.x != 0 else Vector3(45,0.6,0.6)
        node.mesh = mesh
        node.position = position_value
        node.material_override = coast.material(Color(0.06,1,0.7),true)
        gate_visual.add_child(node)
    gate_text = Label3D.new()
    gate_text.font_size = 72
    gate_text.pixel_size = 0.05
    gate_text.position.y = 15
    gate_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    gate_visual.add_child(gate_text)
    gate_visual.visible = false
    var arrow_mesh := ArrayMesh.new()
    var vertices := PackedVector3Array([Vector3(-3,0,2),Vector3(0,0,-2),Vector3(-1,0,2),Vector3(1,0,2),Vector3(0,0,-2),Vector3(3,0,2)])
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    var normals := PackedVector3Array()
    for i in vertices.size():
        normals.append(Vector3.UP)
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    var arrow_material := coast.material(Color(0.25,0.85,0.75),true).duplicate() as StandardMaterial3D
    arrow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    for i in 6:
        var marker := MeshInstance3D.new()
        marker.mesh = arrow_mesh
        marker.material_override = arrow_material
        marker.visible = false
        marker.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
        gameplay_root.add_child(marker)
        guidance.append(marker)

func _update_gate() -> void:
    for i in guidance.size():
        guidance[i].visible = event_active
        if event_active:
            var offset := floorf(progress_offset/17.0)*17+18+i*17
            guidance[i].position = _route_sample(offset)
            guidance[i].position.y = 0.24
            guidance[i].rotation.y = _route_heading(offset)
    gate_visual.visible = event_active and mode != 5 and mode != 6 and passed < target_count
    if not gate_visual.visible:
        return
    var next_gate := _gate_position()
    var changed := gate_visual.position.distance_to(next_gate) > 10
    gate_visual.position = next_gate
    gate_visual.rotation.y = _route_heading(event_offset+gate_spacing*(passed+1))
    if changed:
        gate_visual.reset_physics_interpolation()
    gate_text.text = "%.0f KM/H" % Rules.speed_target(mission_level,passed) if mode == 7 else "%d / %d" % [passed+1,target_count]

func _make_ui() -> void:
    if ui_layer == null:
        ui_layer = CanvasLayer.new()
        ui_layer.name = "UI"
        add_child(ui_layer)
    ui = Control.new()
    ui.name = "RuntimeUI"
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_layer.add_child(ui)
    virtual_stick = StickScript.new()
    virtual_stick.size = Vector2(205,205)
    virtual_stick.position = Vector2(24,-226)
    virtual_stick.anchor_top = 1
    virtual_stick.anchor_bottom = 1
    virtual_stick.axis_changed.connect(func(steer: float, drive: float) -> void:
        player.steer_axis = steer
        player.drive_axis = drive
    )
    ui.add_child(virtual_stick)
    _hold("DRIFT",Vector2(-382,-114),Vector2(98,88),"input_drift")
    _hold("BRAKE",Vector2(-275,-114),Vector2(98,88),"input_brake")
    _hold("BOOST",Vector2(-275,-211),Vector2(98,88),"input_boost")
    _hold("GO",Vector2(-165,-166),Vector2(142,140),"input_accel")
    var menu_button := _button("≡",Vector2(-28,-66),Vector2(56,48),_toggle_hud,ui)
    menu_button.anchor_left = 0.5
    menu_button.anchor_right = 0.5
    menu_button.anchor_top = 1
    menu_button.anchor_bottom = 1
    menu = Panel.new()
    menu.size = Vector2(860,620)
    menu.position = Vector2(-430,-318)
    menu.anchor_left = 0.5
    menu.anchor_right = 0.5
    menu.anchor_top = 0.5
    menu.anchor_bottom = 0.5
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.025,0.07,0.1,0.97)
    panel_style.set_corner_radius_all(22)
    panel_style.border_color = Color(0.13,0.65,0.7)
    panel_style.set_border_width_all(2)
    menu.add_theme_stylebox_override("panel",panel_style)
    ui.add_child(menu)
    title = _label(menu,"AURORA BAY",Vector2(28,22),28)
    details = _label(menu,"",Vector2(28,65),18)
    _button("×",Vector2(780,18),Vector2(54,46),_toggle_hud,menu)
    route_button = _button("ROUTE: COAST",Vector2(28,114),Vector2(548,40),_cycle_route,menu)
    level_button = _button("LEVEL: AUTO",Vector2(592,114),Vector2(240,40),_cycle_level,menu)
    for index in 8:
        var row := index/2
        var column := index%2
        var point := Vector2(28+column*412,166+row*82)
        _button(MODES[index],point,Vector2(384,48),func() -> void: _select_mode(index),menu)
        var info := _label(menu,DESCRIPTIONS[index],point+Vector2(2,52),13)
        info.modulate = Color(0.65,0.8,0.84)
    _button("SWAP CRAFT",Vector2(28,536),Vector2(230,52),_next_craft,menu)
    _button("RETRY",Vector2(280,536),Vector2(230,52),_restart,menu)
    resume_button = _button("RESUME",Vector2(532,536),Vector2(300,52),_toggle_hud,menu)
    touch_option = _button("TOUCH: COMPACT",Vector2(28,593),Vector2(250,24),_cycle_touch_layout,menu)
    touch_option.add_theme_font_size_override("font_size",15)
    _label(menu,"F3 / START: MENU   •   F11: FULLSCREEN",Vector2(308,597),13)
    center_notice = _label(ui,"",Vector2(-400,-315),25)
    center_notice.anchor_left = 0.5
    center_notice.anchor_right = 0.5
    center_notice.anchor_top = 1
    center_notice.anchor_bottom = 1
    center_notice.size = Vector2(800,48)
    center_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
    touch_active = DisplayServer.is_touchscreen_available()
    ui.resized.connect(_layout_menu)
    _layout_menu()
    _refresh_touch_controls()
    _set_hud_visible(false)

func _label(parent: Node, text_value: String, at: Vector2, font_size: int) -> Label:
    var label := Label.new()
    label.text = text_value
    label.position = at
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",Color(0.86,0.98,1))
    label.add_theme_color_override("font_shadow_color",Color(0.015,0.035,0.055))
    label.add_theme_constant_override("shadow_offset_y",2)
    parent.add_child(label)
    return label

func _button(caption: String, at: Vector2, dimensions: Vector2, callback: Callable, parent: Node, hold := false) -> Button:
    var button: Button = HoldScript.new() if hold else Button.new()
    button.text = caption
    button.position = at
    button.size = dimensions
    button.custom_minimum_size = dimensions
    button.add_theme_font_size_override("font_size",22 if caption != "≡" else 32)
    for state in ["normal","hover","pressed"]:
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.025,0.095,0.14,0.68) if state == "normal" else Color(0.1,0.4,0.46,0.9)
        style.border_color = Color(0.38,0.74,0.8,0.65)
        style.set_border_width_all(1)
        style.set_corner_radius_all(20)
        button.add_theme_stylebox_override(state,style)
    var focus_style := StyleBoxFlat.new()
    focus_style.bg_color = Color(0.05,0.3,0.34,0.45)
    focus_style.border_color = Color(1,0.8,0.3)
    focus_style.set_border_width_all(3)
    focus_style.set_corner_radius_all(18)
    button.add_theme_stylebox_override("focus",focus_style)
    button.focus_mode = Control.FOCUS_ALL if parent == menu else Control.FOCUS_NONE
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _hold(caption: String, at: Vector2, dimensions: Vector2, property_name: String) -> void:
    var button := _button(caption,at,dimensions,func() -> void: pass,ui,true) as TouchHoldButton
    button.anchor_left = 1
    button.anchor_right = 1
    button.anchor_top = 1
    button.anchor_bottom = 1
    button.held_changed.connect(func(active: bool) -> void: player.set(property_name,active))
    if not DisplayServer.is_touchscreen_available():
        button.button_down.connect(func() -> void: player.set(property_name,true))
        button.button_up.connect(func() -> void: player.set(property_name,false))
    driving_buttons.append(button)

func _toggle_hud() -> void:
    _set_hud_visible(not hud_visible)

func _set_hud_visible(visible_now: bool) -> void:
    hud_visible = visible_now
    menu.visible = visible_now
    _layout_menu()
    if visible_now:
        resume_button.grab_focus()
    else:
        get_viewport().gui_release_focus()
    player.set_physics_process(not visible_now)
    for i in traffic.size():
        traffic[i].set_physics_process(not visible_now and brains[i].active)
    route_button.text = "ROUTE: %s / %.2f KM" % [coast.circuit_names[selected_route],coast.circuits[selected_route].get_baked_length()/1000.0]
    level_button.text = "LEVEL: AUTO" if selected_level == 0 else "LEVEL: %d" % selected_level
    virtual_stick.set_process_input(not visible_now and virtual_stick.visible)
    virtual_stick._release()
    virtual_stick.active_pointer = -1
    for button in driving_buttons:
        button.set_process_input(not visible_now and button.visible)
        button.disabled = visible_now
        button.pointer_index = -1
    player.input_accel = false
    player.input_boost = false
    player.input_drift = false
    player.input_brake = false

func _message(message: String, seconds := 1.5) -> void:
    center_notice.text = message
    notice_timer = seconds

func _cycle_route() -> void:
    selected_route = (selected_route+1)%coast.circuits.size()
    route_button.text = "ROUTE: %s / %.2f KM" % [coast.circuit_names[selected_route],coast.circuits[selected_route].get_baked_length()/1000.0]

func _cycle_level() -> void:
    selected_level = (selected_level+1)%(mini(5,1+rank_points/350)+1)
    level_button.text = "LEVEL: AUTO" if selected_level == 0 else "LEVEL: %d" % selected_level

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(menu):
        _set_hud_visible(true)

func _route_sample(offset: float) -> Vector3:
    return active_route.sample_baked(fposmod(offset,route_length),true)+Vector3.UP*2.15

func _route_heading(offset: float) -> float:
    var direction := _route_sample(offset+4)-_route_sample(offset)
    return atan2(-direction.x,-direction.z)

func _gate_position() -> Vector3:
    return _route_sample(event_offset+gate_spacing*(passed+1))

func _update_player_progress(delta: float) -> void:
    var offset := active_route.get_closest_offset(Vector3(player.position.x,0,player.position.z))
    var change := wrapf(offset-progress_offset,-route_length*0.5,route_length*0.5)
    progress_delta = 0
    if absf(change) <= maxf(15,(absf(player.forward_speed)+30)*delta*2):
        player_progress += change
        progress_delta = change
    progress_offset = offset

func _update_standings() -> void:
    race_position = 1
    for brain in brains:
        if brain.active and brain.progress > player_progress:
            race_position += 1

func _update_drift(delta: float) -> void:
    var fresh_distance := maxf(0,player_progress-drift_peak_progress)
    drift_peak_progress = maxf(drift_peak_progress,player_progress)
    var sliding := (player.input_drift or Input.is_action_pressed("drift")) and absf(player.side_speed) > 4 and absf(player.forward_speed) > 28 and coast.road_distance(player.position) < 30
    if sliding and fresh_distance > 0.05:
        drift_combo = minf(5,drift_combo+delta*0.35)
        drift_pending += fresh_distance*clampf(absf(player.side_speed)/8,0.4,2.5)*drift_combo*4
        bank_timer = 0
        player.boost_fuel = minf(100,player.boost_fuel+delta*5)
    else:
        bank_timer += delta
        if bank_timer >= 0.65 and drift_pending > 0:
            drift_score += drift_pending
            _message("BANK +%d" % drift_pending,0.6)
            telemetry.record("INFO","drift_bank",{"score":drift_pending,"combo":drift_combo})
            drift_pending = 0
            drift_combo = 1
    if event_time >= 60:
        drift_score += drift_pending
        drift_pending = 0
        _finish(drift_score >= drift_goal)

func _eliminate_last() -> void:
    var standings: Array[float] = []
    for brain in brains:
        standings.append(brain.progress)
    telemetry.record("INFO","elimination_standings",{"player":player_progress,"rivals":standings,"time":event_time})
    var lowest := player_progress
    var victim := -1
    var remaining := 0
    for i in brains.size():
        if brains[i].active:
            remaining += 1
            if brains[i].progress < lowest:
                lowest = brains[i].progress
                victim = i
    if victim < 0:
        _finish(false)
        return
    brains[victim].active = false
    traffic[victim].visible = false
    traffic[victim].collision_layer = 0
    traffic[victim].set_physics_process(false)
    telemetry.record("INFO","rival_eliminated",{"driver":victim,"time":event_time})
    _message("%s ELIMINATED" % RaceBrain.PROFILES[victim].name,1)
    elimination_next += 20
    if remaining <= 1:
        _finish(true)

func _start_patrols(initial := false) -> void:
    for i in traffic.size():
        var route_path: Curve3D = coast.circuits[i%coast.circuits.size()]
        var length := route_path.get_baked_length()
        var offset := length*(0.2+i*0.16)
        if not initial:
            var shortest := INF
            for candidate in coast.circuits:
                var nearest := candidate.get_closest_point(Vector3(traffic[i].position.x,0,traffic[i].position.z))
                if nearest.distance_to(traffic[i].position) < shortest:
                    shortest = nearest.distance_to(traffic[i].position)
                    route_path = candidate
            length = route_path.get_baked_length()
            offset = route_path.get_closest_offset(Vector3(traffic[i].position.x,0,traffic[i].position.z))
        var at := route_path.sample_baked(fposmod(offset,length),true)+Vector3.UP*2.15
        var direction := route_path.sample_baked(fposmod(offset+4,length),true)+Vector3.UP*2.15-at
        if initial:
            traffic[i].reset_to(at,atan2(-direction.x,-direction.z))
        traffic[i].visible = true
        traffic[i].collision_layer = 4
        traffic[i].get_node("PoliceLights").visible = false
        traffic[i].set_physics_process(true)
        brains[i].begin(route_path,offset,"patrol",1)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        touch_active = true
        _refresh_touch_controls()
    elif event is InputEventKey and event.pressed:
        touch_active = false
        _refresh_touch_controls()
    elif event is InputEventMouseMotion and not hud_visible and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        player.mouse_steer_axis = clampf(player.mouse_steer_axis+event.relative.x*0.018,-1,1)
        touch_active = false
        _refresh_touch_controls()
    elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
        if event is InputEventJoypadMotion and absf(event.axis_value) < 0.18:
            return
        last_pad_device = event.device
        touch_active = false
        _refresh_touch_controls()
        if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
            _toggle_hud()
            get_viewport().set_input_as_handled()
        elif hud_visible and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
            _toggle_hud()
            get_viewport().set_input_as_handled()
        elif not hud_visible and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
            _restart()
            get_viewport().set_input_as_handled()
        elif not hud_visible and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK:
            _next_craft()
            get_viewport().set_input_as_handled()

func _on_joy_connection_changed(device: int, connected: bool) -> void:
    telemetry.record("INFO","controller_connection",{"device":device,"connected":connected})
    if not connected and device == last_pad_device:
        InputBindings.release_pad()
        _set_hud_visible(true)
        last_pad_device = -1

func _cycle_touch_layout() -> void:
    touch_layout = "full" if touch_layout == "compact" else "compact"
    touch_active = true
    touch_option.text = "TOUCH: "+touch_layout.to_upper()
    _refresh_touch_controls()

func _refresh_touch_controls() -> void:
    if not is_instance_valid(virtual_stick):
        return
    virtual_stick.visible = touch_active
    virtual_stick.set_process_input(touch_active and not hud_visible)
    if not touch_active:
        virtual_stick._release()
    for button in driving_buttons:
        button.visible = touch_active and (touch_layout == "full" or button.text == "GO")
        button.set_process_input(button.visible and not hud_visible)
        if not button.visible and button.pointer_index != -1:
            button.pointer_index = -1
            button.held_changed.emit(false)

func _layout_menu(viewport_size := Vector2.ZERO) -> void:
    if not is_instance_valid(menu):
        return
    var available: Vector2 = viewport_size if viewport_size != Vector2.ZERO else ui.size
    if minf(available.x,available.y) < 120:
        var scale_setting: float = maxf(1.0,float(ProjectSettings.get_setting("display/window/stretch/scale",1.0)))
        available = Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width",1280)),float(ProjectSettings.get_setting("display/window/size/viewport_height",720)))/scale_setting
    var fit := minf(1,minf((available.x-24)/860.0,(available.y-24)/620.0))
    fit = maxf(0.25,fit)
    menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
    menu.scale = Vector2.ONE*fit
    menu.position = (available-menu.size*fit)*0.5

func _toggle_fullscreen() -> void:
    if OS.has_feature("android"):
        return
    var current := DisplayServer.window_get_mode()
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if current == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
