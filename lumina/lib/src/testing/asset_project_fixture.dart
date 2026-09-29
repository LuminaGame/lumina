import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:lumina_smoke/lumina_smoke.dart';

import '../../data/models/lumina_asset.dart';
import '../../data/models/lumina_project.dart';
import '../blueprint/blueprint.dart';

/// A generated project with many real `.lmas` files of every kind the
/// editor scans (for the derived-data tests and smoke): static meshes
/// carrying the barrels of `test-assets/Props/Barrels/` (half with an
/// `.entity.glb` companion), textures, materials, Blueprint classes, enum /
/// interface / save-game / montage documents, particle systems, widgets and
/// levels — every third file written in the older key order (base64 fields
/// before `metadata`), as older editor builds left them.
class AssetProjectFixture {
  AssetProjectFixture._();

  static const List<String> barrels = [
    'Props/Barrels/bent_barrel.glb',
    'Props/Barrels/dented_barrel.glb',
    'Props/Barrels/empty_barrel.glb',
    'Props/Barrels/fuel_barrel_black.glb',
    'Props/Barrels/fuel_barrel_red.glb',
    'Props/Barrels/fuel_barrel_yellow.glb',
    'Props/Barrels/lootbarrel_junk.glb',
  ];

  /// A small opaque PNG tinted by [seed] (a thumbnail / texture image).
  static Uint8List png(int seed, {int size = 32}) {
    final image = img.Image(width: size, height: size);
    final r = (seed * 53) % 256, g = (seed * 97) % 256, b = (seed * 151) % 256;
    img.fill(image, color: img.ColorRgb8(r, g, b));
    return img.encodePng(image);
  }

  /// [asset] as an older build wrote it: `thumbnail_png` and `raw_payload`
  /// before `raw_mat_source`, `references` and `metadata`.
  static Uint8List legacyBytes(LuminaAsset asset) {
    final map = asset.toMap();
    final legacy = <String, dynamic>{
      'asset_id': map['asset_id'],
      'name': map['name'],
      'type': map['type'],
      'has_thumbnail': map['has_thumbnail'],
      'thumbnail_png': map['thumbnail_png'],
      'raw_payload': map['raw_payload'],
      'raw_mat_source': map['raw_mat_source'],
      'references': map['references'],
      'metadata': map['metadata'],
    };
    return (BytesBuilder()
          ..add(const [0x4C, 0x4D, 0x41, 0x53])
          ..add(utf8.encode(jsonEncode(legacy))))
        .toBytes();
  }

