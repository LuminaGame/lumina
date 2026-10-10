import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';

/// The skeletal mesh editor's Skin Weight Heatmap on the native viewport.
///
/// [material] is an unlit material that reads each vertex's skin joints and
/// weights in its vertex stage — the same attributes skinning uses, so the
/// colours follow any pose — and colours the weight of one joint, blue (0)
/// → cyan → green → yellow → red (1), the ramp the CPU preview and the
/// editor's legend use. A vertex stage without skinning (an unskinned
/// renderable) reads no weights and stays blue.
///
/// glTF joints are indices into the skin of the node that draws a mesh, so
/// the selected bone is a different index per skin: [jointSlots] gives it
/// for every renderable, set as [jointParameter] on that renderable's
/// material instance.
abstract final class SkinWeightHeatmap {
  static const String materialName = 'LuminaSkinWeightHeatmap';

  /// The material parameter: the selected joint's index in the renderable's
  /// skin, -1 for none.
  static const String jointParameter = 'joint';

  static const String materialSource = '''
material {
    name : $materialName,
    shadingModel : unlit,
    parameters : [
        { type : int, name : $jointParameter }
    ],
    variables : [ heat ],
    requires : [ position ]
}

vertex {
    void materialVertex(inout MaterialVertexInputs material) {
        float w = 0.0;
#if defined(VARIANT_HAS_SKINNING_OR_MORPHING)
        int j = materialParams.$jointParameter;
        if (j >= 0 && (object_uniforms_flagsChannels & FILAMENT_OBJECT_SKINNING_ENABLED_BIT) != 0) {
            uint u = uint(j);
            uvec4 ids = mesh_bone_indices;
            vec4 ws = mesh_bone_weights;
            if (ids.x == u) w += ws.x;
            if (ids.y == u) w += ws.y;
            if (ids.z == u) w += ws.z;
            // A negative w marks more than four influences (the rest live in
            // a texture); its first three are still read.
            if (ws.w >= 0.0 && ids.w == u) w += ws.w;
        }
#endif
        material.heat = vec4(w, 0.0, 0.0, 0.0);
    }
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        float w = clamp(variable_heat.x, 0.0, 1.0);
        vec3 c;
        if (w <= 0.25) {
            c = vec3(0.0, w / 0.25, 1.0);
        } else if (w <= 0.5) {
            c = vec3(0.0, 1.0, 1.0 - (w - 0.25) / 0.25);
        } else if (w <= 0.75) {
            c = vec3((w - 0.5) / 0.25, 1.0, 0.0);
        } else {
            c = vec3(1.0, 1.0 - (w - 0.75) / 0.25, 0.0);
        }
        // The ramp is authored in sRGB; the base colour is linear.
        material.baseColor = vec4(pow(c, vec3(2.2)), 1.0);
    }
}
''';

  static Future<Uint8List?>? _compiled;

  /// matc's messages from the last compile (empty when it succeeded).
  static String lastDiagnostics = '';

  /// The compiled material, built once per process on a background isolate
  /// (matc takes about a second).
  static Future<Uint8List?> material() => _compiled ??= _compile();

  static Future<Uint8List?> _compile() async {
    final result = await Isolate.run(() {
      final r = FilamentMatc.compile(materialSource, fileName: '$materialName.mat', defaultName: materialName);
      return (package: r.package, log: r.log);
    });
    lastDiagnostics = result.log;
    if (result.package == null) _compiled = null;
    return result.package;
  }

  /// For each renderable of the GLB [glb] — one per mesh node, in node order,
  /// as gltfio builds them — the index of node [boneNodeIndex] in that node's
  /// skin's `joints`, or -1 (no skin, the bone is not in it, or no bone).
  static List<int> jointSlots(Uint8List glb, int? boneNodeIndex) {
    final json = _json(glb);
    if (json == null) return const [];
    final nodes = (json['nodes'] as List?) ?? const [];
    final skins = (json['skins'] as List?) ?? const [];
    return [
      for (final n in nodes)
        if (n is Map && n['mesh'] != null)
          () {
            final skin = n['skin'];
            if (boneNodeIndex == null || skin is! int || skin < 0 || skin >= skins.length) return -1;
            final joints = ((skins[skin] as Map)['joints'] as List?) ?? const [];
            return joints.indexOf(boneNodeIndex);
          }(),
    ];
  }

  /// The JSON chunk of a binary glTF.
  static Map<String, dynamic>? _json(Uint8List glb) {
    if (glb.length < 20) return null;
    final data = ByteData.sublistView(glb);
    if (data.getUint32(0, Endian.little) != 0x46546C67) return null;
    final length = data.getUint32(12, Endian.little);
    if (data.getUint32(16, Endian.little) != 0x4E4F534A || 20 + length > glb.length) return null;
    final decoded = jsonDecode(utf8.decode(glb.sublist(20, 20 + length)));
    return decoded is Map<String, dynamic> ? decoded : null;
  }
}
