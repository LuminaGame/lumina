import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../services/git_service.dart';
import '../../../core/theme/editor_theme.dart';

/// Colour per working-tree state (amber modified, green added/untracked,
/// red deleted, purple conflict, blue renamed).
Color sourceControlStateColor(GitFileState state) => switch (state) {
      GitFileState.modified => EditorColors.warning,
      GitFileState.added || GitFileState.untracked => EditorColors.chart3,
      GitFileState.deleted => EditorColors.destructive,
      GitFileState.conflicted => EditorColors.chart4,
      GitFileState.renamed => EditorColors.accent,
    };

/// Small corner badge (`M`, `A`, `?`, `D`, `R`, `C`) for one file state.
/// Renders nothing when [state] is null — which is also the git-absent path.
class SourceControlBadge extends StatelessWidget {
  final GitFileState? state;
  final String path;
  final double size;

  const SourceControlBadge({super.key, required this.state, required this.path, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) return const SizedBox.shrink();
    final color = sourceControlStateColor(s);
    return Tooltip(
      tooltip: (_) => TooltipContainer(child: Text('${s.description} · $path')),
      child: Container(
        key: ValueKey('sc_badge_$path'),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color, width: 1),
        ),
        child: Text(
          s.badgeLabel,
          style: TextStyle(fontSize: size * 0.6, fontWeight: FontWeight.bold, color: color, height: 1),
        ),
      ),
    );
  }
}

/// Overlays a [SourceControlBadge] on the top-right corner of [child]
/// (Content Browser tiles). Layout is untouched when [state] is null.
class SourceControlBadgeOverlay extends StatelessWidget {
  final GitFileState? state;
  final String path;
  final Widget child;

  const SourceControlBadgeOverlay({super.key, required this.state, required this.path, required this.child});

  @override
  Widget build(BuildContext context) {
    if (state == null) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(top: 3, right: 3, child: SourceControlBadge(state: state, path: path)),
      ],
    );
  }
}
