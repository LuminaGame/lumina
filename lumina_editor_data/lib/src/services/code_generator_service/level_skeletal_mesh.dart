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

/// [expression] (one placed mesh actor and the list's comma) with the Min /
/// Max Draw Distance its Mesh Component Details set (metres → cm), through
/// `LuminaDrawDistance.apply`; unchanged when they limit nothing.
String _withDrawDistance(Map<String, dynamic> a, String expression) {
  if (!const {'Mesh', 'StaticMesh', 'SkeletalMesh'}.contains((a['type'] ?? '').toString())) return expression;
  final mesh = _componentOfType(a, 'LuminaMeshComponent') ?? _componentOfType(a, 'LuminaSkeletalMeshComponent');
  final props = mesh?['properties'];
  final limits = props is Map ? LuminaDrawDistance.fromDetails(Map<String, Object?>.from(props)) : null;
  final trimmed = expression.trimRight();
  if (limits == null || !trimmed.endsWith(',')) return expression;
  // Comment lines before the actor stay in front of the call, which may
  // span lines (collision lists).
  final lines = trimmed.substring(0, trimmed.length - 1).split('\n');
  var first = 0;
  while (first < lines.length - 1 && lines[first].trimLeft().startsWith('//')) {
    first++;
  }
  final head = [for (final l in lines.take(first)) '$l\n'].join();
  final call = lines.skip(first).join('\n');
  final indent = call.length - call.trimLeft().length;
  return '$head${call.substring(0, indent)}LuminaDrawDistance.apply(${call.substring(indent)}, '
      'min: ${DartCodeGeneratorService._dartLiteral(limits.min)}, max: ${DartCodeGeneratorService._dartLiteral(limits.max)}),';
}

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
