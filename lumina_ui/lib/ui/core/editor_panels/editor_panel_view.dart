import 'dart:async';

import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_trust_prompt.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/editor_widget_set.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select/asset_picker_popup.dart';
import 'package:lumina_ui/ui/core/services/asset_picker_catalog.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_runtime_view.dart';

/// One editor panel's slot: the running panel rendered through the UMG
/// runtime renderer in the editor's theme, or why it does not run (not
/// trusted yet, graph errors, stopped by the step budget), with the panel's
/// progress bars below. Resizable docks give it at least the asset's
/// `minWidth` / `minHeight`.
class EditorPanelView extends StatefulWidget {
  const EditorPanelView(
      {super.key, required this.host, required this.panelId, this.settings, this.closeOnDispose = false, this.dialogSerial});

  final EditorPanelHost host;
  final String panelId;

  /// The Project Settings working copy (a `projectSettings` panel).
  final PluginSettingsHandle? settings;

  /// Closes the panel when the view goes (a tab, a settings section).
  final bool closeOnDispose;

  /// A dialog's own instance (opened by the dialog), by serial.
  final int? dialogSerial;

  @override
  State<EditorPanelView> createState() => _EditorPanelViewState();
}

class _EditorPanelViewState extends State<EditorPanelView> {
  EditorPanelInstance? _instance;
  static final Set<String> _prompted = {};

  EditorPanelHost get host => widget.host;

