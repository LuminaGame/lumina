import 'dart:async';

import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_library/editor_library.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart' show EditorActorNode;

const String _selection = 'Editor|Selection';
const String _level = 'Editor|Level';
const String _transactions = 'Editor|Transactions';
const String _levelCap = 'level';

/// Selection, level actors (through the level proxy, every write undoable)
/// and transactions.
final List<EditorLibraryNode> levelLibraryNodes = [
  // --- Selection ---------------------------------------------------------------
  EditorLibraryNode(
    pureNode('editor_get_selected_actors', 'Get Selected Actors', _selection,
        outputs: [ret(LuminaPinType.array, elementType: LuminaPinType.string)], tooltip: 'The ids of the selected level actors.'),
    function: (c, _) => {'return_value': editorPanelCall(c)?.host.vm.selectedActorIds.toList() ?? <String>[]},
  ),
  EditorLibraryNode(
    impureNode('editor_select_actors', 'Select Actors', _selection, inputs: [idsPin('actor_ids', 'Actor Ids')]),
    function: (c, i) {
      editorPanelCall(c)?.host.vm.setActorSelection(inIds(i, 'actor_ids'));
      return const {};
    },
  ),
  EditorLibraryNode(
    impureNode('editor_clear_selection', 'Clear Selection', _selection),
    function: (c, _) {
      editorPanelCall(c)?.host.vm.clearSelection();
      return const {};
    },
  ),

  // --- Level ---------------------------------------------------------------------
  EditorLibraryNode(
    pureNode('editor_get_level_actors', 'Get Level Actors', _level,
        inputs: [strPin('class_filter', 'Class Filter'), strPin('label_filter', 'Label Filter')],
        outputs: [ret(LuminaPinType.array, elementType: LuminaPinType.string)],
        tooltip: 'The ids of the open level\'s actors whose type (or Blueprint class) matches Class Filter and whose label '
            'matches Label Filter (* matches anything; empty matches all).'),
    function: (c, i) {
      final vm = editorPanelCall(c)?.host.vm;
      if (vm == null) return {'return_value': <String>[]};
      final cls = _glob(inStr(i, 'class_filter'));
      final label = _glob(inStr(i, 'label_filter'));
      return {
        'return_value': [
          for (final a in vm.actors)
            if ((cls == null || cls.hasMatch(a.type) || cls.hasMatch(a.blueprintClass?.split('/').last.replaceAll('.lmas', '') ?? '')) &&
                (label == null || label.hasMatch(a.name)))
              a.id,
        ],
      };
    },
  ),
  EditorLibraryNode(
    pureNode('editor_get_level_actor_tree', 'Get Level Actor Tree', _level,
        inputs: [strPin('label_filter', 'Label Filter')],
        outputs: [ret(LuminaPinType.json)],
        tooltip: 'The open level\'s actors as Tree View items: one folder per actor type, each actor '
            '{"id", "label", "icon"} under it (Label Filter: * matches anything; empty matches all).'),
    function: (c, i) {
      final vm = editorPanelCall(c)?.host.vm;
      if (vm == null) return {'return_value': <Object?>[]};
      final label = _glob(inStr(i, 'label_filter'));
      final byType = <String, List<Map<String, Object?>>>{};
      for (final a in vm.actors) {
        if (label != null && !label.hasMatch(a.name)) continue;
        (byType[a.type] ??= []).add({'id': a.id, 'label': a.name, 'icon': 'box'});
      }
      final types = byType.keys.toList()..sort();
      return {
        'return_value': [
          for (final t in types) {'id': 'type:$t', 'label': t, 'icon': 'folder', 'children': byType[t]},
        ],
      };
    },
  ),
  EditorLibraryNode(
    pureNode('editor_get_actor_label', 'Get Actor Label', _level,
        inputs: [strPin('actor_id', 'Actor Id')], outputs: [ret(LuminaPinType.string)]),
    function: (c, i) => {'return_value': _actor(c, i)?.name ?? ''},
  ),
  EditorLibraryNode(
    pureNode('editor_get_actor_transform', 'Get Actor Transform', _level,
        inputs: [strPin('actor_id', 'Actor Id')], outputs: [ret(LuminaPinType.transform), boolPin('found', 'Found')],
        tooltip: 'Location (cm, Z up), rotation (degrees) and scale.'),
    function: (c, i) {
      final a = _actor(c, i);
      return {
        'return_value': a == null ? transformOut(const [0, 0, 0], const [0, 0, 0], const [1, 1, 1]) : transformOut(a.location, a.rotation, a.scale),
        'found': a != null,
      };
    },
  ),
  EditorLibraryNode(
    impureNode('editor_set_actor_transform', 'Set Actor Transform', _level,
        inputs: [strPin('actor_id', 'Actor Id'), transformPin('transform', 'Transform')],
        outputs: [boolPin('success', 'Success')],
        capability: _levelCap,
        tooltip: 'One undo step, or part of the open transaction\'s.'),
    function: (c, i) {
      final call = editorPanelCall(c);
      if (call == null) return {'success': false};
      final t = inTransform(i['transform']);
      final ok = call.host.transactions.edit(call.instance, () => call.host.vm.setActorTransformWithTransaction(inStr(i, 'actor_id'),
          location: t.location, rotation: t.rotation, scale: t.scale));
      return {'success': ok};
    },
  ),
  EditorLibraryNode(
    pureNode('editor_get_component_property', 'Get Component Property', _level,
        inputs: [strPin('actor_id', 'Actor Id'), strPin('component_type', 'Component Type'), strPin('property', 'Property')],
        outputs: [ret(LuminaPinType.json), boolPin('found', 'Found')]),
    function: (c, i) {
      final comp = _actor(c, i)?.components.where((x) => x.type == inStr(i, 'component_type')).firstOrNull;
      final key = inStr(i, 'property');
      return {'return_value': LuminaJsonBlueprintNodes.plain(comp?.properties[key]), 'found': comp?.properties.containsKey(key) ?? false};
    },
  ),
  EditorLibraryNode(
    impureNode('editor_set_component_property', 'Set Component Property', _level,
        inputs: [strPin('actor_id', 'Actor Id'), strPin('component_type', 'Component Type'), strPin('property', 'Property'), jsonPin('value', 'Value')],
        capability: _levelCap),
    function: (c, i) {
      final call = editorPanelCall(c);
      if (call != null) {
        call.host.transactions.edit(
            call.instance,
            () => call.host.vm.setComponentPropertyWithTransaction(
                inStr(i, 'actor_id'), inStr(i, 'component_type'), inStr(i, 'property'), i['value']));
      }
      return const {};
    },
  ),
  EditorLibraryNode(
    latentNode('editor_add_actor_from_asset', 'Add Actor From Asset', _level,
        inputs: [strPin('asset_path', 'Asset Path'), transformPin('transform', 'Transform'), strPin('label', 'Label')],
        results: [exec('completed', 'Completed'), exec('failed', 'Failed')],
        outputs: [strPin('actor_id', 'Actor Id'), strPin('error', 'Error')],
        capability: _levelCap,
        tooltip: 'Places the mesh or Blueprint asset in the open level; Completed gives the new actor\'s id.'),
    latent: (c, i, resume) {
      final call = editorPanelCall(c);
      if (call == null) return;
      final r = resumer(call.host, call.instance, resume);
      final vm = call.host.vm;
      final path = inStr(i, 'asset_path');
      final asset = vm.realAssets.where((a) => a.relativePath == path || a.lmasPath == path).firstOrNull;
      if (asset == null) {
        scheduleMicrotask(() => r('failed', {'error': "No asset '$path' in the project."}));
        return;
      }
      final t = inTransform(i['transform']);
      final label = inStr(i, 'label');
      final before = {for (final a in vm.actors) a.id};
      unawaited(call.host.transactions.edit(call.instance, () async {
        try {
          await vm.spawnActorFromAsset(asset, location: t.location);
          final added = vm.actors.where((a) => !before.contains(a.id)).firstOrNull;
          if (added == null) {
            r('failed', {'error': 'The asset could not be placed.'});
            return;
          }
          vm.setActorTransformWithTransaction(added.id, rotation: t.rotation, scale: t.scale);
          if (label.isNotEmpty) vm.renameActorWithTransaction(added.id, label);
          r('completed', {'actor_id': added.id});
        } on Object catch (e) {
          r('failed', {'error': '$e'});
        }
      }));
    },
  ),
  EditorLibraryNode(
    impureNode('editor_remove_actors', 'Remove Actors', _level, inputs: [idsPin('actor_ids', 'Actor Ids')], capability: _levelCap),
    function: (c, i) {
      final call = editorPanelCall(c);
      if (call != null) {
        call.host.transactions.edit(call.instance, () => call.host.vm.removeActorNodes(inIds(i, 'actor_ids'), label: 'Remove Actors'));
      }
      return const {};
    },
  ),
  EditorLibraryNode(
    impureNode('editor_focus_viewport_on_actors', 'Focus Viewport On Actors', _level, inputs: [idsPin('actor_ids', 'Actor Ids')]),
    function: (c, i) {
      final vm = editorPanelCall(c)?.host.vm;
      if (vm == null) return const {};
      final ids = inIds(i, 'actor_ids');
      final first = vm.actors.where((a) => ids.contains(a.id)).firstOrNull;
      if (first != null) {
        vm.focusCameraOnActor(first);
        vm.setActorSelection(ids, primaryId: first.id);
      }
      return const {};
    },
  ),
  EditorLibraryNode(
    latentNode('editor_save_level', 'Save Level', _level,
        results: [exec('completed', 'Completed'), exec('failed', 'Failed')], outputs: [strPin('error', 'Error')], capability: _levelCap),
    latent: (c, i, resume) {
      final call = editorPanelCall(c);
      if (call == null) return;
      final r = resumer(call.host, call.instance, resume);
      call.host.vm.saveLevelAndGenerateCode().then((_) => r('completed'), onError: (Object e) => r('failed', {'error': '$e'}));
    },
  ),

  // --- Transactions --------------------------------------------------------------
  EditorLibraryNode(
    impureNode('editor_begin_transaction', 'Begin Transaction', _transactions,
        inputs: [strPin('label', 'Label', 'Editor Panel Edit')],
        outputs: [ret(LuminaPinType.integer)],
        tooltip: 'Every level or asset edit until End Transaction is one Edit ▸ Undo step named Label. A transaction left '
            'open when the event finishes is ended by the editor (with a warning).'),
    function: (c, i) {
      final call = editorPanelCall(c);
      return {'return_value': call == null ? 0 : call.host.transactions.begin(call.instance, inStr(i, 'label'))};
    },
  ),
  EditorLibraryNode(
    impureNode('editor_end_transaction', 'End Transaction', _transactions, inputs: [intPin('transaction', 'Transaction')]),
    function: (c, i) {
      final call = editorPanelCall(c);
      call?.host.transactions.end(call.instance, (i['transaction'] as num?)?.toInt() ?? 0);
      return const {};
    },
  ),
  EditorLibraryNode(
    impureNode('editor_cancel_transaction', 'Cancel Transaction', _transactions,
        inputs: [intPin('transaction', 'Transaction')], tooltip: 'Ends the transaction and reverts its edits.'),
    function: (c, i) {
      final call = editorPanelCall(c);
      call?.host.transactions.cancel(call.instance, (i['transaction'] as num?)?.toInt() ?? 0);
      return const {};
    },
  ),
];

EditorActorNode? _actor(LuminaBlueprintCallContext c, Map<String, Object?> i) {
  final vm = editorPanelCall(c)?.host.vm;
  final id = inStr(i, 'actor_id');
  return vm?.actors.where((a) => a.id == id).firstOrNull;
}

/// `Barrel*` → a case-insensitive whole-string pattern; empty → null (all).
RegExp? _glob(String pattern) {
  if (pattern.trim().isEmpty) return null;
  final escaped = pattern.trim().split('*').map(RegExp.escape).join('.*');
  return RegExp('^$escaped\$', caseSensitive: false);
}
