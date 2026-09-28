extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    game.save_path = "user://capture_progress.cfg"
    root.add_child(game)
    for i in 8:
        await process_frame
    root.get_texture().get_image().save_png("/tmp/aurora_start.png")
    game._set_hud_visible(true)
    for i in 3:
        await process_frame
    root.get_texture().get_image().save_png("/tmp/aurora_menu.png")
    game._set_hud_visible(false)
    game.camera.set_process(false)
    game.set_process(false)
    game.player.set_physics_process(false)
    game.camera.position = Vector3(0,1150,800)
    game.camera.look_at(Vector3.ZERO)
    game.camera.fov = 70
    for i in 3:
        await process_frame
    root.get_texture().get_image().save_png("/tmp/aurora_map.png")
    quit()
