import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_renderer.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A [PluginViewRenderer] in the editor theme whose spec the test swaps, and
/// every event it sent.
class PluginViewHarness {
  PluginViewHarness(PluginViewSpec spec) : spec = ValueNotifier(spec);

  final ValueNotifier<PluginViewSpec> spec;
  final List<PluginViewEvent> events = [];

  Future<void> pump(WidgetTester tester, {String? projectDir, double width = 460}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: ValueListenableBuilder<PluginViewSpec>(
                valueListenable: spec,
                // A new closure every build: the renderer must keep sending
                // to the current one.
                builder: (context, s, _) => PluginViewRenderer(spec: s, onEvent: (e) => events.add(e), projectDir: projectDir),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  /// Applies [patch] the way a panel host does.
  Future<void> patch(WidgetTester tester, PluginViewPatch patch) async {
    spec.value = spec.value.apply(patch);
    await tester.pump();
  }

  /// `(controlId, kind, value)` of every event, for compact expectations.
  List<(String, String, Object?)> get sent => [for (final e in events) (e.controlId, e.kind, e.value)];
}

Finder byControl(String viewId, String controlId) => find.byKey(ValueKey('$viewId/$controlId'));
