import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:path/path.dart' as p;

import 'package:lumina_ui/ui/core/editor_panels/editor_library/editor_library.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

const String _assets = 'Editor|Assets';
const String _browser = 'Editor|Content Browser';
const String _assetsCap = 'assets';

/// Assets (reads need nothing; writes need `assets` and go through the
/// reference-safe asset operations) and the Content Browser.
final List<EditorLibraryNode> assetsLibraryNodes = [
  EditorLibraryNode(
    pureNode('editor_get_selected_assets', 'Get Selected Assets', _assets,
        outputs: [ret(LuminaPinType.array, elementType: LuminaPinType.string)], tooltip: 'The Content Browser selection (project-relative paths).'),
    function: (c, _) => {'return_value': editorPanelCall(c)?.host.vm.contentBrowserSelection.toList() ?? <String>[]},
  ),
  EditorLibraryNode(
    pureNode('editor_list_assets', 'List Assets', _assets,
        inputs: [strPin('folder', 'Folder', 'contents'), strPin('type_filter', 'Type Filter'), boolPin('recursive', 'Recursive', true)],
        outputs: [ret(LuminaPinType.array, elementType: LuminaPinType.string)],
        tooltip: 'Project-relative paths of the assets in Folder (Type Filter: an asset type such as StaticMesh, Texture, '
            'Material, Blueprint, Widget; empty: every type).'),
    function: (c, i) {
      final vm = editorPanelCall(c)?.host.vm;
      if (vm == null) return {'return_value': <String>[]};
      final folder = _rel(inStr(i, 'folder'));
      final types = assetTypesOf(inStr(i, 'type_filter'));
      final recursive = i['recursive'] != false;
      return {
        'return_value': [
          for (final a in vm.realAssets)
            if (_inFolder(a.relativePath, folder, recursive) && (types == null || types.contains(a.type))) a.relativePath,
        ]..sort(),
      };
    },
  ),
  EditorLibraryNode(
    pureNode('editor_get_asset_info', 'Get Asset Info', _assets,
        inputs: [strPin('asset_path', 'Asset Path')], outputs: [ret(LuminaPinType.json), boolPin('found', 'Found')],
        tooltip: '{"path", "name", "type", "size", "thumbnail"}: thumbnail is the asset path when it has one, else "".'),
    function: (c, i) {
      final a = _asset(editorPanelCall(c)?.host.vm, inStr(i, 'asset_path'));
      return {
        'return_value': a == null
            ? null
            : {
                'path': a.relativePath,
                'name': p.basenameWithoutExtension(a.fileName),
                'type': assetTypeName(a.type),
                'size': a.bytes,
                'thumbnail': a.thumbnailBytes == null ? '' : a.relativePath,
              },
        'found': a != null,
      };
    },
  ),
  EditorLibraryNode(
    impureNode('editor_open_asset_editor', 'Open Asset Editor', _assets, inputs: [strPin('asset_path', 'Asset Path')]),
    function: (c, i) {
      editorPanelCall(c)?.host.vm.openAssetEditorByPath(inStr(i, 'asset_path'));
      return const {};
    },
  ),
  _write('editor_rename_asset', 'Rename Asset', [strPin('new_name', 'New Name')], (vm, asset, i) async {
    final abs = asset.lmasPath!;
    final error = vm.renameAsset(abs, inStr(i, 'new_name'));
    if (error != null) throw StateError(error);
    return '${p.dirname(asset.relativePath)}/${inStr(i, 'new_name').trim()}.lmas';
  }),
  _write('editor_move_asset', 'Move Asset', [strPin('folder', 'Folder')], (vm, asset, i) async {
    final folder = _rel(inStr(i, 'folder'));
    vm.moveAsset(asset.lmasPath!, p.join(vm.projectDirPath, folder));
    return '$folder/${asset.fileName}';
  }),
  _write('editor_duplicate_asset', 'Duplicate Asset', const [], (vm, asset, i) async {
    final before = {for (final a in vm.realAssets) a.relativePath};
    vm.duplicateAsset(asset.lmasPath!);
    return vm.realAssets.map((a) => a.relativePath).where((r) => !before.contains(r)).firstOrNull ?? '';
  }),
  _write('editor_delete_asset', 'Delete Asset', const [], (vm, asset, i) async {
    await vm.deleteAssetsToTrash([asset]);
    return asset.relativePath;
  }),
  EditorLibraryNode(
    latentNode('editor_save_asset_json', 'Save Asset Json', _assets,
        inputs: [strPin('asset_path', 'Asset Path'), strPin('asset_type', 'Asset Type'), jsonPin('payload', 'Payload')],
        results: [exec('completed', 'Completed'), exec('failed', 'Failed')],
        outputs: [strPin('error', 'Error')],
        capability: _assetsCap,
        tooltip: 'Writes a .lmas of a known type under contents/ with Payload as its data, validated first (a Widget '
            'payload must parse as a designer document).'),
    latent: (c, i, resume) {
      final call = editorPanelCall(c);
      if (call == null) return;
      final r = resumer(call.host, call.instance, resume);
      final vm = call.host.vm;
      final rel = _rel(inStr(i, 'asset_path'));
      final types = assetTypesOf(inStr(i, 'asset_type'));
      final payload = i['payload'];
      String? why;
      if (!rel.startsWith('contents/') || !rel.endsWith('.lmas') || rel.contains('..')) {
        why = 'Asset Path must be a .lmas under contents/.';
      } else if (types == null || types.length != 1) {
        why = "Unknown asset type '${inStr(i, 'asset_type')}'.";
      } else if (payload is! Map) {
        why = 'Payload must be a Json object.';
      }
      if (why != null) {
        scheduleMicrotask(() => r('failed', {'error': why}));
        return;
      }
      final existing = _asset(vm, rel);
      final asset = LuminaAsset(
        assetId: existing?.assetId ?? 'epw_${DateTime.now().microsecondsSinceEpoch}',
        name: p.basenameWithoutExtension(rel),
        type: types!.single,
        rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(payload))),
      );
      unawaited(call.host.transactions.edit(call.instance, () async {
        try {
          await vm.extensionRegistry.saveAsset(relativePath: rel, bytes: asset.toProtoBufferBytes());
          r('completed');
        } on Object catch (e) {
          r('failed', {'error': '$e'});
        }
      }));
    },
  ),

  // --- Content Browser -------------------------------------------------------------
  EditorLibraryNode(
    impureNode('editor_sync_content_browser_to_asset', 'Sync Content Browser To Asset', _browser,
        inputs: [strPin('asset_path', 'Asset Path')]),
    function: (c, i) {
      final vm = editorPanelCall(c)?.host.vm;
      final a = _asset(vm, inStr(i, 'asset_path'));
      if (vm != null && a != null) vm.browseToAsset(a);
      return const {};
    },
  ),
  EditorLibraryNode(
    pureNode('editor_get_content_browser_folder', 'Get Content Browser Folder', _browser, outputs: [ret(LuminaPinType.string)]),
    function: (c, _) => {'return_value': editorPanelCall(c)?.host.vm.selectedFolder ?? 'contents'},
  ),
  EditorLibraryNode(
    impureNode('editor_show_content_drawer', 'Show Content Drawer', _browser),
    function: (c, _) {
      final vm = editorPanelCall(c)?.host.vm;
      if (vm != null && !vm.layoutState.bottomVisible) vm.toggleContentDrawer();
      return const {};
    },
  ),
];

