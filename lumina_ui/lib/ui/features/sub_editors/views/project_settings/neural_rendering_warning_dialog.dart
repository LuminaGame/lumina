import 'dart:async';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaNeuralRendering;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/services/external_url.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// What the user must read before "Use OpenDLSS-NR" turns on, one statement
/// per line (also what the widget tests check).
const List<String> kNeuralRenderingWarningStatements = [
  'OpenDLSS-NR is a third-party, unofficial re-implementation of NVIDIA\'s DLSS 5 neural rendering. '
      'It is not made, endorsed or supported by NVIDIA or by Lumina.',
  'It needs NVIDIA\'s model weights, which Lumina does not provide and which may not be redistributed.',
  'Obtaining or using those weights may violate NVIDIA\'s licence terms. You are responsible for that.',
  'NVIDIA Ada or newer GPUs only. It is experimental and its output may be wrong (an upstream report shows '
      'wrong colours on an RTX 4080 laptop), and it costs a lot of GPU time.',
];

/// Shows the blocking OpenDLSS-NR warning; true when the user chose
/// "I understand, enable", false on Cancel or when the dialog was dismissed.
Future<bool> showNeuralRenderingWarning(BuildContext context) {
  final answer = Completer<bool>();
  void finish(BuildContext dialogContext, bool accepted) {
    Navigator.of(dialogContext).pop();
    if (!answer.isCompleted) answer.complete(accepted);
  }

  showOverlay(
    context,
    const DialogConfiguration(barrierDismissible: false),
    builder: (dialogContext) => NeuralRenderingWarningDialog(
      onCancel: () => finish(dialogContext, false),
      onAccept: () => finish(dialogContext, true),
    ),
  );
  return answer.future;
}

/// The OpenDLSS-NR warning: the statements, the upstream project page (for
/// its requirements) and the two choices.
class NeuralRenderingWarningDialog extends StatelessWidget {
  const NeuralRenderingWarningDialog({super.key, required this.onCancel, required this.onAccept});

  final VoidCallback onCancel;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final url = LuminaNeuralRendering.upstreamUrl;
    return AlertDialog(
      key: const ValueKey('neural_rendering_warning_dialog'),
      title: const Row(children: [
        Icon(LucideIcons.triangleAlert, size: 16, color: EditorColors.warning),
        SizedBox(width: 8),
        Text('Use OpenDLSS-NR (experimental, third-party)?'),
      ]),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final statement in kNeuralRenderingWarningStatements)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4, right: 8),
                    child: Icon(LucideIcons.dot, size: 12, color: EditorColors.mutedForeground),
                  ),
                  Expanded(child: Text(statement, style: const TextStyle(fontSize: 11, color: EditorColors.foreground))),
                ]),
              ),
            const SizedBox(height: 4),
            const Text('The upstream project page lists its requirements:',
                style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: SelectableText(url,
                    key: const ValueKey('neural_rendering_warning_url'),
                    style: const TextStyle(fontSize: 11, color: EditorColors.primary)),
              ),
              GhostButton(
                key: const ValueKey('neural_rendering_warning_open'),
                density: ButtonDensity.compact,
                onPressed: () => openExternalUrl(url),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.externalLink, size: 12),
                  SizedBox(width: 4),
                  Text('Open', style: TextStyle(fontSize: 10)),
                ]),
              ),
              GhostButton(
                key: const ValueKey('neural_rendering_warning_copy'),
                density: ButtonDensity.compact,
                onPressed: () => Clipboard.setData(ClipboardData(text: url)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.copy, size: 12),
                  SizedBox(width: 4),
                  Text('Copy', style: TextStyle(fontSize: 10)),
                ]),
              ),
            ]),
          ],
        ),
      ),
      actions: [
        OutlineButton(
          key: const ValueKey('neural_rendering_warning_cancel'),
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        DestructiveButton(
          key: const ValueKey('neural_rendering_warning_accept'),
          onPressed: onAccept,
          child: const Text('I understand, enable'),
        ),
      ],
    );
  }
}
