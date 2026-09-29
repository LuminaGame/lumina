import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/audio_editor_state.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/audio_wav_decoder_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/audio_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/audio_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Every scenario runs against
/// real WAV bytes written to a real temp `.lmas` on disk.
/// Fixtures are synthesized by the tiny RIFF writer below, so the decoder is
/// exercised on genuine PCM16 / PCM24 / IEEE-float32 files.

// ---------------------------------------------------------------------------
// Test-side RIFF/WAVE writer (real files, no fabricated "imports")
// ---------------------------------------------------------------------------

Uint8List buildWav({
  required int sampleRate,
  required int bitDepth,
  required List<Float32List> channelData,
  bool floatFormat = false,
  int? truncateDataBy,
}) {
  final channels = channelData.length;
  final frames = channelData.first.length;
  final bytesPerSample = bitDepth ~/ 8;
  final dataSize = frames * channels * bytesPerSample;
  final data = BytesBuilder();

  void addSample(double v) {
    final c = v.clamp(-1.0, 1.0).toDouble();
    if (floatFormat) {
      final b = ByteData(4)..setFloat32(0, c, Endian.little);
      data.add(b.buffer.asUint8List());
    } else if (bitDepth == 16) {
      final i = (c * 32767.0).round();
      final b = ByteData(2)..setInt16(0, i, Endian.little);
      data.add(b.buffer.asUint8List());
    } else if (bitDepth == 24) {
      final i = (c * 8388607.0).round();
      final u = i < 0 ? i + 0x1000000 : i;
      data.add([u & 0xFF, (u >> 8) & 0xFF, (u >> 16) & 0xFF]);
    } else if (bitDepth == 32) {
      final i = (c * 2147483647.0).round();
      final b = ByteData(4)..setInt32(0, i, Endian.little);
      data.add(b.buffer.asUint8List());
    } else {
      throw ArgumentError('unsupported bit depth $bitDepth');
    }
  }

  for (var f = 0; f < frames; f++) {
    for (var c = 0; c < channels; c++) {
      addSample(channelData[c][f]);
    }
  }

  var payload = data.toBytes();
  if (truncateDataBy != null) {
    payload = Uint8List.sublistView(payload, 0, payload.length - truncateDataBy);
  }

  final out = BytesBuilder();
  void str(String s) => out.add(ascii.encode(s));
  void u32(int v) => out.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) => out.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

  str('RIFF');
  u32(36 + dataSize);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(floatFormat ? 3 : 1);
  u16(channels);
  u32(sampleRate);
  u32(sampleRate * channels * bytesPerSample);
  u16(channels * bytesPerSample);
  u16(bitDepth);
  str('data');
  u32(dataSize); // declared size stays honest → truncation is detectable
  out.add(payload);
  return out.toBytes();
}

List<Float32List> sineChannels({
  required int sampleRate,
  required double seconds,
  required int channels,
  double frequency = 440.0,
}) {
  final frames = (sampleRate * seconds).round();
  return List.generate(channels, (c) {
    final out = Float32List(frames);
    for (var i = 0; i < frames; i++) {
      out[i] = math.sin(2 * math.pi * frequency * i / sampleRate);
    }
    return out;
  });
}

/// Half silence, then half full-scale square — exact bin boundaries.
List<Float32List> halfSilenceChannels({required int frames, int channels = 1}) {
  return List.generate(channels, (c) {
    final out = Float32List(frames);
    for (var i = frames ~/ 2; i < frames; i++) {
      out[i] = i.isEven ? 1.0 : -1.0;
    }
    return out;
  });
}

