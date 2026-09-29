import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Regression coverage: the toolbar showed two separate PIE Play/Pause/Stop
/// clusters.
///
/// The toolbar carried two Play/Pause/Stop groups. Both were live, but the
/// right-hand one rendered muted whatever the play state, so it read as a row
/// of dead buttons.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory projectsDir;

  setUp(() {
    projectsDir = Directory.systemTemp.createTempSync('toolbar_pie_');
  });

  tearDown(() {
    if (projectsDir.existsSync()) projectsDir.deleteSync(recursive: true);
  });

  Future<EditorViewModel> bootViewModel() async {
    final dir = Directory('${projectsDir.path}/ToolbarProject')..createSync(recursive: true);
    const project = LuminaProject(
      projectName: 'ToolbarProject',
      activeLevel: 'contents/levels/L_Main.lmas',
    );
    File('${dir.path}/ToolbarProject.lmproject')
        .writeAsStringSync(jsonEncode(project.toMap()));
    final vm = EditorViewModel(initialProject: project, projectLocation: projectsDir.path);
    await vm.ensureDefaultLevelAssets();
    return vm;
  }

  testWidgets('the toolbar offers one PIE cluster, not two', (tester) async {
    final vm = await tester.runAsync(bootViewModel) as EditorViewModel;

    tester.view.physicalSize = const Size(2400, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: ToolbarWidget(viewModel: vm)),
      ),
    );
    await tester.pump();

    Finder iconsOf(IconData icon) => find.byWidgetPredicate(
          (w) => w is Icon && w.icon == icon,
        );

    expect(
      iconsOf(LucideIcons.play),
      findsOneWidget,
      reason: 'two Play buttons in one toolbar leaves the user guessing which one runs',
    );
    expect(iconsOf(LucideIcons.pause), findsOneWidget);
    expect(iconsOf(LucideIcons.square), findsOneWidget);
  });

  // The title bar's window controls draw the same
  // Lucide glyphs — Maximize is a square — so anything that found Play, Pause
  // or Stop by icon tapped the window instead. They carry stable keys.
  testWidgets('Play, Pause and Stop carry stable keys', (tester) async {
    final vm = await tester.runAsync(bootViewModel) as EditorViewModel;

    tester.view.physicalSize = const Size(2400, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: ToolbarWidget(viewModel: vm)),
      ),
    );
    await tester.pump();

    Finder iconIn(String key, IconData icon) => find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byWidgetPredicate((w) => w is Icon && w.icon == icon),
        );

    expect(iconIn('toolbar_play', LucideIcons.play), findsOneWidget);
    expect(iconIn('toolbar_pause', LucideIcons.pause), findsOneWidget);
    expect(iconIn('toolbar_stop', LucideIcons.square), findsOneWidget);
  });

  testWidgets('Step and Eject stay out of the way until a session is running', (tester) async {
    final vm = await tester.runAsync(bootViewModel) as EditorViewModel;

    tester.view.physicalSize = const Size(2400, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: ToolbarWidget(viewModel: vm)),
      ),
    );
    await tester.pump();

    // These only exist in the cluster being consolidated away, so the merge has
    // to carry them over rather than drop them.
    expect(
      find.byWidgetPredicate((w) => w is Icon && w.icon == LucideIcons.stepForward),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate((w) => w is Icon && w.icon == LucideIcons.camera),
      findsNothing,
    );
  });
}
