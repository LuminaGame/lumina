part of '../code_generator_service.dart';

/// The Mesh Component Details a placed skeletal mesh plays with
/// (`LuminaLevelSkeletalMesh.build`): cast shadow, slot, pose from.
const Set<String> _levelSkeletalMeshDetails = {'castShadow', 'slot', 'poseFrom'};

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
  return 'LuminaLevelSkeletalMesh.build($key, meshAssetPath: \'${_escape(_bundlePath(meshPath))}\', '
      '$transform, scale: $scaleCode, castShadows: $castShadows, visible: $visible'
      '${material.isEmpty ? '' : ', $material'}'
      '${details.isEmpty ? '' : ', details: ${DartCodeGeneratorService._dartLiteral(details)}'}'
      '${springProps == null ? '' : ', springs: ${DartCodeGeneratorService._dartLiteral(springProps)}'}),';
}
