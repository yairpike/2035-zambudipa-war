# Unit and structure models

Drop a file here and the match uses it instead of the procedural mesh.

`res://game/models/<id>.glb` or `res://game/models/<id>.gltf`

`<id>` is the unit id (`militia`, `amber_tank`) or the building id (`barracks`, `war_factory`). A structure spawned as `Built_barracks` looks up `barracks`. Anything else uses the node name in lower case, so the yard block looks for `playeryard`. A missing file keeps the procedural mesh.

## Space

- 1 unit = 1 metre.
- Up is +Y.
- Forward is -Z, the same axis the procedural meshes face. Do not export the model facing +Z.

The game measures the procedural mesh, then uniformly scales a unit so its horizontal footprint fits inside that mesh, and sits the model's base on the procedural mesh's lowest point. A building with an authored size fills the footprint on X and Z separately, keeping that aspect, and uses the tighter of those scales for its height. A `Wake` node is left out of that measurement so foam behind a hull does not shrink the boat.

## Optional nodes

These names are case-sensitive. Leave them out when the unit has no moving part.

| Node | Where it sits | What the game does |
| --- | --- | --- |
| `Turret` | Direct child of the scene root | Parented to `Body` and yawed toward the target |
| `Barrel` | Child of `Turret` | Yaws with the turret |
| `Rotor` | Direct child of the scene root | Spun while the unit is alive |
| `Wake` | Direct child of the scene root | Shown while a boat is moving |

## Budget

The stand-ins in this folder were built to these limits. Two or three materials are allowed.

- Infantry: 1,500 triangles.
- Vehicles: 3,000 triangles.
- Buildings: 5,000 triangles.

`Body` carries one small grey palette so the faction primary can multiply it. `Trim` is a flat accent. `Wake` is white foam.

## Faction colour

A grey stand-in multiplies `Body` by about 60% of the faction primary, mixed into a dark ground so the palette shading stays visible. MVD's charcoal and Black Market's near-black are lifted first, so they do not multiply down to plain grey. A textured model in `models/tripo/` is preferred over the stand-in of the same id. Its `Body` keeps the texture and takes only a light faction wash. `Trim` is set to the faction accent on both. `Wake` is not recolored. A frozen loaded model draws the ice shader as an overlay and does not replace those materials.

## Web

`.glb` and `.gltf` files in this folder are left out of the web pack. The export copies them to `models/` beside the page, with `models/index.txt`, and copies a Tripo file over the stand-in of the same name. The page does not download them at startup. A match fetches the index, then each model when that unit or building appears, and writes it under `user://models/` (Tripo files under `user://models/tripo/`). The parsed file is kept, so later copies of that unit do not read it again. The procedural mesh stays in place until that file is on disk.

## Shipped Tripo files

`tripo/`, `env/`, and `rigged/` hold simplified copies: about half the triangles of the generated originals, textures capped at 512 px, with every named node, material, skin, and clip kept. `bash tools/optimize_models.sh` rebuilds them from the full-detail originals at commit `20332a0`. Run it again, rather than editing a file by hand, after replacing an original. The game builds mipmaps for these textures when it loads them, and halves them again on Low graphics.

CC0 stand-in credits are in `CREDITS.md` next to the models.
