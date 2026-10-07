import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

/// A UMG element's visibility decides whether it takes pointer input.
void main() {
  testWidgets('HitTestInvisible elements render but let taps through', (tester) async {
    var taps = 0;
    final instance = <String, Object?>{
      'class': 'WBP_Clicker',
      'elements': {
        'StartButton': <String, Object?>{'type': 'button', 'name': 'StartButton', 'visibility': 'HitTestInvisible', 'isEnabled': true, 'renderOpacity': 1.0},
      },
    };
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: LuminaUmgElement(
          instance: instance,
          name: 'StartButton',
          builder: (context, e) => GestureDetector(onTap: () => taps++, child: const SizedBox(width: 80, height: 40, child: Text('Go'))),
        ),
      ),
    ));
    expect(find.text('Go'), findsOneWidget);
    await tester.tap(find.text('Go'), warnIfMissed: false);
    expect(taps, 0);
  });
}
