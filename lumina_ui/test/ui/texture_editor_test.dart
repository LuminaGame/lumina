import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/texture_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/texture_editor_view_model.dart';
import '../view_models/texture_editor_view_model_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  late Directory tempDir;
  late String lmasPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tex_widget_test_');
    lmasPath = '${tempDir.path}/T_Hero_BaseColor.lmas';

    final pngBytes = buildTestPng4x4();
    final asset = LuminaAsset(
      assetId: 'hero-tex-widget-uuid',
      name: 'T_Hero_BaseColor',
      type: AssetType.texture,
      rawPayload: pngBytes,
      metadata: {},
    );

    final lmasBytes = asset.toProtoBufferBytes();
    File(lmasPath).writeAsBytesSync(lmasBytes);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('TextureSubEditor renders 3-panel UI, metadata table, channel switches, and inspector bar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = TextureEditorViewModel(assetPath: lmasPath);
    await tester.runAsync(() => vm.load());

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: TextureSubEditor(
            assetName: 'T_Hero_BaseColor',
            assetPath: lmasPath,
            viewModel: vm,
          ),
        ),
      ),
    );
    await tester.pump();

    // 1. Assert Toolbar & Badges
    expect(find.text('TEXTURE 2D'), findsOneWidget);
    expect(find.text('T_Hero_BaseColor'), findsOneWidget);
    expect(find.text('4 × 4'), findsWidgets);
    expect(find.text('3 Mips'), findsWidgets); // 4x4 -> 2x2 -> 1x1

    // 2. Assert Left Panel Metrics & Channel Isolator
    expect(find.text('TEXTURE METRICS'), findsOneWidget);
    expect(find.text('4 × 4 px'), findsOneWidget);
    expect(find.text('1:1'), findsOneWidget);
    expect(find.text('64 B'), findsOneWidget); // Uncompressed size

    expect(find.text('CHANNEL ISOLATOR'), findsOneWidget);
    expect(find.text('Red Channel (R)'), findsOneWidget);
    expect(find.text('Alpha as Greyscale'), findsOneWidget);

    // 3. Assert Right Panel Compression Settings
    expect(find.text('GENERAL SETTINGS'), findsOneWidget);
    expect(find.text('COMPRESSION'), findsOneWidget);
    expect(find.text('KTX2 / Basis Universal'), findsOneWidget);
    expect(find.text('MIPMAP GEN & SAMPLER'), findsOneWidget);

    // 4. Test Pixel Inspector Bar with Hover
    vm.setHover(0.5, 0.5, 2, 2);
    await tester.pump();

    expect(find.textContaining('UV: 0.5000, 0.5000'), findsOneWidget);
    expect(find.textContaining('XY: 2, 2'), findsOneWidget);
    expect(find.textContaining('RGBA: (128, 128, 128, 255)'), findsOneWidget);
    expect(find.textContaining('#808080FF'), findsOneWidget);

    // 5. Test Zoom Slider & Reset Button
    expect(find.text('Zoom: 100%'), findsOneWidget);
    vm.setZoom(8.0); // 800%
    await tester.pump();
    expect(find.text('Zoom: 800%'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(vm.zoom, equals(1.0));
    expect(find.text('Zoom: 100%'), findsOneWidget);

    // The zoom slider takes a typed percentage.
    final zoomField = find.descendant(of: find.byKey(const ValueKey('texture_zoom_slider')), matching: find.byType(EditableText));
    expect(zoomField, findsOneWidget);
    await tester.tap(zoomField);
    await tester.pump();
    await tester.enterText(zoomField, '250');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(vm.zoom, closeTo(2.5, 1e-9));
    expect(find.text('Zoom: 250%'), findsOneWidget);
  });
}
