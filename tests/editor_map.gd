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
	check(game.get_node("Vehicles").get_child_count() == 4,
		"four racers appear in the editor")
	check(game.player == null and game.telemetry == null and game.ui == null,
		"editor simulation leaves player, telemetry, and gameplay UI inactive")
	var racer: HoverShip = game._editor_racers[0]
	var before := racer.position
	var before_time: float = world.time_of_day
	game._process(1.0)
	check(racer.position.distance_to(before) > 40.0, "racers move along the map in editor mode")
	check(world.time_of_day > before_time, "day/night clock advances in editor mode")
	check(world.road_distance(racer.position) < 0.5, "editor racer stays on the road")
	check(not racer.is_physics_processing() and racer.collision_layer == 0,
		"editor racers do not run runtime driving physics")
	world.time_of_day = world.day_duration_seconds + 1.0
	game._process(0.0)
	check(world.street_lights[0].visible, "editor night cycle switches street lights on")
	var racers_count := game.get_node("Vehicles").get_child_count()
	game._ready_editor_simulation()
	check(game.get_node("Vehicles").get_child_count() == racers_count,
		"reinitializing does not duplicate editor racers")
	game.coast = null
	game._editor_racers.clear()
	game._editor_offsets.clear()
	game._process(0.0)
	check(game._editor_racers.size() == 4 and game.get_node("Vehicles").get_child_count() == 4,
		"editor processing restores preview after script reload without duplicates")
	var automatic_start: Vector3 = game._editor_racers[0].position
	await create_timer(0.2).timeout
	check(game._editor_racers[0].position.distance_to(automatic_start) > 1.0,
		"racers animate automatically without directly calling process")
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