  /// Writes `<parent>/<name>` with [count] assets and returns its path.
  /// With [withSidecars] every thumbnail is also left as an older build wrote
  /// it — a `.thumbnails/<name>.png` beside the asset, stamped not older than
  /// the `.lmas`, and every tenth asset with the sidecar only — plus
  /// `contents/.thumbnails/cover.png`. Without [writeManifest] only
  /// `contents/` is written (into an existing project).
  static String write(Directory parent,
      {String name = 'IndexedGame', int count = 300, bool withSidecars = false, bool writeManifest = true}) {
    final root = Directory('${parent.path}/$name')..createSync(recursive: true);
    if (writeManifest) {
      File('${root.path}/$name.lmproject').writeAsStringSync(jsonEncode(LuminaProject(projectName: name).toMap()));
      File('${root.path}/.gitignore').writeAsStringSync('build/\n.dart_tool/\n');
    }
    final barrelBytes = <Uint8List>[
      for (final b in barrels)
        if (File('${SmokeArtifacts.testAssetsDir.path}/$b').existsSync()) File('${SmokeArtifacts.testAssetsDir.path}/$b').readAsBytesSync(),
    ];
    if (barrelBytes.isEmpty) barrelBytes.add(Uint8List.fromList(utf8.encode('{"asset":{"version":"2.0"}}')));
    final base = DateTime.now().subtract(const Duration(hours: 1));

    for (var i = 0; i < count; i++) {
      final slot = i % 10;
      late String folder;
      late LuminaAsset asset;
      Uint8List? companion;
      String? companionExt;
      final thumb = png(i);
      switch (slot) {
        case 0:
        case 1:
        case 2:
          folder = 'meshes/static';
          final glb = barrelBytes[i % barrelBytes.length];
          asset = LuminaAsset(
            assetId: 'mesh-$i',
            name: 'SM_Barrel_$i',
            type: AssetType.filamesh,
            hasThumbnail: true,
            thumbnailPng: thumb,
            rawPayload: glb,
            references: [AssetReference(slotName: 'material_0', assetId: 'mat-${i + 5}', assetPath: 'contents/materials/M_Barrel_${i + 5}.lmas')],
            metadata: {'source': barrels[i % barrels.length], 'thumbnail_source': 'filament'},
          );
          if (i.isEven) {
            companion = glb;
            companionExt = 'entity.glb';
          }
        case 3:
        case 4:
          folder = 'textures';
          final image = png(i + 1000, size: 64);
          asset = LuminaAsset(
            assetId: 'tex-$i',
            name: 'T_Barrel_$i',
            type: AssetType.texture,
            hasThumbnail: true,
            thumbnailPng: thumb,
            rawPayload: image,
            metadata: {'format': 'png', 'thumbnail_source': 'image'},
          );
          companion = image;
          companionExt = 'png';
        case 5:
          folder = 'materials';
          asset = LuminaAsset(
            assetId: 'mat-$i',
            name: 'M_Barrel_$i',
            type: AssetType.filamat,
            hasThumbnail: true,
            thumbnailPng: thumb,
            rawMatSource: 'material { name : M_Barrel_$i, shadingModel : lit }',
            metadata: {'baseColor': '#${(i * 4099 % 0xFFFFFF).toRadixString(16).padLeft(6, '0')}', 'thumbnail_source': 'filament'},
          );
        case 6:
          folder = 'blueprints';
          const parents = ['LuminaActor', 'LuminaCharacter', 'LuminaPawn', 'LuminaGameMode'];
          final doc = LuminaBlueprintDocument(parentClass: parents[(i ~/ 10) % parents.length]);
          asset = LuminaAsset(
            assetId: 'bp-$i',
            name: 'BP_Thing_$i',
            type: AssetType.actor,
            hasThumbnail: true,
            thumbnailPng: thumb,
            rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(doc.toJson()))),
            metadata: {'parent_class': doc.parentClass, 'thumbnail_source': 'badge'},
          );
        case 7:
          folder = 'blueprints';
          final kind = (i ~/ 10) % 4;
          final Map<String, dynamic> json = switch (kind) {
            0 => LuminaBlueprintEnumDocument(name: 'E_State_$i', values: const ['Idle', 'Walk', 'Run']).toJson(),
            1 => LuminaBlueprintInterfaceDocument(name: 'BPI_Use_$i').toJson(),
            2 => LuminaBlueprintSaveGameDocument(name: 'SG_Progress_$i').toJson(),
            _ => LuminaBlueprintMontageDocument(name: 'AM_Attack_$i', clip: 'Attack').toJson(),
          };
          asset = LuminaAsset(
            assetId: 'doc-$i',
            name: json['name'] as String,
            type: AssetType.actor,
            hasThumbnail: true,
            thumbnailPng: thumb,
            rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(json))),
            metadata: {'blueprint_kind': json['kind'] as String, 'thumbnail_source': 'badge'},
          );
        case 8:
          folder = 'particles';
          asset = LuminaAsset(
            assetId: 'ps-$i',
            name: 'PS_Sparks_$i',
            type: AssetType.particle,
            hasThumbnail: true,
            thumbnailPng: thumb,
            metadata: {
              'particle_system': jsonEncode({
                'v': 1,
                'emitters': [
                  {
                    'name': 'Sparks',
                    'enabled': true,
                    'config': {'spawnRate': 10 + i, 'lifetime': 1.5},
                  },
                ],
              }),
              'thumbnail_source': 'badge',
            },
          );
        default:
          if ((i ~/ 10).isEven) {
            folder = 'widgets';
            asset = LuminaAsset(
              assetId: 'wbp-$i',
              name: 'WBP_Hud_$i',
              type: AssetType.widget,
              hasThumbnail: true,
              thumbnailPng: thumb,
              rawPayload: Uint8List.fromList(utf8.encode(jsonEncode({'version': 1, 'root': {'id': 'root', 'type': 'canvasPanel', 'children': []}}))),
              metadata: const {'parent_class': 'LuminaWidget', 'thumbnail_source': 'badge'},
            );
          } else {
            folder = 'levels';
            asset = LuminaAsset(
              assetId: 'lvl-$i',
              name: 'L_Arena_$i',
              type: AssetType.level,
              hasThumbnail: true,
              thumbnailPng: thumb,
              metadata: {
                'actors': jsonEncode([
                  {'id': 'a$i', 'type': 'StaticMesh', 'asset': 'contents/meshes/static/SM_Barrel_${i - 9}.lmas'},
                ]),
                'thumbnail_source': 'filament',
              },
            );
          }
      }
      final dir = Directory('${root.path}/contents/$folder')..createSync(recursive: true);
      final lmas = File('${dir.path}/${asset.name}.lmas');
      final sidecarOnly = withSidecars && i % 10 == 3;
      final stamp = base.add(Duration(seconds: i));
      if (withSidecars) {
        asset = LuminaAsset(
          assetId: asset.assetId,
          name: asset.name,
          type: asset.type,
          hasThumbnail: !sidecarOnly,
          thumbnailPng: sidecarOnly ? null : asset.thumbnailPng,
          rawPayload: asset.rawPayload,
          rawMatSource: asset.rawMatSource,
          references: asset.references,
          metadata: {
            ...asset.metadata,
            'thumbnail_rendered_at': stamp.toUtc().toIso8601String(),
            'thumbnail_asset_modified': stamp.toUtc().toIso8601String(),
          },
        );
      }
      lmas.writeAsBytesSync(withSidecars || i % 3 == 0 ? legacyBytes(asset) : asset.toProtoBufferBytes());
      if (companion != null) {
        final c = File('${dir.path}/${asset.name}.$companionExt')..writeAsBytesSync(companion);
        c.setLastModifiedSync(stamp.subtract(const Duration(minutes: 5)));
      }
      if (withSidecars) {
        // The old write order: the thumbnail patched into the .lmas two
        // seconds after the stamp, then the sidecar, stamped no older.
        final written = stamp.add(const Duration(seconds: 2));
        lmas.setLastModifiedSync(written);
        final sidecar = File('${dir.path}/.thumbnails/${asset.name}.png')..createSync(recursive: true);
        sidecar.writeAsBytesSync(thumb);
        sidecar.setLastModifiedSync(written);
      }
    }
    if (withSidecars) {
      final cover = File('${root.path}/contents/.thumbnails/cover.png')..createSync(recursive: true);
      cover.writeAsBytesSync(png(4242, size: 64));
    }
    return root.path;
  }
}
