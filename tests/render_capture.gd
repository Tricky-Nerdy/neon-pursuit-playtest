extends SceneTree

const OUTPUT_DIR := "res://docs/screenshots/gameplay"
const SHOTS := ["coast-day", "harbor-day", "canyon-day", "airfield-day", "coast-night", "world-map"]
var failures := 0

func _initialize() -> void:
    # Script errors must fail instead of leaving a graphical CI process hanging.
    create_timer(90.0).timeout.connect(func(): quit(1))
    call_deferred("_run")

func _capture(name: String) -> void:
    # process_frame resumes before drawing; explicitly wait for completed GPU frames.
    for frame in 12:
        await process_frame
        await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    if image == null or image.is_empty() or image.get_width() != 1920 or image.get_height() != 1080:
        push_error("Invalid capture: " + name)
        failures += 1
        return
    var path := OUTPUT_DIR.path_join(name + ".png")
    if image.save_png(path) != OK:
        push_error("Failed to save " + path)
        failures += 1
    else:
        print("CAPTURE ", path)

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Gameplay capture requires a graphical display (use xvfb-run in CI).")
        quit(1)
        return
    seed(42)
    root.size = Vector2i(1920, 1080)
    var scene = load("res://scenes/main.tscn")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    game.save_path = "user://capture_progress.cfg"
    game.telemetry.path = "user://capture.log"
    root.add_child(game)
    await process_frame
    game._set_hud_visible(false)
    game.player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    game.set_process(false)
    game.set_physics_process(false)
    for ship in game.vehicles_root.get_children():
        ship.set_physics_process(false)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
    game.coast.time_of_day = game.coast.day_duration_seconds * 0.5
    game.coast.advance_day_night(0.0)
    var spawns = game.coast.get_node("FreeRoamSpawns")
    for index in 4:
        var spawn = spawns.get_child(index)
        game.player.reset_to(spawn.global_position, spawn.global_rotation.y)
        game.player.reset_physics_interpolation()
        await physics_frame
        await process_frame
        game._camera_follow(1.0)
        await _capture(SHOTS[index])
    var coast_spawn = spawns.get_node("Coast")
    game.player.reset_to(coast_spawn.global_position, coast_spawn.global_rotation.y)
    game.player.reset_physics_interpolation()
    game.coast.time_of_day = game.coast.day_duration_seconds + game.coast.night_duration_seconds * 0.5
    game.coast.advance_day_night(0.0)
    game.player.headlights_on = true
    for lamp in game.player.headlights:
        lamp.visible = true
    await physics_frame
    await process_frame
    game._camera_follow(1.0)
    await _capture(SHOTS[4])
    game.coast.time_of_day = game.coast.day_duration_seconds * 0.5
    game.coast.advance_day_night(0.0)
    game.camera.position = Vector3(0, 1600, 1050)
    game.camera.look_at(Vector3.ZERO)
    game.camera.fov = 70
    await _capture(SHOTS[5])
    game.queue_free()
    await process_frame
    quit(failures)
