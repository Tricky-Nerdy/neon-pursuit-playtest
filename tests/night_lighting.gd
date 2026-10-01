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
    var overhangs: Array[Node] = game.coast.find_children("OverhangLight*", "OmniLight3D", false, false)
    check(overhangs.size() > 0, "overhanging fixtures have light sources")
    var cover_road := true
    for lamp in overhangs:
        var road_point: Vector3 = game.coast.closest_road_point(lamp.position)
        cover_road = cover_road and lamp.position.distance_to(road_point) < lamp.omni_range and lamp.position.y < 7.8
    check(cover_road, "overhang lights clear housing and reach road surface")
    check(game.coast.overhang_lamp_material.emission_enabled, "overhang panels glow at night")
    game.coast.time_of_day = game.coast.day_duration_seconds * 0.5
    game.coast.advance_day_night(0.0)
    var all_off := true
    for lamp in overhangs:
        all_off = all_off and not lamp.visible
    check(all_off and not game.coast.overhang_lamp_material.emission_enabled, "overhang illumination and glow off at midday")
    game.coast.time_of_day = game.coast.day_duration_seconds + 1.0
    game.coast.advance_day_night(0.0)
    var all_on := true
    for lamp in overhangs:
        all_on = all_on and lamp.visible
    check(all_on and game.coast.overhang_lamp_material.emission_enabled, "overhang illumination and glow return at night")
    game.set_process(false)
    game.player.set_physics_process(false)
    for craft in 3:
        game.player.select_craft(craft)
        await process_frame
        var front := INF
        for mesh in game.player.visuals.find_children("*", "MeshInstance3D", true, false):
            if mesh.is_visible_in_tree():
                var bounds: AABB = game.player.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
                front = minf(front, bounds.position.z)
        for lamp in game.player.headlights:
            check(front < INF and lamp.position.z < front - 0.1, "headlight clears craft %d hull" % craft)
    game.coast.time_of_day = game.coast.day_duration_seconds * 0.5
    game.coast.advance_day_night(0.0)
    root.push_input(key)
    await process_frame
    check(game.player.headlights_on and game.player.headlights[0].visible, "manual headlights remain on in daylight")
    game.coast.time_of_day = game.coast.day_duration_seconds + 1.0
    game.coast.advance_day_night(0.0)
    check(game.player.headlights_on and game.player.headlights[0].visible, "sun cycle does not turn headlights off")
    game.queue_free()
    await process_frame
    quit(failures)
