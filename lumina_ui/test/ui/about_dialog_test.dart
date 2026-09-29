import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/views/about_dialog.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Help ▸ About names the engine and what renders it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String gradleVersion() {
    final text = File('${Directory.current.parent.path}/filament/android/gradle.properties').readAsStringSync();
    return RegExp(r'^VERSION_NAME=(.+)$', multiLine: true).firstMatch(text)!.group(1)!.trim();
  }

  testWidgets('About shows Lumina and Filament versions, the Filament logo and credit; copies and closes', (tester) async {
    final version = gradleVersion();
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: Builder(
          builder: (context) => PrimaryButton(
            onPressed: () => showAboutLuminaDialog(context, engineVersion: '0.0.1'),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('About Lumina Studio'), findsOneWidget);
    expect(find.text('Lumina Engine 0.0.1'), findsOneWidget);
    expect(find.text('Filament $version'), findsOneWidget);
    expect(find.textContaining('Apache-2.0'), findsOneWidget);
    expect(find.textContaining(RegExp(r'Material version \d+')), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) =>
          w is SvgPicture && w.bytesLoader is SvgAssetLoader && (w.bytesLoader as SvgAssetLoader).assetName.endsWith('filament_logo.svg')),
      findsOneWidget,
      reason: 'the dark editor theme shows the light-on-dark Filament logo',
    );

    await tester.tap(find.text('Copy version info'));
    await tester.pumpAndSettle();
    expect(clipboard, contains('Lumina Engine 0.0.1'));
    expect(clipboard, contains('Filament $version (material '));
    expect(clipboard, contains('RHI: Vulkan'));

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('About Lumina Studio'), findsNothing);
  });
}
