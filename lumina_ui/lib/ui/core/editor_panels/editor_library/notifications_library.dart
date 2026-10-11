import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_library/assets_library.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_library/editor_library.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

const String _notifications = 'Editor|Notifications';
const String _menus = 'Editor|Menus';
const String _picker = 'Editor|Asset Picker';

/// Notifications (toasts, progress, the Output Log, confirm dialogs), the
/// context menu and the asset picker. They show over the panel's own view.
final List<EditorLibraryNode> notificationsLibraryNodes = [
  EditorLibraryNode(
    impureNode('editor_show_toast', 'Show Toast', _notifications,
        inputs: [strPin('title', 'Title'), strPin('message', 'Message'), strPin('tone', 'Tone', 'info')],
        tooltip: 'Tone: info, success, warning or error.'),
    function: (c, i) {
      final call = editorPanelCall(c);
      if (call != null) _toast(call.host, call.instance, inStr(i, 'title'), inStr(i, 'message'), inStr(i, 'tone'));
      return const {};
    },
  ),
  EditorLibraryNode(
    impureNode('editor_show_progress', 'Show Progress', _notifications,
        inputs: [strPin('id', 'Id', 'progress'), strPin('text', 'Text'), floatPin('value', 'Value')],
        tooltip: 'Shows or updates progress bar Id at the bottom of the panel (Value 0–1; below 0: indeterminate).'),
    function: (c, i) {
      final call = editorPanelCall(c);
      if (call != null) {
        call.instance.progress[inStr(i, 'id')] = (text: inStr(i, 'text'), value: (i['value'] as num?)?.toDouble() ?? 0);
        call.host.panelChanged(call.instance);
      }
      return const {};
    },
  ),
  EditorLibraryNode(
    impureNode('editor_finish_progress', 'Finish Progress', _notifications, inputs: [strPin('id', 'Id', 'progress')]),
    function: (c, i) {
      final call = editorPanelCall(c);
      if (call != null && call.instance.progress.remove(inStr(i, 'id')) != null) call.host.panelChanged(call.instance);
      return const {};
    },
  ),
  EditorLibraryNode(
    impureNode('editor_log_to_output', 'Log To Output', _notifications,
        inputs: [strPin('message', 'Message'), strPin('level', 'Level', 'info'), strPin('source', 'Source')],
        tooltip: 'Level: info, success, warning or error. Source defaults to the panel\'s title.'),
    function: (c, i) {
      final call = editorPanelCall(c);
      if (call != null) {
        final source = inStr(i, 'source');
        call.host.vm.logger.log(inStr(i, 'message'),
            level: _level(inStr(i, 'level')), source: source.isEmpty ? 'Editor Panel ${call.instance.runtime.title}' : source);
      }
      return const {};
    },
  ),
  EditorLibraryNode(
    latentNode('editor_show_confirm_dialog', 'Show Confirm Dialog', _notifications,
        inputs: [strPin('title', 'Title'), strPin('message', 'Message'), strPin('confirm_label', 'Confirm Label', 'OK')],
        results: [exec('confirmed', 'Confirmed'), exec('cancelled', 'Cancelled')]),
    latent: (c, i, resume) {
      final call = editorPanelCall(c);
      if (call == null) return;
      final r = resumer(call.host, call.instance, resume);
      final context = call.instance.viewContext;
      if (context == null || !context.mounted) {
        scheduleMicrotask(() => r('cancelled'));
        return;
      }
      showOverlay<bool>(context, const DialogConfiguration(),
          builder: (ctx) => ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AlertDialog(
                  key: const ValueKey('editor_panel_confirm_dialog'),
                  title: Text(inStr(i, 'title')),
                  content: Text(inStr(i, 'message')),
                  actions: [
                    OutlineButton(
                        key: const ValueKey('editor_panel_confirm_cancel'),
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel')),
                    PrimaryButton(
                        key: const ValueKey('editor_panel_confirm_ok'),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(inStr(i, 'confirm_label'))),
                  ],
                ),
              )).future.then((ok) => r(ok == true ? 'confirmed' : 'cancelled'), onError: (_) => r('cancelled'));
    },
  ),

  // --- Menus ------------------------------------------------------------------------
  EditorLibraryNode(
    impureNode('editor_add_panel_menu_item', 'Add Panel Menu Item', _menus,
        inputs: [strPin('path', 'Path'), strPin('label', 'Label'), strPin('event_name', 'Event Name')],
        tooltip: 'Adds Label under the panel\'s plugin menu (Plugins/<Plugin>/<Path>); choosing it runs the panel\'s custom '
            'event Event Name. Removed with the panel.'),
    function: (c, i) {
      final call = editorPanelCall(c);
      if (call != null) call.host.addMenuItem(call.instance, inStr(i, 'path'), inStr(i, 'label'), inStr(i, 'event_name'));
      return const {};
    },
  ),
  EditorLibraryNode(
    latentNode('editor_show_context_menu', 'Show Context Menu', _menus,
        inputs: [jsonPin('items', 'Items')],
        results: [exec('chosen', 'Chosen'), exec('cancelled', 'Cancelled')],
        outputs: [strPin('item_id', 'Item Id')],
        tooltip: 'Items: a Json array of {"id", "label"} (or plain strings). Shown at the pointer over the panel.'),
    latent: (c, i, resume) {
      final call = editorPanelCall(c);
      if (call == null) return;
      final r = resumer(call.host, call.instance, resume);
      final context = call.instance.viewContext;
      final raw = i['items'];
      final items = <({String id, String label})>[
        if (raw is List)
          for (final e in raw)
            if (e is Map) (id: '${e['id'] ?? e['label']}', label: '${e['label'] ?? e['id']}') else (id: '$e', label: '$e'),
      ];
      if (context == null || !context.mounted || items.isEmpty) {
        scheduleMicrotask(() => r('cancelled'));
        return;
      }
      String? chosen;
      final box = context.findRenderObject() as RenderBox?;
      final at = call.instance.lastPointer ?? box?.localToGlobal(Offset.zero) ?? Offset.zero;
      showDropdown<void>(
        context: context,
        position: at,
        follow: false,
        alignment: Alignment.topLeft,
        anchorAlignment: Alignment.topLeft,
        builder: (ctx) => DropdownMenu(children: [
          for (final item in items)
            MenuButton(
              key: ValueKey('editor_panel_menu_${item.id}'),
              onPressed: (_) => chosen = item.id,
              child: Text(item.label, style: const TextStyle(fontSize: 11)),
            ),
        ]),
      ).future.then((_) => chosen == null ? r('cancelled') : r('chosen', {'item_id': chosen}),
          onError: (_) => r('cancelled'));
    },
  ),

  // --- Asset picker --------------------------------------------------------------
  EditorLibraryNode(
    latentNode('editor_pick_asset', 'Pick Asset', _picker,
        inputs: [strPin('type_filter', 'Type Filter')],
        results: [exec('picked', 'Picked'), exec('cancelled', 'Cancelled')],
        outputs: [strPin('asset_path', 'Asset Path')],
        tooltip: 'Opens the editor\'s asset picker popup over the panel (search, thumbnails, recents, Type Filter such '
            'as StaticMesh); Picked gives the chosen asset\'s path.'),
    latent: (c, i, resume) {
      final call = editorPanelCall(c);
      if (call == null) return;
      final r = resumer(call.host, call.instance, resume);
      final context = call.instance.viewContext;
      if (context == null || !context.mounted) {
        scheduleMicrotask(() => r('cancelled'));
        return;
      }
      final types = assetTypesOf(inStr(i, 'type_filter'));
      final previous = call.instance.pickRequest;
      if (previous != null && !previous.done.isCompleted) previous.done.complete(null);
      final done = Completer<String?>();
      call.instance.pickRequest = (types: types, done: done);
      call.host.panelChanged(call.instance);
      done.future.then((path) => path == null || path.isEmpty ? r('cancelled') : r('picked', {'asset_path': path}));
    },
  ),
];

String _level(String level) => switch (level.toLowerCase()) {
      'warn' || 'warning' => 'warning',
      'error' => 'error',
      'success' => 'success',
      _ => 'info',
    };

void _toast(EditorPanelHost host, EditorPanelInstance instance, String title, String message, String tone) {
  host.vm.logger.log(message.isEmpty ? title : '$title: $message', level: _level(tone), source: 'Editor Panel ${instance.runtime.title}');
  final context = instance.viewContext;
  if (context == null || !context.mounted) return;
  final color = switch (_level(tone)) {
    'error' => EditorColors.logError,
    'warning' => EditorColors.logWarning,
    'success' => EditorColors.logSuccess,
    _ => EditorColors.foreground,
  };
  showToast(
    context: context,
    location: ToastLocation.bottomRight,
    builder: (_, overlay) => SurfaceCard(
      key: const ValueKey('editor_panel_toast'),
      child: Basic(
        title: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        content: message.isEmpty ? null : Text(message, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
      ),
    ),
  );
}
