import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_layout_state.dart';

/// The right dock's width, which plugin panels are open and the
/// active right panel persist with the layout.
void main() {
  test('the right dock round-trips through JSON', () {
    final s = EditorLayoutState(rightWidth: 420, pluginPanelVisible: {'probe.chat': true, 'probe.notes': false}, activeRightPanel: 'probe.chat');
    final back = EditorLayoutState.fromJson(s.toJson());
    expect(back.rightWidth, 420);
    expect(back.pluginPanelVisible, {'probe.chat': true, 'probe.notes': false});
    expect(back.activeRightPanel, 'probe.chat');
  });

  test('a layout saved before the right dock loads with it closed at the default width', () {
    final back = EditorLayoutState.fromJson({'outlinerWidth': 250.0, 'bottomPinned': true});
    expect(back.outlinerWidth, 250);
    expect(back.rightWidth, EditorLayoutState.defaultRightWidth);
    expect(back.pluginPanelVisible, isEmpty);
    expect(back.activeRightPanel, isNull);
    expect(EditorLayoutState.defaultRightWidth, 340);
  });

  test('Reset Layout closes every plugin panel and restores the dock width', () {
    final s = EditorLayoutState(rightWidth: 500, pluginPanelVisible: {'probe.chat': true}, activeRightPanel: 'probe.chat');
    s.resetToDefault();
    expect(s.pluginPanelVisible, isEmpty);
    expect(s.activeRightPanel, isNull);
    expect(s.rightWidth, EditorLayoutState.defaultRightWidth);
  });

  test('the dock width is clamped to its minimum', () {
    expect(EditorLayoutState(rightWidth: 100).rightWidth, EditorLayoutState.minRightWidth);
    expect(EditorLayoutState.minRightWidth, 260);
  });
}
