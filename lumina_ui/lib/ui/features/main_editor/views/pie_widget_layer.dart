import 'dart:io';
import 'dart:typed_data';

import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../services/pie_controller.dart';
import '../../sub_editors/models/umg_document.dart';
import '../../sub_editors/services/umg_widget_codegen.dart';
import '../../sub_editors/view_models/umg_editor_view_model.dart';
import '../../sub_editors/views/umg/umg_runtime_view.dart';

/// Renders the UMG widgets a Play-In-Editor session adds to the viewport
/// through the engine's [LuminaWidgetLayer], so PIE and the
/// built game share one rendering path. The editor has no compiled widget
/// classes, so each class is built from its designer document
/// ([UmgRuntimeView]) bound to the instance's per-element state; the
/// project's widget documents are registered into
/// [LuminaWidgetClassRegistry] so `Create Widget` seeds those elements.
class PieWidgetLayer extends StatefulWidget {
  final PieController pieController;
  final String projectDirPath;

  const PieWidgetLayer({
    super.key,
    required this.pieController,
    required this.projectDirPath,
  });

  @override
  State<PieWidgetLayer> createState() => _PieWidgetLayerState();
}

class _PieWidgetLayerState extends State<PieWidgetLayer> {
  Map<String, UmgDocument> _docs = const {};
  bool _wasPlaying = false;

  /// The bound textures of every document (Image brushes, Container
  /// backgrounds), by node id, read once per session.
  Map<String, Uint8List> _textures = const {};

  /// The project's widget library: a plain-Flutter game shows no shadcn
  /// component, and neither does its PIE.
  bool _plainLibrary = false;
  final EngineLoggerService _logger = EngineLoggerService();

  @override
  void initState() {
    super.initState();
    widget.pieController.viewModel.addListener(_onChanged);
    _loadDocuments();
  }

  @override
  void didUpdateWidget(covariant PieWidgetLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pieController != widget.pieController) {
      oldWidget.pieController.viewModel.removeListener(_onChanged);
      widget.pieController.viewModel.addListener(_onChanged);
    }
    if (oldWidget.projectDirPath != widget.projectDirPath) _loadDocuments();
  }

  @override
  void dispose() {
    widget.pieController.viewModel.removeListener(_onChanged);
    super.dispose();
  }

  /// Reads every widget `.lmas` of the project and registers its class, so a
  /// widget created during this session has its elements.
  void _loadDocuments() {
    _docs = UmgWidgetCodegen.widgetDocuments(widget.projectDirPath);
    _plainLibrary = UmgWidgetCodegen.libraryFor(widget.projectDirPath) == kUmgWidgetLibraryFlutter;
    final textures = <String, Uint8List>{};
    for (final doc in _docs.values) {
      for (final n in doc.allNodes) {
        final key = UmgEditorViewModel.textureKeyOf(n.type);
        final rel = key == null ? '' : n.props[key]?.toString() ?? '';
        if (rel.isEmpty) continue;
        final file = File('${widget.projectDirPath}/$rel');
        try {
          final bytes = file.existsSync() ? LuminaAsset.fromBytes(file.readAsBytesSync()).rawPayload : null;
          if (bytes != null) textures[n.id] = bytes;
        } catch (e) {
          _logger.log('PIE: texture $rel of ${n.name} is not a readable .lmas: $e', level: 'warning', source: 'UMG');
        }
      }
    }
    _textures = textures;
    LuminaWidgetClassRegistry.registerAll([
      for (final e in _docs.entries) UmgWidgetCodegen.widgetClassFor(e.value, e.key),
    ]);
  }

  void _onChanged() {
    if (!mounted) return;
    final playing = widget.pieController.isPlaying;
    // A new session sees the documents as saved now.
    if (playing && !_wasPlaying) _loadDocuments();
    _wasPlaying = playing;
    setState(() {});
  }

  UmgDocument? _documentFor(String className) {
    if (className.isEmpty) return null;
    final name = className.endsWith('.lmas') ? className.substring(0, className.length - 5) : className;
    return _docs[name] ?? _docs[UmgWidgetCodegen.fileBaseName(name)];
  }

  LuminaWidgetBuilder? _resolveBuilder(String className) {
    final doc = _documentFor(className);
    if (doc == null) return null;
    return (context, instance) => UmgRuntimeView(
          key: ValueKey('pie_widget_${className}_${identityHashCode(instance)}'),
          document: doc,
          runtimeValues: instance,
          textureBytes: _textures,
          plainLibrary: _plainLibrary,
          onAction: (nodeId, action) => _onWidgetAction(className, doc, instance, nodeId, action),
        );
  }

  /// A widget event in PIE (`OnValueChanged`, `OnClicked`):
  /// the new value is already in the instance's element state, so `Is
  /// Checked` & co. read it; the layer refreshes and the Output Log names it.
  void _onWidgetAction(String className, UmgDocument doc, Map<String, Object?> instance, String nodeId, String action) {
    final node = doc.findNode(nodeId);
    if (node == null) return;
    final state = LuminaUmgElementBinding.element(instance, node.name);
    final value = switch (action) {
      'OnValueChanged' => ' → ${state?['isChecked'] ?? state?['selectedOption'] ?? state?['activeIndex'] ?? state?['value'] ?? state?['text']}',
      _ => '',
    };
    _logger.log('$className.${node.name} $action$value', level: 'info', source: 'UMG');
    widget.pieController.game?.world?.getSubsystem<LuminaWidgetSubsystem>()?.notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    return LuminaWidgetLayer(
      world: widget.pieController.game?.world,
      resolveBuilder: _resolveBuilder,
    );
  }
}
