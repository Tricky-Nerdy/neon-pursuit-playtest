extends SceneTree

var failures := 0
func check(ok: bool, label: String) -> void:
    print("PASS " if ok else "FAIL ", label)
    if not ok:
        failures += 1

func _initialize() -> void:
    create_timer(20.0).timeout.connect(func(): quit(1))
    call_deferred("_run")

func _run() -> void:
    var capture = load("res://tests/render_capture.gd")
    check(capture != null and capture.can_instantiate(), "capture script compiles after import")
    var names := {}
    for name in capture.SHOTS:
        names[name] = true
    check(names.size() == 6, "six distinct capture filenames")
    var scene = load("res://scenes/main.tscn")
    check(scene != null and scene.can_instantiate(), "real gameplay scene loads")
    var game = scene.instantiate()
    game.save_path = "user://capture_test.cfg"
    game.telemetry.path = "user://capture_test.log"
    root.add_child(game)
    await process_frame
    check(game.camera.near >= 0.5, "world camera preserves depth precision")
    var views = load("res://tests/capture_views.gd")
    check(views.VIEWS.size() == 6, "six authored landmark views")
    game.player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    game.set_process(false)
    game.set_physics_process(false)
    game._set_hud_visible(false)
    game.player.set_physics_process(false)
    for view in views.VIEWS:
        var pose: Transform3D = views.road_pose(game.coast, view)
        game.player.reset_to(pose.origin, pose.basis.get_euler().y)
        await physics_frame
        await process_frame
        game._camera_follow(1.0)
        check(game.coast.road_distance(game.player.global_position) < 0.1, "ship centered on road for " + view.name)
        var expected = game.player.global_position + game.player.global_basis.z.normalized() * 9.0 + Vector3.UP * 4.2
        check(game.camera.global_position.distance_to(expected) < 0.01, "camera uses current pose for " + view.name)
        var road: Curve3D = game.coast.roads[view.road]
        var offset := road.get_closest_offset(view.near)
        var tangent := (road.sample_baked(offset + 5.0,true) - road.sample_baked(offset,true)).normalized()
        if view.get("reverse", false):
            tangent = -tangent
        check((-game.player.global_basis.z).dot(tangent) > 0.99, "ship follows road heading for " + view.name)
        if view.has("camera"):
            game.camera.global_position = view.camera
            game.camera.look_at(view.target)
            check(game.camera.is_position_in_frustum(view.target), "landmark inside frame for " + view.name)
    game.coast.time_of_day = game.coast.day_duration_seconds * 0.5
    game.coast.advance_day_night(0.0)
    check(not game.coast.street_lights[0].visible, "day capture applies daylight")
    game.coast.time_of_day = game.coast.day_duration_seconds + game.coast.night_duration_seconds * 0.5
    game.coast.advance_day_night(0.0)
    check(game.coast.street_lights[0].visible, "night capture applies street lighting")
    game.queue_free()
    await process_frame
    quit(failures)