  @override
  void initState() {
    super.initState();
    host.addListener(_changed);
    // Opening notifies the editor: after this frame, never during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final serial = widget.dialogSerial;
      final instance = serial == null
          ? host.open(widget.panelId)
          : host.instancesOf(widget.panelId).where((i) => i.serial == serial).firstOrNull;
      if (instance == null) return;
      instance
        ..viewContext = context
        ..settings = widget.settings;
      setState(() => _instance = instance);
      _promptTrust();
    });
  }

  @override
  void dispose() {
    host.removeListener(_changed);
    final instance = _instance;
    if (instance != null && identical(instance.viewContext, context)) instance.viewContext = null;
    if (widget.closeOnDispose && instance != null) {
      final id = widget.panelId;
      scheduleMicrotask(() => host.close(id, only: instance));
    }
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final current = host.instancesOf(widget.panelId);
    final instance = _instance;
    if (instance != null && !current.contains(instance)) {
      // Closed elsewhere (Close This Panel, the plugin disabled).
      _instance = null;
    }
    setState(() {});
  }

  void _promptTrust() {
    if (host.trustOf(widget.panelId) != EditorPanelTrust.untrusted) return;
    final key = '${host.vm.projectDirPath}|${widget.panelId}';
    if (!_prompted.add(key)) return;
    unawaited(showEditorPanelTrustPrompt(context, host));
  }

  @override
  Widget build(BuildContext context) {
    final rt = host.panel(widget.panelId);
    if (rt == null) return _message(LucideIcons.circleOff, 'This editor panel is no longer available.');
    final info = rt.info;
    Widget body;
    if (host.trustOf(rt.id) == EditorPanelTrust.untrusted) {
      body = _untrusted(rt);
    } else if (rt.hasErrors && (_instance?.script == null)) {
      body = _errors(rt);
    } else {
      final instance = _instance;
      body = instance == null ? const SizedBox.shrink() : _running(rt, instance);
    }
    return Container(
      key: ValueKey('editor_panel_view_${rt.id}'),
      color: EditorColors.sidebar,
      constraints: BoxConstraints(minWidth: info.minWidth, minHeight: info.minHeight),
      child: body,
    );
  }

  Widget _running(EditorPanelRuntime rt, EditorPanelInstance instance) {
    instance.viewContext = context;
    final set = EditorWidgetSet(host, instance);
    final droppable = rt.info.contentDroppable;
    return RepaintBoundary(
      key: instance.boundaryKey,
      child: ColoredBox(
        color: EditorColors.sidebar,
        child: _runningBody(rt, instance, set, droppable),
      ),
    );
  }

  Widget _runningBody(EditorPanelRuntime rt, EditorPanelInstance instance, EditorWidgetSet set, bool droppable) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (instance.stoppedMessage != null)
        _banner(instance.stoppedMessage!, EditorColors.logError, action: ('Reload', () => unawaited(host.reload(rt.id)))),
      if (instance.reloadErrors != null)
        _banner('The saved version has errors; the last good one keeps running. ${instance.reloadErrors!.first}', EditorColors.logWarning),
      Expanded(
        child: Stack(children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: (e) => instance.lastPointer = e.position,
              child: LuminaUmgInstanceScope(
                binding: instance.binding,
                child: UmgRuntimeView(
                  key: ValueKey('editor_panel_runtime_${rt.id}_${instance.serial}_${identityHashCode(instance.map)}'),
                  document: rt.document,
                  runtimeValues: instance.map,
                  editorTheme: true,
                  projectDir: host.vm.projectDirPath,
                  editorElementBuilder: set.build,
                  onElementEvent: (node, event, args) => host.fire(instance, node.name, event, args),
                  onViewportController: (node, c) =>
                      c == null ? instance.viewports.remove(node.name) : instance.viewports[node.name] = c,
                  elementDecorator: droppable ? (node, child) => _dropTarget(instance, node, child) : null,
                ),
              ),
            ),
          ),
          if (instance.pickRequest != null) ..._picker(instance),
        ]),
      ),
      for (final p in instance.progress.entries)
        Container(
          key: ValueKey('editor_panel_progress_${p.key}'),
          padding: const EdgeInsets.symmetric(horizontal: EditorDensity.gutter, vertical: 4),
          decoration: const BoxDecoration(color: EditorColors.cardHeader, border: Border(top: BorderSide(color: EditorColors.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(p.value.text, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
            const SizedBox(height: 3),
            p.value.value < 0 ? const LinearProgressIndicator() : Progress(progress: p.value.value.clamp(0.0, 1.0)),
          ]),
        ),
    ]);
  }

  /// `Pick Asset`: the host's asset picker popup (search, thumbnails,
  /// recents, the type filter) over the panel; a tap outside dismisses it.
  List<Widget> _picker(EditorPanelInstance instance) {
    final request = instance.pickRequest!;
    void done(String? path) {
      instance.pickRequest = null;
      if (!request.done.isCompleted) request.done.complete(path);
      setState(() {});
    }

    return [
      Positioned.fill(
        child: GestureDetector(
          key: const ValueKey('editor_panel_pick_asset_barrier'),
          behavior: HitTestBehavior.opaque,
          onTap: () => done(null),
          // A scrim over any surface: black at 20%, not a theme surface.
          child: const ColoredBox(color: Color(0x33000000)),
        ),
      ),
      Positioned(
        left: 8,
        top: 8,
        right: 8,
        child: Align(
          alignment: Alignment.topLeft,
          child: AssetPickerPopup(
            key: const ValueKey('editor_panel_pick_asset'),
            assets: host.vm.realAssets,
            typeFilter: request.types,
            selectedPath: null,
            recents: _recents,
            width: 320,
            onClose: () => done(null),
            onSelected: (a) {
              _recents.record(a);
              done(a.relativePath);
            },
          ),
        ),
      ),
    ];
  }

  static final AssetPickerRecents _recents = AssetPickerRecents();

  /// An element flagged "Accepts Asset Drops" (with its type filter) takes
  /// Content Browser drags and fires On Asset Dropped.
  Widget _dropTarget(EditorPanelInstance instance, UmgNode node, Widget child) {
    if (node.props['acceptsAssetDrops'] != true) return child;
    final filter = '${node.props['assetDropTypes'] ?? ''}'.toLowerCase();
    bool accepts(RealAssetInfo a) =>
        filter.trim().isEmpty || filter.split(',').map((s) => s.trim()).contains(a.type.name.toLowerCase());
    return DragTarget<RealAssetInfo>(
      key: ValueKey('editor_panel_drop_${node.name}'),
      onWillAcceptWithDetails: (d) => accepts(d.data),
      onAcceptWithDetails: (d) => host.fire(instance, node.name, 'OnAssetDropped', {
        'asset_path': d.data.relativePath,
        'asset_type': d.data.type.name,
      }),
      builder: (context, candidates, _) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: candidates.isEmpty ? null : Border.all(color: EditorColors.primary, width: 1.5),
        ),
        child: child,
      ),
    );
  }

  Widget _untrusted(EditorPanelRuntime rt) => Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.shieldAlert, size: 20, color: EditorColors.logWarning),
            const SizedBox(height: 6),
            Text('${rt.title}: not trusted', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
            const SizedBox(height: 4),
            const Text('This project\'s editor panel runs only after you trust it.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
            const SizedBox(height: 8),
            OutlineButton(
              key: ValueKey('editor_panel_review_${rt.id}'),
              size: ButtonSize.small,
              onPressed: () => unawaited(showEditorPanelTrustPrompt(context, host)),
              child: const Text('Not trusted · Review'),
            ),
          ]),
        ),
      );

  Widget _errors(EditorPanelRuntime rt) => ListView(
        padding: const EdgeInsets.all(EditorDensity.gutter),
        children: [
          Text('${rt.title} has errors and does not run:',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.logError)),
          const SizedBox(height: 6),
          for (final e in rt.errors)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('• $e', style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlineButton(
              key: ValueKey('editor_panel_open_in_widget_editor_${rt.id}'),
              size: ButtonSize.small,
              onPressed: () => host.vm.openAssetEditorByPath(rt.entry.filePath),
              child: const Text('Open in Widget Editor'),
            ),
          ),
        ],
      );

  Widget _banner(String text, Color color, {(String, VoidCallback)? action}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: EditorDensity.gutter, vertical: 4),
        color: color.withValues(alpha: 0.15),
        child: Row(children: [
          Expanded(child: Text(text, style: TextStyle(fontSize: 10, color: color))),
          if (action != null)
            GhostButton(
              key: ValueKey('editor_panel_banner_${action.$1}'),
              density: ButtonDensity.compact,
              onPressed: action.$2,
              child: Text(action.$1, style: const TextStyle(fontSize: 10)),
            ),
        ]),
      );

  Widget _message(IconData icon, String text) => Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: EditorColors.mutedForeground),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        ]),
      );
}
