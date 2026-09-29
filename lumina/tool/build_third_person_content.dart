// Builds the Third Person template's character bundle: the "Superhero
// Female" of Quaternius' Universal Base Characters with the template's clips
// from Quaternius' Universal Animation Library 1 and 2 merged in, so one
// gltfio asset plays them all. All three packs are CC0 (see
// assets/templates/third_person/LICENSE.txt).
//
//   dart run tool/build_third_person_content.dart --source <dir>
//
// <dir> holds the three packs' "[Standard]" downloads, unzipped as they come:
//
//   Universal Base Characters[Standard]/     https://quaternius.itch.io/universal-base-characters
//   Universal Animation Library[Standard]/   https://quaternius.itch.io/universal-animation-library
//   Universal Animation Library 2[Standard]/ https://quaternius.itch.io/universal-animation-library-2
//
// The character comes as a `.gltf` with PNG textures beside it. The tool
// packs it into a GLB, keeps only the vertex attributes the engine draws
// (the export also carries unused UV sets and colour layers) and re-encodes
// the 2048² textures as smaller JPEGs, so the bundle stays a few MB.
//
// The libraries animate a mannequin with the same 65-bone skeleton but other
// bone lengths, so every clip is retargeted rotation-only (translation only
// on root / pelvis, scaled by the bind length ratio). They are in-place
// exports that move forward only: the side and backward walk / jog cycles
// are the forward cycle turned about the vertical axis (a yaw on the root
// bone) toward the move direction, and, for the backward directions, played
// backward with the body facing away from the move.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:lumina/data/services/glb_animation_merger.dart';
import 'package:lumina/src/game/template_clips.dart';

const characterPath = 'Universal Base Characters[Standard]/Base Characters/Godot - UE/Superhero_Female_FullBody.gltf';
const library1Path = 'Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb';
const library2Path = 'Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb';

/// The source animation of every clip that is copied as it is.
const Map<String, String> plainClips = {
  LuminaThirdPersonClips.idle: 'Idle_Loop',
  LuminaThirdPersonClips.jump: 'Jump_Start',
  LuminaThirdPersonClips.fallLoop: 'Jump_Loop',
  LuminaThirdPersonClips.land: 'Jump_Land',
  LuminaThirdPersonClips.dash: 'Roll',
  LuminaThirdPersonClips.wallJump: 'NinjaJump_Start',
  'Idle_Talking_Loop': 'Idle_Talking_Loop',
  'Idle_FoldArms_Loop': 'Idle_FoldArms_Loop',
  'Yes': 'Yes',
};

/// The forward cycles the directional walks / jogs are derived from.
const String walkSource = 'Walk_Loop';
const String jogSource = 'Jog_Fwd_Loop';

/// Bones no clip may lose: dropping any of them means the export is not this
/// skeleton at all.
const requiredBones = ['root', 'pelvis', 'spine_01'];

/// Longest texture edge per image name prefix (the eyebrows use a corner of
/// the hair texture, the eyes are small already).
int maxEdgeFor(String imageName) {
  if (imageName.startsWith('T_Hair')) return 512;
  if (imageName.startsWith('T_Eye')) return 256;
  return 1024;
}

