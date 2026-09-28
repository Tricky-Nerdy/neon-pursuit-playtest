extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
    call_deferred("_run")
func check(condition: bool, label: String) -> void:
    checks += 1
    print("PASS " if condition else "FAIL ",label)
    if not condition:
        failures += 1
func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    game.save_path = "user://ai_endurance.cfg"
    game.telemetry.path = "user://ai_endurance.log"
    root.add_child(game)
    await process_frame
    game.set_physics_process(false)
    game.set_process(false)
    game.player.set_physics_process(false)
    game.player.position = Vector3(700,2,0)
    for route_index in 4:
        var path: Curve3D = game.coast.circuits[route_index]
        var length := path.get_baked_length()
        var max_offroad := [0.0,0.0,0.0,0.0]
        for i in 4:
            var offset := -i*18.0
            var at := path.sample_baked(fposmod(offset,length),true)+Vector3.UP*2.15
            var direction := path.sample_baked(fposmod(offset+4,length),true)+Vector3.UP*2.15-at
            game.traffic[i].reset_to(at,atan2(-direction.x,-direction.z))
            game.traffic[i].set_physics_process(true)
            game.traffic[i].collision_layer = 4
            game.brains[i].begin(path,offset,"race",3)
            game.brains[i].progress = offset
        # The uploaded user project caps all crafts below 80 m/s; use a 150 s window
        # so the pace-3 endurance check still covers two laps on the long coast.
        for frame in 9000:
            for i in 4:
                game.brains[i].tick(1.0/60,game.traffic,game.player)
                max_offroad[i] = maxf(max_offroad[i],game.coast.road_distance(game.traffic[i].position))
            await physics_frame
            var completed := true
            for brain in game.brains:
                if brain.progress < length*1.8:
                    completed = false
            if completed:
                break
        for i in 4:
            print("METRIC route=",route_index," driver=",i," progress=",snappedf(game.brains[i].progress,0.1)," length=",snappedf(length,0.1)," offroad=",snappedf(max_offroad[i],0.1)," recoveries=",game.brains[i].recoveries," overtakes=",game.brains[i].overtakes," boosts=",game.brains[i].boosts)
            check(game.brains[i].progress > length*1.5,"route %d driver %d completes multiple laps" % [route_index,i])
            check(max_offroad[i] < 45,"route %d driver %d remains near the roads" % [route_index,i])
    print("RESULT %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
