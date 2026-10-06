# Changelog

## Unreleased

- Filament upgraded to v1.77.2 (prebuilt `1.77.2-lumina.1`): Metal external image handles, correct
  Vulkan depth/stencil render-target format reporting. The material version stays 77. The prebuilt
  scripts re-apply the patches after a tag change (a forced checkout used to drop them silently).
- The WebAssembly module is built in CI (`.github/actions/filament-web`): `tool/web/build_host_tools.sh`
  exports Filament's host tools, the web scripts take `LUMINA_FILAMENT_SRC` (a patched source checkout,
  `tool/filament/build_prebuilt.sh --checkout-only`), `build_module.sh` reads the hook's current source and
  include lists again, and every release attaches `flutter-filament-web-<tag>.zip`.
- Filament upgraded to v1.77.0 (from a 1.75.0 release-candidate cut).
- `FilamentTransformManager.getTransformAt` implemented (new C function
  `filament_transform_manager_get_transform_i`); previously threw `UnimplementedError`.
- `FilamentAsset`: `renderableEntities`, `lightEntities`, `cameraEntities`, `resourceUris`
  (+ `*Count` getters) and `popRenderable()`.
- `Ktx1Bundle.getBlob`, `LinearImage.isValid`.
- `FilamentWidget.onFrame` callback reporting per-frame CPU and frame time.
- `filament_wireframe_set_color` is now declared in `src/gltf_c.h` so binding regeneration keeps it.
- Test fixtures (`blackjack_blender2.glb`, `attackhelicopter.entity.glb`, `YVO3D_44368.glb`) now live in `../test-assets/fixtures/`.
- Removed stray root binaries/scratch sources and the dead `flutter_filament_bindings_generated.dart` stub;
  README rewritten for the real package.

## 0.0.1 (2026-08-22)

- Initial import: engine, renderer, view, scene, entity/transform/renderable/light managers,
  materials and material instances, gltfio (asset loader, resource loader, animator, instances),
  image/ktx1/ktx2/imageio, IBL prefilter, camutils manipulators, editor primitives (gizmo, wireframe),
  smoke-report tooling with GPU 1 environment injection.
