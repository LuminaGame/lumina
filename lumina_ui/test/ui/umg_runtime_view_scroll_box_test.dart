import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_runtime_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A horizontal box inside a vertical Scroll Box (a sidebar of button rows)
/// lays out: the row centres its children instead of stretching them to an
/// unbounded height.
void main() {
  testWidgets('a horizontal box of buttons inside a vertical scroll box lays out', (tester) async {
    UmgNode n(UmgWidgetType t, String name, [List<UmgNode> children = const []]) {
      final node = UmgNode.create(t, name: name, id: 'n_$name');
      node.children.addAll(children);
      return node;
    }

    final root = n(UmgWidgetType.verticalBox, 'Root', [
      n(UmgWidgetType.scrollBox, 'Sidebar', [
        n(UmgWidgetType.horizontalBox, 'Buttons', [n(UmgWidgetType.button, 'A'), n(UmgWidgetType.button, 'B')]),
        n(UmgWidgetType.text, 'Label'),
      ]),
    ]);
    final doc = UmgDocument(root: root);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: SizedBox(width: 400, height: 300, child: UmgRuntimeView(document: doc, editorTheme: true)),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Button'), findsNWidgets(2));
  });
}
