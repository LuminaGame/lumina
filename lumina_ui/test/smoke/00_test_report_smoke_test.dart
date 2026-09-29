// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A running widget for the harness to record: a progress bar and a frame
/// counter driven by a real ticker, so every captured frame differs.
class _RecordingProbe extends StatefulWidget {
  const _RecordingProbe();

  @override
  State<_RecordingProbe> createState() => _RecordingProbeState();
}

class _RecordingProbeState extends State<_RecordingProbe> with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final t = _clock.value;
        return Container(
          color: EditorColors.background,
          padding: const EdgeInsets.all(48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Smoke Report Self Test', style: TextStyle(fontSize: 28, color: EditorColors.foreground)),
              const SizedBox(height: 24),
              Text('${(t * 10).toStringAsFixed(2)} s recorded',
                  style: const TextStyle(fontSize: 20, color: EditorColors.mutedForeground)),
              const SizedBox(height: 24),
              SizedBox(width: 800, child: Progress(progress: t, min: 0, max: 1)),
              const SizedBox(height: 48),
              // A block sweeping across the frame.
              Transform.translate(
                offset: Offset(t * 800, 0),
                child: Container(width: 120, height: 120, color: EditorColors.primary),
              ),
            ],
          ),
        );
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('00_test_report: smoke report harness self test captures screenshot and saves sidecar artifact with 3d assets', (tester) async {
    // Deliberately does not clear the artifact directory: it is shared with
    // every other smoke test in the package and clearing it deletes their
    // evidence. Artifacts are matched to tests by declared name through the
    // sidecar JSON, so stale files cannot be mistaken for this one's.

    // Verify test-assets directory
    final assetsDir = SmokeArtifacts.testAssetsDir;
    expect(assetsDir.existsSync(), isTrue);

    final barrelAsset = 'Props/Barrels/barrel_01.glb';
    final barrelFile = File('${assetsDir.path}/$barrelAsset');
    final usedAssets = <String>[];
    if (barrelFile.existsSync()) {
      usedAssets.add(barrelAsset);
    } else {
      // Find any valid prop asset
      final propsDir = Directory('${assetsDir.path}/Props');
      if (propsDir.existsSync()) {
        for (final entity in propsDir.listSync()) {
          if (entity is Directory) {
            usedAssets.add('Props/${entity.path.split('/').last}');
            break;
          }
        }
      }
    }

    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: const _RecordingProbe()),
    ));
    await tester.pump();

    // A real capture of the running widget, published with its sidecar.
    final screenshot = await SmokeArtifacts.captureWidgetPng(tester, find.byKey(boundaryKey));
    final pngFile = SmokeArtifacts.saveScreenshot(
      '00_test_report: smoke report harness self test',
      screenshot,
      usedAssets: usedAssets,
    );

    expect(pngFile.existsSync(), isTrue);
    expect(pngFile.lengthSync(), greaterThan(0));

    final sidecarFile = File('${SmokeArtifacts.dir.path}/00_test_report_smoke_report_harness_self_test.json');
    expect(sidecarFile.existsSync(), isTrue);

    // A recording under 10 s is refused.
    final short = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await short.hold(const Duration(seconds: 2));
    expect(() => short.save('00_test_report: too short'), throwsStateError);
    expect(File('${SmokeArtifacts.dir.path}/00_test_report_too_short.webm').existsSync(), isFalse);

    // The harness records the running widget: 10.5 s at 30 fps, 1024×768.
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(milliseconds: 10500));
    final videoFile = rec.save('00_test_report: smoke report harness self test', usedAssets: usedAssets);
    expect(SmokeArtifacts.videoDurationSeconds(videoFile), greaterThanOrEqualTo(10.0));
    expect(SmokeArtifacts.videoFramesPerSecond(videoFile), greaterThanOrEqualTo(29.9));
    expect(SmokeArtifacts.videoFrameSize(videoFile), (1024, 768));
    expect(videoFile.existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
