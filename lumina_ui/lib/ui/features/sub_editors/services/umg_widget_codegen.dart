import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment, EdgeInsets;

import 'package:lumina_editor_data/lumina_editor.dart'
    show BlueprintDartGenerator, BlueprintGenerationResult;
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/lumina_editor.dart'
    show
        AssetType,
        LuminaAssetIndex,
        LuminaAsset,
        LuminaBlueprintWidgetClass,
        LuminaBlueprintWidgetElement,
        LuminaProject,
        LuminaUmgContainerStyle,
        LuminaBlueprintNodeLibrary,
        LuminaWidgetBlueprintDocument,
        UmgWidgetLibraryService,
        kUmgWidgetLibraryFlutter,
        kUmgWidgetLibraryShadcn;

import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';

part 'umg_widget_codegen/emission.dart';
part 'umg_widget_codegen/containers_and_shadcn.dart';
part 'umg_widget_codegen/literals.dart';
part 'umg_widget_codegen/graph.dart';

/// Outcome of one compile of a widget document.
class UmgCompileResult {
  final String filePath;
  final bool written;
  final String source;
  final List<String> warnings;

  const UmgCompileResult({required this.filePath, required this.written, required this.source, this.warnings = const []});
}

/// Generates the real Flutter widget class for a [UmgDocument]
/// (`<project>/lib/widgets/wbp_<name>.dart`, class `Wbp<Name>`). Same principles as the actor
/// codegen: deterministic, idempotent,
/// compare-before-write, `// BEGIN USER CODE: <tag>` … `// END USER CODE`
/// regions survive regeneration, orphaned regions are kept commented at the
/// end of the file. The game never parses the `.lmas`; this file is the truth.
class UmgWidgetCodegen {
  static final RegExp _regionRegex = RegExp(r'// BEGIN USER CODE: ([a-zA-Z0-9_]+)([\s\S]*?)// END USER CODE');
  static final RegExp _orphanRegex = RegExp(r'// ORPHANED USER CODE: ([a-zA-Z0-9_]+)[^\n]*\n((?:\/\/[^\n]*\n?)*)');

  /// The widget class name the document registers under (`WBP_` prefix
  /// enforced): what `Create Widget` names and the generated file derives from.
  static String fileBaseName(String assetName) {
    final raw = assetName.replaceAll('.lmas', '').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    return raw.startsWith('WBP_') ? raw : 'WBP_$raw';
  }

  /// The generated Dart file (`WBP_PlayerHUD` → `wbp_player_hud.dart`, [dartFileName]).
  static String dartFileNameFor(String assetName) => dartFileName(fileBaseName(assetName));

  /// The generated Dart class (`WBP_PlayerHUD` → `WbpPlayerHUD`, [dartTypeName]).
  static String classNameFor(String assetName) => UmgNaming.toClassName(fileBaseName(assetName));

  /// The `Is Variable` elements of [doc] as lumina types them.
  static List<LuminaBlueprintWidgetElement> variablesOf(UmgDocument doc) => _variablesOf(doc);

  /// The script class [assetName]'s graph compiles into (`WbpClickerGraph`).
  static String graphClassNameFor(String assetName) => _graphClassNameFor(assetName);

  /// The generated script of [doc]'s graph; null without a graph or with errors.
  static BlueprintGenerationResult? graphScriptFor(UmgDocument doc, String assetName, {List<String>? warnings}) =>
      _graphScriptFor(doc, assetName, warnings: warnings);

  /// The graph of [doc] as lumina runs it (Play-In-Editor's VM); null without one.
  static LuminaWidgetBlueprintDocument? widgetGraphOf(UmgDocument doc, String assetName) => _widgetGraphOf(doc, assetName);

  /// The handler an element event gets (`onClickedStartButton`).
  static String handlerNameFor(UmgNode node, String eventName) => _handlerNameFor(node, eventName);

