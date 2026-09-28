# NEON PURSUIT — Aurora Bay 4.0 — Broken Coast

Godot 4.7.2 hover racer for Android and PC. Explore 8.44 km of connected roads across the coast, harbor, canyon and airfield. Four selectable circuits, seven events, endless free roam and three original Blender-built ships.

## The map rebuild

The flat oval island is gone. An irregular shoreline wraps around a 5.09 km main route with headlands, inland bends and a northern mountain section. The complete network has 8.44 km of connected roads and four event circuits.

Sculpted terrain rises to 196 m around the roads, with a reservoir, forest clusters and a ridge tunnel. The driving routes remain level; this release adds surrounding terrain relief, not jump or elevation physics. The shore recovery boundary follows the new land shape, so northern and eastern roads are fully playable.

The waterfront now has a market, connected piers, yachts, cranes and a ribbed container yard. The city has stepped glass buildings with floor bands, mullions and rooftop equipment. A lighthouse, radar dishes, hangar and tower distinguish the outer districts. Original Blender models for six prop types are included with their editable sources.

Repeated model instances are combined into 23 mesh batches; roadside boxes are also grouped by material. The environment contains 2,347 placed object/detail elements. This is a geometry improvement, not a measured claim about Android frame rate.

## Open on Android

1. Extract this ZIP into a new folder.
2. In Godot Android, import `neon_pursuit_aurora_bay_v4/project.godot`, then Play.
3. Hold the phone sideways; sensor landscape is enabled.
4. Tap **≡** at the bottom center, or press **F3**, to pause and open missions, district selection, difficulty, craft swap and retry. The top information/debug bar stays hidden during play.
5. Left stick steers; pushing up accelerates. Right-side GO, BOOST, DRIFT and BRAKE support separate fingers. Brake takes priority over acceleration. Release drift to regain grip and bank your combo.

This is a Godot project, not an APK. Models are included; no additional asset packs, Blender installation or Termux edits are needed. The internal application name remains unchanged to preserve the existing save location.

## Events

Choose COAST, HARBOR, CANYON or AIRFIELD in the menu. Every district supports all events.

- **Free Roam:** explore the connected map with roaming pilots and coastal boost pads.
- **Bay Sprint:** a short race against two rivals.
- **Coast Circuit:** one full lap of the selected district against four rivals.
- **Checkpoint Rush:** every gate adds time; allowances scale with distance and difficulty.
- **Pursuit:** clear the marked route, then stay clear of police for six seconds. Officers chase, take road-network intercept routes and search your last known location after losing sight.
- **Drift Rush:** slide through corners for 60 seconds. Release the slide to bank points; hitting scenery loses the unbanked combo. Driving fresh distance is required.
- **Elimination:** the last pilot is eliminated every 20 seconds. Survive all four rounds.
- **Speed Trial:** six speed traps with increasing targets. Hit four to pass, five for silver or all six for gold.

Medals and personal records are saved separately by event, district and level. Rank points unlock five difficulty levels; select AUTO or any earned level. Retry restores the event start instantly. Craft swaps preserve the current event. There are no race intros.

Rivals use the same physical ship controller as the player. They brake for corners, choose passing lanes, manage boost and reverse out of trouble. Police use a connected road graph and line-of-sight checks. Neither system teleports to catch up.

Keyboard: WASD/arrows, Space boost, Shift drift, E/Tab next mode, Q craft, R retry, F3/Esc menu. Opening the menu or losing app focus pauses driving and mission timers.

## Camera and graphics

The close 9 m chase camera and physics interpolation from 2.1 are retained. The camera anchor stays level while the hull gently bobs. Resets clear interpolation history.

Mobile renderer, sky ambient light, directional shadows, fog, emissive markings and a water shader. This is stylized geometry, not real-time global illumination. Roads have continuous meshes; repeated scenery is batched by material. Rocks have collision and driving lanes are checked for obstructions.

## Testing and logs

See `tests/TEST_REPORT.md` and `tests/reports/`. From the project directory:

```sh
godot --headless --editor --path . --import --quit
for suite in run_all input_devices ai_endurance mission_scenarios police_scenarios world_integrity; do
    godot --headless --path . --fixed-fps 60 --script "tests/$suite.gd" || exit 1
done
```

Tests use isolated save/log filenames. Driving scenarios operate actual ship physics, steering, brakes and boost. Runtime structured events and periodic performance samples go to `user://neon_pursuit.log`, rotated at 512 KiB. Engine logging is enabled. These diagnostics do not add an in-game top bar.

Editable Blender sources and generation scripts are in `tools/`; Git history is included. Geometry review renders are labelled separately from gameplay. `tests/render_capture.gd` supports actual engine capture on a machine with a display.

Build details, controller/keyboard bindings, TV setup, automated releases and Android update signing are in `PLAYTESTER_GUIDE.md`. No code or assets from G-Zero, EVE, WipEout or NFS are distributed.
