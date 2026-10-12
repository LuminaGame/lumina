[Türkçe](../../tr/lumina/cloth.md)

# Cloth

Flags, curtains, clothes on a line and sheets draped over things: a `LuminaClothComponent` turns a grid or a mesh asset into a soft body that the world's [physics](physics.md) subsystem simulates on the Jolt backend, collides with the level, simulating props and characters' capsules, takes wind, and is drawn from the simulated vertices every frame.

| Part | Where |
| :--- | :--- |
| Component (shape, pins, settings, drawing, properties) | `lib/src/physics/cloth/cloth_component.dart` |
| Geometry (grid, mesh welding, pieces, pin selection) | `lib/src/physics/cloth/cloth_geometry.dart` |
| Backend interface | `lib/src/physics/cloth/cloth_simulator.dart` |
| Jolt simulation | `lib/src/physics/jolt/jolt_cloth_simulator.dart` (soft bodies of [flutter_jolt](https://github.com/LuminaGame/tools/blob/main/docs/en/flutter_jolt.md)) |
| Garments on characters | `lib/src/physics/cloth/skinned_cloth_component.dart`, `lib/src/physics/jolt/jolt_cloth_skinning.dart` |
| Blueprint nodes | `lib/src/blueprint/node_library/cloth.dart`, `blueprint_function_library/cloth.dart` |

## The component

`LuminaClothComponent` is a scene component (a procedural mesh section of its own). Its **shape** is either:

- `meshAsset`: a static mesh `.glb` (Draco-compressed meshes too). It is parsed on a worker isolate; vertices at the same position (split along UV seams) are welded for the simulation, and a vertex the weld leaves out of every triangle is drawn with its nearest simulated neighbour. A mesh made of several unconnected pieces (a towel's body and its folded top) keeps them as separate pieces.
- otherwise a grid: `gridWidth` x `gridHeight` cm (default 200 x 150) of `gridColumns` x `gridRows` quads (24 x 18) in the local XY plane, facing +Z, its top edge centred on the component origin.

**Pins** keep vertices where the component puts them: `pinning` (`none`, `topEdge`, `bottomEdge`, `leftEdge`, `rightEdge`, `topCorners`; in every piece of a mesh, the vertices at that extreme of the piece) plus `pinnedVertices` (simulation vertex indices). Every step the pinned vertices are driven to the component's current world transform, so a cloth attached to a moving parent (a simulating body, a character, a bone socket) follows it and drags the rest. `pinVertex(i, pinned:)` pins or frees a vertex at run time without restarting the simulation; tethers built at the start keep holding a vertex near the vertices pinned then.

**Settings**: `massKg` (the whole cloth, default 1), `stiffness` (stretch, 0..1, 0.95), `bendStiffness` (0..1, 0.3; 0 bends freely), `damping` (0.5), `friction` (0.5), `thickness` (cm, the distance it keeps from surfaces, 1), `iterations` (8), `gravityScale` (1), `color` (linear RGB, or `#RRGGBB` from the editor), `castShadows`. Changing one of the simulation settings rebuilds the simulation from the rest pose.

**Cloth settings asset**: `clothSettingsAsset` names a cloth settings `.lmas` (a `LuminaClothSettingsDocument`, edited in the [Cloth settings editor](../lumina_ui/sub-editors/cloth-settings.md)); when the cloth is built its material, simulation, wind, motion and self-collision settings are replaced by the asset's (`applySettings`). A cloth that cannot read it keeps its own and logs why.

**Look**: the cloth is drawn with a lit, double-sided material in `color`. `baseColorTexture` (a texture `.lmas` or an image) is drawn on its UVs (the grid's run 0..1 across it; a mesh keeps its own), tinted by `color` (white leaves the texture's colours). `materialAsset` (a project material `.lmas` or `.filamat`, with the parameters and textures the Material Editor saved) is drawn instead. Both load once the cloth draws in a world (`lookReady`, `drawsLook`, `drawnMaterial`); one that cannot be read leaves the colour and is logged.

**Self-collision**: with `selfCollision` the cloth keeps `selfCollisionDistance` (cm, default 2) between its own layers: after every step a vertex that came that close to one of the cloth's triangles is pushed out and stops approaching it (Jolt soft bodies have no self-collision; flutter_jolt adds the pass). Vertices that close to a triangle at rest are its neighbours and are skipped. It costs time (about 0.3 ms per step for 441 vertices), so it is off by default; turn it on for cloth that folds onto itself (a sheet crumpling on the floor, a towel thrown over a rail).

**Wind**: `wind` (cm/s, runtime axes; authoring axes in properties and nodes), `windDrag` (per second, 1) and `windTurbulence` (0..1, gusts over time). The wind pushes each face along its normal by the part of the wind that hits it, so a flag lies flat in still air, droops, catches the wind and flutters; a face edge-on to the wind feels nothing.

**Motion**: `inertiaScale` (0..1, default 1) is how much of its owner's motion the cloth resists: 1 keeps all of its inertia in the world (it lags and swings when the owner moves or turns), 0 carries it rigidly with the owner, values between carry that share of each step's motion. A move of more than `teleportDistance` (100 cm) or a turn of more than `teleportRotation` (60 degrees) within one step is a teleport: the whole cloth, pins included, is carried along at once, so it never stretches across the jump.

**Run time**: `simulate` (off draws the rest pose, on starts from it), `reset()`, `isSimulating`, `ready` (the geometry is built), `geometry`, `currentSimPositions()`, `resolvePinnedVertices()`.

## How it is simulated

The physics subsystem keeps the world's cloths (`LuminaPhysicsSubsystem.cloths`, `addCloth` / `removeCloth`); the backend's `LuminaClothSimulator` (`LuminaPhysicsBackend.cloth`) simulates them. On Jolt each cloth is a Jolt soft body built at its centre from the rest pose at the component's transform: edge, shear and dihedral bend constraints, tethers (long range attachments) to the pinned vertices, the thickness as the vertex radius. The compliances are scaled by the vertices' inverse mass (`w = vertices / massKg`): stretch `1e-4 · w · (1/stiffness − 1)` (at least `1e-6 · w`), shear twice that, bend `4.5e-3 · w · (1/bendStiffness − 1)` (at least `1e-5 · w`), so a light cloth behaves like a heavy one and stays stable over sharp edges. Before every step the pins are driven and the wind applied; when the component draws (`onRenderPrep`) it reads the vertices and their normals in its own frame (computed natively) and updates its mesh section. The step itself runs on the Jolt world's stepping thread.

**Dart backend** (the web, builds without Jolt): there is no cloth simulator. The component draws its rest pose, `isSimulating` is false, and the engine log says once "Cloth needs the Jolt physics backend". Nothing else changes; the web build never reaches Jolt.

## Garments on characters

`LuminaSkinnedClothComponent` is cloth worn by an animated character: its vertices are skinned to the character's skeleton, so the garment moves with the animation and swings within a distance of where the skin puts it.

- **Garment**: `meshAsset` (a skinned `.glb` whose joints are named like the character's bones; its own weights are used) or a generated skirt around `waistBone` (`pelvis`, else `Hips`): `skirtLength` (45 cm), `waistRadius` (17) to `hemRadius` (34), `waistOffset` above the bone (6), `skirtColumns` x `skirtRows` (32 x 12). With `fitToBody` (default) each ring is widened until it clears the hip, spine and leg capsules at rest by the thickness plus 2.5 cm, and is never narrower than the ring above, so the legs and the hands at the hips stay outside. The waist follows the waist bone; toward the hem the weights blend (smoothly over the top 70 %) to the two nearest leg bones by `legFollow` (0..1, 0.5); the rest of the hem is pushed aside by the legs as they collide.
- **Freedom**: `maxDistance` (25 cm) at the garment's far end, `t^1.5` of it toward the top; the top stays on the body (hard skinned). `maxDistanceMap` (one value per simulation vertex, cm) replaces the falloff.
- **Backstop**: with `backstopDistance` (cm; null or negative: none) a vertex may go at most that far behind its skinned position, against the skin's normal, so the garment never folds into the body however the wind or a collision pushes it. The backstop is a sphere of `backstopRadius` (20 cm) behind the vertex; `backstopMap` gives per-vertex distances.
- **Painted maps**: with `paintedMaps`, a garment asset's vertex colours paint the maps: red is the fraction of `maxDistance`, green of `backstopDistance`.
- **Body**: with `collideWithBody` the character's limbs are capsules (the physics asset generated from the skeleton, as for ragdolls) that move with the animation every step and push the garment out. A cloth ignores the other bodies of its owner (the character's capsule) unless they are marked as its colliders.
- **Pose**: the component attaches itself to `mesh` and reads the animated pose as a pose modifier (it never changes it); nodes the mesh cannot address are taken at rest. The skeleton (`sampler`) is read from the mesh asset when not given.

On Jolt each step skins the soft body to the latest pose (`SkinVertices`, hard the first time) and moves the limb capsules (kinematic). The motion settings above apply: a share of the character's move or turn (`1 − inertiaScale`) carries the garment along before the step, and a teleport or a sudden turn (say 180 degrees within one frame) puts it back on the body with every vertex on its skinned position and no velocity. A pose taken before the character last moved (an animated mesh poses after the physics step, so its pose is a frame old) is carried to where the character is now, for the skin and the limb capsules alike: a late pose never pulls the garment back, and the limbs never sweep back through it. The garment ignores `pinning` (its pins are the hard-skinned vertices). Without Jolt it draws its rest pose.

Measured on the walking mannequin: the hands and forearms stay outside the skirt (deepest vertex 0.8 cm inside a hand capsule, less than the cloth's thickness), the legs within 1.3 cm, edges stretch at most 18 % mid-stride; a 3000-vertex garment steps in 1.3 ms at 120 Hz (8 iterations); a 416-vertex skirt costs 1.4 ms per 60 Hz frame for the whole scene. The same skirt fits a MetaHuman body (its skeleton uses the same bone names; the mannequin's walk retargeted with `GlbAnimationRetargeter`): hands within 0.05 cm, legs within 1.7 cm, at most 16 % stretch on the frame it turns round.

## Blueprints and the editor

Component type `LuminaClothComponent` (a scene component): the Blueprint editor adds it as **Cloth** (category Physics) with every setting above in the Details panel; `meshAsset` is an asset reference, `wind` a vector in authoring axes. The component mapping builds it in Play-In-Editor and generated games alike, and the properties are saved with the Blueprint (`toProperties` / `fromProperties`).

Both components' Details panels also have the look (Texture, Material), Self Collision and **Cloth Settings** (a cloth settings asset) fields.

Component type `LuminaSkinnedClothComponent` is added as **Skinned Cloth** (category Physics): attach it under the Skeletal Mesh that wears it (otherwise it is worn by the actor's first skeletal mesh). Its Details panel has the garment (`meshAsset`, waist bone, skirt size, fit to body), its freedom (max distance, leg follow, backstop distance and radius, painted maps, collide with body), the cloth material, wind and motion settings; a negative backstop distance is none. The per-vertex maps are properties too (`maxDistanceMap`, `backstopMap`), set from code or painted into the garment's vertex colours.

Nodes (category **Physics|Cloth**, acting on the cloths of the actor that runs them; Play-In-Editor and generated code give the same results):

| Node | Does |
| :--- | :--- |
| Set Cloth Wind (Wind, Drag) | sets every cloth's wind (authoring axes, cm/s) and drag |
| Set Cloth Simulation Enabled (Enabled) | turns the simulation off (rest pose) or on |
| Is Cloth Simulating → bool | true when any cloth of the actor is simulated |
| Reset Cloth | back to the rest pose at the current transform |
| Pin Cloth Vertex (Vertex, Pinned) | pins or frees a simulation vertex of the first cloth |

## Limits

- One material per cloth (one section).
- Self-collision is vertex against triangle: an edge can still slip through another edge of a coarse cloth.

---

[Previous: Ragdolls, falls and getting up](ragdoll.md) | [Up: lumina (engine core)](index.md) | [Next: AI](ai.md)
