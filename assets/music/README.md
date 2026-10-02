# Neon Pursuit music

87 full-length MP3 tracks generated with Runway, playing on twelve in-game radio stations. The audio files are stored directly in Git; `git pull --ff-only origin main` downloads them without ZIP extraction or Git LFS.

Open `all-tracks.m3u` in VLC or another playlist player, or open any MP3 in the genre folders. Each genre includes `playlist.m3u`. Eleven stations have the original seven themes; STATIC FM adds Alternative rock versions of those themes plus Copper Sky, Midnight Causeway and Saltwater Signal (ten tracks).

| Station / album | Genre | Tracks |
| --- | --- | --- |
| AURORA JAZZ | Swing jazz | 7 |
| NEON FM | Synth-pop | 7 |
| COASTLINE PUNK | Punk rock | 7 |
| NIGHT DRIVE | Synthwave | 7 |
| PORCHLIGHT FM | Acoustic | 7 |
| CEDAR ROAD RADIO | Americana | 7 |
| MIRAGE FM | Chillwave | 7 |
| REDLINE RADIO | Drum and bass | 7 |
| WILLOW CREEK FM | Folk | 7 |
| HARBOR HOUSE | House | 7 |
| ISLAND DAWN RADIO | Island reggae | 7 |
| STATIC FM | Alternative rock | 10 |

Track filenames use `Title - Genre.mp3` (for example, `Afterglow - Acoustic.mp3`) so each version is identifiable even outside its genre folder.

`manifest.json` records each source task, duration, byte count, and SHA-256 checksum. The added Alternative tracks are tagged with artist/album artist **Neon Pursuit OST** and album **STATIC FM**.

The game builds station playlists from this manifest and loads one MP3 at a time. Tracks play alphabetically, advance automatically, and wrap at the end of each station. Changing stations retains each station's track index during the session and starts that track from the beginning. The existing menu arrows, saved station selection and music volume control work with all twelve stations. Playback is offline; exported builds bundle the manifest and imported audio resources.
