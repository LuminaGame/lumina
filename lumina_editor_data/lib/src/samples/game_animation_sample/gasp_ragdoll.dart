import 'package:lumina/lumina.dart';

import 'package:lumina_editor_data/src/samples/game_animation_sample/gasp_export.dart';

/// The example character's falls and ragdoll: the sample's Ragdoll clips
/// (get up face down / face up, flailing in the air) and a heavy landing go
/// into the character mesh, a physics asset generated from its skeleton
/// gives the bodies, and a `LuminaRagdollComponent` on the character plays
/// it: R toggles the ragdoll, a long fall goes limp, a hard landing lands
/// heavily.
abstract final class GaspRagdoll {
  /// The get-up clips the component picks from (the one lying like the
  /// ragdoll), as the sample's get-up chooser lists them.
  static const List<String> getUpClips = ['M_ragdoll_getup_stand_F', 'M_ragdoll_getup_stand_B'];

  /// What the joints are driven toward while falling as a ragdoll.
  static const String flailClip = 'M_ragdoll_flail_armsFirst';

  /// Played over the animation on a hard touchdown.
  static const String hardLandingClip = 'M_Neutral_Jump_F_Land_Stand_Heavy_Lfoot';

  /// The R key (`LogicalKeyboardKey.keyR.keyId`).
  static const int keyIdR = 0x00000072;
  static const String inputAction = 'IA_Ragdoll';

  /// Falls: limp in the air past 1100 cm/s (about 6.2 m: the sandbox's
  /// 7 m block), limp on a touchdown past 1000 cm/s (5.1 m), a heavy landing
  /// past 750 cm/s (about 2.9 m).
  static const double ragdollFallSpeed = 1100.0;
  static const double ragdollLandingSpeed = 1000.0;
  static const double hardLandingSpeed = 750.0;

  /// The clips of [export] the character mesh must carry for the ragdoll.
  static Set<String> clips(GaspExport export) => {
        for (final name in [...getUpClips, flailClip, hardLandingClip])
          if (export.sequence(name) != null) name,
      };

  static const ProjectInputAction action = ProjectInputAction(name: inputAction);
  static const ProjectInputMapping mapping = ProjectInputMapping(action: inputAction, keyId: keyIdR, keyLabel: 'R');

  /// The character's ragdoll component, its physics asset at
  /// [physicsAssetPath] (the clips it lacks are skipped at run time).
  static LuminaBlueprintComponent component(String physicsAssetPath) => LuminaBlueprintComponent(
        id: 'ragdoll',
        name: 'Ragdoll',
        type: 'LuminaRagdollComponent',
        isSceneComponent: false,
        properties: {
          'physicsAsset': physicsAssetPath,
          'getUpClips': getUpClips,
          'flailClip': flailClip,
          'hardLandingClip': hardLandingClip,
          'ragdollFallSpeed': ragdollFallSpeed,
          'ragdollLandingSpeed': ragdollLandingSpeed,
          'hardLandingSpeed': hardLandingSpeed,
          'autoRagdollOnFall': true,
          'autoGetUp': true,
        },
      );
}
