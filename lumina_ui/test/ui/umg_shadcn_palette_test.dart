import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_widget_layer.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/widget_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The shadcn palette category — only for projects on the
/// shadcn widget library, every component rendered as the real shadcn
/// widget, a plain project shown the placeholder and a validator error.
void main() {
  late Directory tempDir;
  late String projectDir;
  late String lmasPath;

  void writeManifest(String library) => File('$projectDir/HudProject.lmproject').writeAsStringSync(jsonEncode(LuminaProject(
        projectName: 'HudProject',
        activeLevel: 'contents/levels/L_Main.lmas',
        ui: ProjectUiSettings(widgetLibrary: library),
      ).toMap()));

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('umg_shadcn_palette_test_');
    projectDir = '${tempDir.path}/HudProject';
    Directory('$projectDir/lib').createSync(recursive: true);
    writeManifest(kUmgWidgetLibraryShadcn);
    await AssetRepository().createAsset(projectPath: projectDir, subFolder: 'widgets', fileName: 'WBP_Menu.lmas', type: AssetType.widget);
    lmasPath = '$projectDir/contents/widgets/WBP_Menu.lmas';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<UmgEditorViewModel> pumpEditor(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = UmgEditorViewModel(assetPath: lmasPath);
    await tester.runAsync(() => vm.load());
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: UMGWidgetSubEditor(assetName: 'WBP_Menu', assetPath: lmasPath, viewModel: vm)),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    return vm;
  }

  Finder inNode(UmgNode n, Finder f) => find.descendant(of: find.byKey(ValueKey('umg_rt_${n.id}')), matching: f);

  /// The shadcn widget each component renders as.
  const rendered = <UmgWidgetType, Type>{
    UmgWidgetType.shadcnCard: Card,
    UmgWidgetType.shadcnBadge: PrimaryBadge,
    UmgWidgetType.shadcnAvatar: Avatar,
    UmgWidgetType.shadcnAlert: Alert,
    UmgWidgetType.shadcnSeparator: Divider,
    UmgWidgetType.shadcnProgress: Progress,
    UmgWidgetType.shadcnSwitch: Switch,
    UmgWidgetType.shadcnToggle: Toggle,
    UmgWidgetType.shadcnTabs: Tabs,
    UmgWidgetType.shadcnAccordion: Accordion,
    UmgWidgetType.shadcnTooltip: Tooltip,
    UmgWidgetType.shadcnChip: Chip,
    UmgWidgetType.shadcnKbd: KeyboardDisplay,
    UmgWidgetType.shadcnTextField: TextField,
    UmgWidgetType.shadcnTextArea: TextArea,
    UmgWidgetType.shadcnSelect: Select<String>,
    UmgWidgetType.shadcnRadioGroup: RadioGroup<String>,
    UmgWidgetType.shadcnSlider: Slider,
    UmgWidgetType.shadcnCheckbox: Checkbox,
    UmgWidgetType.shadcnPrimaryButton: PrimaryButton,
    UmgWidgetType.shadcnSecondaryButton: SecondaryButton,
    UmgWidgetType.shadcnOutlineButton: OutlineButton,
    UmgWidgetType.shadcnGhostButton: GhostButton,
    UmgWidgetType.shadcnDestructiveButton: DestructiveButton,
    UmgWidgetType.shadcnLinkButton: LinkButton,
  };

  testWidgets('a shadcn project shows the shadcn category with every component; each renders as the real shadcn widget; a Card with a Text child is a shadcn Card', (tester) async {
    final vm = await pumpEditor(tester);
    expect(vm.widgetLibrary, kUmgWidgetLibraryShadcn);
    expect(find.byKey(const ValueKey('umg_palette_category_shadcn')), findsOneWidget);
    final shadcnTypes = UmgWidgetType.values.where((t) => t.isShadcn).toList();
    expect(shadcnTypes, hasLength(26));
    for (final t in shadcnTypes) {
      expect(find.byKey(ValueKey('umg_palette_${t.name}')), findsOneWidget, reason: '${t.displayName} is in the palette');
    }
    expect(find.byKey(const ValueKey('umg_palette_container')), findsOneWidget, reason: 'the Container is a panel in every project');

    final root = vm.document.root.id;
    final nodes = <UmgNode>[];
    var y = 20.0;
    for (final t in shadcnTypes) {
      nodes.add(vm.addWidget(t, parentId: root, canvasPosition: Offset(20, y))!);
      y += 110;
    }
    await tester.pump(const Duration(milliseconds: 150));
    for (final n in nodes) {
      if (n.type == UmgWidgetType.shadcnSkeleton) {
        expect(inNode(n, find.text('Loading placeholder text line')), findsWidgets, reason: 'the skeleton placeholder lines');
        continue;
      }
      expect(inNode(n, find.byType(rendered[n.type]!)), findsWidgets, reason: '${n.type.displayName} renders as ${rendered[n.type]}');
    }

    final card = nodes.firstWhere((n) => n.type == UmgWidgetType.shadcnCard);
    final text = vm.addWidget(UmgWidgetType.text, parentId: card.id)!;
    vm.setProp(text.id, 'text', 'Inside the card');
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.descendant(of: inNode(card, find.byType(Card)), matching: find.text('Inside the card')), findsOneWidget);
    expect(inNode(card, find.text('Card Title')), findsOneWidget);
    expect(vm.validationErrors, isEmpty);

    // Inspector fields come from the component's props.
    final badge = nodes.firstWhere((n) => n.type == UmgWidgetType.shadcnBadge);
    vm.select(badge.id);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(ValueKey('umg_group_shadcn_${badge.id}')), findsOneWidget);
    vm.setProp(badge.id, 'variant', 'destructive');
    await tester.pump();
    expect(inNode(badge, find.byType(DestructiveBadge)), findsOneWidget);
  });

  testWidgets('a plain project hides the category; a document with a shadcn Badge shows the placeholder and a validator error naming it, and compile refuses', (tester) async {
    // Written while the project was on shadcn, then switched to plain.
    final doc = UmgDocument.createDefault();
    final badge = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.shadcnBadge, name: 'New Badge'), canvasPosition: const Offset(40, 40))!;
    final old = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync());
    File(lmasPath).writeAsBytesSync(LuminaAsset(
      assetId: old.assetId,
      name: old.name,
      type: AssetType.widget,
      rawPayload: Uint8List.fromList(utf8.encode(doc.toFormattedJson())),
    ).toProtoBufferBytes());
    writeManifest(kUmgWidgetLibraryFlutter);

    final vm = await pumpEditor(tester);
    expect(vm.widgetLibrary, kUmgWidgetLibraryFlutter);
    expect(find.byKey(const ValueKey('umg_palette_category_shadcn')), findsNothing);
    expect(find.byKey(const ValueKey('umg_palette_shadcnBadge')), findsNothing);
    expect(find.byKey(ValueKey('umg_requires_shadcn_${badge.id}')), findsOneWidget);
    expect(find.byType(PrimaryBadge), findsNothing);
    expect(find.textContaining('Badge (shadcn) requires the shadcn widget library'), findsOneWidget);
    expect(vm.validationErrors.single, contains('"New Badge"'));
    expect(find.byKey(const ValueKey('umg_validation_error')), findsOneWidget);
    expect(find.textContaining('"New Badge" is a shadcn Badge'), findsOneWidget);

    final result = await tester.runAsync(vm.compile);
    expect(result!.written, isFalse);
    expect(File(UmgWidgetCodegen.outputPath(projectDir, 'WBP_Menu')).existsSync(), isFalse, reason: 'nothing a plain game could not compile is written');

    // Project Settings lists what a plain project cannot compile.
    final settings = ProjectSettingsViewModel(projectDirPath: projectDir);
    await tester.runAsync(() => settings.load());
    expect(settings.shadcnWidgetsBlockingPlain, ['WBP_Menu: New Badge (Badge)']);
    settings.dispose();
  });

  testWidgets('PIE: toggling a shadcn Switch writes its state (Is Checked) and fires OnValueChanged', (tester) async {
    final doc = UmgDocument.createDefault();
    final sw = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.shadcnSwitch, name: 'Music'), canvasPosition: const Offset(20, 20))!;
    sw.props['label'] = 'Music';
    File(lmasPath).writeAsBytesSync(LuminaAsset(
      assetId: 'wbp_menu',
      name: 'WBP_Menu',
      type: AssetType.widget,
      rawPayload: Uint8List.fromList(utf8.encode(doc.toFormattedJson())),
    ).toProtoBufferBytes());

    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final owner = LuminaCharacter();
    final editor = EditorViewModel(projectDirPath: projectDir, autoInitAssets: false, enableTimers: false);
    final pie = PieController(editor);
    pie.startHeadlessForTest(world);
    LuminaWidgetClassRegistry.clear();
    addTearDown(() {
      pie.stopHeadlessForTest();
      editor.dispose();
      LuminaWidgetClassRegistry.clear();
    });
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 800, height: 600, child: PieWidgetLayer(pieController: pie, projectDirPath: projectDir))),
    ));
    await tester.pumpAndSettle();
    world.spawnActorImmediately(owner);
    final menu = LuminaBlueprintFunctionLibrary.createWidget(owner, 'WBP_Menu') as Map<String, Object?>;
    LuminaBlueprintFunctionLibrary.addToViewport(owner, menu, 0);
    await tester.pump();
    expect(find.byType(Switch), findsOneWidget);
    final music = LuminaBlueprintFunctionLibrary.getWidgetElement(menu, 'Music');
    expect(LuminaBlueprintFunctionLibrary.getElementIsChecked(music), isFalse);

    final logged = <String>[];
    final sub = EngineLoggerService().logStream.listen((e) => logged.add(e.message));
    addTearDown(sub.cancel);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(LuminaBlueprintFunctionLibrary.getElementIsChecked(music), isTrue, reason: 'Is Checked reads what the player toggled');
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue, reason: 'the layer refreshed');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(logged.where((m) => m.contains('WBP_Menu.Music OnValueChanged')), isNotEmpty);
  });

  test('codegen: shadcn components are the real shadcn widgets; a plain project emits none of them', () {
    final doc = UmgDocument.createDefault();
    final box = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.verticalBox, name: 'Box'), canvasPosition: Offset.zero)!;
    for (final t in UmgWidgetType.values.where((t) => t.isShadcn)) {
      doc.addChild(box.id, UmgNode.create(t, name: '${t.displayName} Item'));
    }
    final card = doc.allNodes.firstWhere((n) => n.type == UmgWidgetType.shadcnCard);
    doc.addChild(card.id, UmgNode.create(UmgWidgetType.text, name: 'Card Body'));
    doc.allNodes.firstWhere((n) => n.type == UmgWidgetType.shadcnSwitch).events.add(const UmgEvent(name: 'OnValueChanged', handler: 'onValueChangedSwitch'));
    final src = UmgWidgetCodegen.generateWidgetDart(doc, assetName: 'WBP_Shadcn');
    for (final w in ['Card(', 'PrimaryBadge(', 'Avatar(', 'Alert(', 'Divider(', 'Progress(', 'Switch(', 'Toggle(', 'Tabs(', 'TabItem(', 'Accordion(',
        'AccordionItem(', 'Tooltip(', 'TooltipContainer(', 'Chip(', 'KeyboardDisplay(', 'LuminaUmgSkeleton(', 'TextField(', 'TextArea(', 'Select<String>(',
        'RadioGroup<String>(', 'RadioItem<String>(', 'Slider(', 'Checkbox(', 'PrimaryButton(', 'SecondaryButton(', 'OutlineButton(', 'GhostButton(',
        'DestructiveButton(', 'LinkButton(']) {
      expect(src, contains(w));
    }
    expect(src, contains("LuminaUmgElementBinding.value<bool>(e, 'isChecked', switchItemValue)"), reason: 'Set Is Checked drives the Switch');
    expect(src, contains("LuminaUmgElementBinding.write(widget.instance, 'Switch Item', 'isChecked', v);"));
    expect(src, contains('void _onValueChangedSwitch(bool value)'));
    expect(src, contains("LuminaUmgElementBinding.value<int>(e, 'activeIndex', tabsItemValue)"));
    expect(src, contains("LuminaUmgStyleJson.keyboardKeys(LuminaUmgElementBinding.value<String>(e, 'text', 'Ctrl+S'))"));

    final plain = UmgWidgetCodegen.generateWidgetDart(doc, assetName: 'WBP_Shadcn', library: kUmgWidgetLibraryFlutter);
    expect(plain, isNot(contains('shadcn_flutter')));
    expect(plain, isNot(contains('PrimaryBadge(')));
    expect(plain, contains('not available with plain Flutter widgets'));
  });
}
