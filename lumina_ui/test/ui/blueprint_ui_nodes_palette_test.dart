import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/node_palette.dart';

void main() {
  group('Blueprint UI / Widget Palette Entries', () {
    test('palette includes all User Interface and Player/Input nodes', () {
      final entries = BlueprintPalette.entries();
      final ids = entries.map((e) => e.registryId).toSet();

      // UI nodes
      expect(ids.contains('create_widget'), isTrue);
      expect(ids.contains('add_to_viewport'), isTrue);
      expect(ids.contains('remove_from_parent'), isTrue);
      expect(ids.contains('set_widget_visibility'), isTrue);
      expect(ids.contains('is_in_viewport'), isTrue);
      expect(ids.contains('get_owning_player'), isTrue);
      expect(ids.contains('set_widget_text'), isTrue);
      expect(ids.contains('set_widget_percent'), isTrue);

      // Player and Controller / Mouse / Input Mode
      expect(ids.contains('get_player_controller'), isTrue);
      expect(ids.contains('get_player_pawn'), isTrue);
      expect(ids.contains('get_player_character'), isTrue);
      expect(ids.contains('set_show_mouse_cursor'), isTrue);
      expect(ids.contains('set_input_mode_game_and_ui'), isTrue);
      expect(ids.contains('set_input_mode_game_only'), isTrue);
      expect(ids.contains('set_input_mode_ui_only'), isTrue);

      final uiEntries = entries.where((e) => e.category == 'User Interface').toList();
      expect(uiEntries.length, greaterThanOrEqualTo(8));
      expect(uiEntries.map((e) => e.title), containsAll([
        'Create Widget',
        'Add to Viewport',
        'Remove from Parent',
        'Set Visibility (Widget)',
        'Is In Viewport',
        'Get Owning Player',
        'Set Text (Widget)',
        'Set Percent (Widget)',
      ]));
    });

    test('searching widget, ui, hud, or mouse finds relevant nodes', () {
      final entries = BlueprintPalette.entries();

      final widgetResults = BlueprintPalette.search(entries, 'widget');
      expect(widgetResults.map((e) => e.registryId), containsAll([
        'create_widget',
        'add_to_viewport',
        'remove_from_parent',
        'set_widget_visibility',
        'set_widget_text',
        'set_widget_percent',
      ]));

      final uiResults = BlueprintPalette.search(entries, 'ui');
      expect(uiResults.map((e) => e.registryId), containsAll([
        'create_widget',
        'add_to_viewport',
        'get_player_controller',
        'set_show_mouse_cursor',
      ]));

      final mouseResults = BlueprintPalette.search(entries, 'mouse');
      expect(mouseResults.map((e) => e.registryId), containsAll([
        'set_show_mouse_cursor',
        'set_input_mode_game_and_ui',
      ]));
    });
  });

  group('BlueprintNodePalette Widget', () {
    testWidgets('renders USER INTERFACE category and allows selecting Create Widget', (tester) async {
      BlueprintPaletteEntry? selected;

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: BlueprintNodePalette(
              entries: BlueprintPalette.entries(),
              onSelect: (entry) => selected = entry,
              onClose: () {},
            ),
          ),
        ),
      );

      // Search for "widget"
      await tester.enterText(find.byKey(const ValueKey('palette_search')), 'widget');
      await tester.pumpAndSettle();

      // Verify category heading and nodes are in the palette
      expect(find.text('USER INTERFACE'), findsOneWidget);
      expect(find.text('Create Widget'), findsOneWidget);
      expect(find.text('Add to Viewport'), findsOneWidget);

      // Tap on Create Widget
      await tester.tap(find.text('Create Widget'));
      await tester.pumpAndSettle();

      expect(selected?.registryId, 'create_widget');
    });
  });
}
