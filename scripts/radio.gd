extends AudioStreamPlayer
# Keep the first four stations in their original order for saved selections.
const STATIONS := [
	{"name":"AURORA JAZZ", "genre":"Swing jazz"},
	{"name":"NEON FM", "genre":"Synth-pop"},
	{"name":"COASTLINE PUNK", "genre":"Punk rock"},
	{"name":"NIGHT DRIVE", "genre":"Synthwave"},
	{"name":"PORCHLIGHT FM", "genre":"Acoustic"},
	{"name":"CEDAR ROAD RADIO", "genre":"Americana"},
	{"name":"MIRAGE FM", "genre":"Chillwave"},
	{"name":"REDLINE RADIO", "genre":"Drum and bass"},
	{"name":"WILLOW CREEK FM", "genre":"Folk"},
	{"name":"HARBOR HOUSE", "genre":"House"},
	{"name":"ISLAND DAWN RADIO", "genre":"Island reggae"},
	{"name":"STATIC FM", "genre":"Alternative rock"},
]
const MANIFEST_PATH := "res://assets/music/manifest.json"
var station := -1
var playlists: Array = []
var track_indices := PackedInt32Array()

static func station_names() -> Array[String]:
	var names: Array[String] = []
	for entry in STATIONS:
		names.append(entry.name)
	return names

func _ready() -> void:
	track_indices.resize(STATIONS.size())
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	for entry in STATIONS:
		var tracks: Array[String] = []
		if manifest is Dictionary:
			for track in manifest.get("tracks", []):
				if track.get("genre", "") == entry.genre:
					tracks.append("res://" + str(track.path))
		tracks.sort()
		playlists.append(tracks)
		if tracks.is_empty():
			push_error("No music tracks for station: " + entry.name)
	finished.connect(_on_track_finished)

func _exit_tree() -> void:
	stop()
	stream = null

func tune(index: int) -> void:
	index = posmod(index, STATIONS.size())
	if station == index and (playing or stream_paused) and stream != null:
		return
	station = index
	_play_current_track()

func _play_current_track() -> void:
	# play()/stream replacement can clear pause, including when changing stations.
	var was_paused := stream_paused
	stop()
	stream = null
	var tracks: Array = playlists[station]
	for attempt in tracks.size():
		var path: String = tracks[track_indices[station]]
		# Only keep the current MP3 in memory, rather than caching the whole library.
		var audio := load_track(path)
		if audio != null:
			stream = audio
			play()
			stream_paused = was_paused
			return
		track_indices[station] = (track_indices[station] + 1) % tracks.size()
	stream_paused = was_paused
	push_error("No playable music for station: " + STATIONS[station].name)

func load_track(path: String) -> AudioStreamMP3:
	if not ResourceLoader.exists(path):
		push_warning("Missing radio track: " + path)
		return null
	var audio := ResourceLoader.load(path, "AudioStreamMP3", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamMP3
	if audio != null:
		audio.loop = false
	return audio

func _on_track_finished() -> void:
	if station < 0 or playlists[station].is_empty():
		return
	track_indices[station] = (track_indices[station] + 1) % playlists[station].size()
	_play_current_track()
