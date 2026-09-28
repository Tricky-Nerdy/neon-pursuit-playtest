# Neon Pursuit playtest build

## Run on PC

Export `Windows Desktop` or `Linux Desktop` from Godot 4.7.2, or run `run_game_windows.cmd` / `run_game_linux.sh` with the Godot editor installed. The workflow creates self-contained Windows and Linux builds whenever a `v*` tag is pushed. Connect the PC directly to the TV over HDMI and enable the TV's Game mode for the most responsive show build.

## Controls

| Action | Keyboard / mouse | Controller |
| --- | --- | --- |
| Steer / drive | A/D or arrows; hold left mouse and drag to steer | Left stick / D-pad |
| Accelerate | W / Up or hold left mouse | Right trigger / right shoulder |
| Brake | S / Down or right mouse | Left trigger / left shoulder |
| Boost / drift | Space / Shift or middle mouse for boost | A / X |
| Menu / resume | F3 or Escape | Start; B backs out |
| Change mode / craft | E / Q | View / Back |
| Instant retry | R | Y |
| Full screen | F11 | — |

Touch driving stays compact by default; the expanded touch layout is an option in the F3 menu. The driving HUD and stats are hidden during play. F3 opens the mode, route, level, craft and retry menu. Session diagnostics are written to `user://neon_pursuit.log`, not drawn over the game.

## Phone to TV

For an S23 Ultra demo, use a USB-C-to-HDMI adapter/cable into the TV, open the Android build in landscape, and pair a gamepad over Bluetooth (or USB if supported by the adapter). Samsung DeX can show the phone app on an HDMI display. Wireless mirroring is available but adds another link to the display path; direct PC-to-TV HDMI is the better choice for a low-latency live demo.

## Tester updates

Push a version tag such as `v0.1.0` after the automated test job passes. GitHub Actions then attaches Windows and Linux builds to a prerelease. Each build includes the map and game data; it does not need an extra asset pack. Android release builds are gated on a persistent tester signing key. Set repository variable `ENABLE_ANDROID_RELEASE=true` and secrets `ANDROID_TESTER_KEYSTORE_BASE64`, `ANDROID_TESTER_KEY_ALIAS`, and `ANDROID_TESTER_KEY_PASSWORD` before tagging. Keep the keystore safe: every Android update must use the same signing key and a higher version code.

Create the keystore once on a trusted computer with `keytool -genkeypair -v -keystore neon-pursuit-testers.keystore -alias neon-pursuit-testers -keyalg RSA -keysize 2048 -validity 10000`. Store the alias and password in the matching repository secrets, then base64-encode the keystore into `ANDROID_TESTER_KEYSTORE_BASE64`. Never commit or send the keystore or its password in chat.

GitHub prerelease downloads are manual installs. Android requires the tester to accept the package installer; silent APK replacement is not available to an ordinary app. Automatic Android installation updates require a Play Console internal-testing track and tester opt-in. Windows/Linux builds are published automatically on each version tag, but replacing an installed build is still a tester action. The source is in the private [`neon-pursuit-playtest`](https://github.com/Tricky-Nerdy/neon-pursuit-playtest) repository on `main`.

## Build and test

Use the included Godot 4.7.2 engine and export templates. Run `tests/run_all.gd`, `tests/input_devices.gd`, `tests/ai_endurance.gd`, `tests/mission_scenarios.gd`, `tests/police_scenarios.gd`, and `tests/world_integrity.gd` headlessly; see `tests/TEST_REPORT.md` for the latest recorded run.
