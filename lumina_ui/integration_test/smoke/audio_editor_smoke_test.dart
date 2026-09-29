import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/audio_editor_state.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/audio_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/audio_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Audio editor smoke: boot the real editor on a temp
/// project, import a **real** synthesized WAV file through the real import
/// pipeline (producing a genuine AUDIO `.lmas`), open the AudioEditor from the
/// shell, press Play and let the real clock advance the needle, then switch to
/// the Attenuation tab, drag a handle on the real curve canvas, Save, and
/// verify the `.lmas` on disk. PNG + WebM evidence goes to SmokeArtifacts.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Audio Smoke: real WAV import → decoded waveform, transport, attenuation drag, .lmas round-trip',
      (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_audio_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeAudio')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeAudio', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeAudio.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    try {
      // A real, decodable 6 s stereo PCM16 WAV written to disk: 440 Hz sine
      // in the left channel, a 220 Hz sine that fades in on the right. It is
      // long enough that the needle is still mid-file after the capture pass.
      const sampleRate = 44100;
      const seconds = 6.0;
      final frames = (sampleRate * seconds).round();
      final left = Float32List(frames);
      final right = Float32List(frames);
      for (var i = 0; i < frames; i++) {
        final t = i / sampleRate;
        left[i] = math.sin(2 * math.pi * 440.0 * t) * (i < frames ~/ 2 ? 0.2 : 1.0);
        right[i] = math.sin(2 * math.pi * 220.0 * t) * (i / frames);
      }
      final wavPath = '${tempProjectsDir.path}/Beep440.wav';
      File(wavPath).writeAsBytesSync(_buildWav(sampleRate: sampleRate, channelData: [left, right]));

      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // Real import pipeline → AUDIO .lmas under contents/audio/.
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: wavPath));
      final imported = vm.realAssets.firstWhere((a) => a.type == AssetType.audio && a.fileName.startsWith('Beep440'));
      expect(imported.lmasPath, isNotNull);

      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Live binding: animations run on the real clock, so a bare pump loop
      // advances nothing — each frame waits for real time to pass.
      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      /// A right-panel `Accordion` section can render collapsed even with
      /// `expanded: true`; a collapsed section clips its content to zero height
      /// so its controls are found but cannot be tapped.
      Future<void> expandSection(String title, String probeKey) async {
        final probe = find.byKey(ValueKey(probeKey));
        if (probe.evaluate().isEmpty) return;
        final clip = find.ancestor(of: probe, matching: find.byType(ClipRect));
        if (clip.evaluate().isEmpty || tester.getRect(clip.first).height >= 2) return;
        await tester.tap(find.descendant(of: find.byType(AccordionTrigger), matching: find.text(title)).first);
        await settle(20);
      }

      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // Open the AudioEditor workspace tab the way the Content Browser does.
      vm.openSubEditorTab('Audio', asset: imported);
      await settle(30);
      await rec.hold(const Duration(seconds: 2));
      expect(find.byType(AudioSubEditor), findsOneWidget);
      expect(find.text('Lumina 3D Spatial Audio Waveform & Attenuation Viewport'), findsNothing,
          reason: 'the stub caption is gone');

      final audioVm = _findVm(tester);
      expect(audioVm.hasError, isFalse, reason: audioVm.errorMessage ?? '');
      expect(audioVm.audio, isNotNull);
      expect(audioVm.audio!.sampleRate, 44100);
      expect(audioVm.audio!.channels, 2);
      expect(audioVm.duration, closeTo(6.0, 1e-3));
      expect(find.byKey(const ValueKey('audio_waveform_canvas')), findsOneWidget);
      expect(find.text('44100 Hz'), findsOneWidget);
      debugPrint('[audio_editor_smoke] decoded ${audioVm.audio!.frameCount} frames, '
          '${audioVm.bitDepthLabel}, ${audioVm.channelsLabel}, ${audioVm.durationLabel}');
      debugPrint('[audio_editor_smoke] ${audioVm.backendStatus}');

      // Transport: Play through the real toolbar button, then let the real
      // clock drive the needle while the video records it (well inside the
      // 6 s file).
      await tester.tap(find.byKey(const ValueKey('audio_play')));
      await settle(3);
      expect(audioVm.isPlaying, isTrue);
      await rec.hold(const Duration(milliseconds: 800));
      expect(audioVm.positionSeconds, greaterThan(0.05), reason: 'the needle really advanced on ticked time');
      expect(audioVm.positionSeconds, lessThan(audioVm.duration));
      debugPrint('[audio_editor_smoke] playhead at ${audioVm.positionLabel}, VU ${audioVm.vuPeaks}');
      expect(audioVm.vuPeaks.any((v) => v > 0.05), isTrue, reason: 'the PCM-derived VU meter is live');

      final playingPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('audio_editor_waveform_playing', playingPng);

      await tester.tap(find.byKey(const ValueKey('audio_stop')));
      await settle(3);
      expect(audioVm.isPlaying, isFalse);
      await rec.hold(const Duration(seconds: 1));

      // Click-to-seek on the real waveform canvas.
      final waveRect = tester.getRect(find.byKey(const ValueKey('audio_waveform_canvas')));
      await tester.tapAt(Offset(waveRect.left + waveRect.width * 0.5, waveRect.center.dy));
      await settle(3);
      expect(audioVm.positionSeconds, closeTo(audioVm.duration * 0.5, 0.05));
      await rec.hold(const Duration(milliseconds: 1500));

      // Attenuation tab: drag a handle on the real curve canvas.
      await tester.tap(find.byKey(const ValueKey('audio_tab_attenuation')));
      await settle(20);
      expect(find.byKey(const ValueKey('audio_attenuation_canvas')), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));

      audioVm.setAttenuationModel(LuminaAttenuationModel.inverse);
      audioVm.setInnerRadius(400.0);
      audioVm.setFalloffDistance(3500.0);
      await settle(5);
      await rec.hold(const Duration(seconds: 1));

      final curveRect = tester.getRect(find.byKey(const ValueKey('audio_attenuation_canvas')));
      final innerBefore = audioVm.settings.attenuation.innerRadius;
      final startX = curveRect.left + curveRect.width * audioVm.innerRadiusHandleFraction;
      final gesture = await tester.startGesture(Offset(startX, curveRect.center.dy));
      // The handle drag is recorded as it moves.
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(Offset(curveRect.width * 0.01, 0));
        await tester.pump(const Duration(milliseconds: 16));
        await rec.capture();
      }
      await settle(5);
      await gesture.up();
      await settle(5);
      expect(audioVm.settings.attenuation.innerRadius, greaterThan(innerBefore),
          reason: 'the inner-radius handle followed the drag');
      expect(audioVm.outerDistance, greaterThanOrEqualTo(audioVm.settings.attenuation.innerRadius),
          reason: 'handles never cross');

      audioVm.setProbeDistance(1200.0);
      await settle(5);
      expect(find.text(audioVm.probeLabel), findsOneWidget);
      debugPrint('[audio_editor_smoke] probe ${audioVm.probeLabel} '
          '(inner ${audioVm.settings.attenuation.innerRadius.toStringAsFixed(1)}, '
          'falloff ${audioVm.settings.attenuation.falloffDistance.toStringAsFixed(1)})');

      final curvePng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('audio_editor_attenuation_curve', curvePng);
      await rec.hold(const Duration(milliseconds: 1500));

      // Properties + Save through the real toolbar, then read the .lmas back.
      await expandSection('Sound Properties', 'audio_sound_class');
      audioVm.setVolumeMultiplier(0.5);
      audioVm.setSoundClass(AudioSoundClass.music);
      await settle(5);
      expect(audioVm.isDirty, isTrue);
      await rec.hold(const Duration(seconds: 1));

      await tester.tap(find.byKey(const ValueKey('audio_save')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await settle(10);
      expect(audioVm.isDirty, isFalse);
      await rec.hold(const Duration(milliseconds: 1500));
      rec.save('Audio Smoke: real WAV import → decoded waveform, transport, attenuation drag, .lmas round-trip');

      final saved = LuminaAsset.fromBytes(File(imported.lmasPath!).readAsBytesSync());
      final stored = jsonDecode(saved.metadata['audio_settings']!) as Map<String, dynamic>;
      expect(stored['v'], 1);
      expect(stored['volumeMultiplier'], 0.5);
      expect(stored['soundClass'], 'Music');
      expect((stored['attenuation'] as Map)['model'], 'inverse');
      expect(saved.rawPayload, isNotNull, reason: 'the real WAV payload survives the save');

      // Reopening restores every control from the real file.
      final reopened = AudioEditorViewModel(assetPath: imported.lmasPath!);
      await tester.runAsync(reopened.load);
      expect(reopened.settings.volumeMultiplier, 0.5);
      expect(reopened.settings.soundClass, AudioSoundClass.music);
      expect(reopened.settings.attenuation.model, LuminaAttenuationModel.inverse);
      expect(reopened.audio!.channels, 2);
      reopened.dispose();
      vm.dispose();
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });
}

