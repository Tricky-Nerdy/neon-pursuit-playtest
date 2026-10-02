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

	# A tool preview must never activate a gameplay Camera3D. The native 3D editor
	# viewport owns its own editor camera, so any current scene camera here would
	# steal or replace the fly-camera view the designer is using.
	var editor_cameras: Array[Camera3D] = []
	_collect_cameras(game, editor_cameras)
	check(editor_cameras.all(func(camera: Camera3D) -> bool: return not camera.current),
		"editor simulation does not steal camera ownership from the 3D editor")
	var camera_current_state: Array[bool] = []
	for camera in editor_cameras:
		camera_current_state.append(camera.current)

	var racer: HoverShip = game._editor_racers[0]
	var before := racer.position
	var before_time: float = world.time_of_day
	for step in 120:
		game._process(1.0 / 60.0)
	check(racer.position.distance_to(before) > 15.0, "racers move along the map in editor mode")
	check(world.time_of_day > before_time, "day/night clock advances in editor mode")
	check(world.road_distance(racer.position) < 24.0, "editor racer stays on the road")
	check(not racer.is_physics_processing() and racer.collision_layer == 4,
		"editor drives craft with explicit fixed simulation steps")
	var camera_state_unchanged := editor_cameras.size() == camera_current_state.size()
	for i in editor_cameras.size():
		camera_state_unchanged = camera_state_unchanged and editor_cameras[i].current == camera_current_state[i]
	check(camera_state_unchanged,
		"live racer and day-night simulation leaves editor camera state untouched")
	world.time_of_day = world.day_duration_seconds + 1.0
	game._process(0.0)
	check(world.street_lights[0].visible, "editor night cycle switches street lights on")
	var racers_count := game.get_node("Vehicles").get_child_count()
	game._ready_editor_simulation()
	check(game.get_node("Vehicles").get_child_count() == racers_count,
		"reinitializing does not duplicate editor racers")
	game.coast = null
	game._editor_racers.clear()
	game.brains.clear()
	game._process(0.0)
	check(game._editor_racers.size() == 4 and game.get_node("Vehicles").get_child_count() == 4,
		"editor processing restores preview after script reload without duplicates")
	var reloaded_cameras: Array[Camera3D] = []
	_collect_cameras(game, reloaded_cameras)
	check(reloaded_cameras.all(func(camera: Camera3D) -> bool: return not camera.current),
		"script reload does not activate a gameplay camera in the editor")
	var automatic_start: Vector3 = game._editor_racers[0].position
	await create_timer(0.2).timeout
	check(game._editor_racers[0].position.distance_to(automatic_start) > 1.0,
		"racers animate automatically without directly calling process")
	check(game.brains.size() == 4 and game.brains[0].race_time > 0.0, "real race brains advance in editor mode")
	check(racer.forward_speed > 0.0, "shared craft driving model accelerates racers")
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

func _collect_cameras(node: Node, cameras: Array[Camera3D]) -> void:
	if node is Camera3D:
		cameras.append(node as Camera3D)
	for child in node.get_children():
		_collect_cameras(child, cameras)
