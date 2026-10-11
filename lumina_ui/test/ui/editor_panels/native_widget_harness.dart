import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/interaction/editor_interaction.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Hosts one native widget the way an editor panel does: its committed
/// changes are written into the state map (a new map, as an element
/// refresh delivers it) and every event is recorded.
class NativeWidgetHarness {
  NativeWidgetHarness(Map<String, Object?> state) : state = ValueNotifier(state);

  final ValueNotifier<Map<String, Object?>> state;
  final List<EditorWidgetEvent> events = [];
  final List<(Map<String, Object?>, bool)> commits = [];

  void onEvent(EditorWidgetEvent e) => events.add(e);

  void onState(Map<String, Object?> changes, {required bool edit}) {
    commits.add((changes, edit));
    state.value = {...state.value, ...changes};
  }

  /// The events named [event].
  List<EditorWidgetEvent> named(String event) => [for (final e in events) if (e.event == event) e];

  Future<void> pump(WidgetTester tester, Widget Function(Map<String, Object?> state) build, {Size size = const Size(900, 360)}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: ValueListenableBuilder<Map<String, Object?>>(valueListenable: state, builder: (context, s, _) => build(s)),
          ),
        ),
      ),
    ));
    await tester.pump();
  }
}

/// Pumps [count] frames of 16 ms.
Future<void> frames(WidgetTester tester, [int count = 1]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
