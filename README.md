# Neon Pursuit: Aurora Bay

**Current build:** Neon Pursuit **v0.6.2**  
**Map:** Aurora Bay **5.0**  
**Branch:** `main`  
**Targets:** Android, Windows, Linux  
**CI:** Godot 4.7.2 regression suite gates release builds

An open-map arcade pursuit racer for Android and PC. Cruise a connected coastal world, jump into an event instantly, and swap craft or modes without leaving the drive. The current playtest build includes seven event types, four districts, three ships, AI rivals, police pursuits, persistent medals and instant retries.

## Aurora Bay

The map connects 8.44 km of roads through the coast, harbor, canyon and airfield. The main route is 5.09 km, with an irregular shoreline, inland reservoir, ridge tunnel, city blocks, piers and a container yard. Roads and driving physics stay level; the mountains add terrain relief rather than jump physics.

### Aurora Bay 5.0

Six new **1920 × 1080 screenshots captured from the running Godot game**, with runtime world geometry, lighting and UI. The coastal drive, harbor piers, canyon road, airfield, nighttime drive and overhead map use authored landmark views, road-aligned ship headings and fixed times of day.

**Coast — daytime driving**

![Coast — daytime driving](docs/screenshots/gameplay/coast-day.png)

**Harbor — piers and waterfront**

![Harbor — piers and waterfront](docs/screenshots/gameplay/harbor-day.png)

**Canyon — daytime driving**

![Canyon — daytime driving](docs/screenshots/gameplay/canyon-day.png)

**Airfield — hangar and control tower**

![Airfield — hangar and control tower](docs/screenshots/gameplay/airfield-day.png)

**Coast — nighttime headlights and streetlights**

![Coast — nighttime headlights and streetlights](docs/screenshots/gameplay/coast-night.png)

**Aurora Bay — overhead world view**

![Aurora Bay — overhead world view](docs/screenshots/gameplay/world-map.png)

## Driving and events

- **Free Roam** for uninterrupted exploration.
- **Bay Sprint** and **Coast Circuit** against AI rivals.
- **Checkpoint Rush** with time added at each gate.
- **Pursuit** with road-network police and search behavior.
- **Drift Rush** where slides build a combo that must be banked.
- **Elimination** and **Speed Trial** for short score-chasing runs.

Choose Coast, Harbor, Canyon or Airfield. Events have levels, medals and saved records. Retry resets straight to the action; there are no race intro sequences. The compact driving HUD stays clear of diagnostic text; use **F3** (or the bottom menu button on touch) for the event and craft menu.

Touch, keyboard, mouse, and gamepad input are supported. Android is a first-class playtest target; pushes to `main` run the regression suites before Android, Windows, and Linux build jobs are allowed to proceed. The camera follows close behind the craft. The look uses stylized 3D geometry, sky lighting, shadows, emissive road markings and reflective water. The built-in sky environment currently runs a 7-minute daylight and 4-minute night cycle. Real-time global illumination is not currently implemented.

## Version history

The repository history predates formal semantic versioning. The milestones below reconstruct the development lineage from the repository's Git history and map it into the current version scheme without rewriting the original commits.

| Game version | Map version | Historical milestone |
| --- | --- | --- |
| **v0.6.2** | **Aurora Bay 5.0** | Current playtest line: day/night environment, vehicle headlights, illuminated street fixtures, Android/PC playtest pipeline, regression-gated builds, and current map/fixture corrections. |
| **v0.6.1** | **Aurora Bay 5.0** | Lighting-development line: HDR/panorama sky work, environment tuning, tunable day/night cycle, and nighttime road/vehicle-lighting iteration. |
| **v0.6.0** | **Aurora Bay 5.0** | Readable Godot-project refactor: explicit World, Vehicles, Gameplay, UI and Camera structure; free-roam boot; four curated district spawn points; hover-ship scenes bound to scene nodes. |
| **v0.5.x** | **Aurora Bay 4.x** | Mature Aurora Bay playtest baseline: connected coast, harbor, canyon and airfield routes; events, AI rivals, police behavior, persistence, diagnostics and automated world-integrity testing. |
| **v0.4.x and earlier** | **Aurora Bay 1.x–3.x** | Earlier map/gameplay construction preserved in Git history, before the current map and project structure were formalized. |

Historical labels describe development milestones; the original commits remain the source of truth for exact file-level history. Going forward, release tags and Aurora Bay map revisions should be recorded when a milestone is cut so version history remains exact.

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

Runtime events and periodic performance samples are written to `user://neon_pursuit.log`; the game does not add a debug bar to the driving view. `tests/render_capture.gd` captures six views from the running game when launched with a graphical display. Reproduce and validate them with:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/render_capture_test.gd
godot --headless --path . --script tests/world_rendering.gd
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 --rendering-method gl_compatibility --script tests/render_capture.gd
python3 tests/verify_render_captures.py
```

The capture regression test checks scene loading, road-centered positions and headings, exact camera poses after teleporting, landmark framing and day/night lighting. `tests/world_rendering.gd` checks clear visibility and prevents road stripes crossing junctions. The world uses fog-free lighting, explicit night ambient fill and world-space water shading. Image validation rejects missing, damaged, flat or duplicate captures. CI runs capture independently of the gameplay suites and uploads all six PNGs. The images in `tests/geometry_review/` are scene geometry reviews and should not be presented as gameplay captures.

### Playtesters

Playtest setup, controls, TV connection, release downloads and update/signing notes are in the [Playtester Guide](PLAYTESTER_GUIDE.md). Windows and Linux prereleases are built from version tags. Android release builds require the persistent tester signing key described in that guide.

## Project notes

This is a playable prototype and playtest project, not a finished commercial release. Android store distribution and silent updates are not configured. No code or assets from G-Zero, EVE, WipEout or NFS are distributed.
