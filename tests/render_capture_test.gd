extends SceneTree

var failures := 0
func check(ok: bool, label: String) -> void:
    print("PASS " if ok else "FAIL ", label)
    if not ok:
        failures += 1

func _initialize() -> void:
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
    var spawns = game.coast.get_node("FreeRoamSpawns")
    check(spawns.get_child_count() == 4, "four district capture positions exist")
    game.player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    game.set_process(false)
    game.set_physics_process(false)
    game._set_hud_visible(false)
    game.player.set_physics_process(false)
    for spawn in spawns.get_children():
        game.player.reset_to(spawn.global_position, spawn.global_rotation.y)
        await physics_frame
        await process_frame
        game._camera_follow(1.0)
        check(game.player.global_position.distance_to(spawn.global_position) < 0.01, "capture reaches " + spawn.name)
        var expected = game.player.global_position + game.player.global_basis.z.normalized() * 9.0 + Vector3.UP * 4.2
        check(game.camera.global_position.distance_to(expected) < 0.01, "camera uses current capture pose at " + spawn.name)
    game.coast.time_of_day = game.coast.day_duration_seconds * 0.5
    game.coast.advance_day_night(0.0)
    check(not game.coast.street_lights[0].visible, "day capture applies daylight")
    game.coast.time_of_day = game.coast.day_duration_seconds + game.coast.night_duration_seconds * 0.5
    game.coast.advance_day_night(0.0)
    check(game.coast.street_lights[0].visible, "night capture applies street lighting")
    game.queue_free()
    await process_frame
    quit(failures)
