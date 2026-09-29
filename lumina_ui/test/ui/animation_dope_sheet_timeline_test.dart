import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/data/services/glb_parser_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/anim_notify_and_curves.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/anim_bone_track_info.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/widgets/animation_dope_sheet_widget.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Animation Dope Sheet & Timeline Keyframe Editor Tests', () {
    late Directory tempDir;
    late String animPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dope_sheet_test_');
      final animDir = Directory('${tempDir.path}/contents/animations')..createSync(recursive: true);
      final asset = LuminaAsset(
        assetId: 'dope-anim-01',
        name: 'A_Character_Run',
        type: AssetType.animation,
        rawPayload: Uint8List.fromList([0x67, 0x6C, 0x54, 0x46, 2, 0, 0, 0, 0, 0, 0, 0]),
      );
      animPath = '${animDir.path}/A_Character_Run.lmas';
      File(animPath).writeAsBytesSync(asset.toProtoBufferBytes());
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('ViewModel supports dope sheet keyframe track operations and snapping', () async {
      final vm = AnimationEditorViewModel(assetPath: animPath);
      await vm.load();

      // Add a float curve and keyframes
      vm.addCurve('FootstepWeight');
      vm.addCurveKey('FootstepWeight', 0.0, 0.0);
      vm.addCurveKey('FootstepWeight', 0.5, 1.0);
      vm.addCurveKey('FootstepWeight', 1.0, 0.0);

      // Add notify markers
      vm.addNotify('Footstep_L', 0.25, type: AnimNotifyType.footstep);
      vm.addNotify('Footstep_R', 0.75, type: AnimNotifyType.footstep);

      expect(vm.curves.length, equals(1));
      expect(vm.curves.first.keys.length, equals(3));
      expect(vm.notifies.length, equals(2));

      // Test snapping
      vm.setSnap(true);
      expect(vm.snapToFrames, isTrue);

      // Add key at current frame (e.g. at 0.333s)
      vm.seek(0.333);
      vm.addKeyAtCurrentFrame(curveName: 'FootstepWeight', value: 0.8);
      expect(vm.curves.first.keys.length, equals(4));

      // Delete key
      vm.deleteCurveKey('FootstepWeight', 0.333);
      expect(vm.curves.first.keys.length, equals(3));
    });

    testWidgets('AnimationDopeSheetWidget renders ruler, notifies track, curves track, and controls', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final vm = AnimationEditorViewModel(assetPath: animPath);
      await tester.runAsync(() => vm.load());

      vm.addNotify('Footstep_L', 0.25, type: AnimNotifyType.footstep);
      vm.addCurve('WeaponTrail');
      vm.addCurveKey('WeaponTrail', 0.5, 1.0);

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SizedBox(
              width: 1200,
              height: 300,
              child: AnimationDopeSheetWidget(
                viewModel: vm,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Check Dope sheet components exist
      expect(find.text('DOPE SHEET'), findsOneWidget);
      expect(find.text('Notifies'), findsOneWidget);
      expect(find.text('Curves'), findsOneWidget);
      expect(find.text('Footstep_L'), findsOneWidget);
      expect(find.text('WeaponTrail'), findsOneWidget);
      expect(find.text('+ Key'), findsOneWidget);
      expect(find.text('+ Notify'), findsOneWidget);
    });

    test('AnimBoneTrackInfo correctly computes active range and filters static bones', () {
      final staticChannel = GlbAnimationChannel(
        nodeIndex: 0,
        nodeName: 'root',
        path: 'translation',
        keyframeTimes: [0.0, 0.5, 1.0, 1.5, 2.0],
        values: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      );

      final staticBone = AnimBoneTrackInfo.compute('root', 0, [staticChannel], 2.0);
      expect(staticBone.hasVariation, isFalse);

      final movingChannel = GlbAnimationChannel(
        nodeIndex: 1,
        nodeName: 'pelvis',
        path: 'translation',
        keyframeTimes: [0.0, 0.5, 1.0, 1.5, 2.0],
        values: [
          0.0, 0.0, 0.0, // 0.0s (rest)
          0.0, 0.0, 0.0, // 0.5s (rest)
          0.5, 1.2, 0.0, // 1.0s (changed)
          0.8, 1.4, 0.0, // 1.5s (changed)
          0.0, 0.0, 0.0, // 2.0s (rest)
        ],
      );

      final movingBone = AnimBoneTrackInfo.compute('pelvis', 1, [movingChannel], 2.0);
      expect(movingBone.hasVariation, isTrue);
      expect(movingBone.startTime, equals(1.0));
      expect(movingBone.endTime, equals(1.5));
    });

    test('AnimBoneTrackInfo generates subTracks for Location X/Y/Z, Rotation P/Y/R, and Scale X/Y/Z', () {
      final locChannel = GlbAnimationChannel(
        nodeIndex: 1,
        nodeName: 'foot_l',
        path: 'translation',
        keyframeTimes: [0.0, 0.5, 1.0],
        values: [0.0, 0.0, 0.0, 1.0, 2.0, 3.0, 0.0, 0.0, 0.0],
      );
      final rotChannel = GlbAnimationChannel(
        nodeIndex: 1,
        nodeName: 'foot_l',
        path: 'rotation',
        keyframeTimes: [0.0, 0.5, 1.0],
        values: [0.0, 0.0, 0.0, 1.0, 0.1, 0.2, 0.3, 0.9, 0.0, 0.0, 0.0, 1.0],
      );
      final sclChannel = GlbAnimationChannel(
        nodeIndex: 1,
        nodeName: 'foot_l',
        path: 'scale',
        keyframeTimes: [0.0, 0.5, 1.0],
        values: [1.0, 1.0, 1.0, 1.2, 1.2, 1.2, 1.0, 1.0, 1.0],
      );

      final boneInfo = AnimBoneTrackInfo(
        boneName: 'foot_l',
        nodeIndex: 1,
        keyframeTimes: [0.0, 0.5, 1.0],
        startTime: 0.0,
        endTime: 1.0,
        hasVariation: true,
        channels: [locChannel, rotChannel, sclChannel],
      );

      final subs = boneInfo.subTracks;
      expect(subs.length, equals(9));
      expect(subs.map((s) => s.label).toList(), containsAll([
        'Location.X',
        'Location.Y',
        'Location.Z',
        'Rotation.Pitch (P)',
        'Rotation.Yaw (Y)',
        'Rotation.Roll (R)',
        'Scale.X',
        'Scale.Y',
        'Scale.Z',
      ]));
    });

    test('AnimBoneTrackInfo correctly marks static sub-tracks as hasVariation=false with no active keys', () {
      // Translation where X and Y move, but Z remains constant 0.0 on all frames
      final locChannel = GlbAnimationChannel(
        nodeIndex: 1,
        nodeName: 'foot_l',
        path: 'translation',
        keyframeTimes: [0.0, 0.5, 1.0],
        values: [
          0.0, 0.0, 0.0, // X=0, Y=0, Z=0
          1.0, 2.0, 0.0, // X=1, Y=2, Z=0 (Z constant!)
          0.0, 0.0, 0.0, // X=0, Y=0, Z=0
        ],
      );

      final boneInfo = AnimBoneTrackInfo(
        boneName: 'foot_l',
        nodeIndex: 1,
        keyframeTimes: [0.0, 0.5, 1.0],
        startTime: 0.0,
        endTime: 1.0,
        hasVariation: true,
        channels: [locChannel],
      );

      final subs = boneInfo.subTracks;
      final locX = subs.firstWhere((s) => s.label == 'Location.X');
      final locY = subs.firstWhere((s) => s.label == 'Location.Y');
      final locZ = subs.firstWhere((s) => s.label == 'Location.Z');

      expect(locX.hasVariation, isTrue);
      expect(locX.keyframeTimes.isNotEmpty, isTrue);

      expect(locY.hasVariation, isTrue);
      expect(locY.keyframeTimes.isNotEmpty, isTrue);

      expect(locZ.hasVariation, isFalse);
      expect(locZ.keyframeTimes.isEmpty, isTrue);
      expect(locZ.staticValue, equals(0.0));
    });
  });
}
