# Aurora Bay visual and world expansion — 2026-10-15

Status: Approved direction from Grace; implementation pending measured changes. Preserve existing stylized, adorable, approachable art and color palette.

## World content
Expand island roads and navigable neighborhoods with city blocks, side paths, parking lots, sidewalks, highways, boulevards, avenues, varied residential/commercial areas, and a richer tree palette (flowering/broadleaf/colorful species as well as existing palm and pine). Build modular road/intersection/sidewalk kits and reuse assets through instancing. Preserve driving feel and current content.

## Materials and atmosphere
Improve texture quality, UV mapping, material consistency, PBR where appropriate, sky, clouds, reflections, and water. Prefer art-directed inexpensive effects over brute-force GPU cost. Profile mobile and desktop separately. HDR and reflections require compatibility checks. Aesthetic percentage gains do not imply proportional GPU savings.

## Day/night and lighting
The README describes 7 minutes of daylight and 4 minutes of night. Retain the day/night cycle and optimize transitions. Investigate flickering headlights and streetlights by isolating shadow settings, overlapping lights, depth/z-fighting, and light-controller scripts. Record reproduction conditions before changing behavior. Evaluate baked/static GI or lightmaps only for suitable stationary assets and supported renderer; use selective local real-time shadows for dynamic vehicles. Measure frame time, memory, and draw calls before/after each pass.

## Verified repository context
Project: Tricky-Nerdy/neon-pursuit-playtest. project.godot identifies Godot 4.x Mobile feature; README describes Android/Windows/Linux targets and Aurora Bay 5.0. Renderer-dependent features must be verified against actual Godot version and hardware.

## Execution checklist
1. Reproduce and characterize flicker on desktop and Android.
2. Capture baseline FPS/frame time, draw calls, GPU memory, lighting and shadow costs.
3. Prototype one textured block and a varied vegetation cluster.
4. Prototype sky/day-night transitions and compare before/after performance.
5. Expand connected roads incrementally, checking navigation, races and collision.
6. Validate on phone and PC; merge only after tests and review.

## Provenance
Source: Grace's voice discussion on 2026-10-15. This document records approved creative direction, not completed engine changes. Do not overwrite newer unsynced Omarchy work.