AudioEditorViewModel _findVm(WidgetTester tester) {
  final state = tester.state(find.byType(AudioSubEditor));
  // ignore: invalid_use_of_protected_member
  final dynamic s = state;
  return s.viewModelForTest as AudioEditorViewModel;
}

/// Minimal RIFF/WAVE (PCM16) writer — the smoke fixture is a real, decodable
/// audio file on disk, never fabricated sample data pretending to be one.
Uint8List _buildWav({required int sampleRate, required List<Float32List> channelData}) {
  final channels = channelData.length;
  final frames = channelData.first.length;
  const bytesPerSample = 2;
  final dataSize = frames * channels * bytesPerSample;

  final out = BytesBuilder();
  void str(String s) => out.add(ascii.encode(s));
  void u32(int v) => out.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) => out.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

  str('RIFF');
  u32(36 + dataSize);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1);
  u16(channels);
  u32(sampleRate);
  u32(sampleRate * channels * bytesPerSample);
  u16(channels * bytesPerSample);
  u16(16);
  str('data');
  u32(dataSize);

  final pcm = ByteData(dataSize);
  var offset = 0;
  for (var f = 0; f < frames; f++) {
    for (var c = 0; c < channels; c++) {
      pcm.setInt16(offset, (channelData[c][f].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
      offset += 2;
    }
  }
  out.add(pcm.buffer.asUint8List());
  return out.toBytes();
}
