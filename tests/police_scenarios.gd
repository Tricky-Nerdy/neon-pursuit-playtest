extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, name: String) -> void:
    checks += 1
    print("PASS " if ok else "FAIL ",name)
    if not ok: failures += 1
func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    game.save_path = "user://police_scenario.cfg"
    game.telemetry.path = "user://police_scenario.log"
    root.add_child(game)
    await process_frame
    game.selected_route = 1
    game._select_mode(4)
    game.set_physics_process(false)
    game.set_process(false)
    var max_offroad := [0.0,0.0,0.0,0.0]
    var max_step := [0.0,0.0,0.0,0.0]
    var old_positions: Array[Vector3] = []
    for actor in game.traffic:
        old_positions.append(actor.position)
    for frame in 2400:
        var offset: float = game.active_route.get_closest_offset(Vector3(game.player.position.x,0,game.player.position.z))
        var target: Vector3 = game._route_sample(offset+35)
        var direction: Vector3 = target-game.player.position
        var desired := atan2(-direction.x,-direction.z)
        game.player.steer_axis = clampf(-wrapf(desired-game.player.heading,-PI,PI)*2,-1,1)
        game.player.input_accel = true
        for i in 4:
            game.brains[i].tick(1.0/60,game.traffic,game.player)
            max_offroad[i] = maxf(max_offroad[i],game.coast.road_distance(game.traffic[i].position))
            max_step[i] = maxf(max_step[i],game.traffic[i].position.distance_to(old_positions[i]))
            old_positions[i] = game.traffic[i].position
        await physics_frame
    for i in 4:
        print("POLICE driver=",i," plans=",game.brains[i].path_replans," offroad=",snappedf(max_offroad[i],0.1)," step=",snappedf(max_step[i],0.01)," state=",game.brains[i].state)
        check(game.brains[i].path_replans > 10,"officer %d replans through road graph" % i)
        check(max_offroad[i] < 45,"officer %d stays near roads" % i)
        check(max_step[i] < 4,"officer %d never teleports to catch player" % i)
    var memories: Array[Vector3] = []
    for brain in game.brains:
        memories.append(brain.last_seen)
    game.player.set_physics_process(false)
    game.player.position = Vector3(1500,2,1500)
    for frame in 360:
        for i in 4:
            game.brains[i].tick(1.0/60,game.traffic,game.player)
        await physics_frame
    for i in 4:
        check(game.brains[i].state == "SEARCH","officer %d searches after losing sight" % i)
        check(game.brains[i].last_seen.is_equal_approx(memories[i]),"officer %d cannot track unseen player" % i)
    print("RESULT %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
