extends SceneTree
var failures: Array[String] = []
var checks := 0
var game

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, name: String) -> void:
    checks += 1
    print("PASS " if ok else "FAIL ",name)
    if not ok:
        failures.append(name)

func control(caption: String, parent: Node = game.ui) -> Button:
    for child in parent.get_children():
        if child is Button and child.text == caption:
            return child
        var nested := control(caption,child)
        if nested != null:
            return nested
    return null

func drive_event(index: int, seconds: float) -> bool:
    game.player.reset_to(game.coast.sample(0),game.coast.heading_at(0))
    game._select_mode(index)
    game.player.input_accel = true
    for frame in int(seconds*60):
        var distance: float = game.coast.nearest_distance(game.player.position)
        var target: Vector3 = game.coast.sample(distance+36)
        var direction: Vector3 = target-game.player.position
        var desired := atan2(-direction.x,-direction.z)
        var error := wrapf(desired-game.player.heading,-PI,PI)
        game.player.steer_axis = clampf(-error*2.0,-1,1)
        game.player.input_boost = absf(error) < 0.15 and game.player.boost_fuel > 15
        await physics_frame
        if not game.event_active:
            game.player.input_accel = false
            game.player.input_boost = false
            game.player.steer_axis = 0
            return game.last_result.contains("RP")
    game.player.input_accel = false
    game.player.input_boost = false
    return false