/// A latent, reference-safe asset write: Completed (New Path) / Failed (Error).
EditorLibraryNode _write(String id, String title, List<LuminaBlueprintPinSpec> inputs,
        Future<String> Function(EditorViewModel vm, RealAssetInfo asset, Map<String, Object?> i) run) =>
    EditorLibraryNode(
      latentNode(id, title, _assets,
          inputs: [strPin('asset_path', 'Asset Path'), ...inputs],
          results: [exec('completed', 'Completed'), exec('failed', 'Failed')],
          outputs: [strPin('new_path', 'New Path'), strPin('error', 'Error')],
          capability: _assetsCap),
      latent: (c, i, resume) {
        final call = editorPanelCall(c);
        if (call == null) return;
        final r = resumer(call.host, call.instance, resume);
        final asset = _asset(call.host.vm, inStr(i, 'asset_path'));
        if (asset == null || asset.lmasPath == null) {
          scheduleMicrotask(() => r('failed', {'error': "No asset '${inStr(i, 'asset_path')}' in the project."}));
          return;
        }
        // After this event: the write runs on its own turn of the event loop.
        scheduleMicrotask(() async {
          try {
            final path = await call.host.transactions.edit(call.instance, () => run(call.host.vm, asset, i));
            r('completed', {'new_path': path});
          } on Object catch (e) {
            r('failed', {'error': e is StateError ? e.message : '$e'});
          }
        });
      },
    );

String _rel(String path) {
  var s = path.replaceAll(r'\', '/').trim();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s.isEmpty ? 'contents' : s;
}

bool _inFolder(String path, String folder, bool recursive) {
  if (!path.startsWith('$folder/')) return false;
  return recursive || !path.substring(folder.length + 1).contains('/');
}

RealAssetInfo? _asset(EditorViewModel? vm, String path) {
  if (vm == null) return null;
  final rel = _rel(path);
  return vm.realAssets.where((a) => a.relativePath == rel || a.lmasPath == path).firstOrNull;
}

/// The asset types a type filter names (`StaticMesh`, `staticMesh`,
/// `Texture`, `Blueprint`, `Widget`, …; comma-separated); null for none.
Set<AssetType>? assetTypesOf(String filter) {
  final names = [for (final s in filter.split(',')) s.trim().toLowerCase().replaceAll(' ', '')]..removeWhere((s) => s.isEmpty);
  if (names.isEmpty) return null;
  final out = <AssetType>{};
  for (final n in names) {
    for (final t in AssetType.values) {
      if (t.name.toLowerCase() == n || assetTypeName(t).toLowerCase() == n) out.add(t);
    }
  }
  return out;
}

/// The name a graph sees for [type] (`StaticMesh` for a filamesh).
String assetTypeName(AssetType type) => switch (type.name) {
      'filamesh' => 'StaticMesh',
      'filameshSk' => 'SkeletalMesh',
      'filamat' => 'Material',
      'actor' => 'Blueprint',
      final n => n[0].toUpperCase() + n.substring(1),
    };
