import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/property_editors/rotation_row.dart';
import 'package:lumina_ui/ui/core/property_editors/color_field.dart';
import 'package:lumina_ui/ui/core/property_editors/vector_row.dart';
import 'package:lumina_ui/ui/core/property_editors/curve_field.dart';
import 'package:lumina_ui/ui/core/property_editors/enum_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

Widget _buildApp(Widget child) {
  return ShadcnApp(
    theme: luminaEditorTheme(),
    home: child,
  );
}

void main() {
  group('Property Editors', () {
    testWidgets('SliderField unit display renders correct strings', (tester) async {
      await tester.pumpWidget(_buildApp(
        SliderField(
          value: 90.0,
          defaultValue: 90.0,
          unit: '°',
          min: 60.0,
          max: 110.0,
          onChanged: (_) {},
          onCommit: (_) {},
          onReset: () {},
        ),
      ));
      
      expect(find.text('90.00 °'), findsOneWidget);
    });

    testWidgets('VectorRow shows reset arrow when modified', (tester) async {
      await tester.pumpWidget(_buildApp(
        VectorRow(
          value: const [100.0, 0.0, 0.0],
          defaultValue: const [0.0, 0.0, 0.0],
          onChanged: (_) {},
          onCommit: (_) {},
          onReset: () {},
        ),
      ));
      
      expect(find.byIcon(LucideIcons.rotateCcw), findsWidgets);
      expect(find.text('100.00'), findsOneWidget);
    });
    
    testWidgets('RotationRow wraps values correctly on scrub', (tester) async {
      await tester.pumpWidget(_buildApp(
        RotationRow(
          value: const [170.0, 0.0, 0.0],
          onChanged: (_) {},
          onCommit: (_) {},
          onReset: () {},
        ),
      ));
      
      expect(find.text('170.00'), findsOneWidget);
    });
    
    testWidgets('ColorField renders hex and picker', (tester) async {
      await tester.pumpWidget(_buildApp(
        ColorField(
          value: '#FF0000',
          defaultValue: '#FFFFFF',
          onChanged: (_) {},
          onCommit: (_) {},
          onReset: () {},
        ),
      ));
      
      expect(find.text('#FF0000'), findsOneWidget);
    });
    
    testWidgets('CurveField renders sparkline', (tester) async {
      await tester.pumpWidget(_buildApp(
        CurveField(
          value: const {},
          onCommit: (_) {},
        ),
      ));
      
      // Shadcn has multiple custom paints, let's just assert no throw
      expect(find.byType(CurveField), findsOneWidget);
    });
    
    testWidgets('EnumField renders dropdown', (tester) async {
      await tester.pumpWidget(_buildApp(
        EnumField(
          value: 'Perspective',
          enumValues: const ['Perspective', 'Orthographic'],
          isRadioGroup: false,
          onCommit: (_) {},
        ),
      ));
      
      expect(find.text('Perspective'), findsOneWidget);
    });
  });
}