func _run() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    game.save_path = "user://aurora_test_progress.cfg"
    game.telemetry.path = "user://aurora_test.log"
    root.add_child(game)
    await process_frame
    game.rank_points = 0
    game.medals.clear()
    game.best_times.clear()
    check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 6,"uploaded sensor orientation retained")
    check(bool(ProjectSettings.get_setting("physics/common/physics_interpolation")),"physics interpolation enabled")
    game._camera_follow(1.0/120.0)
    var pose: Transform3D = game.player.get_global_transform_interpolated()
    var offset: Vector3 = game.camera.global_position-pose.origin
    check(absf(Vector2(offset.x,offset.z).length()-9.0) < 0.01 and absf(offset.y-4.2) < 0.01,"close chase camera uses a nine meter gap")
    check(game.camera.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,"render camera avoids double interpolation")
    check(game.coast.length > 3000 and game.coast.route.size() == 32,"continuous three kilometer coast circuit")
    check(game.coast.landmark_count >= 5 and game.coast.boost_pads.size() == 8,"landmarks and boost pad network")
    check(game.coast.shortcut.get_baked_length() > 900,"connected inland shortcut")
    check(not game.hud_visible and not game.menu.visible and not game.title.is_visible_in_tree(),"top HUD and info are hidden at startup")
    var key := InputEventKey.new()
    key.keycode = KEY_F3
    key.pressed = true
    game._unhandled_key_input(key)
    check(game.hud_visible and control("EVENTS").is_visible_in_tree(),"F3 opens main menu")
    control("EVENTS").pressed.emit()
    check(control("BAY SPRINT").is_visible_in_tree(),"events page exposes mission buttons")
    game._unhandled_key_input(key)
    check(not game.menu.visible,"F3 closes all menu text")
    control("≡").pressed.emit()
    check(game.menu.visible,"touch menu can reopen without a keyboard")
    control("RESUME").pressed.emit()
    check(not game.menu.visible,"resume returns directly to driving")
    game.touch_layout = "full"
    game.touch_active = true
    game._refresh_touch_controls()
    var touch := InputEventScreenTouch.new()
    touch.pressed = true
    touch.index = 3
    touch.position = game.virtual_stick.global_position+game.virtual_stick.size*0.5+Vector2(45,-35)
    game.virtual_stick._input(touch)
    check(game.player.steer_axis > 0 and game.player.drive_axis < 0,"right/up stick direction")
    touch.pressed = false
    game.virtual_stick._input(touch)
    check(game.player.steer_axis == 0 and game.player.drive_axis == 0,"stick releases cleanly")
    var go := control("GO")
    var boost := control("BOOST")
    touch.index = 4
    touch.pressed = true
    touch.position = go.get_global_rect().get_center()
    go._input(touch)
    touch.index = 5
    touch.position = boost.get_global_rect().get_center()
    boost._input(touch)
    check(game.player.input_accel and game.player.input_boost,"multitouch throttle plus boost")
    game._set_hud_visible(true)
    check(not game.player.input_accel and not game.player.input_boost,"opening menu clears held touch inputs")
    game._set_hud_visible(false)
    check(not go.get_global_rect().intersects(boost.get_global_rect()),"right controls do not overlap")
    game.player.forward_speed = 70
    game.player.input_accel = true
    game.player.input_brake = true
    for frame in 20:
        await physics_frame
    check(game.player.forward_speed < 50,"brake overrides held throttle")
    check(absf(game.player.position.y-2.15) < 0.001,"hover bob does not shake camera anchor")
    game.player.input_brake = false
    game.player.input_accel = false
    check(await drive_event(1,35),"actual steering/throttle completes sprint")
    game._camera_follow(1.0/30.0)
    pose = game.player.get_global_transform_interpolated()
    offset = game.camera.global_position-pose.origin
    check(absf(Vector2(offset.x,offset.z).length()-9.0) < 0.01,"boost speed cannot stretch the chase distance")
    game.player.reset_to(game.coast.sample(0),game.coast.heading_at(0))
    game._camera_follow(1.0/120.0)
    check(game.camera.global_position.distance_to(game.player.position) < 11,"retry resets interpolation without trailing across map")
    check(game.medals.size() >= 1 and game.rank_points > 0,"finish awards saved medal and rank points")
    var config := ConfigFile.new()
    check(config.load(game.save_path) == OK and config.has_section_key("player","medals"),"medals persist to disk")
    game.rank_points = 0
    check(await drive_event(2,65),"actual driving completes circuit against rivals")
    check(game.race_position <= 3,"circuit is competitively winnable")
    game.rank_points = 0
    check(await drive_event(3,45),"checkpoint rush can be completed with the countdown")
    game.rank_points = 0
    check(await drive_event(4,40),"pursuit is escapable by racing the route")
    game._select_mode(3)
    game.rush_time = 0.001
    game._update_event(0.1)
    check(not game.event_active and not game.last_result.contains("RP"),"checkpoint rush timeout fails correctly")
    game._select_mode(4)
    for rival in game.traffic:
        rival.position = game.player.position
    game.pursuit_heat = 99.9
    game._update_event(0.1)
    check(not game.event_active and game.last_result == "INTERCEPTED","pursuit heat can cause interception")
    game._select_mode(5)
    game.player.input_drift = true
    game.player.forward_speed = 55
    game.player.side_speed = 14
    game.player_progress = 60
    game._update_event(2)
    check(game.drift_pending > 300 and game.drift_combo > 1,"fresh road distance builds unbanked drift combo")
    game.player.input_drift = false
    game._update_event(0.8)
    check(game.drift_score > 300 and game.drift_pending == 0,"releasing drift banks the combo")
    game._on_hit_wall()
    check(game.drift_combo == 1,"collision breaks drift combo")
    game.drift_score = 15000
    game.event_time = 59.99
    game._update_event(0.1)
    check(game.last_result.contains("GOLD"),"drift target awards gold medal")
    game._restart()
    check(game.mode == 5 and game.event_active and game.event_time < 0.1,"retry restarts last event after a finish")
    var before: int = game.player.craft_index
    game._next_craft()
    check(game.player.craft_index != before and game.event_active,"craft hot swap preserves mission")
    game._select_mode(0)
    check(not game.event_active and not game.gate_visual.visible,"free roam clears mission")
    game._restart()
    check(game.mode == 0 and not game.event_active,"explicit free roam restart does not retry the previous event")
    game.player.position = game.coast.boost_pads[0]+Vector3.UP*2
    game.player.boost_fuel = 0
    game.pad_cooldown = 0
    game._update_pads()
    check(game.player.boost_fuel > 0 and game.player.forward_speed >= 100,"road boost pads propel and recharge")
    var log_text := FileAccess.get_file_as_string(game.telemetry.path)
    check(log_text.contains("event_finish") and log_text.contains("event_failed") and log_text.contains("progress_saved"),"structured logging records outcomes and saves")
    print("RESULT %d checks, %d failures" % [checks,failures.size()])
    game.queue_free()
    quit(0 if failures.is_empty() else 1)
