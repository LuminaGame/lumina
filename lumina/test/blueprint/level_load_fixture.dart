import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

/// A project with two levels written as Lumina Studio writes
/// them. `L_First` holds a barrel and a player start; `L_Second` names six
/// distinct assets — two meshes, a placed `BP_Crate` Blueprint whose
/// component names a third mesh, a sound and a sky image — every one a real
/// file (the meshes are test-assets props).

const String levelFirstPath = 'contents/levels/L_First.lmas';
const String levelSecondPath = 'contents/levels/L_Second.lmas';
const String levelBrokenPath = 'contents/levels/L_Broken.lmas';
const String crateClassPath = 'contents/blueprints/BP_Crate.lmas';
const String acUnitPath = 'contents/meshes/ac_unit_b_600x600.glb';
const String dentedBarrelPath = 'contents/meshes/dented_barrel.glb';
const String redBarrelPath = 'contents/meshes/fuel_barrel_red.glb';
const String chimePath = 'contents/audio/chime.wav';
const String skyPath = 'contents/textures/sky.png';
const String missingMeshPath = 'contents/meshes/missing_crate.glb';

/// The six assets of L_Second, by their bundle paths.
const List<String> levelSecondAssets = [acUnitPath, dentedBarrelPath, crateClassPath, redBarrelPath, chimePath, skyPath];

/// The test-assets props the meshes are copied from.
Map<String, String> levelLoadSourceMeshes() => {
      acUnitPath: '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/AC_units/ac_unit_b_600x600.glb',
      dentedBarrelPath: '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Barrels/dented_barrel.glb',
      redBarrelPath: '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Barrels/fuel_barrel_red.glb',
    };

Map<String, dynamic> _actor(String id, String type, List<double> location, [Map<String, dynamic> extra = const {}]) => {
      'id': id,
      'name': id,
      'type': type,
      'location': location,
      'rotation': [0.0, 0.0, 0.0],
      'scale': [1.0, 1.0, 1.0],
      ...extra,
    };

List<Map<String, dynamic>> levelFirstActors() => [
      _actor('PlayerStart', 'PlayerStart', [0.0, -600.0, 100.0]),
      _actor('Barrel', 'StaticMesh', [0.0, 0.0, 0.0], {'meshAssetPath': redBarrelPath}),
    ];

List<Map<String, dynamic>> levelSecondActors() => [
      _actor('PlayerStart', 'PlayerStart', [0.0, -600.0, 100.0]),
      _actor('AcUnit', 'StaticMesh', [-150.0, 0.0, 0.0], {'meshAssetPath': acUnitPath}),
      _actor('DentedBarrel', 'StaticMesh', [150.0, 0.0, 0.0], {'meshAssetPath': dentedBarrelPath}),
      _actor('Crate_01', 'Blueprint', [0.0, 250.0, 0.0], {'blueprintClass': crateClassPath}),
      _actor('Chime', 'Actor', [0.0, 0.0, 200.0], {
        'components': [
          {
            'id': 'audio',
            'type': 'LuminaAudioComponent',
            'properties': {'soundAsset': chimePath, 'autoActivate': false},
          },
        ],
      }),
      _actor('Sky', 'Environment', [0.0, 0.0, 0.0], {
        'components': [
          {
            'id': 'sky',
            'type': 'LuminaSkyComponent',
            'properties': {
              'mode': 'environment',
              'sky_environment': {'asset_path': skyPath},
            },
          },
        ],
      }),
    ];

/// BP_Crate: a scene root carrying the red fuel barrel; BeginPlay prints
/// "Crate ready".
LuminaBlueprintDocument crateBlueprint() {
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
    LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
    LuminaBlueprintComponent(id: 'mesh', name: 'Barrel', type: 'LuminaStaticMeshComponent', parentId: 'root', properties: {
      'staticMeshAsset': redBarrelPath,
    }),
  ]);
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Crate');
  doc.eventGraph.nodes.addAll([
    LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin', context: context),
    LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'ready', literals: {'in_string': 'Crate ready'}, context: context),
  ]);
  doc.eventGraph.wires
      .add(const LuminaBlueprintWire(id: 'c0', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'ready', toPinId: 'exec_in'));
  return doc;
}

