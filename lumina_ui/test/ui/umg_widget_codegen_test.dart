import 'dart:io';

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:lumina_editor_data/lumina_editor.dart' show AssetType, GenerateDartCodeUseCase, LuminaAsset, kUmgWidgetLibraryShadcn, kUmgWidgetLibraryFlutter, kGameShadcnFlutterVersion;
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';

import '../helpers/scaffold_game_project.dart';
import '../helpers/widget_graph_fixture.dart';

/// Widget codegen: deterministic, guarded, shadcn-only Flutter source in
/// `<project>/lib/widgets/WBP_<Name>.dart` (codegen, never interpretation).
void main() {
  late Directory projectDir;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('umg_codegen_test_');
    Directory('${projectDir.path}/lib').createSync(recursive: true);
  });

  tearDown(() {
    if (projectDir.existsSync()) projectDir.deleteSync(recursive: true);
  });

  UmgDocument playerHud() {
    final doc = UmgDocument.createDefault();
    final overlay = doc.addChild(
      doc.root.id,
      UmgNode.create(UmgWidgetType.overlay, name: 'HUD Overlay'),
      canvasPosition: const Offset(40, 40),
    )!;
    doc.findNode(overlay.id)!.slot.size = const Size(600, 80);
    final bar = doc.addChild(overlay.id, UmgNode.create(UmgWidgetType.progressBar, name: 'HealthBar Progress'))!;
    bar.props['percent'] = 0.8;
    bar.props['color'] = '#22C55E';
    return doc;
  }

  test('the WBP_PlayerHUD tree generates class WbpPlayerHUD with a Progress( construction', () async {
    final doc = playerHud();
    final result = await UmgWidgetCodegen.compileAndWrite(projectPath: projectDir.path, assetName: 'WBP_PlayerHUD', document: doc);
    final file = File('${projectDir.path}/lib/widgets/wbp_player_hud.dart');
    expect(result.written, isTrue);
    expect(result.filePath, file.path);
    expect(file.existsSync(), isTrue);
    final src = file.readAsStringSync();
    expect(src, contains('class WbpPlayerHUD extends StatelessWidget'));
    expect(src, contains('Progress('));
    expect(src, contains("progress: LuminaUmgElementBinding.value<double>(e, 'percent', 0.8)"), reason: 'the designer value is the fallback of the runtime state');
    expect(src, contains('Color(0xFF22C55E)'));
    expect(src, contains("import 'package:shadcn_flutter/shadcn_flutter.dart';"));
    expect(src, isNot(contains('package:flutter/material.dart')), reason: 'SHADCN_FLUTTER_FIRST applies to generated code');
    expect(src, contains('// BEGIN USER CODE: class_body'));
    expect(src, contains('healthBarProgress'), reason: 'element names become generated identifiers');
    expect(src.endsWith('\n'), isTrue);
  });

  test('generation is deterministic and idempotent: byte-identical twice, no write on the second run', () async {
    final doc = playerHud();
    final first = await UmgWidgetCodegen.compileAndWrite(projectPath: projectDir.path, assetName: 'WBP_PlayerHUD', document: doc);
    final file = File(first.filePath);
    final firstBytes = file.readAsBytesSync();
    // Push the mtime into the past so an unwanted rewrite would be visible.
    file.setLastModifiedSync(DateTime(2020, 1, 1));
    final stampBefore = file.lastModifiedSync();

    final again = UmgDocument.fromJson(doc.toJson());
    final second = await UmgWidgetCodegen.compileAndWrite(projectPath: projectDir.path, assetName: 'WBP_PlayerHUD', document: again);
    expect(second.written, isFalse);
    expect(file.readAsBytesSync(), firstBytes);
    expect(file.lastModifiedSync(), stampBefore, reason: 'compare-before-write must skip the write');
    expect(
      UmgWidgetCodegen.generateWidgetDart(doc, assetName: 'WBP_PlayerHUD'),
      UmgWidgetCodegen.generateWidgetDart(again, assetName: 'WBP_PlayerHUD'),
    );
  });

  test('events: [+] OnClicked on a Button wires onPressed to a guarded handler that survives regeneration', () async {
    final doc = UmgDocument.createDefault();
    final button = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.button, name: 'Start Button'), canvasPosition: const Offset(10, 10))!;
    button.props['label'] = 'Start';
    button.events.add(const UmgEvent(name: 'OnClicked', handler: 'onClickedStartButton'));
    button.events.add(const UmgEvent(name: 'OnHovered', handler: 'onHoveredStartButton'));

    final first = await UmgWidgetCodegen.compileAndWrite(projectPath: projectDir.path, assetName: 'WBP_Menu', document: doc);
    final file = File(first.filePath);
    var src = file.readAsStringSync();
    expect(src, contains('class WbpMenu extends StatefulWidget'), reason: 'events demand a stateful widget');
    expect(src, contains('onPressed: LuminaUmgElementBinding.isEnabled(e) ? _onClickedStartButton : null'));
    expect(src, contains('void _onClickedStartButton()'));
    expect(src, contains('// BEGIN USER CODE: on_clicked_startButton'));
    expect(src, contains('onHover:'));
    expect(src, contains('// BEGIN USER CODE: on_hovered_startButton'));
    expect(src, contains("Text(LuminaUmgElementBinding.value<String>(e, 'label', 'Start'),"));

    // Hand-edit the guarded region, then regenerate after a document change.
    src = src.replaceFirst(
      '// BEGIN USER CODE: on_clicked_startButton\n',
      '// BEGIN USER CODE: on_clicked_startButton\n    debugPrint(\'start pressed\');\n',
    );
    file.writeAsStringSync(src);
    doc.findNode(button.id)!.props['label'] = 'Play';
    final second = await UmgWidgetCodegen.compileAndWrite(projectPath: projectDir.path, assetName: 'WBP_Menu', document: doc);
    expect(second.written, isTrue);
    final regenerated = file.readAsStringSync();
    expect(regenerated, contains("debugPrint('start pressed');"));
    expect(regenerated, contains("Text(LuminaUmgElementBinding.value<String>(e, 'label', 'Play'),"));
    expect(RegExp('BEGIN USER CODE: on_clicked_startButton').allMatches(regenerated).length, 1);

    // Removing the event keeps the orphaned user code commented at the end of the file.
    doc.findNode(button.id)!.events.removeWhere((e) => e.name == 'OnClicked');
    final third = await UmgWidgetCodegen.compileAndWrite(projectPath: projectDir.path, assetName: 'WBP_Menu', document: doc);
    expect(third.warnings, isNotEmpty);
    final afterRemoval = file.readAsStringSync();
    expect(afterRemoval, isNot(contains('onPressed: _onClickedStartButton')));
    expect(afterRemoval, contains('ORPHANED USER CODE: on_clicked_startButton'));
    expect(afterRemoval, contains("// debugPrint('start pressed');"));
  });

  test('image brush: a bound TEXTURE emits asset-loading code and Image.memory', () async {
    final doc = UmgDocument.createDefault();
    final image = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.image, name: 'Crosshair'), canvasPosition: const Offset(0, 0))!;
    image.props['texture'] = 'contents/textures/T_Crosshair.lmas';
    image.props['drawAs'] = 'image';
    final src = UmgWidgetCodegen.generateWidgetDart(doc, assetName: 'WBP_Reticle');
    expect(src, contains("'contents/textures/T_Crosshair.lmas'"));
    expect(src, contains('Image.memory('));
    expect(src, contains('LuminaAssets.loadPayload('));
  });

  test('an Image widget loads its texture from the game\'s asset bundle through the runtime barrel, never dart:io', () async {
    final doc = UmgDocument.createDefault();
    final image = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.image, name: 'Crosshair'), canvasPosition: const Offset(0, 0))!;
    image.props['texture'] = 'contents/textures/T_Crosshair.lmas';
    final src = UmgWidgetCodegen.generateWidgetDart(doc, assetName: 'WBP_Reticle');
    expect(src, contains(RegExp(r"import 'package:lumina_widgets/lumina_game.dart' show [A-Za-z, ]*LuminaAssets[A-Za-z, ]*;")));
    expect(src, isNot(contains('package:lumina/lumina.dart')), reason: 'the editor barrel reaches dart:ffi, which a web build cannot compile');
    expect(src, isNot(contains('dart:io')));
    expect(src, isNot(contains('File(')), reason: 'a relative File path depends on the working directory the game was started from');
    expect(src, contains('LuminaAssets.loadPayload('));

    // The generated file compiles against the real engine and UI packages.
    final dir = Directory('build/umg_codegen_check')..createSync(recursive: true);
    final file = File('${dir.path}/wbp_reticle.dart')..writeAsStringSync(src);
    addTearDown(() => dir.deleteSync(recursive: true));
    final analysis = await Process.run('dart', ['analyze', file.path], runInShell: Platform.isWindows);
    expect(analysis.exitCode, 0, reason: '${analysis.stdout}${analysis.stderr}');
  });

  test('box panels, anchors and every palette type generate without Material widgets', () async {
    final doc = UmgDocument.createDefault();
    final vbox = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.verticalBox, name: 'Menu Box'), canvasPosition: const Offset(0, 0))!;
    doc.findNode(vbox.id)!.slot
      ..anchorMin = const Offset(0.5, 0.5)
      ..anchorMax = const Offset(0.5, 0.5)
      ..alignment = const Offset(0.5, 0.5);
    for (final type in UmgWidgetType.values.where((t) => t != UmgWidgetType.verticalBox)) {
      final node = doc.addChild(vbox.id, UmgNode.create(type, name: '${type.displayName} Item'));
      expect(node, isNotNull, reason: 'vertical box accepts $type');
    }
    final src = UmgWidgetCodegen.generateWidgetDart(doc, assetName: 'WBP_Everything');
    expect(src, contains('Column('));
    expect(src, contains('Slider('));
    expect(src, contains('Checkbox('));
    expect(src, contains('Select<String>('));
    expect(src, contains('TextField('));
    expect(src, contains('SingleChildScrollView('));
    expect(src, contains('IndexedStack('));
    expect(src, contains('SizedBox('));
    expect(src, contains('Table('));
    expect(src, isNot(contains('material.dart')));
    expect(src, isNot(contains('ElevatedButton')));
    expect(src, contains('_umgCanvasRect('), reason: 'anchors are resolved by generated code, not interpreted');
  });

  /// Every palette type in one document, with events and an image.
  UmgDocument everything() {
    final doc = UmgDocument.createDefault();
    final vbox = doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.verticalBox, name: 'Menu Box'), canvasPosition: const Offset(0, 0))!;
    for (final type in UmgWidgetType.values.where((t) => t != UmgWidgetType.verticalBox)) {
      final node = doc.addChild(vbox.id, UmgNode.create(type, name: '${type.displayName} Item'))!;
      if (type == UmgWidgetType.image) node.props['texture'] = 'contents/textures/T_Logo.lmas';
      // A fully styled Container.
      if (type == UmgWidgetType.container) {
        node.props
          ..['gradient'] = {'type': 'radial', 'colors': ['#FB7C01FF', '#1B1B22FF'], 'center': 'center', 'radius': 0.8}
          ..['backgroundImage'] = 'contents/textures/T_Logo.lmas'
          ..['borderColor'] = '#FB7C01FF'
          ..['borderWidth'] = 2.0
          ..['borderSides'] = [true, false, true, false]
          ..['cornerRadius'] = [4.0, 8.0, 12.0, 16.0]
          ..['shadows'] = [
            {'color': '#00000066', 'offsetX': 0.0, 'offsetY': 4.0, 'blur': 12.0, 'spread': 1.0},
          ]
          ..['width'] = 320.0
          ..['maxHeight'] = 200.0
          ..['alignment'] = 'center';
      }
      // Every text-bearing type with a shadow and an outline.
      if (type.isTextBearing) {
        node.props
          ..['shadowEnabled'] = true
          ..['shadowColor'] = '#FF000080'
          ..['shadowOffsetX'] = 3.0
          ..['shadowOffsetY'] = 4.0
          ..['shadowBlur'] = 2.0
          ..['outlineSize'] = 2.0
          ..['outlineColor'] = '#000000FF';
      }
      if (type == UmgWidgetType.button) {
        for (final e in ['OnClicked', 'OnHovered', 'OnUnhovered']) {
          doc.findNode(node.id)!.events.add(UmgEvent(name: e, handler: 'on${e.substring(2)}Button'));
        }
      }
    }
    return doc;
  }

  test('plain Flutter emits the runtime LuminaUmg* widgets and no shadcn', () {
    final src = UmgWidgetCodegen.generateWidgetDart(everything(), assetName: 'WBP_Everything', library: kUmgWidgetLibraryFlutter);
    expect(src, isNot(contains('shadcn')));
    expect(src, contains("import 'package:flutter/widgets.dart';"));
    for (final w in ['LuminaUmgButton(', 'LuminaUmgSlider(', 'LuminaUmgCheckbox(', 'LuminaUmgTextField(', 'LuminaUmgComboBox(', 'LuminaUmgProgressBar(', 'LuminaUmgBorder(']) {
      expect(src, contains(w));
    }
    expect(src, contains('LuminaAssets.loadPayload('));
    expect(src, contains('onHovered: (hovering) {'));
    final shadcn = UmgWidgetCodegen.generateWidgetDart(everything(), assetName: 'WBP_Everything');
    expect(shadcn, contains("import 'package:shadcn_flutter/shadcn_flutter.dart';"), reason: 'shadcn stays the default');
  });

  group('text shadow and outline', () {
    for (final library in [kUmgWidgetLibraryShadcn, kUmgWidgetLibraryFlutter]) {
      test('$library: every text-bearing element reads its shadow and outline through the binding over the designer values', () {
        final src = UmgWidgetCodegen.generateWidgetDart(everything(), assetName: 'WBP_Everything', library: library);
        const shadow = "LuminaUmgElementBinding.shadow(e, const LuminaUmgTextShadow(enabled: true, color: Color(0x80FF0000), offsetX: 3.0, offsetY: 4.0, blur: 2.0))";
        const outline = "LuminaUmgElementBinding.outline(e, const LuminaUmgTextOutline(size: 2.0, color: Color(0xFF000000)))";
        final shown = RegExp(r"import 'package:lumina_widgets/lumina_game.dart' show ([A-Za-z, ]*);").firstMatch(src)!.group(1)!.split(', ');
        expect(shown, containsAll(['LuminaUmgText', 'LuminaUmgTextOutline', 'LuminaUmgTextShadow']));
        // The Text block: the outline is a stroked layer under the fill.
        expect(src, contains("LuminaUmgText(\n"));
        expect(src, contains('shadows: $shadow.shadows)'));
        expect(src, contains('outline: $outline,'));
        // Button, CheckBox and Combo Box labels.
        expect(src, contains("LuminaUmgText(LuminaUmgElementBinding.value<String>(e, 'label', 'Button'), style: TextStyle("));
        expect(src, contains("LuminaUmgText(LuminaUmgElementBinding.value<String>(e, 'label', 'CheckBox'), style: TextStyle("));
        if (library == kUmgWidgetLibraryShadcn) {
          expect(src, contains('itemBuilder: (context, item) => LuminaUmgText(item, style: TextStyle('));
        } else {
          expect(src, contains('outline: $outline,'), reason: 'LuminaUmgComboBox takes the outline');
        }
        // Editable Text: no second layer, the outline rings the glyphs as shadows.
        expect(src, contains('shadows: [...$shadow.shadows, ...$outline.ringShadows]'));
        final plain = UmgWidgetCodegen.generateWidgetDart(playerHud(), assetName: 'WBP_PlayerHUD', library: library);
        expect(plain, isNot(contains('LuminaUmgText')), reason: 'no text-bearing element, no text import');
      });
    }

    test('a default Text emits the designer defaults: shadow off, no outline', () {
      final doc = UmgDocument.createDefault();
      doc.addChild(doc.root.id, UmgNode.create(UmgWidgetType.text, name: 'Title'), canvasPosition: Offset.zero);
      final src = UmgWidgetCodegen.generateWidgetDart(doc, assetName: 'WBP_Title');
      expect(src, contains('const LuminaUmgTextShadow(enabled: false, color: Color(0xB3000000), offsetX: 1.0, offsetY: 1.0, blur: 0.0)'));
      expect(src, contains('const LuminaUmgTextOutline(size: 0.0, color: Color(0xFF000000))'));
    });

    test('#RRGGBBAA puts the alpha last, #RRGGBB is opaque', () {
      expect(UmgWidgetCodegen.parseHexColor('#FF000080'), const Color(0x80FF0000));
      expect(UmgWidgetCodegen.parseHexColor('#22C55E'), const Color(0xFF22C55E));
      expect(UmgWidgetCodegen.parseHexColor('nope'), isNull);
    });
  });

  test("the game's shadcn_flutter pin is the editor's resolved version", () {
    // One pubspec.lock for the pub workspace, at its root (the package's
    // parent: flutter test runs in the package folder).
    final lock = File('${Directory.current.parent.path}/pubspec.lock').readAsStringSync();
    final m = RegExp(r'\n  shadcn_flutter:\n(?:    .*\n)*?    version: "([^"]+)"').firstMatch(lock);
    expect(m, isNotNull);
    expect(kGameShadcnFlutterVersion, m!.group(1), reason: 'the codegen emits the API of the version the editor uses');
  });

  group('generated widgets compile inside the game', () {
    for (final library in [kUmgWidgetLibraryShadcn, kUmgWidgetLibraryFlutter]) {
      test('$library project: every palette type, the widget registry and the launcher analyze clean',() async {
        final root = Directory.systemTemp.createTempSync('lumina_umg_game_');
        addTearDown(() => root.deleteSync(recursive: true));
        final project = await scaffoldGameProject(root, name: 'umg_$library', widgetLibrary: library);
        final result = await UmgWidgetCodegen.compileAndWrite(projectPath: project, assetName: 'WBP_Everything', document: everything());
        expect(result.written, isTrue);
        expect(result.source.contains('shadcn_flutter'), library == kUmgWidgetLibraryShadcn, reason: 'the project\'s library decides');
        final registry = File(UmgWidgetCodegen.registryPath(project));
        expect(registry.existsSync(), isTrue, reason: 'compileAndWrite keeps lib/widgets/widget_registry.g.dart current');
        expect(registry.readAsStringSync(), contains("(context, instance) => WbpEverything(instance: instance)"));
        // A widget with a graph embeds its script class and registers it.
        final clicker = await UmgWidgetCodegen.compileAndWrite(projectPath: project, assetName: 'WBP_Clicker', document: clickerDocument());
        expect(clicker.source, contains('class WbpClickerGraph extends LuminaUserWidget'));
        expect(registry.readAsStringSync(), contains("LuminaUserWidgets.register('WBP_Clicker', WbpClickerGraph.new);"));
        // The launcher (regenerated on every save) registers the classes and stacks the layer.
        final level = File('$project/contents/levels/L_DefaultLevel.lmas');
        final actors = ((jsonDecode(level.readAsStringSync()) as Map)['metadata']['actors'] as List).map((a) => Map<String, dynamic>.from(a as Map)).toList();
        final generated = await GenerateDartCodeUseCase()(projectDir: project, levelName: 'L_DefaultLevel', actors: actors);
        expect(generated.isSuccess, isTrue, reason: generated.error);
        final main = File('$project/lib/main.dart').readAsStringSync();
        expect(main, contains("import 'widgets/widget_registry.g.dart';"));
        expect(main, contains('registerProjectWidgetClasses();'));
        expect(main, contains('LuminaGameHost('), reason: 'the game host stacks the widget layer over the game');
        final analysis = await analyzeGameProject(project);
        expect(analysis.exitCode, 0, reason: '${analysis.stdout}${analysis.stderr}');
      }, timeout: const Timeout(Duration(minutes: 4)));
    }
  });

  group('per-element runtime state and the widget class registry', () {
    test('every generated class takes the widget instance and wraps each element in a LuminaUmgElement bound by name', () {
      final src = UmgWidgetCodegen.generateWidgetDart(playerHud(), assetName: 'WBP_PlayerHUD');
      expect(src, contains('const WbpPlayerHUD({super.key, this.instance});'));
      expect(src, contains('final Map<String, Object?>? instance;'));
      expect(src, contains("import 'package:lumina_widgets/lumina_game.dart' show LuminaUmgElement, LuminaUmgElementBinding;"));
      expect(src, contains("name: 'HUD Overlay',"));
      expect(src, contains("name: 'HealthBar Progress',"));
      expect(src, contains("progress: LuminaUmgElementBinding.value<double>(e, 'percent', 0.8),"), reason: 'the designer value is the fallback');
      expect(src, contains("color: LuminaUmgElementBinding.color(e, 'fillColor', Color(0xFF22C55E)),"), reason: 'Set Fill Color writes fillColor');
      expect('LuminaUmgElement('.allMatches(src).length, 2, reason: 'the root canvas is the widget itself, not an element');
      expect(src, contains('instance: instance,'), reason: 'a stateless class reads its own field');

      final stateful = UmgWidgetCodegen.generateWidgetDart(everything(), assetName: 'WBP_Everything');
      expect(stateful, contains('instance: widget.instance,'));
      expect(stateful, contains("LuminaUmgElementBinding.value<String>(e, 'text', 'Text Block')"));
      expect(stateful, contains("LuminaUmgElementBinding.value<bool>(e, 'isChecked', checkBoxItemValue)"));
      expect(stateful, contains("LuminaUmgElementBinding.write(widget.instance, 'Slider Item', 'value', v.value);"), reason: 'the player\'s input reaches Get Slider Value');
      expect(stateful, contains("onPressed: LuminaUmgElementBinding.isEnabled(e) ? _onClickedButton : null,"));
      expect(stateful, contains("LuminaUmgElementBinding.options(e, const ['Option A', 'Option B', 'Option C'])"));
      expect(stateful, contains("_umgLoadTexture(LuminaUmgElementBinding.value<String>(e, 'texture', 'contents/textures/T_Logo.lmas'))"));
    });

    test('widgetClassFor describes every element but the root with its type and designer props', () {
      final cls = UmgWidgetCodegen.widgetClassFor(playerHud(), 'WBP_PlayerHUD');
      expect(cls.name, 'WBP_PlayerHUD');
      expect(cls.elements.map((e) => e.name), ['HUD Overlay', 'HealthBar Progress']);
      final bar = cls.element('HealthBar Progress')!;
      expect(bar.typeName, 'progressBar');
      expect(bar.fieldName, 'healthBarProgress');
      expect(bar.props['percent'], 0.8);
      expect(bar.props['color'], '#22C55E');
      expect(cls.element('healthBarProgress'), same(bar), reason: 'the field name resolves too');
      expect(cls.objectClass, 'Widget:WBP_PlayerHUD');
    });

    test('compileAndWrite writes widget_registry.g.dart naming every widget of the project, and removes it when none is left', () async {
      final project = projectDir.path;
      await UmgWidgetCodegen.compileAndWrite(projectPath: project, assetName: 'WBP_PlayerHUD', document: playerHud());
      final registry = File(UmgWidgetCodegen.registryPath(project));
      expect(registry.existsSync(), isTrue);
      var src = registry.readAsStringSync();
      expect(src, contains("import 'package:lumina_widgets/lumina_game.dart';"));
      expect(src, contains("import 'wbp_player_hud.dart';"));
      expect(src, contains('void registerProjectWidgetClasses() {'));
      expect(src, contains("LuminaWidgetBuilderRegistry.register(\n    'WBP_PlayerHUD',"));
      expect(src, contains("LuminaBlueprintWidgetElement(name: 'HealthBar Progress', fieldName: 'healthBarProgress', typeName: 'progressBar', props: {'color': '#22C55E', 'percent': 0.8}),"));
      expect(src, contains('(context, instance) => WbpPlayerHUD(instance: instance),'));

      // A second widget saved under contents/ joins the registry on the next compile.
      Directory('$project/contents/widgets').createSync(recursive: true);
      final menu = UmgDocument.createDefault();
      menu.addChild(menu.root.id, UmgNode.create(UmgWidgetType.text, name: 'Title'), canvasPosition: const Offset(0, 0));
      final asset = LuminaAsset(assetId: 'wbp_menu', name: 'WBP_Menu', type: AssetType.widget, rawPayload: Uint8List.fromList(utf8.encode(menu.toFormattedJson())));
      File('$project/contents/widgets/WBP_Menu.lmas').writeAsBytesSync(asset.toProtoBufferBytes());
      expect(UmgWidgetCodegen.widgetClassesOf(project).map((c) => c.name), ['WBP_Menu']);
      final again = await UmgWidgetCodegen.compileAndWrite(projectPath: project, assetName: 'WBP_PlayerHUD', document: playerHud());
      expect(again.written, isFalse, reason: 'the widget itself is unchanged');
      src = registry.readAsStringSync();
      expect(src, contains("import 'wbp_menu.dart';"));
      expect(src, contains("import 'wbp_player_hud.dart';"));
      expect(src.indexOf("'WBP_Menu'"), lessThan(src.indexOf("'WBP_PlayerHUD'")), reason: 'sorted, deterministic');
      expect(src, contains("LuminaBlueprintWidgetElement(name: 'Title', fieldName: 'title', typeName: 'text', props: {'color': '#FFFFFF', 'fontSize': 16.0, "
          "'outlineColor': '#000000FF', 'outlineSize': 0.0, 'shadowBlur': 0.0, 'shadowColor': '#000000B3', 'shadowEnabled': false, 'shadowOffsetX': 1.0, 'shadowOffsetY': 1.0, 'text': 'Text Block'}),"));
      expect(await UmgWidgetCodegen.writeWidgetRegistry(project, extra: {'WBP_PlayerHUD': playerHud()}), isFalse, reason: 'idempotent');

      File('$project/contents/widgets/WBP_Menu.lmas').deleteSync();
      expect(await UmgWidgetCodegen.writeWidgetRegistry(project), isTrue);
      expect(registry.existsSync(), isFalse, reason: 'no widgets, no registry (the launcher stops importing it)');
    });
  });
}
