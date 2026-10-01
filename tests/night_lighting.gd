extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
    print("PASS " if ok else "FAIL ", label)
    if not ok:
        failures += 1
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var scene = load("res://scenes/main.tscn")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    game.save_path = "user://lighting_check.cfg"
    game.telemetry.path = "user://lighting_check.log"
    root.add_child(game)
    await process_frame
    check(game.player.headlights.size() == 2, "two headlights created on startup")
    check(game.coast.street_lights.size() > 0, "streetlights created on startup")
    var key := InputEventKey.new()
    key.keycode = KEY_H
    key.pressed = true
    root.push_input(key)
    await process_frame
    check(game.player.headlights_on and game.player.headlights[0].visible, "H input turns headlights on")
    root.push_input(key)
    await process_frame
    check(not game.player.headlights_on and not game.player.headlights[0].visible, "H input turns headlights off")
    game.coast.time_of_day = game.coast.day_duration_seconds * 0.5
    game.coast.advance_day_night(0.0)
    check(not game.coast.street_lights[0].visible, "streetlights off at midday")
    game.coast.time_of_day = game.coast.day_duration_seconds + 1.0
    game.coast.advance_day_night(0.0)
    check(game.coast.street_lights[0].visible, "streetlights on at night")
    game.queue_free()
    await process_frame
    quit(failures)
