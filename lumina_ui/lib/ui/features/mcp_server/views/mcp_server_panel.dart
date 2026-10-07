import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/views/mcp_tool_catalogue.dart';

/// Tools → AI Agent Access (MCP): the on/off switch for the editor's MCP
/// server, its status and port, the exact registration commands with copy
/// buttons, and the calls agents made.
class McpServerPanel extends StatefulWidget {
  const McpServerPanel({super.key, required this.service, this.onClose});

  final McpServerService service;
  final VoidCallback? onClose;

  @override
  State<McpServerPanel> createState() => _McpServerPanelState();
}

class _McpServerPanelState extends State<McpServerPanel> {
  bool _revealToken = false;
  String? _copied;

  McpServerService get service => widget.service;

  String _masked(String command) {
    if (_revealToken || service.token.isEmpty) return command;
    final token = service.token;
    final tail = token.length > 6 ? token.substring(token.length - 6) : token;
    return command.replaceAll(token, '…$tail');
  }

  Future<void> _copy(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = label);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // A job's state changes repaint its Recent calls row.
      listenable: Listenable.merge([service, service.settings, service.jobs]),
      builder: (context, _) {
        final running = service.isRunning;
        final status = running
            ? 'LISTENING'
            : service.lastError != null
                ? 'FAILED'
                : 'STOPPED';
        final statusColor = running
            ? EditorColors.logSuccess
            : service.lastError != null
                ? EditorColors.destructive
                : EditorColors.mutedForeground;
        return Container(
          color: EditorColors.background,
          child: ListView(
            key: const ValueKey('mcp_server_panel_scroll'),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.bot, size: 16, color: EditorColors.primary),
                  const SizedBox(width: 8),
                  const Text('AI AGENT ACCESS (MCP)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground, letterSpacing: 0.8)),
                  const Spacer(),
                  if (widget.onClose != null)
                    GhostButton(onPressed: widget.onClose, child: const Icon(LucideIcons.x, size: 12)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'A Model Context Protocol server inside this editor lets an AI agent (Claude Code or any MCP client) '
                'operate the level, assets, materials, Blueprints and Play the way you do: every change is an undo '
                'step and shows here live.',
                style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
              ),
              const SizedBox(height: 16),
              _section('Server', [
                _row(
                  'Allow AI agents to operate this editor',
                  Switch(
                    key: const ValueKey('mcp_server_enabled'),
                    value: service.settings.enabled,
                    onChanged: (value) {
                      service.settings.setEnabled(value);
                      service.applySettings();
                    },
                  ),
                  help: 'Starts the MCP server when the editor opens a project. Saved for this user in '
                      '${service.settings.file.path}.',
                ),
                // The risk ceiling, the approval chain's first policy.
                _row(
                  'External agents may run',
                  Select<McpToolRisk>(
                    key: const ValueKey('mcp_max_risk'),
                    value: service.settings.maxRisk,
                    onChanged: (value) {
                      if (value != null) service.settings.setMaxRisk(value);
                    },
                    itemBuilder: (context, item) => Text(_ceilingLabel(item), style: const TextStyle(fontSize: 10.5)),
                    popup: SelectPopup(
                      items: SelectItemList(children: [
                        for (final r in const [McpToolRisk.external, McpToolRisk.mutating, McpToolRisk.editorState])
                          SelectItemButton(
                            key: ValueKey('mcp_max_risk_${r.name}'),
                            value: r,
                            child: Text(_ceilingLabel(r), style: const TextStyle(fontSize: 10.5)),
                          ),
                      ]),
                    ).call,
                  ),
                  help: 'Tools above this are neither listed to agents nor run (the call is refused and shows in '
                      'Recent calls). Look only: read, select, move the camera, screenshot, Play. Applies at once.',
                ),
                _row(
                  'Status',
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(status,
                          key: const ValueKey('mcp_server_status'),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                      if (running) ...[
                        const SizedBox(width: 10),
                        Text(service.url!,
                            key: const ValueKey('mcp_server_url'),
                            style: const TextStyle(fontSize: 10, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground)),
                      ],
                      if (service.lastError != null) ...[
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(service.lastError!,
                              style: const TextStyle(fontSize: 10, color: EditorColors.destructive)),
                        ),
                      ],
                    ],
                  ),
                  help: running
                      ? 'Bound to 127.0.0.1 only; port ${service.port}'
                          '${service.onFallbackPort ? ' (port ${service.settings.port} was taken, so an ephemeral port is in use; the stdio bridge always finds it)' : ''}. '
                          '${service.sessionCount} session(s), ${service.requestCount} request(s) this run.'
                      : 'Turn the switch on to start the server.',
                ),
                _row(
                  'Connection file',
                  Text(service.connectionFile.path,
                      key: const ValueKey('mcp_server_connection_file'),
                      style: const TextStyle(fontSize: 10, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground)),
                  help: 'Port and bearer token, readable by this user only (mode 600); written on start, deleted on stop.',
                ),
                _row(
                  'Bearer token',
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        !running
                            ? '—'
                            : _revealToken
                                ? service.token
                                : '…${service.token.substring(service.token.length - 6)}',
                        style: const TextStyle(fontSize: 10, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground),
                      ),
                      const SizedBox(width: 6),
                      GhostButton(
                        key: const ValueKey('mcp_server_reveal_token'),
                        onPressed: running ? () => setState(() => _revealToken = !_revealToken) : null,
                        child: Icon(_revealToken ? LucideIcons.eyeOff : LucideIcons.eye, size: 12),
                      ),
                      const SizedBox(width: 6),
                      OutlineButton(
                        key: const ValueKey('mcp_server_regenerate_token'),
                        onPressed: running ? service.regenerateToken : null,
                        child: const Text('Regenerate token', style: TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                  help: 'One token per editor session. Regenerating it invalidates every registered client until it is re-registered.',
                ),
              ]),
              const SizedBox(height: 16),
              _section('Connect Claude Code', [
                _commandRow(
                  'HTTP (recommended)',
                  running ? service.httpRegistrationCommand! : 'Start the server to get the command.',
                  enabled: running,
                  keyName: 'http',
                  help: 'Registers this editor as a Streamable HTTP MCP server. The token changes every editor session; '
                      're-run the command (or use the stdio bridge, which never changes) after a restart.',
                ),
                _commandRow(
                  'stdio bridge',
                  service.stdioRegistrationCommand,
                  enabled: true,
                  keyName: 'stdio',
                  help: 'For clients that only launch stdio servers. The bridge reads the connection file, so it '
                      'works across restarts, port changes and token regeneration.',
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Other MCP clients: POST JSON-RPC 2.0 to the URL above with "Authorization: Bearer <token>" '
                    '(Streamable HTTP, protocol 2025-06-18). Tools: tools/list.',
                    style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _section('Recent calls', [
                if (service.recentCalls.isEmpty)
                  const Text('No tool calls yet.', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground))
                else
                  for (final (i, call) in service.recentCalls.indexed)
                    Padding(
                      key: ValueKey('mcp_recent_call_$i'),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(call.ok ? LucideIcons.circleCheck : (call.denied ? LucideIcons.ban : LucideIcons.circleX),
                              size: 10, color: call.ok ? EditorColors.logSuccess : EditorColors.destructive),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 78,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: call.risk == null ? const SizedBox.shrink() : McpRiskBadge(call.risk!),
                            ),
                          ),
                          SizedBox(
                            width: 170,
                            child: call.detail == null
                                ? Text(call.tool,
                                    style: const TextStyle(fontSize: 10, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground))
                                // A file tool's path and snapshot id.
                                : Tooltip(
                                    tooltip: (context) => TooltipContainer(child: Text(call.detail!)),
                                    child: Text(call.tool,
                                        key: ValueKey('mcp_recent_call_detail_$i'),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontFamily: EditorTypography.monoFamily,
                                            color: EditorColors.foreground,
                                            decoration: TextDecoration.underline,
                                            decorationStyle: TextDecorationStyle.dotted)),
                                  ),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(call.client,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text('${call.duration.inMilliseconds} ms',
                                style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                          ),
                          // The job the call started, and its state now.
                          if (call.jobId != null)
                            Container(
                              key: ValueKey('mcp_recent_call_job_$i'),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: EditorColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text('${call.jobId} · ${service.jobs.byId(call.jobId!)?.state.name ?? 'expired'}',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: EditorColors.primary)),
                            ),
                          if (call.denied)
                            Tooltip(
                              tooltip: (context) => TooltipContainer(child: Text(call.deniedReason!)),
                              child: Container(
                                key: ValueKey('mcp_recent_call_denied_$i'),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: EditorColors.destructive.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text('denied',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: EditorColors.destructive)),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              call.error ?? _time(call.started),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: call.ok ? EditorColors.mutedForeground : EditorColors.destructive),
                            ),
                          ),
                        ],
                      ),
                    ),
              ]),
              const SizedBox(height: 16),
              _section('Trash', [_trashRow(context)]),
              const SizedBox(height: 16),
              _section('Tool catalogue', [
                McpToolCatalogue(key: const ValueKey('mcp_tool_catalogue'), registry: service.tools),
              ]),
              const SizedBox(height: 16),
              _section('Security', [
                const Text(
                  '• The server listens on 127.0.0.1 only; nothing outside this machine can reach it.\n'
                  '• Every request needs the bearer token; the token file is readable by your user only.\n'
                  '• Everything an agent does goes through the editor\'s own commands: it is undoable and logged in the Output Log.',
                  style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground, height: 1.5),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  static String _ceilingLabel(McpToolRisk r) => switch (r) {
        McpToolRisk.editorState => 'Look only',
        McpToolRisk.mutating => 'Edits, but nothing destructive',
        _ => 'Everything',
      };

  static String _bytes(int b) => b >= 1 << 20
      ? '${(b / (1 << 20)).toStringAsFixed(1)} MB'
      : b >= 1 << 10
          ? '${(b / (1 << 10)).toStringAsFixed(1)} KB'
          : '$b B';

  /// What deleted assets occupy in the project trash; only
  /// the user can empty it.
  Widget _trashRow(BuildContext context) {
    final trash = service.viewModel.projectTrash;
    final count = trash.list().length;
    return Row(children: [
      Expanded(
        child: Text('$count items · ${_bytes(trash.sizeBytes)} in .lumina/trash',
            key: const ValueKey('mcp_trash_summary'),
            style: const TextStyle(fontSize: 10.5, color: EditorColors.foreground)),
      ),
      DestructiveButton(
        key: const ValueKey('mcp_empty_trash'),
        onPressed: count == 0 ? null : () => _confirmEmptyTrash(context),
        child: const Text('Empty trash…', style: TextStyle(fontSize: 10)),
      ),
    ]);
  }

  void _confirmEmptyTrash(BuildContext context) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (ctx) => AlertDialog(
        key: const ValueKey('mcp_empty_trash_dialog'),
        title: const Text('Empty the project trash?'),
        content: const Text('Deleted assets in .lumina/trash are erased for good; restore_asset and undo can no '
            'longer bring them back.'),
        actions: [
          GhostButton(onPressed: () => closeOverlay(ctx), child: const Text('Cancel')),
          DestructiveButton(
            key: const ValueKey('mcp_empty_trash_confirm'),
            onPressed: () async {
              closeOverlay(ctx);
              await service.viewModel.projectTrash.empty();
              if (mounted) setState(() {});
            },
            child: const Text('Empty trash'),
          ),
        ],
      ),
    );
  }

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  Widget _commandRow(String label, String command, {required bool enabled, required String keyName, String? help}) {
    final copied = _copied == keyName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: EditorColors.card,
                    border: Border.all(color: EditorColors.border),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: SelectableText(
                    _masked(command),
                    key: ValueKey('mcp_server_command_$keyName'),
                    style: const TextStyle(fontSize: 10, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              OutlineButton(
                key: ValueKey('mcp_server_copy_$keyName'),
                onPressed: enabled ? () => _copy(keyName, command) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(copied ? LucideIcons.check : LucideIcons.copy, size: 11),
                    const SizedBox(width: 4),
                    Text(copied ? 'Copied' : 'Copy', style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          if (help != null) ...[
            const SizedBox(height: 3),
            Text(help, style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EditorColors.card,
          border: Border.all(color: EditorColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Widget _row(String label, Widget control, {String? help}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 220,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(label, style: const TextStyle(fontSize: 10.5, color: EditorColors.foreground)),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  control,
                  if (help != null) ...[
                    const SizedBox(height: 3),
                    Text(help, style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}
