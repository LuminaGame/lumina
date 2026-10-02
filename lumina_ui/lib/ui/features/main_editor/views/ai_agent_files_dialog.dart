import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/services/ai_agent_files.dart';

/// Installs the AI agent files into [projectDir] (see [AiAgentFiles]): the
/// skills always, `AGENTS.md` / `CLAUDE.md` when missing or unedited. When
/// the user edited one, [askReplace] decides whether it is replaced; without
/// it the edited documents are kept. The result is logged to the Output Log.
Future<AiAgentFilesReport> setUpAiAgentFiles({
  required String projectDir,
  required LuminaProject project,
  Future<bool> Function(List<String> editedDocs)? askReplace,
  AiAgentFiles? files,
}) async {
  final agentFiles = files ?? AiAgentFiles();
  var overwrite = false;
  if (askReplace != null) {
    final edited = await agentFiles.editedDocs(projectDir);
    if (edited.isNotEmpty) overwrite = await askReplace(edited);
  }
  final report = await agentFiles.install(projectDir, project, overwriteDocs: overwrite);
  EngineLoggerService().log(report.summary, source: 'AI Agent Files');
  return report;
}

/// Asks whether the edited [docs] are replaced by the editor's version
/// (true) or kept (false, also when the dialog is dismissed).
Future<bool> askReplaceEditedAgentDocs(BuildContext context, List<String> docs) async {
  final answer = await showOverlay<bool>(
    context,
    const DialogConfiguration(),
    builder: (ctx) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: AlertDialog(
        title: const Text('Replace edited agent files?'),
        content: Text(
          '${docs.join(', ')} in this project differ from what Lumina Studio wrote. '
          'Replace them with a fresh copy for this project, or keep yours? '
          'The skills are refreshed either way.',
        ),
        actions: [
          OutlineButton(
            key: const ValueKey('agent_files_keep'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep mine'),
          ),
          DestructiveButton(
            key: const ValueKey('agent_files_replace'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    ),
  ).future;
  return answer ?? false;
}

/// Tools → Set Up AI Agent Files...: installs into the open project, asks
/// about edited documents when [context] is given, and confirms with a
/// toast. A failure is logged as an error.
Future<void> runAiAgentFilesCommand(BuildContext? context, {required String projectDir, required LuminaProject project}) async {
  try {
    final ctx = context;
    final report = await setUpAiAgentFiles(
      projectDir: projectDir,
      project: project,
      askReplace: ctx == null ? null : (docs) => ctx.mounted ? askReplaceEditedAgentDocs(ctx, docs) : Future.value(false),
    );
    if (ctx != null && ctx.mounted) {
      showToast(
        context: ctx,
        location: ToastLocation.bottomRight,
        builder: (toastContext, overlay) => SurfaceCard(
          child: Basic(
            title: const Text('AI agent files set up'),
            content: Text(report.summary, key: const ValueKey('agent_files_toast')),
          ),
        ),
      );
    }
  } catch (e) {
    EngineLoggerService().log('Could not set up the AI agent files in $projectDir: $e',
        level: 'error', source: 'AI Agent Files');
  }
}