void main(List<String> args) {
  final at = args.indexOf('--source');
  if (at == -1 || at + 1 >= args.length) {
    stderr.writeln('Usage: dart run tool/build_third_person_content.dart --source <dir with the unzipped packs>');
    exit(2);
  }
  final source = args[at + 1];
  final character = File('$source/$characterPath');
  final library1 = File('$source/$library1Path');
  final library2 = File('$source/$library2Path');
  final missing = [character, library1, library2].where((f) => !f.existsSync()).map((f) => f.path).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('Missing source files:\n  ${missing.join('\n  ')}');
    exit(2);
  }

  final base = packCharacter(character);
  stdout.writeln('Packed ${character.uri.pathSegments.last}: ${_mb(base.length)}');

  final libraries = [
    GlbDocument.parse(library1.readAsBytesSync(), label: library1.path),
    GlbDocument.parse(library2.readAsBytesSync(), label: library2.path),
  ];
  (GlbDocument, int) find(String animation) {
    for (final doc in libraries) {
      final names = [for (final a in (doc.json['animations'] as List)) (a as Map)['name'] as String?];
      final i = names.indexOf(animation);
      if (i != -1) return (doc, i);
    }
    stderr.writeln('No library has an animation named $animation');
    exit(2);
  }

  final clips = <GlbClipSource>[];
  void add(String name, String animation, {double facing = 0.0, bool reverse = false}) {
    final (doc, index) = find(animation);
    clips.add(GlbClipSource(
      name: name,
      bytes: extractClip(doc, index, name: name, yawDegrees: facing, reverse: reverse),
      rotationOnly: true,
    ));
  }

  for (final name in LuminaThirdPersonClips.names) {
    final walk = LuminaThirdPersonClips.walks.indexOf(name);
    final jog = LuminaThirdPersonClips.jogs.indexOf(name);
    if (walk != -1 || jog != -1) {
      final direction = LuminaThirdPersonClips.directionDegrees[walk != -1 ? walk : jog];
      final backward = direction.abs() > 90.0;
      // A backward cycle faces away from the move: 135° right → 45° left.
      final facing = backward ? direction - 180.0 * direction.sign : direction;
      add(name, walk != -1 ? walkSource : jogSource, facing: facing, reverse: backward);
    } else if (plainClips[name] != null) {
      add(name, plainClips[name]!);
    } else {
      stderr.writeln('No source for clip $name');
      exit(2);
    }
  }

  final result = GlbAnimationMerger.mergeWithReport(base: base, clips: clips);
  stdout.writeln('Merge report:');
  var broken = false;
  for (final clip in result.report.clips) {
    stdout.writeln('  $clip');
    if (!clip.keeps(requiredBones)) {
      stderr.writeln('  ERROR: ${clip.clip} lost a channel of ${requiredBones.join('/')}');
      broken = true;
    }
  }
  if (broken) exit(1);

  final out = File(LuminaThirdPersonClips.bundledMeshPath);
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(result.bytes);
  final names = GlbAnimationMerger.animationNames(result.bytes);
  stdout.writeln('Wrote ${out.path} (${_mb(result.bytes.length)}) with ${names.length} clips: ${names.join(', ')}');
}

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';

/// Vertex attributes the bundle keeps; the export's other layers are unused
/// by the materials.
const keptAttributes = {'POSITION', 'NORMAL', 'TANGENT', 'TEXCOORD_0', 'JOINTS_0', 'WEIGHTS_0'};

