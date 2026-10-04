import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings/key_binding_dialog.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('KeyBindingDialog captures Escape key press and assigns it', (tester) async {
    int? assignedId;
    String? assignedLabel;
    var closed = false;

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: KeyBindingDialog(
          initialKeyId: null,
          initialKeyLabel: '',
          onKeySelected: (id, label) {
            assignedId = id;
            assignedLabel = label;
          },
          onClose: () => closed = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Dialog is visible
    expect(find.byKey(const ValueKey('key_binding_dialog')), findsOneWidget);
    expect(find.text('Selected Key: '), findsOneWidget);

    // Simulate pressing Escape on the keyboard
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // Preview should now show Escape
    expect(find.text('Escape'), findsWidgets);
    expect(find.textContaining('0x10000001b'), findsOneWidget);

    // Click "Assign Key"
    final assignButton = find.byKey(const ValueKey('key_binding_assign'));
    expect(assignButton, findsOneWidget);
    await tester.tap(assignButton);
    await tester.pumpAndSettle();

    expect(assignedId, LogicalKeyboardKey.escape.keyId);
    expect(assignedLabel, 'Escape');
    expect(closed, isFalse);
  });

  testWidgets('KeyBindingDialog allows selecting Escape and other keys from quick pick list', (tester) async {
    int? assignedId;
    String? assignedLabel;

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: KeyBindingDialog(
          initialKeyId: null,
          initialKeyLabel: '',
          onKeySelected: (id, label) {
            assignedId = id;
            assignedLabel = label;
          },
          onClose: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Search for "esc" in the search field
    await tester.enterText(find.byKey(const ValueKey('key_binding_search_field')), 'esc');
    await tester.pumpAndSettle();

    // Option for Escape should be visible in the quick pick list
    final escOption = find.byKey(ValueKey('key_binding_option_${LogicalKeyboardKey.escape.keyId}'));
    expect(escOption, findsOneWidget);

    await tester.tap(escOption);
    await tester.pumpAndSettle();

    // Now click assign
    await tester.tap(find.byKey(const ValueKey('key_binding_assign')));
    await tester.pumpAndSettle();

    expect(assignedId, LogicalKeyboardKey.escape.keyId);
    expect(assignedLabel, 'Escape');
  });

  testWidgets('KeyBindingDialog allows selecting keys from combobox', (tester) async {
    int? assignedId;
    String? assignedLabel;

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: KeyBindingDialog(
          initialKeyId: null,
          initialKeyLabel: '',
          onKeySelected: (id, label) {
            assignedId = id;
            assignedLabel = label;
          },
          onClose: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Filter by searching 'space'
    await tester.enterText(find.byKey(const ValueKey('key_binding_search_field')), 'space');
    await tester.pumpAndSettle();

    // Open combobox
    final combobox = find.byKey(const ValueKey('key_binding_combobox'));
    expect(combobox, findsOneWidget);
    await tester.tap(combobox);
    await tester.pumpAndSettle();

    // Select 'Space' item from the popup
    final spaceItem = find.text('Space').last;
    await tester.tap(spaceItem);
    await tester.pumpAndSettle();

    // Click assign
    await tester.tap(find.byKey(const ValueKey('key_binding_assign')));
    await tester.pumpAndSettle();

    expect(assignedId, LogicalKeyboardKey.space.keyId);
    expect(assignedLabel, 'Space');
  });

  testWidgets('KeyBindingDialog cancel button triggers onClose', (tester) async {
    var closed = false;

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: KeyBindingDialog(
          initialKeyId: null,
          initialKeyLabel: '',
          onKeySelected: (_, _) {},
          onClose: () => closed = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('key_binding_cancel')));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });
}
