extends RefCounted

const MAX_LOG_BYTES := 512 * 1024
var path := "user://neon_pursuit.log"

func start() -> void:
    if FileAccess.file_exists(path):
        var reader := FileAccess.open(path, FileAccess.READ)
        if reader != null and reader.get_length() > MAX_LOG_BYTES:
            reader.close()
            var rotated := path + ".old"
            if FileAccess.file_exists(rotated):
                DirAccess.remove_absolute(ProjectSettings.globalize_path(rotated))
            DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(rotated))

func record(level: String, event: String, fields: Dictionary = {}) -> void:
    start()
    var entry := {"at_unix": Time.get_unix_time_from_system(), "level": level, "event": event, "data": fields}
    var line := JSON.stringify(entry)
    print("[NEON] ", line)
    var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
    if file == null:
        push_error("Could not write game log: " + path)
        return
    file.seek_end()
    file.store_line(line)
    file.close()