/// Packs the character's `.gltf`, its binary buffer and its textures into a
/// single-buffer GLB holding only what the meshes, skin and materials use.
Uint8List packCharacter(File gltf) {
  final json = jsonDecode(gltf.readAsStringSync()) as Map<String, dynamic>;
  final dir = gltf.parent.path;
  final buffers = json['buffers'] as List;
  if (buffers.length != 1) throw FormatException('${gltf.path} has ${buffers.length} buffers; expected 1');
  final srcBin = File('$dir/${Uri.decodeComponent((buffers.first as Map)['uri'] as String)}').readAsBytesSync();
  final srcViews = json['bufferViews'] as List;
  final srcAccessors = json['accessors'] as List;

  final bin = BytesBuilder(copy: false);
  var length = 0;
  final views = <Map<String, dynamic>>[];
  int addView(Uint8List bytes, {int? target}) {
    final pad = ((length + 3) & ~3) - length;
    if (pad > 0) bin.add(Uint8List(pad));
    views.add({'buffer': 0, 'byteOffset': length + pad, 'byteLength': bytes.length, 'target': ?target});
    bin.add(bytes);
    length += pad + bytes.length;
    return views.length - 1;
  }

  // Accessors are copied tightly packed, each behind its own buffer view.
  final accessors = <Map<String, dynamic>>[];
  final copied = <int, int>{};
  int copyAccessor(int index, {int? target}) {
    final existing = copied[index];
    if (existing != null) return existing;
    final acc = Map<String, dynamic>.from(srcAccessors[index] as Map);
    final view = srcViews[acc['bufferView'] as int] as Map;
    final elementSize = _componentSize(acc['componentType'] as int) * _componentCount(acc['type'] as String);
    final stride = (view['byteStride'] as int?) ?? elementSize;
    final start = ((view['byteOffset'] as int?) ?? 0) + ((acc['byteOffset'] as int?) ?? 0);
    final count = acc['count'] as int;
    final packed = Uint8List(count * elementSize);
    for (var i = 0; i < count; i++) {
      packed.setRange(i * elementSize, (i + 1) * elementSize, srcBin, start + i * stride);
    }
    acc['bufferView'] = addView(packed, target: target);
    acc.remove('byteOffset');
    accessors.add(acc);
    return copied[index] = accessors.length - 1;
  }

  for (final mesh in json['meshes'] as List) {
    for (final p in (mesh as Map)['primitives'] as List) {
      final prim = p as Map;
      final attributes = Map<String, dynamic>.from(prim['attributes'] as Map)
        ..removeWhere((key, _) => !keptAttributes.contains(key));
      prim['attributes'] = {for (final e in attributes.entries) e.key: copyAccessor(e.value as int, target: 34962)};
      if (prim['indices'] != null) prim['indices'] = copyAccessor(prim['indices'] as int, target: 34963);
      prim.remove('targets');
    }
  }
  for (final skin in (json['skins'] as List?) ?? const []) {
    final s = skin as Map;
    if (s['inverseBindMatrices'] != null) s['inverseBindMatrices'] = copyAccessor(s['inverseBindMatrices'] as int);
  }

  // The body, eyes and eyebrows are three mesh nodes on the same skin at the
  // same (identity) transform: one mesh with three primitives is one
  // skinned renderable to update per frame instead of three.
  final nodes = json['nodes'] as List;
  final meshNodes = [for (final n in nodes) if ((n as Map)['mesh'] != null) n];
  final skins = {for (final n in meshNodes) n['skin']};
  final placed = meshNodes.every((n) => n['translation'] == null && n['rotation'] == null && n['scale'] == null && n['matrix'] == null);
  if (meshNodes.length > 1 && skins.length == 1 && placed) {
    final meshes = json['meshes'] as List;
    // The node keeping the merged mesh: the one with the most triangles.
    int indices(Map node) => [
          for (final p in (meshes[node['mesh'] as int] as Map)['primitives'] as List)
            accessors[(p as Map)['indices'] as int]['count'] as int,
        ].fold(0, (a, b) => a + b);
    final body = meshNodes.reduce((a, b) => indices(a) >= indices(b) ? a : b);
    json['meshes'] = [
      {
        'name': (meshes[body['mesh'] as int] as Map)['name'],
        'primitives': [
          for (final n in meshNodes) ...((meshes[n['mesh'] as int] as Map)['primitives'] as List),
        ],
      },
    ];
    for (final n in meshNodes) {
      if (identical(n, body)) {
        n['mesh'] = 0;
      } else {
        n
          ..remove('mesh')
          ..remove('skin');
      }
    }
  }

  // Textures: resized and re-encoded as JPEG (none of them uses alpha).
  final images = <Map<String, dynamic>>[];
  for (final image in (json['images'] as List?) ?? const []) {
    final m = image as Map;
    final name = ((m['name'] as String?) ?? (m['uri'] as String)).replaceAll('.png', '');
    var decoded = img.decodeImage(_readImage(dir, m['uri'] as String));
    if (decoded == null) throw FormatException('Cannot decode ${m['uri']}');
    final edge = maxEdgeFor(name);
    if (decoded.width > edge || decoded.height > edge) {
      decoded = img.copyResize(decoded,
          width: decoded.width >= decoded.height ? edge : null,
          height: decoded.height > decoded.width ? edge : null,
          interpolation: img.Interpolation.average);
    }
    final jpeg = img.encodeJpg(decoded.convert(numChannels: 3), quality: 90);
    images.add({'name': name, 'mimeType': 'image/jpeg', 'bufferView': addView(jpeg)});
  }

  json
    ..['accessors'] = accessors
    ..['bufferViews'] = views
    ..['images'] = images
    ..['buffers'] = [
      {'byteLength': length},
    ]
    ..remove('animations');
  return GlbDocument(json, bin.takeBytes()).encode();
}

/// An image the `.gltf` references. The export names one texture with a
/// doubled `_png` suffix (`T_Eye_Normal_png.png`) that exists only as
/// `T_Eye_Normal.png`.
Uint8List _readImage(String dir, String uri) {
  final name = Uri.decodeComponent(uri);
  for (final candidate in [name, name.replaceFirst('_png.png', '.png')]) {
    final f = File('$dir/$candidate');
    if (f.existsSync()) return f.readAsBytesSync();
  }
  throw FileSystemException('Texture not found', '$dir/$name');
}

