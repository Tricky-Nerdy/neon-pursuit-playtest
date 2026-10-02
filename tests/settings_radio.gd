extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://settings_test_progress.cfg"
	game.settings_path = "user://settings_radio_test.cfg"
	DirAccess.remove_absolute(game.settings_path)
	root.add_child(game)
	await process_frame
	game._set_hud_visible(true)
	game._show_settings()
	assert(game.settings_page.visible and not game.main_menu_page.visible and not game.events_page.visible)
	game._set_music_volume(0.0)
	assert(game.radio_player.stream_paused)
	game._set_music_volume(0.35)
	game._toggle_mirror()
	game._toggle_vsync()
	game._cycle_touch_layout()
	game._cycle_radio(1)
	assert(game.radio_player.playing)
	assert(game.radio_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	var first = game.radio_player.stream.data
	game._cycle_radio(1)
	assert(first != game.radio_player.stream.data)
	game.music_volume = 1.0
	game.mirror_enabled = true
	game.vsync_enabled = true
	game.touch_layout = "compact"
	game.radio_index = 0
	game._load_settings()
	assert(is_equal_approx(game.music_volume,0.35))
	assert(not game.mirror_enabled and not game.vsync_enabled)
	assert(game.touch_layout == "full" and game.radio_index == 2)
	game._set_hud_visible(false)
	assert(not game.rear_mirror.visible)
	assert(game.rear_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	game._toggle_mirror()
	assert(game.rear_mirror.visible)
	for index in 4:
		game.radio_player.tune(index)
		assert(game.radio_player.stream.data.size() > 0)
		assert(game.radio_player.stream.loop_end*2 == game.radio_player.stream.data.size())
	game._show_main_menu_page()
	assert(not game.settings_page.visible)
	DirAccess.remove_absolute(game.settings_path)
	game.queue_free()
	await process_frame
	print("PASS: settings navigation, saved options, mute, mirror and four radio loops")
	quit()
