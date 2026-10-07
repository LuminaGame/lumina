import 'package:lumina/src/animation/anim_instance.dart';
import 'package:lumina/src/animation/animation_clip.dart';

/// Single section within an animation montage defining sub-segment start points and chaining.
class MontageSection {
  final String name;
  final double startTime;
  final String? nextSection;

  MontageSection({
    required this.name,
    required this.startTime,
    this.nextSection,
  });
}

/// Timed gameplay notification event fired at an exact timestamp during animation playback.
class AnimNotify {
  final String name;
  final double time;
  final void Function(LuminaAnimInstance anim)? callback;

  AnimNotify({
    required this.name,
    required this.time,
    this.callback,
  });
}

/// An event-driven animation sequence layered over the base state machine pose with sections and notifies.
class LuminaAnimMontage {
  final String name;
  final LuminaAnimationClip clip;
  final List<MontageSection> sections;
  final List<AnimNotify> notifies;
  final double blendInTime;
  final double blendOutTime;

  LuminaAnimMontage({
    required this.name,
    required this.clip,
    List<MontageSection>? sections,
    List<AnimNotify>? notifies,
    this.blendInTime = 0.25,
    this.blendOutTime = 0.25,
  })  : sections = (sections != null && sections.isNotEmpty)
            ? (List.of(sections)..sort((a, b) => a.startTime.compareTo(b.startTime)))
            : [MontageSection(name: 'default', startTime: 0.0)],
        notifies = (notifies != null)
            ? (List.of(notifies)..sort((a, b) => a.time.compareTo(b.time)))
            : const [];
}
