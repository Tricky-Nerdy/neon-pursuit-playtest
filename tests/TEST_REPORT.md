# Aurora Bay 4.1 — Playtest merge verification

2026-09-28. Godot 4.7.2 stable, Linux x86_64, headless, fixed 60 FPS and 60 Hz physics.

**162 automated checks passed, zero failures.** Captured suite output is in `reports/`.

| Suite | Checks | Result |
| --- | ---: | --- |
| run_all | 39 | Controls, camera, missions, scoring, saves, retry, craft swap and hidden driving HUD passed |
| input_devices | 30 | Uploaded settings, keyboard devices, mouse, analog triggers, deadzones, gamepad, menu focus, retry and cast-size UI passed |
| ai_endurance | 32 | Four physical rivals complete multiple laps on all four routes; test duration accounts for uploaded craft speeds |
| mission_scenarios | 18 | Circuits, checkpoint, pursuit, drift, elimination and speed-trial events complete |
| police_scenarios | 20 | Replanning, bounded movement, road following and lost-sight search passed |
| world_integrity | 23 | Roads, scenery clearance, terrain, shoreline recovery, difficulty and persistence passed |

## Map-specific evidence

- 8,440.1 m of connected roads; 5,094.0 m main circuit; 359 navigation nodes.
- Terrain peak 196.2 m. Irregular coastline and inland reservoir replace both oval ground discs.
- Every road center stays within the new recovery boundary; the northern extension is explicitly checked against the former oval clipping bug.
- Ray checks find no scenery blocking the center or either driving lane on any road. All four mission circuits follow built roads.
- Terrain, roads and collisions are generated from the same authored layout. Road-facing triangle winding passes.
- 2,347 scenery object/detail elements. Repeated Blender prop instances are grouped into 23 mesh batches.
- All four full circuit driving scenarios earned gold. Drift earned silver through actual slides; elimination survived all four rounds; speed trial hit all six targets.

Drivers use actual CharacterBody3D ship physics, steering, throttle, brake, boost and drift. They do not teleport through gates. Synthetic failure-state tests are separately identified in their source. Tests use isolated save and telemetry filenames.

## Geometry review and limitations

Headless Blender 4.5.4 renders of the exported live scene are included in `geometry_review/`: overhead map, road, city, canyon and ridge views. They verify scenery, terrain and placement, not final Godot lighting. The exporter omits Label3D text and replaces the water shader for review.

No physical Android device or graphics display was available. No manual Android play, in-engine visual review, GPU frame-rate measurement, controller hardware check or phone touch-hardware validation is claimed. Road height and hover physics remain level; the mountains provide surrounding terrain relief.

Export templates, an Android signing key and Windows export host were unavailable here, so native PC/APK exports were not generated or claimed. The project source has been imported and tested in Godot 4.7.2. The automatic release workflow performs tagged platform exports after the branch is pushed; its Android job requires the persistent tester key described in `PLAYTESTER_GUIDE.md`.
