extends SceneTree

const RadioScript = preload("res://scripts/radio.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var radio = RadioScript.new()
	root.add_child(radio)
	assert(radio.station_names().slice(0, 4) == ["AURORA JAZZ", "NEON FM", "COASTLINE PUNK", "NIGHT DRIVE"])
	var total := 0
	for index in RadioScript.STATIONS.size():
		var tracks: Array = radio.playlists[index]
		assert(tracks.size() == (10 if index == 11 else 7))
		for path in tracks:
			var audio = radio.load_track(path)
			assert(audio is AudioStreamMP3 and audio.get_length() > 60.0)
			assert(not audio.loop)
			total += 1
	assert(total == 87)

	# Exercise real end-of-stream delivery, not just the callback in isolation.
	radio.tune(11)
	var first: AudioStream = radio.stream
	radio.seek(first.get_length() - 0.05)
	for frame in 300:
		if radio.track_indices[11] == 1:
			break
		await create_timer(0.01).timeout
	assert(radio.track_indices[11] == 1 and radio.playing)
	assert(radio.stream != first)
	var second: AudioStream = radio.stream
	radio.tune(11)
	assert(radio.stream == second, "Retuning the current station must not restart it")
	radio.track_indices[11] = 9
	radio.finished.emit()
	assert(radio.track_indices[11] == 0 and radio.playing)
	radio.stream_paused = true
	radio.tune(0)
	assert(radio.stream_paused)
	radio.tune(0)
	assert(radio.stream_paused)
	radio.stream_paused = false
	assert(radio.playing)
	radio.tune(-1)
	assert(radio.station == 11)
	radio.tune(12)
	assert(radio.station == 0)
	radio.queue_free()
	await process_frame
	# Let the audio mixer release stopped playbacks before engine shutdown.
	await create_timer(0.1).timeout
	print("PASS: 87 bundled MP3s, 12 stations, automatic advance, wraparound and muted tuning")
	quit()
