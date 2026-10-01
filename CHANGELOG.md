# Neon Pursuit development history

## Version policy

Game version: `application/config/version` in `project.godot`; Android's export version name must match. Map revision: `application/config/map_version`. The HUD and telemetry read map/build labels from these settings.

Use patch versions for fixes, minor versions for substantial playable features, and major versions for a stable breaking milestone. Increment the map revision for an authored layout/content milestone; a rendering correction alone leaves Aurora Bay 5.0 unchanged. Android version codes are separate installation counters and are assigned by the release workflow.

Versions here describe development checkpoints. No release tags existed when this history was written on October 1, 2026. A version label does not imply exported binaries or an Android release. The legacy application name is retained because it determines the existing user save directory.

## 0.6.3 — 2026-10-01 — Aurora Bay 5.0

Rendering implementation: [8588695](https://github.com/Tricky-Nerdy/neon-pursuit-playtest/commit/85886954e053e62bfb5b4e0dabe0d976410473c1).

- Disable distance fog and use explicit ambient fill for nighttime visibility.
- Anchor broad, low-contrast water swells to world coordinates, eliminating camera-space stripes.
- Increase camera near-plane distance to improve depth precision; use a larger near plane for the overhead capture.
- Stop full lane/edge stripes before joining roads, including stripes whose endpoints enter a junction.
- Replace spawn-based images with authored coast, harbor, canyon, airfield, night and whole-map compositions. Place driving ships on road centerlines with matching headings.
- Publish six new 1920 × 1080 real Godot PNGs in the README.
- Align project version, Android version name, runtime labels and documentation.

Validation of the rendering implementation: gameplay suite 41 checks and world-integrity suite 23 checks passed; night-lighting, capture-setup and world-rendering regression tests passed; all six PNGs passed integrity, size and uniqueness checks and were visually inspected. These are Linux checks, not a claim of new Android/device validation or a new release build.

## 0.6.2 — 2026-10-01 — documented playtest milestone

Explicit version documentation: [d2bc88d](https://github.com/Tricky-Nerdy/neon-pursuit-playtest/commit/d2bc88d). Lighting fixes include [9abba51](https://github.com/Tricky-Nerdy/neon-pursuit-playtest/commit/9abba51) and [006e95e](https://github.com/Tricky-Nerdy/neon-pursuit-playtest/commit/006e95e). Six-image capture implementation: [24c38c6](https://github.com/Tricky-Nerdy/neon-pursuit-playtest/commit/24c38c65383229ccef387011fe16d9f5e86e0233).

Vehicle headlights, overhanging street illumination, visible regression steps and independent graphical capture. Import the project before running capture to register Godot script classes. Wait for updated physics poses and completed rendered frames before saving images.

## 0.6.1 / 0.6.0 — retrospective milestones, 2026-10-01

These labels organize overlapping work and were not tags or independently published releases.

- 0.6.1: tunable day/night cycle fix [8b3e433](https://github.com/Tricky-Nerdy/neon-pursuit-playtest/commit/8b3e433), headlights [8665ef8](https://github.com/Tricky-Nerdy/neon-pursuit-playtest/commit/8665ef8), road lighting [bde647b](https://github.com/Tricky-Nerdy/neon-pursuit-playtest/commit/bde647b).
- 0.6.0: reusable ship scene [002be79](https://github.com/Tricky-Nerdy/neon-pursuit-playtest/commit/002be79), readable main scene [9b6b1e4](https://github.com/Tricky-Nerdy/neon-pursuit-playtest/commit/9b6b1e4), gameplay binding [69ca00d](https://github.com/Tricky-Nerdy/neon-pursuit-playtest/commit/69ca00d).

## Unversioned imported baseline — 2026-09-28

Repository begins at [60b14fb](https://github.com/Tricky-Nerdy/neon-pursuit-playtest/commit/60b14fb), importing an existing Aurora Bay 4.0 game. The preserved September 28 test report refers to Aurora Bay 4.1. Subsequent commits add playtester controls/release tooling, editable Blender sources and day/night sky work.

The imported project retained older application metadata. That metadata is not evidence of separate releases in this repository. Aurora Bay 1–3 and v0.4.x/v0.5.x cannot be dated or reconstructed from the available commits, so no release history is invented for them.