  static String outputPath(String projectPath, String assetName) => '$projectPath/lib/widgets/${dartFileNameFor(assetName)}';

  /// The generated registry of every widget class: `main()` calls
  /// its `registerProjectWidgetClasses()` before the world starts.
  static String registryPath(String projectPath) => '$projectPath/lib/widgets/$kWidgetRegistryFileName';

  static const String kWidgetRegistryFileName = 'widget_registry.g.dart';

  /// Parses guarded regions out of an existing generated file.
  static Map<String, String> parseUserRegions(String? existing) {
    final regions = <String, String>{};
    if (existing == null) return regions;
    for (final m in _regionRegex.allMatches(existing)) {
      regions[m.group(1)!] = m.group(2) ?? '';
    }
    return regions;
  }

  static Map<String, String> _parseOrphans(String? existing) {
    final orphans = <String, String>{};
    if (existing == null) return orphans;
    for (final m in _orphanRegex.allMatches(existing)) {
      orphans[m.group(1)!] = m.group(2) ?? '';
    }
    return orphans;
  }

  /// Generates the widget source; [existingContent] supplies user regions.
  ///
  /// [library] is the project's UMG widget library: shadcn
  /// widgets, or plain Flutter widgets plus the runtime's `LuminaUmg*` set.
  static String generateWidgetDart(
    UmgDocument doc, {
    required String assetName,
    String? existingContent,
    List<String>? warnings,
    String library = kUmgWidgetLibraryShadcn,
  }) {
    final plain = library == kUmgWidgetLibraryFlutter;
    final fileName = fileBaseName(assetName);
    final className = UmgNaming.toClassName(fileName);
    // The widget's graph compiles into a script class this
    // file embeds; each element event it binds gets a handler that fires it.
    final script = _graphScriptFor(doc, assetName, warnings: warnings);
    doc = _withGraphEvents(doc);
    final regions = parseUserRegions(existingContent);
    final previousOrphans = _parseOrphans(existingContent);
    final emittedTags = <String>{};

    String region(String tag, String indent) {
      emittedTags.add(tag);
      final content = regions[tag] ?? '\n$indent';
      return '$indent// BEGIN USER CODE: $tag$content// END USER CODE';
    }

    final nodes = doc.allNodes;
    final hasEvents = nodes.any((n) => n.events.isNotEmpty);
    final hasInteractive = nodes.any((n) => n.type.isInteractive);
    final stateful = hasEvents || hasInteractive;
    // Every Image loads through the bundle: a texture the designer left empty
    // can still be bound at run time by Set Brush From Texture.
    final usesImages = nodes.any((n) => n.type == UmgWidgetType.image || _containerTexture(n).isNotEmpty);
    final usesCanvas = nodes.any((n) => n.type == UmgWidgetType.canvasPanel);
    final usesGrid = nodes.any((n) => n.type == UmgWidgetType.gridPanel);
    // Text shadow and outline of every text-bearing element.
    final usesText = nodes.any((n) => n.type.isTextBearing);
    // The Container and, in shadcn mode, the Kbd's key parser.
    final containers = nodes.where((n) => n.type == UmgWidgetType.container).toList();
    final usesGradient = containers.any((n) => LuminaUmgContainerStyle.fromProps(Map<String, Object?>.from(n.props)).gradient != null);
    final usesKbd = !plain && nodes.any((n) => n.type == UmgWidgetType.shadcnKbd);
    // Runtime names this file uses: the bundle loader, and in plain mode the
    // LuminaUmg* widget for each interactive type present.
    final runtimeNames = <String>{
      // Every element reads its runtime state through the binding.
      'LuminaUmgElement',
      'LuminaUmgElementBinding',
      if (usesImages) 'LuminaAssets',
      if (usesText) ...['LuminaUmgText', 'LuminaUmgTextOutline', 'LuminaUmgTextShadow'],
      if (containers.isNotEmpty) ...['LuminaUmgContainer', 'LuminaUmgContainerStyle'],
      if (usesGradient) 'LuminaUmgGradient',
      if (usesKbd) 'LuminaUmgStyleJson',
      if (!plain && nodes.any((n) => n.type == UmgWidgetType.shadcnSkeleton)) 'LuminaUmgSkeleton',
      if (plain)
        for (final n in nodes) ...?_plainRuntimeNames[n.type],
    }.toList()
      ..sort();

    final b = StringBuffer();
    b.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND (edit only inside USER CODE regions)');
    b.writeln('// Lumina Studio UMG Designer: $fileName (designed at ${doc.designResolution.width}x${doc.designResolution.height}, DPI ${_f(doc.dpiScale)})');
    b.writeln('// ignore_for_file: file_names, unused_import, unnecessary_import, unused_shown_name, unused_element, unused_field, unused_local_variable, prefer_const_constructors'
        '${script == null ? '' : ', camel_case_types, non_constant_identifier_names, unnecessary_this, dead_code, dead_null_aware_expression'}');
    b.writeln();
    if (usesImages) {
      b.writeln("import 'dart:typed_data';");
      b.writeln();
    }
    if (plain) b.writeln("import 'package:flutter/widgets.dart';");
    if (usesGrid) b.writeln("import 'package:flutter/widgets.dart' as widgets show Table, TableRow;");
    // The game library (the engine runtime and its Flutter side, not the
    // editor's barrel): it compiles for the web. The graph script uses the
    // whole runtime.
    if (script != null) {
      b.writeln("import '$kLuminaGameLibrary';");
      b.writeln("import 'package:vector_math/vector_math_64.dart' show Vector2, Vector3;");
      for (final i in script.imports) {
        b.writeln(i);
      }
    } else if (runtimeNames.isNotEmpty) {
      b.writeln("import '$kLuminaGameLibrary' show ${runtimeNames.join(', ')};");
    }
    if (!plain) b.writeln("import 'package:shadcn_flutter/shadcn_flutter.dart';");
    b.writeln();
    b.writeln(region('imports', ''));
    b.writeln();
    b.writeln('/// `$fileName` as designed in Lumina Studio.');
    // The widget instance map `Create Widget` built; each element
    // reads its live state from it, and null (a preview) uses the designer's
    // values written below.
    final inst = stateful ? 'widget.instance' : 'instance';
    if (stateful) {
      b.writeln('class $className extends StatefulWidget {');
      b.writeln('  const $className({super.key, this.instance});');
      b.writeln();
      b.writeln(_instanceFieldDoc);
      b.writeln('  final Map<String, Object?>? instance;');
      b.writeln();
      b.writeln('  @override');
      b.writeln('  State<$className> createState() => _${className}State();');
      b.writeln('}');
      b.writeln();
      b.writeln('class _${className}State extends State<$className> {');
    } else {
      b.writeln('class $className extends StatelessWidget {');
      b.writeln('  const $className({super.key, this.instance});');
      b.writeln();
      b.writeln(_instanceFieldDoc);
      b.writeln('  final Map<String, Object?>? instance;');
      b.writeln();
    }
    b.writeln(region('class_body', '  '));
    b.writeln();

    // State fields for interactive widgets.
    if (stateful) {
      var wroteField = false;
      for (final n in nodes.where((n) => n.type.isInteractive)) {
        b.writeln('  /// Live value of `${n.name}`.');
        switch (n.type) {
          case UmgWidgetType.slider:
            b.writeln('  double ${n.fieldName}Value = ${_f(_num(n.props['value'], 0.5))};');
            break;
          case UmgWidgetType.checkBox:
            b.writeln('  bool ${n.fieldName}Value = ${n.props['checked'] == true};');
            break;
          case UmgWidgetType.editableText:
            b.writeln('  String ${n.fieldName}Value = ${_str(n.props['text']?.toString() ?? '')};');
            break;
          case UmgWidgetType.comboBox:
          case UmgWidgetType.shadcnSelect:
          case UmgWidgetType.shadcnRadioGroup:
            b.writeln('  String? ${n.fieldName}Value = ${_str(n.props['selected']?.toString() ?? '')};');
            break;
          case UmgWidgetType.shadcnSwitch:
          case UmgWidgetType.shadcnToggle:
          case UmgWidgetType.shadcnCheckbox:
            b.writeln('  bool ${n.fieldName}Value = ${n.props['checked'] == true};');
            break;
          case UmgWidgetType.shadcnTabs:
            b.writeln('  int ${n.fieldName}Value = ${_int(n.props['activeIndex'], 0)};');
            break;
          case UmgWidgetType.shadcnSlider:
            b.writeln('  double ${n.fieldName}Value = ${_f(_num(n.props['value'], 0.5))};');
            break;
          case UmgWidgetType.shadcnTextField:
          case UmgWidgetType.shadcnTextArea:
            b.writeln('  String ${n.fieldName}Value = ${_str(n.props['text']?.toString() ?? '')};');
            break;
          default:
            break;
        }
        wroteField = true;
      }
      if (wroteField) b.writeln();

      // Event handlers, one guarded method each.
      for (final n in nodes) {
        for (final e in n.events) {
          final tag = '${e.regionTag}_${n.fieldName}';
          final signature = _handlerSignature(n, e);
          b.writeln('  /// `${e.name}` of `${n.name}` (${n.type.displayName}).');
          b.writeln('  void _${e.handler}($signature) {');
          // The graph's `On <Event> (<element>)` runs first; hand-written
          // code in the guarded region still runs after it.
          if (script != null) b.writeln('    ${_fireCall(n, e, inst)}');
          b.writeln(region(tag, '    '));
          b.writeln('  }');
          b.writeln();
        }
      }
    }

    b.writeln('  @override');
    b.writeln('  Widget build(BuildContext context) {');
    b.writeln('    return ${_emit(doc.root, doc, '    ', stateful, plain, inst)};');
    b.writeln('  }');
    b.writeln('}');
    if (script != null) {
      b.writeln();
      b.write(script.code);
    }

    if (usesCanvas) {
      b.writeln();
      b.writeln('/// Resolves a Canvas Panel slot with anchor semantics inside a parent of [w]x[h].');
      b.writeln('Rect _umgCanvasRect(double w, double h, double minX, double minY, double maxX, double maxY, double posX, double posY, double sizeX, double sizeY, double alignX, double alignY) {');
      b.writeln('  double left;');
      b.writeln('  double width;');
      b.writeln('  if (minX == maxX) {');
      b.writeln('    width = sizeX;');
      b.writeln('    left = minX * w + posX - alignX * width;');
      b.writeln('  } else {');
      b.writeln('    left = minX * w + posX;');
      b.writeln('    width = (maxX * w - sizeX - left).clamp(0.0, double.infinity);');
      b.writeln('  }');
      b.writeln('  double top;');
      b.writeln('  double height;');
      b.writeln('  if (minY == maxY) {');
      b.writeln('    height = sizeY;');
      b.writeln('    top = minY * h + posY - alignY * height;');
      b.writeln('  } else {');
      b.writeln('    top = minY * h + posY;');
      b.writeln('    height = (maxY * h - sizeY - top).clamp(0.0, double.infinity);');
      b.writeln('  }');
      b.writeln('  return Rect.fromLTWH(left, top, width, height);');
      b.writeln('}');
      b.writeln();
      b.writeln('/// Places a resolved canvas slot; size-to-content slots only pin their origin.');
      b.writeln('Widget _umgCanvasSlot(Rect r, bool sizeToContent, Widget child) {');
      b.writeln('  return Positioned(left: r.left, top: r.top, width: sizeToContent ? null : r.width, height: sizeToContent ? null : r.height, child: child);');
      b.writeln('}');
    }
    if (usesImages) {
      b.writeln();
      b.writeln("/// The image bytes of a TEXTURE `.lmas`, from the game's asset bundle.");
      b.writeln('Future<Uint8List?> _umgLoadTexture(String path) async {');
      b.writeln('  if (path.isEmpty) return null; // no texture bound (designer or Set Brush From Texture)');
      b.writeln('  try {');
      b.writeln('    return await LuminaAssets.loadPayload(path);');
      b.writeln('  } catch (_) {');
      b.writeln('    return null; // not bundled: the image stays empty');
      b.writeln('  }');
      b.writeln('}');
    }

    // Orphaned regions: user code whose tag vanished is kept, commented out.
    final orphans = <String, String>{};
    previousOrphans.forEach((tag, body) {
      if (!emittedTags.contains(tag)) orphans[tag] = body;
    });
    regions.forEach((tag, content) {
      if (emittedTags.contains(tag)) return;
      final lines = content.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) return;
      orphans[tag] = '${lines.map((l) => '// $l').join('\n')}\n';
      warnings?.add('User code region "$tag" no longer has a target; kept commented out at the end of ${dartFileName(fileName)}');
    });
    if (orphans.isNotEmpty) {
      final tags = orphans.keys.toList()..sort();
      for (final tag in tags) {
        b.writeln();
        b.writeln('// ORPHANED USER CODE: $tag (its event or element no longer exists in the designer)');
        b.write(orphans[tag]!.endsWith('\n') ? orphans[tag]! : '${orphans[tag]!}\n');
        if (previousOrphans.containsKey(tag) && warnings != null) {
          warnings.add('Orphaned user code "$tag" is still kept at the end of ${dartFileName(fileName)}');
        }
      }
    }
    return b.toString();
  }

  /// Writes the generated file into `<projectPath>/lib/widgets/`, skipping
  /// the write when nothing changed (mtime-stable), atomically otherwise.
  static Future<UmgCompileResult> compileAndWrite({
    required String projectPath,
    required String assetName,
    required UmgDocument document,
    String? library,
  }) async {
    // Widgets an earlier version wrote as `WBP_<Name>.dart` move first, with their user code.
    LuminaGeneratedCodeMigration.migrate(projectPath);
    final file = File(outputPath(projectPath, assetName));
    String? existing;
    if (file.existsSync()) existing = await file.readAsString();
    final warnings = <String>[];
    final source = generateWidgetDart(
      document,
      assetName: assetName,
      existingContent: existing,
      warnings: warnings,
      library: library ?? libraryFor(projectPath),
    );
    final written = existing != source;
    if (written) await _writeAtomically(file, source);
    // The registry names every widget class, this one included even
    // before its `.lmas` is saved under contents/.
    await writeWidgetRegistry(projectPath, extra: {fileBaseName(assetName): document});
    return UmgCompileResult(filePath: file.path, written: written, source: source, warnings: warnings);
  }

  static Future<void> _writeAtomically(File file, String source) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(source, flush: true);
    await tmp.rename(file.path);
  }

  // ---------------------------------------------------------------------------
  // Widget class registry
  // ---------------------------------------------------------------------------

  /// The engine's description of [doc] as widget class [assetName]: one
  /// element per designer node except the root, named as the hierarchy shows
  /// it (what `Get <Element>` and the element nodes address), typed by its
  /// [UmgWidgetType] name and seeded with its designer properties.
  static LuminaBlueprintWidgetClass widgetClassFor(UmgDocument doc, String assetName) {
    final elements = <LuminaBlueprintWidgetElement>[];
    final seen = <String>{};
    for (final n in doc.allNodes) {
      if (identical(n, doc.root) || n.name.isEmpty || !seen.add(n.name)) continue;
      elements.add(LuminaBlueprintWidgetElement(
        name: n.name,
        fieldName: n.fieldName,
        typeName: n.type.name,
        props: Map<String, dynamic>.fromEntries(n.props.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
      ));
    }
    return LuminaBlueprintWidgetClass(name: fileBaseName(assetName), elements: elements);
  }

  /// Every widget document under `<projectDir>/contents/`, by file base
  /// name: the widget assets come from the project's asset index,
  /// so only those files are read.
  static Map<String, UmgDocument> widgetDocuments(String projectDir) {
    final contents = Directory('$projectDir/contents');
    final docs = <String, UmgDocument>{};
    if (!contents.existsSync()) return docs;
    final index = LuminaAssetIndex.open(projectDir)..refreshSync();
    for (final e in index.byType(AssetType.widget)) {
      LuminaAsset asset;
      try {
        asset = LuminaAsset.fromBytes(e.file.readAsBytesSync());
      } catch (_) {
        continue;
      }
      final payload = asset.rawPayload;
      if (asset.type != AssetType.widget || payload == null || payload.isEmpty) continue;
      try {
        final document = UmgDocument.fromJson(Map<String, dynamic>.from(jsonDecode(utf8.decode(payload)) as Map));
        docs[fileBaseName(e.baseName)] = document;
      } catch (_) {
        continue;
      }
    }
    return docs;
  }

  /// The widget classes of [projectDir]'s designer documents (what PIE
  /// registers into `LuminaWidgetClassRegistry` before playing).
  static List<LuminaBlueprintWidgetClass> widgetClassesOf(String projectDir) =>
      [for (final e in widgetDocuments(projectDir).entries) widgetClassFor(e.value, e.key)];

  /// `lib/widgets/widget_registry.g.dart`: `registerProjectWidgetClasses()`
  /// registers each class with its elements and the builder of its compiled
  /// widget into `LuminaWidgetBuilderRegistry` (and so `LuminaWidgetClassRegistry`).
  static String generateWidgetRegistryDart(Map<String, UmgDocument> documents) {
    final names = documents.keys.toList()..sort();
    final b = StringBuffer();
    b.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    b.writeln('// Lumina Studio UMG Designer: the widget classes of this project');
    b.writeln('// ignore_for_file: unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables');
    b.writeln();
    b.writeln("import '$kLuminaGameLibrary';");
    b.writeln();
    for (final n in names) {
      b.writeln("import '${dartFileName(n)}';");
    }
    b.writeln();
    b.writeln('/// Registers every UMG widget class with its elements and its compiled');
    b.writeln('/// widget, so `Create Widget` seeds the element state and the');
    b.writeln('/// `LuminaWidgetLayer` over the game can build it.');
    b.writeln('void registerProjectWidgetClasses() {');
    for (final n in names) {
      final cls = widgetClassFor(documents[n]!, n);
      final className = UmgNaming.toClassName(n);
      b.writeln('  LuminaWidgetBuilderRegistry.register(');
      b.writeln('    ${_str(n)},');
      b.writeln('    const LuminaBlueprintWidgetClass(name: ${_str(n)}, elements: [');
      for (final e in cls.elements) {
        b.writeln('      LuminaBlueprintWidgetElement(name: ${_str(e.name)}, fieldName: ${_str(e.fieldName)}, typeName: ${_str(e.typeName)}, props: ${_literal(e.props)}),');
      }
      b.writeln('    ]),');
      b.writeln('    (context, instance) => $className(instance: instance),');
      b.writeln('  );');
      // Create Widget gives each instance the graph's script.
      if (_graphScriptFor(documents[n]!, n) != null) b.writeln('  LuminaUserWidgets.register(${_str(n)}, ${_graphClassNameFor(n)}.new);');
    }
    b.writeln('}');
    return b.toString();
  }

  /// Writes the registry for every widget document of [projectDir] (plus
  /// [extra], documents being compiled that may not be saved yet); removes it
  /// when the project has no widgets. Returns whether the file changed.
  static Future<bool> writeWidgetRegistry(String projectDir, {Map<String, UmgDocument> extra = const {}}) async {
    final documents = widgetDocuments(projectDir)..addAll(extra);
    final file = File(registryPath(projectDir));
    if (documents.isEmpty) {
      if (!file.existsSync()) return false;
      await file.delete();
      return true;
    }
    final source = generateWidgetRegistryDart(documents);
    if (file.existsSync() && await file.readAsString() == source) return false;
    await _writeAtomically(file, source);
    return true;
  }

  /// A JSON-plain designer value as a Dart `const` literal.
  static String _literal(Object? v) {
    if (v == null) return 'null';
    if (v is String) return _str(v);
    if (v is bool) return v.toString();
    if (v is double) return _f(v);
    if (v is num) return v.toString();
    if (v is List) return '[${v.map(_literal).join(', ')}]';
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return '{${keys.map((k) => '${_str(k)}: ${_literal(v[k])}').join(', ')}}';
    }
    return _str(v.toString());
  }

  static const String _instanceFieldDoc = '''
  /// The widget instance this class renders (the map `Create Widget` built):
  /// every element reads its live state from it through
  /// `LuminaUmgElementBinding`. Null in a preview: the designer's values apply.''';

  /// The widget library [projectDir]'s generated widgets can use: its
  /// manifest's choice, shadcn only when the game really depends on it.
  static String libraryFor(String? projectDir) {
    if (projectDir == null) return kUmgWidgetLibraryShadcn;
    LuminaProject? project;
    final hasPubspec = File('$projectDir/pubspec.yaml').existsSync();
    try {
      final manifest = Directory(projectDir).listSync().whereType<File>().where((f) => f.path.endsWith('.lmproject')).firstOrNull;
      if (manifest != null) {
        project = LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(manifest.readAsStringSync()) as Map));
      }
    } catch (_) {
      // Unreadable manifest: fall back to what the pubspec allows.
    }
    // Without a pubspec there is nothing to check the choice against.
    if (!hasPubspec) return project?.ui.widgetLibrary ?? kUmgWidgetLibraryShadcn;
    return UmgWidgetLibraryService.effectiveLibrary(projectDir, project);
  }

  /// Regenerates every UMG widget of [projectDir] (all `WIDGET` assets under
  /// `contents/`) for [library], e.g. after the project switched libraries.
  static Future<List<UmgCompileResult>> recompileProject(String projectDir, {String? library}) async {
    final results = <UmgCompileResult>[];
    for (final e in widgetDocuments(projectDir).entries) {
      results.add(await compileAndWrite(projectPath: projectDir, assetName: e.key, document: e.value, library: library));
    }
    return results;
  }

  /// The runtime widget each interactive type uses in plain-Flutter mode.
  static const Map<UmgWidgetType, List<String>> _plainRuntimeNames = {
    UmgWidgetType.border: ['LuminaUmgBorder'],
    UmgWidgetType.button: ['LuminaUmgButton', 'LuminaUmgButtonStyle'],
    UmgWidgetType.progressBar: ['LuminaUmgProgressBar'],
    UmgWidgetType.slider: ['LuminaUmgSlider'],
    UmgWidgetType.checkBox: ['LuminaUmgCheckbox'],
    UmgWidgetType.editableText: ['LuminaUmgTextField'],
    UmgWidgetType.comboBox: ['LuminaUmgComboBox'],
  };

  /// `#RRGGBB`, or `#RRGGBBAA` with the alpha last (the
  /// order `LuminaUmgElementBinding.parseColor` reads at run time).
  static Color? parseHexColor(String hex) {
    var h = hex.trim().replaceAll('#', '');
    if (h.length == 6) h = '${h}FF';
    if (h.length != 8) return null;
    final value = int.tryParse(h, radix: 16);
    return value == null ? null : Color(((value & 0xFF) << 24) | (value >> 8));
  }

  static String toHex(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
