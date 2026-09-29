import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_data.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_store.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/status_bar_engine_segment.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// The status bar names Filament next to the engine version.
void main() {
  // The editor viewport's tickers never let pumpAndSettle settle.
  Future<void> settle(WidgetTester tester, {int frames = 20}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  String gradleVersion() {
    final text = File('${Directory.current.parent.path}/filament/android/gradle.properties').readAsStringSync();
    return RegExp(r'^VERSION_NAME=(.+)$', multiLine: true).firstMatch(text)!.group(1)!.trim();
  }

  late Directory root;
  const project = LuminaProject(projectName: 'StatusGame', activeLevel: 'contents/levels/L_Main.lmas');

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_status_filament_');
    final dir = Directory('${root.path}/StatusGame/contents/levels')..createSync(recursive: true);
    File('${root.path}/StatusGame/StatusGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    File('${dir.path}/L_Main.lmas').writeAsStringSync(jsonEncode({
      'assetId': 'level_L_Main',
      'name': 'L_Main',
      'type': 'level',
      'relativePath': 'contents/levels/L_Main.lmas',
      'metadata': {
        'actors': [
          EditorActorNode(id: 'a1', name: 'Crate_A', type: 'StaticMesh', location: [0.0, 0.0, 0.0]).toMap(),
          EditorActorNode(id: 'a2', name: 'Crate_B', type: 'StaticMesh', location: [100.0, 0.0, 0.0]).toMap(),
        ],
      },
    }));
  });
  tearDown(() => deleteTempProject(root));

  testWidgets('segments read engine, Filament, level, counts; tooltip; a tap opens About', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    addTearDown(vm.dispose);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await settle(tester);

    final version = gradleVersion();
    String textOf(String key) => tester.widget<Text>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text), matchRoot: true).first).data!;
    final keys = ['status_engine_version', 'status_filament_segment', 'status_level', 'status_actor_counts'];
    expect(keys.map(textOf).toList(), ['Lumina Engine ${vm.engineVersion}', 'Filament $version', 'L_Main', '2 actors · 0 hidden · 0 selected']);
    final xs = [for (final k in keys) tester.getTopLeft(find.byKey(ValueKey(k))).dx];
    expect(xs, orderedEquals([...xs]..sort()), reason: 'left to right in that order');
    expect(find.byKey(const ValueKey('status_filament_logo')), findsOneWidget);

    final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: find.byKey(const ValueKey('status_filament_segment')), matching: find.byType(Tooltip)).first);
    final tip = tooltip.tooltip(tester.element(find.byKey(const ValueKey('status_filament_segment'))));
    final tipText = (tip as TooltipContainer).child as Text;
    expect(tipText.data, matches(RegExp(r'^Rendered by Filament \d+\.\d+\.\d+ \(material \d+\)$')));

    await tester.tap(find.byKey(const ValueKey('status_filament_segment')));
    await settle(tester);
    expect(find.text('About Lumina Studio'), findsOneWidget);
  });

  // The logo is tinted to the theme's muted foreground, so it shows on the
  // dark and on the light theme alike.
  for (final light in [false, true]) {
    testWidgets('the Filament logo is visible on the ${light ? 'light' : 'dark'} theme', (tester) async {
      final previous = EditorTheme.current;
      EditorTheme.apply(light ? EditorThemeData.luminaLight : EditorThemeData.luminaDark);
      addTearDown(() => EditorTheme.apply(previous));
      final boundary = GlobalKey();
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Container(
          color: EditorColors.cardHeader,
          alignment: Alignment.topLeft,
          child: RepaintBoundary(key: boundary, child: const FilamentStatusSegment(onPressed: null)),
        ),
      ));
      await tester.runAsync(() => precacheImage(const AssetImage(FilamentStatusSegment.logoAsset), tester.element(find.byKey(boundary))));
      await tester.pump();
      final logo = tester.getRect(find.byKey(const ValueKey('status_filament_logo')));
      final origin = tester.getTopLeft(find.byKey(boundary));
      final image = await tester.runAsync(() => (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage());
      final bytes = (await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      final bg = EditorColors.cardHeader.toARGB32();
      var differing = 0;
      for (var y = (logo.top - origin.dy).floor(); y < (logo.bottom - origin.dy).ceil(); y++) {
        for (var x = (logo.left - origin.dx).floor(); x < (logo.right - origin.dx).ceil(); x++) {
          final i = (y * image!.width + x) * 4;
          final argb = (bytes.getUint8(i + 3) << 24) | (bytes.getUint8(i) << 16) | (bytes.getUint8(i + 1) << 8) | bytes.getUint8(i + 2);
          if (argb != bg) differing++;
        }
      }
      expect(differing, greaterThan(10), reason: 'the logo draws pixels that differ from the status bar background');
    });
  }

  test('no flutter_filament import and no Material widgets in the new UI files', () {
    for (final path in [
      'lib/ui/features/main_editor/views/about_dialog.dart',
      'lib/ui/features/main_editor/views/status_bar_engine_segment.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('package:flutter_filament')), reason: path);
      expect(source, isNot(contains('package:flutter/material.dart')), reason: path);
    }
  });
}
