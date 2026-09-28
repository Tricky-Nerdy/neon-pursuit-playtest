extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func flatten(node: Node, destination: Node3D) -> void:
    if node is MultiMeshInstance3D and node.multimesh != null:
        for index in node.multimesh.instance_count:
            var item := MeshInstance3D.new()
            item.mesh = node.multimesh.mesh
            item.material_override = node.material_override
            var transforms: Array = node.get_meta("review_transforms",[])
            item.transform = node.global_transform*(transforms[index] if transforms.size() > index else node.multimesh.get_instance_transform(index))
            destination.add_child(item)
            item.owner = destination
    elif node is MeshInstance3D and node.is_visible_in_tree():
        var item := MeshInstance3D.new()
        item.mesh = node.mesh
        item.material_override = node.material_override
        if item.material_override is ShaderMaterial:
            var water := StandardMaterial3D.new()
            water.albedo_color = Color(0.025,0.30,0.39)
            water.roughness = 0.32
            item.material_override = water
        item.transform = node.global_transform
        destination.add_child(item)
        item.owner = destination
    for child in node.get_children():
        flatten(child,destination)
func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_physics_process(false)
    var geometry := Node3D.new()
    geometry.name = "AuroraReview"
    root.add_child(geometry)
    flatten(game.coast,geometry)
    flatten(game.player,geometry)
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    var error := doc.append_from_scene(geometry,state)
    if error == OK:
        error = doc.write_to_filesystem(state,"/tmp/aurora4_review.glb")
    print("REVIEW_EXPORT ",error," instances=",geometry.get_child_count())
    quit(error)
