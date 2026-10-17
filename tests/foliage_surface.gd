extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
    print("PASS " if ok else "FAIL ",label)
    if not ok: failures += 1
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var scenery = load("res://scripts/world_scenery.gd").new()
    root.add_child(scenery)
    # A sloped triangle: its interior height is 3, independent of noise.
    scenery.terrain_vertices = PackedVector3Array([Vector3(0,0,0),Vector3(10,10,0),Vector3(0,2,10)])
    scenery.terrain_triangles = PackedInt32Array([0,1,2])
    check(is_equal_approx(scenery.terrain_surface_height(Vector2(2.5,2.5)),3.0),"interior uses triangle plane")
    check(is_equal_approx(scenery.terrain_surface_height(Vector2(5,5)),6.0),"edge uses triangle plane")
    check(is_nan(scenery.terrain_surface_height(Vector2(20,20))),"missing terrain is explicit")
    for kind in ["pine","palm"]:
        for scale_value in [0.65,1.25]:
            var tree = scenery._asset(kind,Vector3(2.5,50,2.5),scale_value,0.73)
            var bottom := INF
            for child in tree.find_children("*","MeshInstance3D",true,false):
                var box: AABB = child.get_aabb()
                for x in [box.position.x,box.end.x]:
                    for y in [box.position.y,box.end.y]:
                        for z in [box.position.z,box.end.z]:
                            bottom = minf(bottom,scenery.to_local(child.to_global(Vector3(x,y,z))).y)
            check(absf(bottom-3.0) < 0.001,kind+" bottom follows interior surface at scale "+str(scale_value))
    scenery.queue_free()
    await process_frame
    quit(failures)
