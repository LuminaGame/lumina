import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../../core/theme/editor_theme.dart';
import '../../models/blueprint_compile_status.dart';

/// The toolbar's compile status badge with its states: Unknown (not
/// compiled this session), Dirty (edited since), Error, Warnings, Up to date.
class BlueprintCompileBadge extends StatelessWidget {
  final BlueprintCompileStatus status;

  const BlueprintCompileBadge({super.key, required this.status});

  static (IconData, Color) look(BlueprintCompileStatus status) => switch (status) {
        BlueprintCompileStatus.unknown => (LucideIcons.circleHelp, EditorColors.mutedForeground),
        BlueprintCompileStatus.dirty => (LucideIcons.circleDot, EditorColors.warning),
        BlueprintCompileStatus.error => (LucideIcons.circleX, EditorColors.destructive),
        BlueprintCompileStatus.warning => (LucideIcons.triangleAlert, EditorColors.warning),
        BlueprintCompileStatus.upToDate => (LucideIcons.circleCheck, EditorColors.logSuccess),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = look(status);
    return OutlineBadge(
      key: const ValueKey('bp_compile_badge'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(status.label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Compiler Results: one row per diagnostic of the last compile (severity,
/// node, message). Clicking a row that names a node selects and frames it.
class BlueprintCompilerResults extends StatelessWidget {
  final BlueprintCompileStatus status;
  final List<LuminaBlueprintDiagnostic> diagnostics;
  final String? Function(LuminaBlueprintDiagnostic diagnostic) nodeTitle;
  final ValueChanged<LuminaBlueprintDiagnostic> onSelect;

  const BlueprintCompilerResults({
    super.key,
    required this.status,
    required this.diagnostics,
    required this.nodeTitle,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final errors = diagnostics.where((d) => d.isError).length;
    final warnings = diagnostics.length - errors;
    final summary = switch (status) {
      BlueprintCompileStatus.unknown => 'Not compiled yet. Press Compile.',
      BlueprintCompileStatus.dirty => 'Edited since the last compile.',
      _ => diagnostics.isEmpty ? 'Compile complete: no errors or warnings.' : '$errors error(s), $warnings warning(s).',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.listChecks, size: 12, color: EditorColors.primary),
            const SizedBox(width: 6),
            const Text('COMPILER RESULTS',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.primary)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(summary,
                  key: const ValueKey('compiler_results_summary'),
                  style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            itemCount: diagnostics.length,
            itemBuilder: (context, i) {
              final d = diagnostics[i];
              final title = nodeTitle(d);
              return Clickable(
                key: ValueKey('compiler_row_$i'),
                onPressed: () => onSelect(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  color: i.isEven ? const Color(0x0DFFFFFF) : Colors.transparent, // zebra rows, as the Output Log
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(d.isError ? LucideIcons.circleX : LucideIcons.triangleAlert,
                          size: 11, color: d.isError ? EditorColors.destructive : EditorColors.warning),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 58,
                        child: Text(d.isError ? 'Error' : 'Warning',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: d.isError ? EditorColors.destructive : EditorColors.warning)),
                      ),
                      if (title != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text('[$title]',
                              style: const TextStyle(fontSize: 9, color: EditorColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      Expanded(
                        child: Text(d.message, style: const TextStyle(fontSize: 9, color: EditorColors.foreground)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