/// Animation [index] of [doc] alone in a GLB (its nodes, one animation and
/// its key data), with the `root` bone turned [yawDegrees] about the
/// vertical axis (right positive, the character facing glTF +Z) and, with
/// [reverse], the keys played back to front.
Uint8List extractClip(GlbDocument doc, int index, {required String name, double yawDegrees = 0.0, bool reverse = false}) {
  final json = doc.json;
  final nodes = [
    for (final n in json['nodes'] as List) Map<String, dynamic>.from(n as Map)..remove('mesh')..remove('skin'),
  ];
  final animation = (json['animations'] as List)[index] as Map;
  final accessors = json['accessors'] as List;
  final views = json['bufferViews'] as List;
  final data = ByteData.sublistView(doc.bin);

  Float32List read(int accessor) {
    final acc = accessors[accessor] as Map;
    if (acc['componentType'] != 5126) throw FormatException('$name: accessor $accessor is not float');
    final n = _componentCount(acc['type'] as String);
    final view = views[acc['bufferView'] as int] as Map;
    final stride = (view['byteStride'] as int?) ?? n * 4;
    final start = ((view['byteOffset'] as int?) ?? 0) + ((acc['byteOffset'] as int?) ?? 0);
    final count = acc['count'] as int;
    final out = Float32List(count * n);
    for (var i = 0; i < count; i++) {
      for (var c = 0; c < n; c++) {
        out[i * n + c] = data.getFloat32(start + i * stride + c * 4, Endian.little);
      }
    }
    return out;
  }

  // The yaw as a quaternion about +Y (glTF up); a positive (rightward) yaw
  // turns +Z toward −X, the character's right.
  final half = -yawDegrees * math.pi / 360.0;
  final qy = math.sin(half), qw = math.cos(half);

  final bin = BytesBuilder(copy: false);
  var length = 0;
  final newViews = <Map<String, dynamic>>[];
  final newAccessors = <Map<String, dynamic>>[];
  int write(Float32List values, String type, int count, {bool withRange = false}) {
    newViews.add({'buffer': 0, 'byteOffset': length, 'byteLength': values.lengthInBytes});
    bin.add(values.buffer.asUint8List(values.offsetInBytes, values.lengthInBytes));
    length += values.lengthInBytes;
    newAccessors.add({
      'bufferView': newViews.length - 1,
      'componentType': 5126,
      'count': count,
      'type': type,
      if (withRange) 'min': [values.reduce(math.min)],
      if (withRange) 'max': [values.reduce(math.max)],
    });
    return newAccessors.length - 1;
  }

  final samplers = animation['samplers'] as List;
  final inputs = <int, int>{};
  final newSamplers = <Map<String, dynamic>>[];
  final newChannels = <Map<String, dynamic>>[];
  var turnedRoot = false;
  for (final c in animation['channels'] as List) {
    final channel = c as Map;
    final target = channel['target'] as Map;
    final sampler = samplers[channel['sampler'] as int] as Map;
    final interpolation = (sampler['interpolation'] as String?) ?? 'LINEAR';
    if (interpolation == 'CUBICSPLINE') throw FormatException('$name: cubic spline keys are not supported');
    final times = read(sampler['input'] as int);
    final count = times.length;
    final input = inputs.putIfAbsent(sampler['input'] as int, () {
      final t = Float32List(count);
      final end = times[count - 1];
      for (var i = 0; i < count; i++) {
        t[i] = reverse ? end - times[count - 1 - i] : times[i];
      }
      return write(t, 'SCALAR', count, withRange: true);
    });
    final type = (accessors[sampler['output'] as int] as Map)['type'] as String;
    final n = _componentCount(type);
    final src = read(sampler['output'] as int);
    final values = Float32List(src.length);
    for (var i = 0; i < count; i++) {
      final from = reverse ? count - 1 - i : i;
      for (var k = 0; k < n; k++) {
        values[i * n + k] = src[from * n + k];
      }
    }
    if (nodes[target['node'] as int]['name'] == 'root' && target['path'] == 'rotation' && yawDegrees != 0.0) {
      // yaw * key: turn the root's whole pose about the parent's up axis.
      for (var i = 0; i < count; i++) {
        final (x, y, z, w) = (values[i * 4], values[i * 4 + 1], values[i * 4 + 2], values[i * 4 + 3]);
        values[i * 4] = qw * x + qy * z;
        values[i * 4 + 1] = qw * y + qy * w;
        values[i * 4 + 2] = qw * z - qy * x;
        values[i * 4 + 3] = qw * w - qy * y;
      }
      turnedRoot = true;
    }
    newSamplers.add({'input': input, 'output': write(values, type, count), 'interpolation': interpolation});
    newChannels.add({'sampler': newSamplers.length - 1, 'target': target});
  }
  if (yawDegrees != 0.0 && !turnedRoot) throw FormatException('$name: the source has no root rotation channel to turn');

  return GlbDocument(<String, dynamic>{
    'asset': json['asset'],
    'nodes': nodes,
    'accessors': newAccessors,
    'bufferViews': newViews,
    'buffers': [
      {'byteLength': length},
    ],
    'animations': [
      {'name': name, 'channels': newChannels, 'samplers': newSamplers},
    ],
  }, bin.takeBytes())
      .encode();
}

int _componentSize(int componentType) => switch (componentType) {
      5120 || 5121 => 1,
      5122 || 5123 => 2,
      5125 || 5126 => 4,
      _ => throw FormatException('Unknown component type $componentType'),
    };

int _componentCount(String type) => switch (type) {
      'SCALAR' => 1,
      'VEC2' => 2,
      'VEC3' => 3,
      'VEC4' => 4,
      'MAT4' => 16,
      _ => throw FormatException('Unknown accessor type $type'),
    };