/// shadcn panels keep repainting, so a bounded pump loop replaces
/// `pumpAndSettle` throughout the widget group.
Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  late Directory tempDir;
  late String lmasPath;

  String writeAudioAsset(Uint8List wavBytes, {String name = 'Beep', Map<String, String> metadata = const {}}) {
    final path = '${tempDir.path}/contents/audio/$name.lmas';
    Directory('${tempDir.path}/contents/audio').createSync(recursive: true);
    final asset = LuminaAsset(
      assetId: 'audio_$name',
      name: name,
      type: AssetType.audio,
      rawPayload: wavBytes,
      metadata: metadata,
    );
    File(path).writeAsBytesSync(asset.toProtoBufferBytes());
    return path;
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_audio_editor_');
    lmasPath = '${tempDir.path}/contents/audio/Beep.lmas';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------------------
  // Decoder
  // -------------------------------------------------------------------------

  group('WavDecoderService', () {
    test('PCM16 stereo 44100 Hz 0.5 s sine decodes with real header facts', () {
      final bytes = buildWav(sampleRate: 44100, bitDepth: 16, channelData: sineChannels(sampleRate: 44100, seconds: 0.5, channels: 2));
      final decoded = WavDecoderService.decode(bytes);

      expect(decoded.sampleRate, 44100);
      expect(decoded.channels, 2);
      expect(decoded.bitDepth, 16);
      expect(decoded.frameCount, 22050);
      expect(decoded.duration, closeTo(0.5, 1e-6));
      expect(decoded.samples.length, 2);

      var peak = 0.0;
      for (final v in decoded.samples[0]) {
        peak = math.max(peak, v.abs());
      }
      expect(peak, closeTo(1.0, 0.01));
    });

    test('PCM24 and float32 decode to the same normalized values as PCM16 within 1e-3', () {
      final src = sineChannels(sampleRate: 8000, seconds: 0.05, channels: 1);
      final ref = WavDecoderService.decode(buildWav(sampleRate: 8000, bitDepth: 32, channelData: src, floatFormat: true));
      final pcm24 = WavDecoderService.decode(buildWav(sampleRate: 8000, bitDepth: 24, channelData: src));
      final pcm16 = WavDecoderService.decode(buildWav(sampleRate: 8000, bitDepth: 16, channelData: src));

      expect(pcm24.bitDepth, 24);
      expect(ref.isFloat, isTrue);
      expect(pcm24.frameCount, ref.frameCount);
      for (var i = 0; i < ref.frameCount; i++) {
        expect(pcm24.samples[0][i], closeTo(ref.samples[0][i], 1e-3), reason: '24-bit sign extension at frame $i');
        expect(pcm16.samples[0][i], closeTo(ref.samples[0][i], 1e-3), reason: '16-bit at frame $i');
      }
      // A negative 24-bit sample must stay negative (the classic decoder bug).
      expect(pcm24.samples[0].any((v) => v < -0.5), isTrue);
    });

    test('mono file decodes to a single channel', () {
      final decoded = WavDecoderService.decode(
        buildWav(sampleRate: 22050, bitDepth: 16, channelData: sineChannels(sampleRate: 22050, seconds: 0.1, channels: 1)),
      );
      expect(decoded.channels, 1);
      expect(decoded.samples.length, 1);
    });

    test('peakEnvelope(100) on half-silence/half-full-scale has exact bin boundaries', () {
      final decoded = WavDecoderService.decode(
        buildWav(sampleRate: 1000, bitDepth: 16, channelData: halfSilenceChannels(frames: 1000)),
      );
      final env = decoded.peakEnvelope(100);
      expect(env.length, 1);
      expect(env[0].mins.length, 100);
      expect(env[0].maxs.length, 100);
      for (var i = 0; i < 50; i++) {
        expect(env[0].mins[i], closeTo(0.0, 1e-6), reason: 'bin $i is silent');
        expect(env[0].maxs[i], closeTo(0.0, 1e-6), reason: 'bin $i is silent');
      }
      for (var i = 50; i < 100; i++) {
        expect(env[0].maxs[i], closeTo(1.0, 1e-3), reason: 'bin $i is full scale');
        expect(env[0].mins[i], closeTo(-1.0, 1e-3), reason: 'bin $i is full scale');
      }
    });

    test('peakEnvelope re-bins from decoded samples at any zoom level', () {
      final decoded = WavDecoderService.decode(
        buildWav(sampleRate: 1000, bitDepth: 16, channelData: halfSilenceChannels(frames: 1000)),
      );
      final zoomed = decoded.peakEnvelope(40, startFrame: 500, endFrame: 1000);
      for (final v in zoomed[0].maxs) {
        expect(v, closeTo(1.0, 1e-3));
      }
    });

    test('truncated data chunk throws a typed decode error', () {
      final bytes = buildWav(
        sampleRate: 8000,
        bitDepth: 16,
        channelData: sineChannels(sampleRate: 8000, seconds: 0.1, channels: 1),
        truncateDataBy: 200,
      );
      expect(() => WavDecoderService.decode(bytes), throwsA(isA<WavDecodeException>()));
    });

    test('non-RIFF payload (e.g. an mp3) throws a typed decode error', () {
      final mp3ish = Uint8List.fromList([0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x21]);
      expect(() => WavDecoderService.decode(mp3ish), throwsA(isA<WavDecodeException>()));
    });
  });

  // -------------------------------------------------------------------------
  // View model: load / transport / seek / VU
  // -------------------------------------------------------------------------

  group('AudioEditorViewModel', () {
    Future<AudioEditorViewModel> open({
      Uint8List? wav,
      Map<String, String> metadata = const {},
      LuminaAudioBackend? backend,
    }) async {
      final bytes = wav ?? buildWav(sampleRate: 44100, bitDepth: 16, channelData: sineChannels(sampleRate: 44100, seconds: 0.5, channels: 2));
      writeAudioAsset(bytes, metadata: metadata);
      final vm = AudioEditorViewModel(assetPath: lmasPath, backend: backend);
      await vm.load();
      return vm;
    }

    test('loading a real AUDIO .lmas exposes the fixture header facts', () async {
      final vm = await open();
      addTearDown(vm.dispose);
      expect(vm.hasError, isFalse);
      expect(vm.audio, isNotNull);
      expect(vm.sampleRateLabel, '44100 Hz');
      expect(vm.bitDepthLabel, '16-bit PCM');
      expect(vm.channelsLabel, 'Stereo');
      expect(vm.durationLabel, '00:00.500');
      expect(vm.sampleCountLabel, '22050 samples');
    });

    test('malformed payload surfaces the decode error and no waveform', () async {
      final vm = await open(
        wav: buildWav(
          sampleRate: 8000,
          bitDepth: 16,
          channelData: sineChannels(sampleRate: 8000, seconds: 0.1, channels: 1),
          truncateDataBy: 200,
        ),
      );
      addTearDown(vm.dispose);
      expect(vm.hasError, isTrue);
      expect(vm.errorMessage, isNotNull);
      expect(vm.audio, isNull, reason: 'never a fake waveform');
    });

    test('play() logs one backend play with base · multiplier volume; stop() uses the same handle', () async {
      final backend = NullAudioBackend();
      final vm = await open(backend: backend);
      addTearDown(vm.dispose);

      vm.setVolumeMultiplier(0.5);
      await vm.play();
      expect(backend.playCalls.length, 1);
      expect(backend.playCalls.single.volume, closeTo(0.5, 1e-9));
      expect(backend.playCalls.single.looping, isFalse);
      expect(vm.isPlaying, isTrue);
      final handle = vm.activeHandle;
      expect(handle, isNotNull);

      vm.tick(0.1);
      expect(vm.positionSeconds, closeTo(0.1, 1e-9));

      vm.stop();
      expect(backend.stopCalls.single, handle);
      expect(vm.isPlaying, isFalse);
      expect(vm.positionSeconds, 0.0);
    });

    test('loop on wraps the needle; loop off ends via the synthesized onFinished', () async {
      final backend = NullAudioBackend();
      final vm = await open(backend: backend);
      addTearDown(vm.dispose);

      vm.setLooping(true);
      await vm.play();
      expect(backend.playCalls.single.looping, isTrue);
      for (var i = 0; i < 6; i++) {
        vm.tick(0.1);
      }
      expect(vm.isPlaying, isTrue, reason: 'loop keeps running');
      expect(vm.positionSeconds, closeTo(0.1, 1e-6), reason: 'wrapped at 0.5 s');
      vm.stop();

      vm.setLooping(false);
      await vm.play();
      for (var i = 0; i < 6; i++) {
        vm.tick(0.1);
      }
      expect(vm.isPlaying, isFalse, reason: 'NullAudioBackend.onFinished ended it');
      expect(vm.finishedCount, 1);

      // A late/unknown handle callback must be tolerated silently.
      backend.onFinished?.call(const LuminaAudioHandle(987654));
      expect(vm.finishedCount, 1);
    });

    test('click-to-seek at 50% and PCM-derived VU', () async {
      final frames = 44100;
      final vm = await open(
        wav: buildWav(sampleRate: 44100, bitDepth: 16, channelData: halfSilenceChannels(frames: frames, channels: 2)),
      );
      addTearDown(vm.dispose);

      vm.seekFraction(0.5);
      expect(vm.positionSeconds, closeTo(vm.duration / 2, 1e-9));

      vm.seekFraction(0.25);
      expect(vm.vuPeaks[0], closeTo(0.0, 1e-3), reason: 'silent half');
      vm.seekFraction(0.75);
      expect(vm.vuPeaks[0], closeTo(1.0, 1e-2), reason: 'full-scale half');
    });
  });

  // -------------------------------------------------------------------------
  // Attenuation parity with the runtime
  // -------------------------------------------------------------------------

  group('attenuation editor', () {
    Future<AudioEditorViewModel> openDefault() async {
      writeAudioAsset(buildWav(sampleRate: 8000, bitDepth: 16, channelData: sineChannels(sampleRate: 8000, seconds: 0.2, channels: 1)));
      final vm = AudioEditorViewModel(assetPath: lmasPath);
      await vm.load();
      return vm;
    }

    test('linear parity with LuminaSoundAttenuation exact values', () async {
      final vm = await openDefault();
      addTearDown(vm.dispose);
      vm.setAttenuationModel(LuminaAttenuationModel.linear);
      vm.setInnerRadius(2.0);
      vm.setFalloffDistance(8.0);

      expect(vm.gainAt(2.0), closeTo(1.0, 1e-9));
      expect(vm.gainAt(6.0), closeTo(0.5, 1e-9));
      expect(vm.gainAt(10.0), closeTo(0.0, 1e-9));
      expect(vm.gainAt(50.0), closeTo(0.0, 1e-9));

      vm.setProbeDistance(6.0);
      expect(vm.probeGain, closeTo(0.5, 1e-9));
      expect(vm.probeLabel, 'd = 6.0 → gain 0.500');
    });

    test('logarithmic and inverse are monotonic with a -60 dB floor', () async {
      final vm = await openDefault();
      addTearDown(vm.dispose);
      vm.setInnerRadius(2.0);
      vm.setFalloffDistance(8.0);

      for (final model in [LuminaAttenuationModel.logarithmic, LuminaAttenuationModel.inverse]) {
        vm.setAttenuationModel(model);
        final runtime = LuminaSoundAttenuation(innerRadius: 2.0, falloffDistance: 8.0, model: model);
        var previous = 1.1;
        for (var d = 2.0; d <= 10.0; d += 0.5) {
          final g = vm.gainAt(d);
          expect(g, closeTo(runtime.calculateGain(d), 1e-12), reason: 'runtime parity at $d for $model');
          expect(g, lessThanOrEqualTo(previous + 1e-9), reason: 'monotonic decreasing');
          previous = g;
        }
        expect(vm.gainAt(10.0), closeTo(0.001, 1e-9), reason: '-60 dB floor');
      }

      vm.setAttenuationModel(LuminaAttenuationModel.logarithmic);
      final logGain = vm.gainAt(6.0);
      vm.setAttenuationModel(LuminaAttenuationModel.inverse);
      expect(vm.gainAt(6.0), isNot(closeTo(logGain, 1e-6)), reason: 'switching the model changes the curve');
    });

    test('dragging the inner-radius handle syncs with the numeric field and clamps ordering', () async {
      final vm = await openDefault();
      addTearDown(vm.dispose);
      vm.setInnerRadius(400.0);
      vm.setFalloffDistance(3500.0);

      // Drag: canvas x → distance. The plot spans 0 → outer × 1.2.
      vm.dragInnerRadiusToFraction(0.25);
      expect(vm.settings.attenuation.innerRadius, closeTo(vm.plotMaxDistance * 0.25, 1e-6));

      // Numeric field → handle
      vm.setInnerRadius(800.0);
      expect(vm.innerRadiusHandleFraction, closeTo(800.0 / vm.plotMaxDistance, 1e-9));

      // Ordering validation: the inner handle cannot pass the falloff edge.
      final outer = vm.outerDistance;
      vm.setInnerRadius(outer + 1000.0);
      expect(vm.settings.attenuation.innerRadius, closeTo(outer, 1e-6));
      expect(vm.settings.attenuation.falloffDistance, greaterThanOrEqualTo(0.0));
      expect(vm.outerDistance, greaterThanOrEqualTo(vm.settings.attenuation.innerRadius));

      vm.setFalloffDistance(-50.0);
      expect(vm.settings.attenuation.falloffDistance, greaterThanOrEqualTo(0.0));
    });
  });

  // -------------------------------------------------------------------------
  // Persistence
  // -------------------------------------------------------------------------

  group('AUDIO .lmas metadata round-trip', () {
    test('save writes versioned audio_settings and reopening restores every control', () async {
      writeAudioAsset(buildWav(sampleRate: 44100, bitDepth: 16, channelData: sineChannels(sampleRate: 44100, seconds: 0.25, channels: 2)));
      final vm = AudioEditorViewModel(assetPath: lmasPath);
      await vm.load();
      expect(vm.isDirty, isFalse);

      vm.setVolumeMultiplier(0.5);
      vm.setPitchMultiplier(1.25);
      vm.setPitchRandomization(0.1);
      vm.setSoundClass(AudioSoundClass.music);
      vm.setLooping(true);
      vm.setSpatialized(true);
      vm.setAttenuationModel(LuminaAttenuationModel.inverse);
      vm.setInnerRadius(400.0);
      vm.setFalloffDistance(3500.0);
      expect(vm.isDirty, isTrue);

      expect(await vm.save(), isTrue);
      expect(vm.isDirty, isFalse);
      vm.dispose();

      final raw = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync());
      final stored = jsonDecode(raw.metadata['audio_settings']!) as Map<String, dynamic>;
      expect(stored['v'], 1);
      expect(stored['volumeMultiplier'], 0.5);
      expect(stored['soundClass'], 'Music');
      expect((stored['attenuation'] as Map)['model'], 'inverse');
      expect((stored['attenuation'] as Map)['innerRadius'], 400.0);
      expect((stored['attenuation'] as Map)['falloffDistance'], 3500.0);
      expect(raw.rawPayload, isNotNull, reason: 'the WAV payload survives a save');

      final reopened = AudioEditorViewModel(assetPath: lmasPath);
      await reopened.load();
      addTearDown(reopened.dispose);
      expect(reopened.settings.volumeMultiplier, 0.5);
      expect(reopened.settings.pitchMultiplier, 1.25);
      expect(reopened.settings.pitchRandomization, 0.1);
      expect(reopened.settings.soundClass, AudioSoundClass.music);
      expect(reopened.settings.looping, isTrue);
      expect(reopened.settings.spatialized, isTrue);
      expect(reopened.settings.attenuation.model, LuminaAttenuationModel.inverse);
      expect(reopened.settings.attenuation.innerRadius, 400.0);
      expect(reopened.settings.attenuation.falloffDistance, 3500.0);
      expect(reopened.audio!.sampleRate, 44100);
    });

    test('AudioSettings JSON is versioned and tolerant of a missing block', () {
      final defaults = AudioSettings();
      final round = AudioSettings.fromJson(jsonDecode(jsonEncode(defaults.toJson())) as Map<String, dynamic>);
      expect(round, defaults);
      expect(AudioSettings.fromJson(const {}), defaults);
    });
  });

  // -------------------------------------------------------------------------
  // Widget
  // -------------------------------------------------------------------------

  group('AudioSubEditor widget', () {
    Future<AudioEditorViewModel> pumpEditor(WidgetTester tester, {Uint8List? wav, NullAudioBackend? backend}) async {
      writeAudioAsset(wav ?? buildWav(sampleRate: 44100, bitDepth: 16, channelData: halfSilenceChannels(frames: 22050, channels: 2)));
      final vm = AudioEditorViewModel(assetPath: lmasPath, backend: backend);
      // Real disk I/O must run outside the fake-async zone.
      await tester.runAsync(vm.load);
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: AudioSubEditor(assetName: 'Beep', assetPath: lmasPath, viewModel: vm)),
      ));
      await settle(tester);
      return vm;
    }

    testWidgets('header badges show real facts and the stub caption is gone', (tester) async {
      final vm = await pumpEditor(tester);
      addTearDown(vm.dispose);

      expect(find.text('Lumina 3D Spatial Audio Waveform & Attenuation Viewport'), findsNothing);
      expect(find.text('44100 Hz'), findsOneWidget);
      expect(find.text('16-bit PCM'), findsOneWidget);
      expect(find.text('Stereo'), findsOneWidget);
      expect(find.text('00:00.500'), findsWidgets);
      expect(find.byKey(const ValueKey('audio_waveform_canvas')), findsOneWidget);
      expect(find.byKey(const ValueKey('audio_backend_status')), findsOneWidget);
    });

    testWidgets('transport buttons drive the view model through the backend', (tester) async {
      final backend = NullAudioBackend();
      final vm = await pumpEditor(tester, backend: backend);
      addTearDown(vm.dispose);

      await tester.tap(find.byKey(const ValueKey('audio_play')));
      await tester.pump();
      expect(vm.isPlaying, isTrue);
      expect(backend.playCalls.length, 1);

      await tester.tap(find.byKey(const ValueKey('audio_stop')));
      await tester.pump();
      expect(vm.isPlaying, isFalse);
      expect(backend.stopCalls.length, 1);
    });

    testWidgets('attenuation tab shows the curve canvas and the probe readout', (tester) async {
      final vm = await pumpEditor(tester);
      addTearDown(vm.dispose);

      await tester.tap(find.byKey(const ValueKey('audio_tab_attenuation')));
      await settle(tester);

      expect(find.byKey(const ValueKey('audio_attenuation_canvas')), findsOneWidget);
      vm.setInnerRadius(2.0);
      vm.setFalloffDistance(8.0);
      vm.setProbeDistance(6.0);
      await settle(tester);
      expect(find.text('d = 6.0 → gain 0.500'), findsOneWidget);
    });

    testWidgets('decode error renders the error state, never a waveform', (tester) async {
      final vm = await pumpEditor(
        tester,
        wav: buildWav(
          sampleRate: 8000,
          bitDepth: 16,
          channelData: sineChannels(sampleRate: 8000, seconds: 0.1, channels: 1),
          truncateDataBy: 200,
        ),
      );
      addTearDown(vm.dispose);
      expect(find.byKey(const ValueKey('audio_decode_error')), findsOneWidget);
      expect(find.byKey(const ValueKey('audio_waveform_canvas')), findsNothing);
    });

    testWidgets('Save through the toolbar persists to the real .lmas', (tester) async {
      final vm = await pumpEditor(tester);
      addTearDown(vm.dispose);

      vm.setVolumeMultiplier(0.25);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('audio_save')));
      // The button's save does real disk I/O: alternate fake-clock frames with
      // real time so the write completes inside the test.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }

      final raw = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync());
      final stored = jsonDecode(raw.metadata['audio_settings']!) as Map<String, dynamic>;
      expect(stored['volumeMultiplier'], 0.25);
      expect(vm.isDirty, isFalse);
    });
  });
}
