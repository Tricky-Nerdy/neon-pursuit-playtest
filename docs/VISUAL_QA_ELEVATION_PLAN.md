# Visual QA and elevation release gates

Baseline: Godot project config reports game 0.7.1, map 5.0. Preserve the current map layout and neon building lighting.

## Patch release: visual defects
- Floating trees: compare each tree base world Y to terrain surface Y at its world X/Z; flag positive gaps and underground placements. Check mesh pivot and collision separately.
- Shadows: inspect directional light settings, shadow bias, normal bias, cascade ranges, mesh normals and transparency; compare screenshots at multiple times of day.
- Run Godot headless editor import and project checks, then launch playable scenes and capture screenshots from fixed camera positions. A passing headless test does **not** count as visual verification.
- Validate roads, spawn points, music, events and collision after corrections.
- Capture before/after images and log observed results. No bug is 'fixed' until both code and rendered validation pass.

## Next major release: terrain elevation
- Keep current X/Z road graph, districts, building placement and map footprint.
- Introduce a deterministic height sampler with smooth rolling hills and canyon/mountain regions; reserve flatter masks under city blocks and critical road intersections.
- Project trees and terrain props onto sampled ground heights. Rebuild road meshes, terrain collision and vehicle/navigation height alignment; bridges/tunnels need explicit treatment.
- Add slope, clearance, collision and spawn tests, plus screenshot comparisons and drive-through checks.
- Gate release on mobile performance and Godot Android playability.

Status: planning baseline only; no rendering or automated tests executed yet.
