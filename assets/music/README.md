# Neon Pursuit music

77 full-length MP3 tracks: all seven themes in each of eleven genres, generated with Runway. The audio files are stored directly in Git; `git pull --ff-only origin main` downloads them without ZIP extraction or Git LFS.

Open `all-tracks.m3u` in VLC or another playlist player, or open any MP3 in the genre folders. Each genre includes `playlist.m3u` with seven tracks.

Track filenames use `Title - Genre.mp3` (for example, `Afterglow - Acoustic.mp3`) so each version is identifiable even outside its genre folder.

`manifest.json` records each source task, duration, byte count, and SHA-256 checksum. These files are for direct listening; the game's existing synthesized radio remains unchanged.
