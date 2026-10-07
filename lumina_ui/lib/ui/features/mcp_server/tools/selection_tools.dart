import 'package:flutter/foundation.dart' show Listenable;
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/details/models/component_property_registry.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_graph_ref.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blend_space_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_enum_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_graph_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_interface_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/particle_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/physics_asset_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/graph_json.dart';

/// The editor's current selection as one read-only tool: the selected level
/// actors (the primary one is the Details panel's subject), the Content
/// Browser's selected assets and folder, and the active workspace tab with
/// its sub-editor's own selection.
void registerSelectionTools(McpToolRegistry registry, EditorViewModel vm) {
  registry.register(McpTool(
    name: 'get_selection',
    risk: McpToolRisk.readOnly,
    groups: const {McpToolGroups.level, McpToolGroups.asset},
    title: 'Get selection',
    description: 'What the user has selected now: the selected level actors in selection order (id, name, type, '
        'transform, mobility, parent, Blueprint class, mesh / material asset paths, components with the assets they '
        'reference) with the primary one (the Details panel\'s subject) marked; the Content Browser\'s selected '
        'assets and current folder; the active workspace tab (the level or a sub-editor and its asset) with the '
        'sub-editor\'s own selection (Blueprint graph nodes, a skeleton bone, a UMG widget, …). Asset paths are '
        'project-relative. Units: centimetres, degrees, Z up.',
    inputSchema: McpSchema.object({
      'include_components': McpSchema.boolean('List each selected actor\'s components. Default true.'),
      'include_properties': McpSchema.boolean('Give each component its full Details properties, as get_actor returns '
          'them, and each selected graph node its pins. Default false.'),
    }),
    handler: (args) => McpToolResult.json(mcpSelectionSnapshot(
      vm,
      includeComponents: args.has('include_components') ? args.boolean('include_components') : true,
      includeProperties: args.boolean('include_properties'),
    )),
  ));
}

