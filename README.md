# Neon Pursuit: Aurora Bay

An open-map arcade pursuit racer for Android and PC. Cruise a connected coastal world, jump into an event instantly, and swap craft or modes without leaving the drive. The current playtest build includes seven event types, four districts, three ships, AI rivals, police pursuits, persistent medals and instant retries.

## Aurora Bay

The map connects 8.44 km of roads through the coast, harbor, canyon and airfield. The main route is 5.09 km, with an irregular shoreline, inland reservoir, ridge tunnel, city blocks, piers and a container yard. Roads and driving physics stay level; the mountains add terrain relief rather than jump physics.

### Scene review renders

These are renders of the exported game scene used to review map layout and geometry. They are not in-game gameplay screenshots.

| Map overview | Driving view | City district |
| --- | --- | --- |
| ![Aurora Bay map layout](tests/geometry_review/map.png) | ![Road and player craft scene review](tests/geometry_review/road.png) | ![City street scene review](tests/geometry_review/city.png) |

## Driving and events

- **Free Roam** for uninterrupted exploration.
- **Bay Sprint** and **Coast Circuit** against AI rivals.
- **Checkpoint Rush** with time added at each gate.
- **Pursuit** with road-network police and search behavior.
- **Drift Rush** where slides build a combo that must be banked.
- **Elimination** and **Speed Trial** for short score-chasing runs.

Choose Coast, Harbor, Canyon or Airfield. Events have levels, medals and saved records. Retry resets straight to the action; there are no race intro sequences. The compact driving HUD stays clear of diagnostic text; use **F3** (or the bottom menu button on touch) for the event and craft menu.

Touch, keyboard, mouse, and gamepad input are supported. The camera follows close behind the craft. The look uses stylized 3D geometry, sky lighting, shadows, fog, emissive road markings and reflective water. Real-time global illumination is not currently implemented.

## Developers

### Requirements and launch

- Godot **4.7.2** and matching export templates for official builds.
- Open `project.godot` in Godot and press Play, or launch with `run_game_linux.sh` / `run_game_windows.cmd`.
- All runtime models are included in `assets/`. Editable Blender sources and generation scripts are in `tools/`; no extra asset packs are required.

### Tests and diagnostics

See [`tests/TEST_REPORT.md`](tests/TEST_REPORT.md) for the latest automated results and known limits. Run the suites from the project root:

```sh
godot --headless --editor --path . --import --quit
for suite in run_all input_devices ai_endurance mission_scenarios police_scenarios world_integrity; do
    godot --headless --path . --fixed-fps 60 --script "tests/$suite.gd" || exit 1
done
```

Runtime events and periodic performance samples are written to `user://neon_pursuit.log`; the game does not add a debug bar to the driving view. `tests/render_capture.gd` captures the running game when launched with a graphical display. The images in `tests/geometry_review/` are scene geometry reviews and should not be presented as gameplay captures.

### Playtesters

Playtest setup, controls, TV connection, release downloads and update/signing notes are in the [Playtester Guide](PLAYTESTER_GUIDE.md). Windows and Linux prereleases are built from version tags. Android release builds require the persistent tester signing key described in that guide.

## Project notes

This is a playable prototype and playtest project, not a finished commercial release. Android store distribution and silent updates are not configured. No code or assets from G-Zero, EVE, WipEout or NFS are distributed.
