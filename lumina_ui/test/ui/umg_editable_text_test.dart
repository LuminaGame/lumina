import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_editable_text.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The runtime Editable Text follows its element's text (a graph's Set Text
/// or a plugin process's patch) and commits on Enter or on leaving it.
void main() {
  testWidgets('shows a text set from outside and commits when it loses focus after an edit', (tester) async {
    final commits = <(String, String)>[];
    final changes = <String>[];
    Widget field(String text) => ShadcnApp(
          theme: luminaEditorTheme(),
          home: Column(children: [
            SizedBox(
              width: 200,
              child: UmgEditableText(
                text: text,
                placeholder: 'hint',
                style: const TextStyle(fontSize: 11),
                onChanged: changes.add,
                onCommitted: (t, m) => commits.add((t, m)),
              ),
            ),
            const SizedBox(width: 200, child: TextField(key: ValueKey('other'))),
          ]),
        );
    await tester.pumpWidget(field('12'));
    expect(find.text('12'), findsOneWidget);
    await tester.pumpWidget(field('32'));
    expect(find.text('32'), findsOneWidget, reason: 'a patched text shows at once');
    expect(changes, isEmpty, reason: 'a text set from outside is no user change');

    await tester.tap(find.byType(UmgEditableText));
    await tester.pump();
    await tester.enterText(find.byType(UmgEditableText), '40');
    await tester.pumpWidget(field('32'));
    expect(find.text('40'), findsOneWidget, reason: 'typing is not overwritten');
    await tester.tap(find.byKey(const ValueKey('other')));
    await tester.pump();
    expect(commits, [('40', 'OnUserMovedFocus')]);
    await tester.pumpWidget(field('40'));
    expect(find.text('40'), findsOneWidget);
  });
}
