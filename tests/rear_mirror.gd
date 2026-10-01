extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://mirror_test.cfg"
	root.add_child(game)
	await process_frame
	game.player.set_physics_process(false)
	assert(game.rear_viewport.world_3d == game.get_viewport().world_3d)
	assert(game.rear_mirror.flip_h)
	assert(game.rear_mirror.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(game.rear_mirror.visible)
	assert(game.camera.get_viewport() != game.rear_camera.get_viewport())
	for heading in [0.0, PI/2.0, PI, -PI/2.0]:
		game.player.reset_to(Vector3(100,3,100),heading)
		await physics_frame
		await process_frame
		game._camera_follow(1.0)
		var pose: Transform3D = game.player.get_global_transform_interpolated()
		var back: Vector3 = pose.basis.z.normalized()
		assert((-game.rear_camera.global_basis.z).dot(back) > 0.999)
		assert(game.rear_camera.global_position.distance_to(pose.origin+back*4.0+Vector3.UP*2.0) < 0.01)
	game._set_hud_visible(true)
	assert(not game.rear_mirror.visible)
	assert(game.rear_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	game._set_hud_visible(false)
	assert(game.rear_mirror.visible)
	assert(game.rear_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	game.ui.size = Vector2(320,240)
	game._layout_rear_mirror()
	assert(game.rear_mirror.size.x <= 320)
	assert(is_equal_approx(game.rear_mirror.size.x/game.rear_mirror.size.y,4.0))
	print("PASS: rear mirror world, direction, tracking, menu and resize")
	quit()
