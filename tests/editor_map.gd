extends SceneTree
# Run with --headless --editor --path . --script tests/editor_map.gd.
var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Let the editor finish its initial scan before creating or closing scenes.
	await create_timer(3.0).timeout
	check(Engine.is_editor_hint(), "test runs in actual editor mode")
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	var world := game.get_node("World") as CoastMap
	check(world.scenery != null and world.scenery.terrain_mesh != null,
		"terrain generated in the editor")
	check(world.roads.size() == 5 and world.road_markings.size() > 300,
		"complete road network visible in the editor")
	check(world.scenery.prop_count > 500, "scenery generated in the editor")
	check(world.get_node("FreeRoamSpawns").get_child_count() == 4,
		"authored spawn markers remain available")
	check(game.get_node("Vehicles").get_child_count() == 0,
		"editor preview does not start gameplay or spawn vehicles")
	# Editor-generated geometry must not become saved scene content.
	var packed := PackedScene.new()
	check(packed.pack(game) == OK, "preview scene can be saved")
	var saved := packed.get_state()
	check(saved.get_node_count() == scene.get_state().get_node_count(),
		"saving preserves authored nodes without baking preview geometry")
	var count := world.get_child_count()
	var points := world.curve.point_count
	game.remove_child(world)
	game.add_child(world)
	world.request_ready()
	game.remove_child(world)
	game.add_child(world)
	check(world.get_child_count() == count and world.curve.point_count == points,
		"re-entering the tree does not duplicate map geometry")
	game.queue_free()
	await process_frame
	await process_frame
	quit(failures)