/// The selection `get_selection` returns (and the `lumina://selection`
/// resource serves with the defaults).
Map<String, Object?> mcpSelectionSnapshot(
  EditorViewModel vm, {
  bool includeComponents = true,
  bool includeProperties = false,
}) {
  final projectPrefix = '${vm.projectDirPath.replaceAll(r'\', '/')}/';
  String? relative(String? path) {
    if (path == null) return null;
    final p = path.replaceAll(r'\', '/');
    return p.startsWith(projectPrefix) ? p.substring(projectPrefix.length) : p;
  }

  String baseName(String path) {
    final file = path.substring(path.lastIndexOf('/') + 1);
    return file.endsWith('.lmas') ? file.substring(0, file.length - 5) : file;
  }

  Object? assetRef(Object? value) => switch (value) {
        String s => relative(s),
        List l => [for (final v in l) v is String ? relative(v) : v],
        _ => value,
      };

  Map<String, Object?> componentJson(EditorComponentNode c) {
    final refs = <String, Object?>{};
    final descriptor = ComponentPropertyRegistry.descriptors[c.type];
    for (final p in descriptor?.properties ?? const <PropertyDescriptor>[]) {
      if (p.editor != PropertyEditorType.assetRef) continue;
      final value = c.properties[p.id];
      if (value == null || (value is String && value.isEmpty) || (value is List && value.isEmpty)) continue;
      refs[p.id] = assetRef(value);
    }
    return {
      'id': c.id,
      'type': c.type,
      'name': c.name,
      'enabled': c.enabled,
      'asset_refs': refs,
      if (includeProperties) 'properties': c.toMap()['properties'],
    };
  }

  final primary = vm.primarySelectedActor;
  final actorsById = {for (final a in vm.actors) a.id: a};
  Map<String, Object?> actorJson(EditorActorNode a) {
    final parent = a.parentId == null ? null : actorsById[a.parentId];
    final blueprint = a.blueprintClass;
    return {
      'id': a.id,
      'name': a.name,
      'type': a.type,
      'primary': a.id == primary?.id,
      'location': a.location,
      'rotation': a.rotation,
      'scale': a.scale,
      'mobility': a.mobility,
      'visible': a.isVisible,
      'locked': a.isLocked,
      'parent': parent == null ? null : {'id': parent.id, 'name': parent.name, 'type': parent.type},
      'blueprint': blueprint == null ? null : {'path': relative(blueprint), 'class_name': baseName(blueprint.replaceAll(r'\', '/'))},
      'mesh_asset_path': relative(a.meshAssetPath),
      'material_path': relative(a.materialPath),
      if (includeComponents) 'components': [for (final c in a.components) componentJson(c)],
    };
  }

  final selected = vm.selectedActors;

  // The Content Browser: only assets still in the project; the primary one
  // is the last clicked while it stays selected, else the last selected.
  final assetsByPath = {for (final a in vm.realAssets) a.relativePath: a};
  final selectedAssets = [for (final p in vm.contentBrowserSelection) ?assetsByPath[p]];
  final clicked = vm.contentBrowserPrimaryAsset;
  final primaryAsset = selectedAssets.any((a) => a.relativePath == clicked)
      ? clicked
      : selectedAssets.lastOrNull?.relativePath;

  Map<String, Object?> assetJson(RealAssetInfo a) => {'path': a.relativePath, 'name': baseName(a.fileName), 'type': a.type.name};

  final tabs = vm.openTabs;
  final tab = vm.currentTab;
  final isLevel = tab.id == EditorViewModel.kLevelTabId;

  return {
    'level': {
      'count': selected.length,
      'primary_actor_id': primary?.id,
      'actors': [for (final a in selected) actorJson(a)],
    },
    'content_browser': {
      'current_folder': vm.selectedFolder ?? 'contents',
      'count': selectedAssets.length,
      'primary_asset': primaryAsset,
      'assets': [
        for (final a in selectedAssets) {...assetJson(a), 'primary': a.relativePath == primaryAsset},
      ],
    },
    'active_tab': {
      'index': vm.activeTabIndex,
      'id': tab.id,
      'title': tab.title,
      'category': tab.category,
      'kind': isLevel ? 'level' : 'sub_editor',
      'asset': tab.asset == null ? null : assetJson(tab.asset!),
      'is_dirty': isLevel ? vm.project.isDirty : vm.isTabDirty(vm.activeTabIndex),
      'selection': isLevel ? null : _subEditorSelection(vm.editorSessionFor(tab.id), includeProperties),
    },
    'open_tabs': [
      for (var i = 0; i < tabs.length; i++)
        {'index': i, 'title': tabs[i].title, 'category': tabs[i].category, 'asset_path': tabs[i].asset?.relativePath},
    ],
  };
}

/// The selection a sub-editor's view model already holds; null for an editor
/// without one (or a tab with no bound view model).
Map<String, Object?>? _subEditorSelection(Listenable? session, bool full) {
  List<Map<String, Object?>> nodes(BlueprintGraphEditor graph) => [
        for (final id in graph.selectedNodeIds)
          if (graph.node(id) case final n?)
            full ? mcpNodeJson(graph, n) : {'id': n.id, 'node': n.registryId, 'title': n.title},
      ];

  String graphName(BlueprintGraphRef ref) => switch (ref.kind) {
        BlueprintGraphKind.eventGraph => 'event',
        BlueprintGraphKind.constructionScript => 'construction_script',
        BlueprintGraphKind.function => 'function:${ref.name}',
        BlueprintGraphKind.macro => 'macro:${ref.name}',
        BlueprintGraphKind.timeline => 'timeline:${ref.name}',
      };

  switch (session) {
    case BlueprintEditorViewModel e:
      final ref = e.activeGraph;
      final graph = ref.hasGraph ? e.activeGraphEditor : null;
      return {
        'editor': 'blueprint',
        'graph': graphName(ref),
        'selected_node_ids': graph?.selectedNodeIds.toList() ?? const <String>[],
        'selected_nodes': graph == null ? const <Object>[] : nodes(graph),
        'selected_component_id': e.selectedComponentId,
      };
    case MaterialEditorViewModel e:
      final graph = e.graph.editor;
      return {'editor': 'material', 'selected_node_ids': graph.selectedNodeIds.toList(), 'selected_nodes': nodes(graph)};
    case SkeletalMeshEditorViewModel e:
      return {'editor': 'skeletal_mesh', 'bone': e.selectedBone?.name, 'socket': e.selectedSocket?.name};
    case UmgEditorViewModel e:
      return {'editor': 'widget', 'widget_id': e.selectedId};
    case AnimBlueprintEditorViewModel e:
      return {
        'editor': 'anim_blueprint',
        'state': e.selectedState,
        'transition': e.selectedTransition,
        'variable': e.selectedVariable,
      };
    case AnimationEditorViewModel e:
      return {'editor': 'animation', 'clip': e.selectedClip, 'keyframe_ids': e.selectedKeyframeIds.toList()};
    case BlendSpaceEditorViewModel e:
      return {'editor': 'blend_space', 'sample': e.selectedSample};
    case SequencerViewModel e:
      return {
        'editor': 'sequencer',
        'track_id': e.selectedTrackId,
        'keys': [
          for (final k in e.selectedKeys) {'track_id': k.$1, 'channel': k.$2, 'index': k.$3},
        ],
      };
    case ParticleEditorViewModel e:
      return {'editor': 'particle', 'emitter_index': e.selectedEmitterIndex};
    case PhysicsAssetEditorViewModel e:
      return {
        'editor': 'physics_asset',
        'body_bone': e.selectedBody?.boneName,
        'constraint': e.selectedConstraint?.name,
        'bone': e.selectedBoneName,
      };
    case BlueprintEnumViewModel e:
      return {'editor': 'enum', 'value_index': e.selectedIndex};
    case BlueprintInterfaceViewModel e:
      return {'editor': 'interface', 'function': e.selectedFunction};
    default:
      return null;
  }
}
