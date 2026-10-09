import 'package:flutter/material.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// A game fills the screen at the display's physical pixels, without the
/// tool viewport's rounded border; tools keep the logical size and the panel.
void main() {
  Future<(int, int)> renderSizeOf(WidgetTester tester, FilamentWidget widget) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    final size = (tester.state(find.byType(FilamentWidget)) as dynamic).renderSize as (int, int);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    return size;
  }

  BoxDecoration? decorationOf(WidgetTester tester) {
    final container = tester.widgetList<Container>(
      find.descendant(of: find.byType(FilamentWidget), matching: find.byType(Container)),
    ).first;
    return container.decoration as BoxDecoration?;
  }

  testWidgets('physicalResolution renders at layout size x device pixel ratio', (tester) async {
    final size = await renderSizeOf(
      tester,
      const FilamentWidget(backend: FilamentBackend.noop, physicalResolution: true, decorated: false),
    );
    expect(size, (1600, 900));
  });

  testWidgets('by default the frame renders at the logical layout size', (tester) async {
    final size = await renderSizeOf(tester, const FilamentWidget(backend: FilamentBackend.noop));
    expect(size, (800, 450));
  });

  testWidgets('an undecorated frame has no border or rounded corners', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FilamentWidget(backend: FilamentBackend.noop, decorated: false)),
    ));
    final decoration = decorationOf(tester)!;
    expect(decoration.border, isNull);
    expect(decoration.borderRadius, isNull);
    expect(decoration.boxShadow, isNull);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FilamentWidget(backend: FilamentBackend.noop)),
    ));
    expect(decorationOf(tester)!.border, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  });
}
