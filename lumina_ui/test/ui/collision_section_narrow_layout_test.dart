import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/property_editors/collision_section_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// In the level editor's default-width Details panel (~190 px of
/// content) the Collision Presets and Object Type values wrapped one letter
/// per line. They must stay on one line (truncated if they do not fit).
void main() {
  for (final width in [190.0, 320.0]) {
    testWidgets('at $width px the preset and object type values are one line high', (tester) async {
      final value = CollisionJson.withPreset(const {}, LuminaCollisionPreset.blockAll);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(
                child: CollisionSectionEditor(value: value, onChanged: (_) {}, keyPrefix: 'probe'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      double lineHeight(String text, Key selectKey) {
        final label = find.descendant(of: find.byKey(selectKey), matching: find.text(text));
        expect(label, findsOneWidget, reason: text);
        return tester.getSize(label).height;
      }

      final presetText = CollisionJson.presetLabel(LuminaCollisionPreset.blockAll);
      final objectText = CollisionJson.channelLabel(CollisionJson.profile(value).objectType);
      // 11 px text: one line is well under 20 px; two or more lines are not.
      expect(lineHeight(presetText, const ValueKey('probe_preset')), lessThan(20));
      expect(lineHeight(objectText, const ValueKey('probe_object_type')), lessThan(20));
      // The response grid's column headers (Ignore / Overlap / Block) too.
      for (final r in CollisionResponse.values) {
        final header = find.text(CollisionJson.responseLabel(r));
        expect(tester.getSize(header.first).height, lessThan(20), reason: r.name);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