/// A 1 s 440 Hz mono 16-bit PCM WAV.
Uint8List chimeWav({int sampleRate = 22050}) {
  final samples = sampleRate;
  final data = ByteData(44 + samples * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    data.setInt16(44 + i * 2, (math.sin(2 * math.pi * 440 * i / sampleRate) * 12000).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// A 64×32 sky gradient PNG.
Uint8List skyPng() {
  const w = 64, h = 32;
  final rgba = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      rgba[i] = 90 + y * 3;
      rgba[i + 1] = 140 + y * 2;
      rgba[i + 2] = 220;
      rgba[i + 3] = 255;
    }
  }
  return SmokeArtifacts.encodePng(w, h, rgba);
}

void _writeLevel(String projectDir, String relativePath, List<Map<String, dynamic>> actors) {
  final level = LuminaLevelDocument(relativePath: relativePath)..actors = actors;
  LuminaLevelRepository(projectDir).save(level);
}

/// Writes the project under [projectDir]: L_First, L_Second, BP_Crate and
/// the six assets; with [broken], also `L_Broken`, which names a mesh that
/// does not exist next to one that does.
void writeLevelLoadProject(String projectDir, {bool broken = false}) {
  for (final e in levelLoadSourceMeshes().entries) {
    File('$projectDir/${e.key}')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(File(e.value).readAsBytesSync());
  }
  File('$projectDir/$chimePath')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(chimeWav());
  File('$projectDir/$skyPath')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(skyPng());
  File('$projectDir/$crateClassPath')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(LuminaAsset(
      assetId: 'bp_BP_Crate',
      name: 'BP_Crate',
      type: AssetType.actor,
      rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(crateBlueprint().toJson()))),
      metadata: {'parent_class': 'LuminaActor'},
    ).toProtoBufferBytes());
  _writeLevel(projectDir, levelFirstPath, levelFirstActors());
  _writeLevel(projectDir, levelSecondPath, levelSecondActors());
  if (broken) {
    _writeLevel(projectDir, levelBrokenPath, [
      _actor('AcUnit', 'StaticMesh', [0.0, 0.0, 0.0], {'meshAssetPath': acUnitPath}),
      _actor('Missing', 'StaticMesh', [200.0, 0.0, 0.0], {'meshAssetPath': missingMeshPath}),
    ]);
  }
}

/// A game host for tests, as the generated `_GameHost` and
/// Play-In-Editor are: Change Level preloads the level through
/// [LuminaLevelPreloader.instance], ends the running world and plays a fresh
/// one of that level, whose probe actor logs `<level> BeginPlay` into [log].
class LevelLoadTestHost {
  LevelLoadTestHost(this.world, {this.levels = const {'L_First', 'L_Second'}, this.build});

  /// The world playing now.
  LuminaWorld world;
  final Set<String> levels;
  final List<String> log = [];

  /// Adds the level's actors to a new world (the probe is added either way).
  final void Function(String level, LuminaWorld world)? build;

  void install() => LuminaGame.onChangeLevelRequested = change;

  void uninstall() {
    if (LuminaGame.onChangeLevelRequested == change) LuminaGame.onChangeLevelRequested = null;
  }

  Future<void> change(String levelName) => LuminaLevelPreloader.instance.changeLevel(levelName, () async {
        if (!levels.contains(levelName)) throw StateError("no level named '$levelName' in this game");
        final previous = world;
        final next = LuminaWorld(worldType: LuminaWorldType.game);
        next.persistentLevel.levelName = levelName;
        build?.call(levelName, next);
        next.persistentLevel.registerActor(_BeginPlayProbe(() => log.add('$levelName BeginPlay')));
        previous.persistentLevel.unloadActors();
        world = next;
        next.beginPlay();
      });
}

class _BeginPlayProbe extends LuminaActor {
  _BeginPlayProbe(this.onBegin);
  final void Function() onBegin;

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    onBegin();
  }
}
