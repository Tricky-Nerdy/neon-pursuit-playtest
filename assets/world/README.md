# Original world prop kit

Six original low-poly assets generated for NEON PURSUIT in headless Blender 4.5.4:
pine, palm, lighthouse, crane, yacht and radar dish.

Rebuild from the project root:

```sh
blender -b --python tools/make_world_props.py
```

Editable .blend files live in tools/blender_source/. Models are exported with materials included; no external textures or asset packs are required. Each material group is joined before export. World instances are batched at runtime by mesh.
