part of '../glb_animation_retargeter.dart';

bool _isSomaClip(GlbDocument document) =>
    (document.json['extras'] as Map?)?['source'] == 'NVIDIA GEM-X / SOMA';

int? _resolveSomaBone(String name, List<String?> targetNames, Map<String, int> sourceNames) {
  if (GlbAnimationRetargeter.isCorrectiveOrFace(name)) return null;
  final lower = name.toLowerCase();
  final direct = sourceNames[lower];
  if (direct != null) return direct;
  final extendedSpine = targetNames.any((n) => n?.toLowerCase() == 'spine_05');
  if (lower == 'spine_03' && extendedSpine) return null;
  final central = <String, String>{
    'pelvis': 'hips',
    'spine_01': 'spine1',
    'spine_02': 'spine2',
    'spine_03': 'chest',
    'spine_05': 'chest',
    'neck_01': 'neck1',
    'neck_02': 'neck2',
    'head': 'head',
  }[lower];
  if (central != null) return sourceNames[central];
  for (final side in ['l', 'r']) {
    final prefix = side == 'l' ? 'left' : 'right';
    final source = <String, String>{
      'clavicle_$side': '${prefix}shoulder',
      'upperarm_$side': '${prefix}arm',
      'lowerarm_$side': '${prefix}forearm',
      'hand_$side': '${prefix}hand',
      'thigh_$side': '${prefix}leg',
      'calf_$side': '${prefix}shin',
      'foot_$side': '${prefix}foot',
      'ball_$side': '${prefix}toebase',
    }[lower];
    if (source != null) return sourceNames[source];
  }
  return null;
}
