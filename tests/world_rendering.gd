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
    var world = load("res://scripts/coast_map.gd").new()
    root.add_child(world)
    await process_frame
    check(not world.world_environment.environment.fog_enabled, "distance fog disabled for a clear world")
    check(world.world_environment.environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "night uses explicit ambient fill rather than a nearly black sky")
    check(world.road_markings.size() > 300, "lane and edge markings retained away from junctions")
    var clear := true
    for marking in world.road_markings:
        if not world.marking_clear_of_junction(marking.path, marking.at, marking.yaw, marking.length):
            clear = false
    check(clear, "every complete stripe stays outside joining road surfaces")
    var crossing := Curve3D.new()
    crossing.add_point(Vector3(-50,0,0))
    crossing.add_point(Vector3(50,0,0))
    var other := Curve3D.new()
    other.add_point(Vector3(0,0,-50))
    other.add_point(Vector3(0,0,50))
    world.roads.assign([crossing, other])
    world.road_widths = [20.0,20.0]
    check(not world.marking_clear_of_junction(crossing, Vector3.ZERO, PI/2, 6), "reject stripe at crossing center")
    check(not world.marking_clear_of_junction(crossing, Vector3(16,0,0), PI/2, 14), "reject stripe with endpoint inside junction")
    check(world.marking_clear_of_junction(crossing, Vector3(35,0,0), PI/2, 14), "retain stripe beyond junction")
    world.queue_free()
    await process_frame
    quit(failures)
