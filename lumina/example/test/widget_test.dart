import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('Lumina Example App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LuminaExampleApp());
    expect(find.text('Lumina 3D Game Engine (Declarative Node Tree)'), findsOneWidget);
  });
}
