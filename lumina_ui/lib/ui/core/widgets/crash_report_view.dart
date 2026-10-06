import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../services/crash_report.dart';
import '../services/crash_reporter.dart';
import '../theme/editor_theme.dart';

/// Lays the crash report screen over the whole app while the reporter has a
/// pending report: an uncaught error while the editor runs, or a previous
/// session that never closed. The editor underneath keeps running.
class CrashReportOverlay extends StatelessWidget {
  const CrashReportOverlay({super.key, required this.reporter, required this.child});

  final CrashReporter reporter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CrashReport?>(
      valueListenable: reporter.pending,
      builder: (context, report, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (report != null)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xB3000000),
                  child: Center(
                    child: CrashReportView(
                      key: ValueKey('crash_report_${report.id}'),
                      report: report,
                      reporter: reporter,
                      onClose: reporter.dismiss,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The crash report screen: what happened, what would be sent, a place for
/// the user's own words and contact, and Send / Don't send / Copy. Nothing
/// leaves the machine before Send.
class CrashReportView extends StatefulWidget {
  const CrashReportView({super.key, required this.report, required this.reporter, required this.onClose});

  final CrashReport report;
  final CrashReporter reporter;
  final VoidCallback onClose;

  @override
  State<CrashReportView> createState() => _CrashReportViewState();
}

class _CrashReportViewState extends State<CrashReportView> {
  final _description = TextEditingController();
  final _email = TextEditingController();
  bool _includeLog = true;
  bool _showDetails = false;
  bool _sending = false;
  String? _sentId;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _sentId = widget.report.sentId;
  }

  @override
  void dispose() {
    _description.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _previousRun => widget.report.kind == CrashReportKind.previousRun;

  String get _text => widget.report.toText(description: _description.text, email: _email.text, includeLog: _includeLog);

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final receipt = await widget.reporter.send(widget.report, description: _description.text, email: _email.text, includeLog: _includeLog);
      if (!mounted) return;
      setState(() => _sentId = receipt.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendError = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final sent = _sentId != null;
    return Container(
      width: 640,
      constraints: const BoxConstraints(maxHeight: 720),
      decoration: BoxDecoration(
        color: EditorColors.card,
        border: Border.all(color: EditorColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: EditorColors.cardHeader,
            child: Row(
              children: [
                const Icon(LucideIcons.triangleAlert, size: 18, color: EditorColors.destructive),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _previousRun ? 'THE LAST SESSION ENDED UNEXPECTEDLY' : 'LUMINA STUDIO RAN INTO A PROBLEM',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: EditorColors.foreground),
                  ),
                ),
                Text(report.id, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _previousRun
                        ? 'Lumina Studio did not close properly last time. Sending a report with the end of the log helps find out why; the editor is ready to use.'
                        : 'An error nobody handled happened. The editor keeps running, but save your work soon. Sending a report helps fix it.',
                    style: const TextStyle(fontSize: 11, color: EditorColors.foreground),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: EditorColors.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: EditorColors.border),
                    ),
                    child: SelectableText(
                      report.headline,
                      key: const ValueKey('crash_headline'),
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: EditorColors.destructive),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('What happened? (optional)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                  const SizedBox(height: 4),
                  TextArea(
                    key: const ValueKey('crash_description'),
                    controller: _description,
                    enabled: !sent && !_sending,
                    placeholder: const Text('What were you doing just before? Steps that make it happen again are the most useful.'),
                    minLines: 3,
                    maxLines: 6,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  const Text('Contact e-mail (optional, only to ask back)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                  const SizedBox(height: 4),
                  TextField(
                    key: const ValueKey('crash_email'),
                    controller: _email,
                    enabled: !sent && !_sending,
                    placeholder: const Text('you@example.com'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: sent ? null : () => setState(() => _includeLog = !_includeLog),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Checkbox(
                        key: const ValueKey('crash_include_log'),
                        state: _includeLog ? CheckboxState.checked : CheckboxState.unchecked,
                        onChanged: sent ? null : (s) => setState(() => _includeLog = s == CheckboxState.checked),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Include the last ${report.logTail.length} lines of the editor log',
                        style: const TextStyle(fontSize: 11, color: EditorColors.foreground),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Button(
                        key: const ValueKey('crash_toggle_details'),
                        style: const ButtonStyle.ghost(),
                        onPressed: () => setState(() => _showDetails = !_showDetails),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_showDetails ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 11, color: EditorColors.mutedForeground),
                          const SizedBox(width: 4),
                          const Text('What is sent', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                        ]),
                      ),
                      const Spacer(),
                      Text(
                        'Sent to ${widget.reporter.serverUrl.host}. No project files, only the text below.',
                        style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                      ),
                    ],
                  ),
                  if (_showDetails) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      height: 220,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EditorColors.background,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EditorColors.border),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _text,
                          key: const ValueKey('crash_details_text'),
                          style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: EditorColors.secondaryForeground),
                        ),
                      ),
                    ),
                  ],
                  if (_sendError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Could not send: $_sendError\nThe report is kept at ${widget.reporter.fileOf(report).path}; Copy puts it on the clipboard.',
                      key: const ValueKey('crash_send_error'),
                      style: const TextStyle(fontSize: 10, color: EditorColors.destructive),
                    ),
                  ],
                  if (sent) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Thank you. The report was sent as $_sentId.',
                      key: const ValueKey('crash_sent'),
                      style: const TextStyle(fontSize: 10, color: EditorColors.chart3),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: EditorColors.border))),
            child: Row(
              children: [
                Button(
                  key: const ValueKey('crash_copy'),
                  style: const ButtonStyle.secondary(),
                  onPressed: () => Clipboard.setData(ClipboardData(text: _text)),
                  child: const Text('Copy report', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                if (!sent) ...[
                  Button(
                    key: const ValueKey('crash_dismiss'),
                    style: const ButtonStyle.secondary(),
                    onPressed: _sending ? null : widget.onClose,
                    child: const Text("Don't send", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    key: const ValueKey('crash_send'),
                    style: const ButtonStyle.primary(),
                    onPressed: _sending ? null : _send,
                    child: Text(_sending ? 'Sending...' : 'Send report', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ] else
                  Button(
                    key: const ValueKey('crash_continue'),
                    style: const ButtonStyle.primary(),
                    onPressed: widget.onClose,
                    child: const Text('Continue', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
