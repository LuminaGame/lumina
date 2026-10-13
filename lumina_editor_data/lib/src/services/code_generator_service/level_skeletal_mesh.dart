part of '../code_generator_service.dart';

/// The Mesh Component Details a placed skeletal mesh plays with
/// (`LuminaLevelSkeletalMesh.build`): cast shadow, slot, pose from.
const Set<String> _levelSkeletalMeshDetails = {'castShadow', 'slot', 'poseFrom'};

/// The project path of the Animation Blueprint a placed skeletal mesh's
/// Details name as its Anim Class, or null.
String? _levelAnimClass(Map<String, dynamic> a) {
  if ((a['type'] ?? '').toString() != 'SkeletalMesh') return null;
  final props = _componentOfType(a, 'LuminaSkeletalMeshComponent')?['properties'];
  return props is Map ? LuminaLevelSkeletalMesh.animClassPath(Map<String, Object?>.from(props)) : null;
}

/// The libraries of the compiled Anim Classes the level's skeletal meshes
/// play, as the level (in `lib/levels/`) imports them.
Set<String> _levelAnimImports(List<Map<String, dynamic>> maps, Map<String, BlueprintAnimClassRef> animBlueprints) => {
      for (final a in maps)
        if (_levelAnimClass(a) case final path?) ?animBlueprints[path]?.importUri,
    };

/// A placed `SkeletalMesh` actor as generated code: an animated skeletal
/// mesh with its Details, level material and springs, built by the same
/// runtime factory Play-In-Editor uses.
String _emitLevelSkeletalMesh(
  Map<String, dynamic> a, {
  required String key,
  required String meshPath,
  required String transform,
  required String scaleCode,
  required String castShadows,
  required String visible,
  required String material,
  Map<String, BlueprintAnimClassRef> animBlueprints = const {},
}) {
  final mesh = _componentOfType(a, 'LuminaSkeletalMeshComponent');
  final props = mesh?['properties'] is Map ? Map<String, dynamic>.from(mesh!['properties'] as Map) : const <String, dynamic>{};
  final details = <String, dynamic>{
    for (final e in props.entries)
      if (_levelSkeletalMeshDetails.contains(e.key) && e.value != null && e.value != '' && e.value != 'None') e.key: e.value,
  };
  final springs = _componentOfType(a, 'LuminaSpringMorphComponent');
  final springProps =
      springs == null ? null : (springs['properties'] is Map ? Map<String, dynamic>.from(springs['properties'] as Map) : <String, dynamic>{});
  // The Anim Class, compiled into lib/anim/ before the level is generated.
  final animPath = _levelAnimClass(a);
  final anim = animPath == null ? null : animBlueprints[animPath];
  final animNote = animPath != null && anim == null
      ? "// Anim Class '${animPath.replaceAll('\n', ' ')}' is not compiled (missing or has errors): the mesh plays no animation.\n          "
      : '';
  return '${animNote}LuminaLevelSkeletalMesh.build($key, meshAssetPath: \'${_escape(_bundlePath(meshPath))}\', '
      '$transform, scale: $scaleCode, castShadows: $castShadows, visible: $visible'
      '${material.isEmpty ? '' : ', $material'}'
      '${details.isEmpty ? '' : ', details: ${DartCodeGeneratorService._dartLiteral(details)}'}'
      '${springProps == null ? '' : ', springs: ${DartCodeGeneratorService._dartLiteral(springProps)}'}'
      '${anim == null ? '' : ', animBlueprint: ${anim.className}.create'}),';
}
