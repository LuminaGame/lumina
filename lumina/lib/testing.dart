/// Test support of the lumina package: the shared smoke-test system
/// (`package:lumina_smoke`: the smoke-video rules and probe, the frame
/// recorders), lumina's `SmokeArtifacts` (lumina_smoke's plus
/// `renderRealAssetMedia`, which films real assets with Filament) and the
/// engine fixtures.
library;

export 'package:lumina_smoke/lumina_smoke.dart' hide SmokeArtifacts;

export 'src/testing/asset_project_fixture.dart';
export 'src/testing/import_folder_fixture.dart';
export 'src/testing/smoke_artifacts.dart';
export 'src/testing/smoke_render.dart';
