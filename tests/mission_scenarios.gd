extends SceneTree
var game
var failures := 0
var checks := 0
func _initialize() -> void:
    call_deferred("_run")
func check(condition: bool, name: String) -> void:
    checks += 1
    print("PASS " if condition else "FAIL ",name)
    if not condition:
        failures += 1
func drive(mode: int, route_index: int, seconds: float) -> bool:
    game.selected_route = route_index
    var route: Curve3D = game.coast.circuits[route_index]
    var at := route.sample_baked(0)+Vector3.UP*2.15
    var direction := route.sample_baked(5)-route.sample_baked(0)
    game.player.reset_to(at,atan2(-direction.x,-direction.z))
    game.rank_points = 0
    game._select_mode(mode)
    game.player.input_accel = true
    var max_offroad := 0.0
    for frame in int(seconds*60):
        var offset: float = route.get_closest_offset(Vector3(game.player.position.x,0,game.player.position.z))
        var target: Vector3 = route.sample_baked(fposmod(offset+32,route.get_baked_length()),true)
        var next: Vector3 = route.sample_baked(fposmod(offset+64,route.get_baked_length()),true)
        if mode == 6:
            var forward := (next-target).normalized()
            var lane_offset := Vector3(forward.z,0,-forward.x)*9.0
            target += lane_offset
            next += lane_offset
        var heading := atan2(-(target-game.player.position).x,-(target-game.player.position).z)
        var error := wrapf(heading-game.player.heading,-PI,PI)
        var bend: float = (target-game.player.position).normalized().angle_to((next-target).normalized())
        game.player.steer_axis = clampf(-error*2.0,-1,1)
        game.player.input_drift = mode == 5 and absf(error) > 0.09
        game.player.input_brake = (absf(error) > 0.55 or bend > 0.45) and game.player.forward_speed > 48
        game.player.input_accel = not game.player.input_brake
        game.player.input_boost = bend < 0.25 and absf(error) < 0.2 and game.player.boost_fuel > 10 and mode != 5
        max_offroad = maxf(max_offroad,game.coast.road_distance(game.player.position))
        await physics_frame
        if not game.event_active:
            break
    print("SCENARIO mode=",mode," route=",route_index," time=",snappedf(game.event_time,0.1)," gates=",game.passed," score=",snappedf(game.drift_score,1)," traps=",game.speed_traps_hit," offroad=",snappedf(max_offroad,0.1)," result=",game.last_result," active=",game.event_active)
    game.player.input_accel = false
    game.player.input_boost = false
    game.player.input_drift = false
    game.player.input_brake = false
    return not game.event_active and game.last_result.contains("RP")
func _run() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    game.save_path = "user://mission_scenarios.cfg"
    game.telemetry.path = "user://mission_scenarios.log"
    root.add_child(game)
    await process_frame
    for route_index in 4:
        var route: Curve3D = game.coast.circuits[route_index]
        check(route.get_point_position(0).distance_to(route.get_point_position(route.point_count-1)) < 0.1,"district %d route closes" % route_index)
        check(await drive(2,route_index,95),"circuit %d physically drivable and winnable" % route_index)
    check(await drive(3,2,65),"canyon checkpoint rush is winnable")
    check(await drive(4,1,80),"harbor pursuit can be escaped")
    check(await drive(5,2,65),"canyon drift mission can be completed through real slides")
    check(await drive(6,0,90),"elimination survives all four rounds")
    check(await drive(7,0,55),"speed trap mission is winnable")
    game.selected_route = 0
    game._select_mode(1)
    var before: float = game.event_time
    var before_pos: Vector3 = game.player.position
    game._set_hud_visible(true)
    for frame in 20:
        await physics_frame
    check(game.event_time == before and game.player.position.is_equal_approx(before_pos),"mission menu pauses timers and ship physics")
    game._set_hud_visible(false)
    var count_before: int = game.passed
    game.player_progress = -50
    game.previous_position = game._gate_position()
    game.player.position = game._gate_position()
    game._update_event(0.01)
    check(game.passed == count_before,"standing at a checkpoint cannot farm gates")
    game._select_mode(5)
    game.player.forward_speed = 60
    game.player.side_speed = 20
    game.player.input_drift = true
    game.player_progress = 0
    game._update_event(1)
    check(game.drift_pending == 0,"stationary progress cannot farm drift points")
    game.drift_pending = 900
    game.crash_cooldown = 0
    game._on_hit_wall()
    check(game.drift_pending == 0,"collision loses unbanked drift points")
    var graph_path: PackedVector3Array = game.coast.navigation_path(Vector3(-500,0,240),Vector3(320,0,-420))
    var on_road := graph_path.size() > 3
    for point in graph_path:
        on_road = on_road and game.coast.road_distance(point) < 1
    check(on_road,"police graph connects districts along road centers")
    print("RESULT %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
