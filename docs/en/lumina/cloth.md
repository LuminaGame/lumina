[Türkçe](../../tr/lumina/cloth.md)

# Cloth

Flags, curtains, clothes on a line and sheets draped over things: a `LuminaClothComponent` turns a grid or a mesh asset into a soft body that the world's [physics](physics.md) subsystem simulates on the Jolt backend, collides with the level, simulating props and characters' capsules, takes wind, and is drawn from the simulated vertices every frame.

| Part | Where |
| :--- | :--- |
| Component (shape, pins, settings, drawing, properties) | `lib/src/physics/cloth/cloth_component.dart` |
| Geometry (grid, mesh welding, pieces, pin selection) | `lib/src/physics/cloth/cloth_geometry.dart` |
| Backend interface | `lib/src/physics/cloth/cloth_simulator.dart` |
| Jolt simulation | `lib/src/physics/jolt/jolt_cloth_simulator.dart` (soft bodies of [flutter_jolt](https://github.com/LuminaGame/tools/blob/main/docs/en/flutter_jolt.md)) |
| Blueprint nodes | `lib/src/blueprint/node_library/cloth.dart`, `blueprint_function_library/cloth.dart` |

## The component

`LuminaClothComponent` is a scene component (a procedural mesh section of its own). Its **shape** is either:

- `meshAsset`: a static mesh `.glb` (Draco-compressed meshes too). It is parsed on a worker isolate; vertices at the same position (split along UV seams) are welded for the simulation, and a vertex the weld leaves out of every triangle is drawn with its nearest simulated neighbour. A mesh made of several unconnected pieces (a towel's body and its folded top) keeps them as separate pieces.
- otherwise a grid: `gridWidth` x `gridHeight` cm (default 200 x 150) of `gridColumns` x `gridRows` quads (24 x 18) in the local XY plane, facing +Z, its top edge centred on the component origin.

**Pins** keep vertices where the component puts them: `pinning` (`none`, `topEdge`, `bottomEdge`, `leftEdge`, `rightEdge`, `topCorners`; in every piece of a mesh, the vertices at that extreme of the piece) plus `pinnedVertices` (simulation vertex indices). Every step the pinned vertices are driven to the component's current world transform, so a cloth attached to a moving parent (a simulating body, a character, a bone socket) follows it and drags the rest. `pinVertex(i, pinned:)` pins or frees a vertex at run time without restarting the simulation; tethers built at the start keep holding a vertex near the vertices pinned then.

**Settings**: `massKg` (the whole cloth, default 1), `stiffness` (stretch, 0..1, 0.95), `bendStiffness` (0..1, 0.3; 0 bends freely), `damping` (0.5), `friction` (0.5), `thickness` (cm, the distance it keeps from surfaces, 1), `iterations` (8), `gravityScale` (1), `color` (linear RGB, or `#RRGGBB` from the editor), `castShadows`. Changing one of the simulation settings rebuilds the simulation from the rest pose.

**Wind**: `wind` (cm/s, runtime axes; authoring axes in properties and nodes), `windDrag` (per second, 1) and `windTurbulence` (0..1, gusts over time). The wind pushes each face along its normal by the part of the wind that hits it, so a flag lies flat in still air, droops, catches the wind and flutters; a face edge-on to the wind feels nothing.

**Run time**: `simulate` (off draws the rest pose, on starts from it), `reset()`, `isSimulating`, `ready` (the geometry is built), `geometry`, `currentSimPositions()`, `resolvePinnedVertices()`.

## How it is simulated

The physics subsystem keeps the world's cloths (`LuminaPhysicsSubsystem.cloths`, `addCloth` / `removeCloth`); the backend's `LuminaClothSimulator` (`LuminaPhysicsBackend.cloth`) simulates them. On Jolt each cloth is a Jolt soft body built at its centre from the rest pose at the component's transform: edge, shear and dihedral bend constraints, tethers (long range attachments) to the pinned vertices, the thickness as the vertex radius. The compliances are scaled by the vertices' inverse mass (`w = vertices / massKg`): stretch `1e-4 · w · (1/stiffness − 1)` (at least `1e-6 · w`), shear twice that, bend `4.5e-3 · w · (1/bendStiffness − 1)` (at least `1e-5 · w`), so a light cloth behaves like a heavy one and stays stable over sharp edges. Before every step the pins are driven and the wind applied; when the component draws (`onRenderPrep`) it reads the vertices and their normals in its own frame (computed natively) and updates its mesh section. The step itself runs on the Jolt world's stepping thread.

**Dart backend** (the web, builds without Jolt): there is no cloth simulator. The component draws its rest pose, `isSimulating` is false, and the engine log says once "Cloth needs the Jolt physics backend". Nothing else changes; the web build never reaches Jolt.

## Blueprints and the editor

Component type `LuminaClothComponent` (a scene component): the Blueprint editor adds it as **Cloth** (category Physics) with every setting above in the Details panel; `meshAsset` is an asset reference, `wind` a vector in authoring axes. The component mapping builds it in Play-In-Editor and generated games alike, and the properties are saved with the Blueprint (`toProperties` / `fromProperties`).

Nodes (category **Physics|Cloth**, acting on the cloths of the actor that runs them; Play-In-Editor and generated code give the same results):

| Node | Does |
| :--- | :--- |
| Set Cloth Wind (Wind, Drag) | sets every cloth's wind (authoring axes, cm/s) and drag |
| Set Cloth Simulation Enabled (Enabled) | turns the simulation off (rest pose) or on |
| Is Cloth Simulating → bool | true when any cloth of the actor is simulated |
| Reset Cloth | back to the rest pose at the current transform |
| Pin Cloth Vertex (Vertex, Pinned) | pins or frees a simulation vertex of the first cloth |

## Limits

- One material per cloth (a base colour, double-sided, no texture yet).
- Cloth collides with bodies and colliders; it does not collide with itself.
- Skinned garments that follow a character's skeleton are not built yet.

---

[Previous: Ragdolls, falls and getting up](ragdoll.md) | [Up: lumina (engine core)](index.md) | [Next: AI](ai.md)
