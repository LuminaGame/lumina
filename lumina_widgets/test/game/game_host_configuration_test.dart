import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

void main() {
  testWidgets(
    'preview hosts can disable extra frame drivers in their subtree',
    (tester) async {
      bool? allowed;
      final probe = Builder(
        builder: (context) {
          allowed = LuminaGameHostConfiguration.allowsHeadlessFrameDriver(
            context,
          );
          return const SizedBox.shrink();
        },
      );
      await tester.pumpWidget(probe);
      expect(allowed, isTrue);
      await tester.pumpWidget(
        LuminaGameHostConfiguration(
          allowHeadlessFrameDriver: false,
          child: probe,
        ),
      );
      expect(allowed, isFalse);
    },
  );
}
