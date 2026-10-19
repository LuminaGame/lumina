// The texture path reads frames back without waiting for the GPU on the UI
// thread: a tick submits the frame and its readback, the pixels arrive later
// and are presented then. Waiting inside the tick (and for the image decode
// before the next frame) held the viewport at every other vsync or worse.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/widget_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final backend in [FilamentBackend.noop, FilamentBackend.vulkan]) {
    testWidgets('a tick submits the frame and its readback without waiting; at most two are in flight (${backend.name})',
        (tester) async {
      final frames = <Duration>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 200,
            child: FilamentWidget(backend: backend, sharedEngine: false, onFrame: (cpu, _) => frames.add(cpu)),
          ),
        ),
      ));
      NativeFilamentWidgetState state() => tester.state<NativeFilamentWidgetState>(find.byType(FilamentWidget));

      // Engine up and a first frame presented.
      for (var i = 0; i < 120 && find.byType(RawImage).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      expect(find.byType(RawImage), findsOneWidget, reason: 'a rendered frame must be presented');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      final presented = frames.length;

      // Ticks with no time for the readback callbacks to arrive: the frames
      // are submitted, not waited for, and never more than two at once.
      await tester.pump(const Duration(milliseconds: 16));
      expect(state().readbacksInFlight, greaterThanOrEqualTo(1), reason: 'the tick returned before its frame was read back');
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(state().readbacksInFlight, 2, reason: 'a third frame waits for the GPU instead of piling up');

      // Given real time, they arrive and are presented.
      for (var i = 0; i < 20 && state().readbacksInFlight > 0; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(frames.length, greaterThan(presented), reason: 'the read-back frames were presented');

      if (backend == FilamentBackend.vulkan) {
        // The pixels are the frame's: the widget's clear colour.
        final image = tester.widget<RawImage>(find.byType(RawImage)).image!;
        final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
        final mid = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
        expect(bytes.getUint8(mid + 3), 255);
        expect(bytes.getUint8(mid + 2), greaterThanOrEqualTo(bytes.getUint8(mid)),
            reason: 'the dark blue-grey clear colour (0.05, 0.05, 0.07)');
      }

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });
  }

  testWidgets('onFrame runs inside a frame tick, never from the readback callback between frames', (tester) async {
    final phases = <SchedulerPhase>[];
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 160,
        height: 100,
        child: FilamentWidget(
          backend: FilamentBackend.noop,
          sharedEngine: false,
          onFrame: (_, _) => phases.add(SchedulerBinding.instance.schedulerPhase),
        ),
      ),
    ));
    // Real time between the ticks: the readbacks complete while no frame runs.
    for (var i = 0; i < 40 && phases.length < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    expect(phases.length, greaterThanOrEqualTo(4), reason: 'frames were read back and reported');
    expect(phases, everyElement(SchedulerPhase.transientCallbacks),
        reason: 'an owner may tear down between frames; its onFrame must not run then');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  });
}
