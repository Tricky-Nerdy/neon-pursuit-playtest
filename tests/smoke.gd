extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    game.save_path = "user://aurora_smoke.cfg"
    root.add_child(game)
    await process_frame
    assert(game.coast.route.size() == 32)
    assert(not game.menu.visible)
    game._select_mode(1)
    assert(game.event_active)
    game._restart()
    assert(game.event_time == 0)
    game._next_craft()
    assert(game.player.craft_index == 1)
    print("PASS: coast, hidden HUD, mission, retry and craft swap")
    quit()
