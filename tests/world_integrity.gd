extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, name: String) -> void:
    checks += 1
    print("PASS " if ok else "FAIL ",name)
    if not ok: failures += 1
func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    game.save_path = "user://world_integrity.cfg"
    game.telemetry.path = "user://world_integrity.log"
    root.add_child(game)
    await physics_frame
    game.set_physics_process(false)
    game.player.set_physics_process(false)
    for rival in game.traffic:
        rival.set_physics_process(false)
    var total := 0.0
    for road in game.coast.roads:
        total += road.get_baked_length()
    print("WORLD road_meters=",snappedf(total,0.1)," navigation_nodes=",game.coast.navigation.get_point_count())
    check(total > 6000,"more than six kilometers of connected roads")
    print("SCENERY peak_m=",snappedf(game.coast.scenery.terrain_peak,0.1)," props=",game.coast.scenery.prop_count," asset_batches=",game.coast.scenery.batched_prop_groups)
    check(game.coast.scenery.batched_prop_groups > 0 and game.coast.scenery.batched_prop_groups < 35,"repeated scenery is batched into fewer than 35 mesh groups")
    check(game.coast.scenery.terrain_peak > 100,"sculpted terrain includes substantial mountain relief")
    check(game.coast.scenery.prop_count > 500,"districts contain detailed props and roadside objects")
    var land_under_roads := true
    for road in game.coast.roads:
        for d in range(0,int(road.get_baked_length()),12):
            if not game.coast.is_driveable_land(road.sample_baked(d,true)):
                land_under_roads = false
    check(land_under_roads,"every route remains inside the new shoreline recovery boundary")
    check(not game.coast.is_driveable_land(Vector3(-100,0,-375)),"reservoir is excluded from drivable land")
    check(game.coast.is_driveable_land(Vector3(-450,0,-730)),"new northern route is no longer clipped by the old oval boundary")
    var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
    for ri in game.coast.roads.size():
        var road: Curve3D = game.coast.roads[ri]
        var length := road.get_baked_length()
        var blocked := 0
        for distance in range(5,int(length)-5,8):
            var at := road.sample_baked(distance,true)+Vector3.UP*2.15
            var next := road.sample_baked(distance+5,true)+Vector3.UP*2.15
            var direction := (next-at).normalized()
            var side := Vector3(direction.z,0,-direction.x)
            for lane in [-8.0,0.0,8.0]:
                var query := PhysicsRayQueryParameters3D.create(at+side*lane,next+side*lane,1)
                if not space.intersect_ray(query).is_empty():
                    blocked += 1
        check(blocked == 0,"road %d has no scenery blocking driving lanes (%d hits)" % [ri,blocked])
    for ri in game.coast.circuits.size():
        var route: Curve3D = game.coast.circuits[ri]
        var on_road := true
        for d in range(0,int(route.get_baked_length()),15):
            if game.coast.road_distance(route.sample_baked(d,true)) > 5:
                on_road = false
        check(on_road,"mission route %d stays on built roads" % ri)
    var correct_faces := true
    var ribbons := 0
    for child in game.coast.get_children():
        if child is MeshInstance3D and str(child.name).begins_with("RoadRibbon"):
            ribbons += 1
            var vertices: PackedVector3Array = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
            for i in range(0,vertices.size(),3):
                var normal := (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
                if normal.y > 0.001:
                    correct_faces = false
                    print("BAD_FACE ",child.name," triangle=",i/3," cross=",normal.y)
    print("RIBBONS ",ribbons)
    check(ribbons >= 10 and correct_faces,"road surfaces have correct Godot front-face winding")
    game.rank_points = 1400
    game.selected_level = 1
    game.selected_route = 2
    game._select_mode(1)
    check(game.mission_level == 1,"earned rank allows choosing an easier unlocked level")
    game.selected_level = 5
    game._select_mode(1)
    check(game.mission_level == 5,"highest unlocked difficulty is selectable")
    game.rank_points = 0
    game._select_mode(1)
    check(game.mission_level == 1,"locked difficulty cannot be selected")
    game.selected_route = 3
    game._select_mode(1)
    game.event_time = 14
    game._finish(true)
    var cfg := ConfigFile.new()
    check(cfg.load(game.save_path) == OK and cfg.get_value("player","medals",{}).has("BAY SPRINT:AIRFIELD:1"),"medals are saved for the specific district and level")
    game._select_mode(2)
    game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(game.hud_visible and not game.player.is_physics_processing(),"losing app focus pauses driving safely")
    game._set_hud_visible(false)
    check(game.player.is_physics_processing(),"resume restores player simulation")
    print("RESULT %d checks, %d failures" % [checks,failures])
    quit(0 if failures == 0 else 1)
