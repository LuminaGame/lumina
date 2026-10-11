import 'package:lumina_editor_api/lumina_editor_api.dart' show EditorAssetPicker, PluginBoundViewport;
import 'package:lumina_editor_data/lumina_editor.dart'
    show LuminaAnimatedMeshComponent, LuminaUmgElementBinding, LuminaUmgInstanceBinding, LuminaViewportController, LuminaViewportScene;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/canvas/editor_canvas.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/interaction/editor_interaction.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/table/editor_table.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/editor_timeline.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';

/// The Timeline, Table and Canvas elements of a running editor panel: the
/// native widgets over the element state (what the graph's `Set Element
/// State` and the typed helpers, and `host.panelState`, write). Their
/// events fire the element's events in the panel graph; their committed
/// changes are written back into the element state, so the graph reads
/// what is on screen.
class EditorNativeElements {
  EditorNativeElements(this.host, this.instance);

  final EditorPanelHost host;
  final EditorPanelInstance instance;

  /// The element's state, or its designer props before it has one.
  Map<String, Object?> _state(UmgNode node, Map<String, Object?>? e) => e ?? node.props.cast<String, Object?>();

  void _fire(UmgNode node, EditorWidgetEvent e) => host.fire(instance, node.name, e.event, e.args);

  void _write(UmgNode node, Map<String, Object?> changes) {
    for (final c in changes.entries) {
      LuminaUmgElementBinding.write(instance.map, node.name, c.key, c.value);
    }
    instance.refresh();
  }

  /// One driver per Timeline element and binding for the instance's life.
  static final Expando<Map<String, EditorPanelViewportDriver>> _drivers = Expando('timeline viewport drivers');

  EditorPanelViewportDriver _driver(String element, PluginBoundViewport bound) {
    final all = _drivers[instance] ??= {};
    final d = all[element];
    if (d != null && d.bound.element == bound.element && d.bound.node == bound.node) return d;
    final i = instance;
    return all[element] =
        EditorPanelViewportDriver(instance: () => i.map, binding: () => i.binding, viewports: i.viewports, bound: bound);
  }

  Widget? build(UmgNode node, Map<String, Object?>? e) {
    switch (node.type) {
      case UmgWidgetType.editorTimeline:
        final state = _state(node, e);
        final bound = state['boundViewport'];
        PluginBoundViewport? binding;
        try {
          binding = bound == null ? null : PluginBoundViewport.fromJson(bound, '${node.name}.boundViewport');
        } on FormatException {
          binding = null;
        }
        return EditorTimeline(
          key: ValueKey('editor_timeline_widget_${node.name}'),
          name: node.name,
          state: state,
          onEvent: (ev) => _fire(node, ev),
          onState: (changes, {required edit}) => _write(node, changes),
          viewport: binding == null ? null : _driver(node.name, binding),
        );
      case UmgWidgetType.editorTable:
        return EditorTable(
          key: ValueKey('editor_table_widget_${node.name}'),
          name: node.name,
          state: _state(node, e),
          onEvent: (ev) => _fire(node, ev),
          onState: (changes, {required edit}) => _write(node, changes),
          assetPicker: (context, {required selectedPath, required types, required onSelected}) => EditorAssetPicker(
            key: ValueKey('editor_table_asset_picker_${node.name}'),
            hostContext: host.vm.extensionRegistry,
            selectedPath: selectedPath,
            typeFilter: types,
            onSelected: onSelected,
          ),
        );
      case UmgWidgetType.editorCanvas:
        return EditorCanvas(
          key: ValueKey('editor_canvas_widget_${node.name}'),
          name: node.name,
          state: _state(node, e),
          projectDir: host.vm.projectDirPath,
          onEvent: (ev) => _fire(node, ev),
          onState: (changes, {required edit}) => _write(node, changes),
        );
      default:
        return null;
    }
  }
}

/// A Timeline bound to a Viewport element of the same panel: the playhead
/// sets the bound node's animation time on the Viewport's live preview
/// every frame it moves (no description diff, no graph run, no process
/// message), and writes it into the Viewport's scene description when the
/// playhead stops, so the time is kept.
class EditorPanelViewportDriver implements TimelineViewportDriver {
  EditorPanelViewportDriver({required this.instance, required this.binding, required this.viewports, required this.bound});

  /// The panel's widget instance map (read each time: a reload replaces it).
  final Map<String, Object?> Function() instance;
  final LuminaUmgInstanceBinding Function() binding;

  /// The live Viewport previews by element name.
  final Map<String, LuminaViewportController> viewports;
  final PluginBoundViewport bound;

  /// Whether the scene description was switched to the timeline's time
  /// (the animation no longer advances by itself).
  bool _taken = false;

  void _writeDescription(double seconds) {
    final element = LuminaUmgElementBinding.element(instance(), bound.element);
    if (element == null) return;
    LuminaViewportScene.of(element).setAnimationTime(bound.node, seconds);
    // Only the Viewport diffs its description; no graph runs.
    binding().refresh();
  }

  void _local(double seconds) {
    final c = viewports[bound.element];
    if (c == null) return;
    c.runtime.setLocalAnimationTime(bound.node, seconds);
    // The timeline is the clock now: the pose holds between its frames.
    final mesh = c.runtime.componentOf(bound.node);
    if (mesh is LuminaAnimatedMeshComponent) mesh.playRate = 0;
    c.clock.markDirty();
  }

  @override
  void drive(double seconds) {
    if (!_taken) {
      _taken = true;
      _writeDescription(seconds);
    }
    _local(seconds);
  }

  @override
  void settle(double seconds) {
    _taken = true;
    _writeDescription(seconds);
    _local(seconds);
  }
}
