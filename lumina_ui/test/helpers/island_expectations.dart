import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/widgets/editor_island.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Expects each island of [islands] (its key name → its header title, upper
/// case as drawn, or null for an island whose content brings its own top
/// row) once, laid out on the ground: an [EditorIsland] with a size, and
/// the title inside that island.
void expectIslands(WidgetTester tester, Map<String, String?> islands) {
  for (final MapEntry(key: name, value: title) in islands.entries) {
    final island = find.byKey(ValueKey(name));
    expect(island, findsOneWidget, reason: 'island $name');
    expect(tester.widget(island), isA<EditorIsland>(), reason: '$name is an EditorIsland');
    final size = tester.getSize(island);
    expect(size.width > 0 && size.height > 0, isTrue, reason: '$name is laid out ($size)');
    if (title != null) {
      expect(find.descendant(of: island, matching: find.text(title)), findsWidgets, reason: '$name shows "$title"');
    }
  }
}
