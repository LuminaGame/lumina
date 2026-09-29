part of '../details_widget.dart';

/// Adds the Light component to a legacy light actor after the frame, so the
/// section appears without mutating the level during build.
class _LightComponentSeeder extends StatefulWidget {
  const _LightComponentSeeder({required this.viewModel, required this.actorId});
  final EditorViewModel viewModel;
  final String actorId;

  @override
  State<_LightComponentSeeder> createState() => _LightComponentSeederState();
}

class _LightComponentSeederState extends State<_LightComponentSeeder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.viewModel.ensureLightComponent(widget.actorId);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Adds the LuminaSkyComponent to a legacy environment actor after the frame, so the
/// section appears without mutating the level during build.
class _SkyComponentSeeder extends StatefulWidget {
  const _SkyComponentSeeder({required this.viewModel, required this.actorId});
  final EditorViewModel viewModel;
  final String actorId;

  @override
  State<_SkyComponentSeeder> createState() => _SkyComponentSeederState();
}

class _SkyComponentSeederState extends State<_SkyComponentSeeder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.viewModel.ensureSkyComponent(widget.actorId);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _CategoryHeader extends StatelessWidget {
  final String title;

  const _CategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    // The prototype's collapsible Section header: `h-7 px-2 gap-1.5
    // bg-[oklch(0.105 0 0)]` with a `text-[10px] font-semibold uppercase
    // tracking-widest text-muted-foreground` label.
    return Container(
      height: EditorDensity.panelHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: EditorDensity.gutter),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          const Icon(LucideIcons.chevronDown,
              size: 12, color: EditorColors.mutedForeground),
          const SizedBox(width: 6),
          Text(
            title,
            style: EditorTypography.panelHeading,
          ),
        ],
      ),
    );
  }
}

class _MobilityBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MobilityBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Compact padding and a one-line label that scales down: the Details
    // panel is ~210 px wide by default.
    return Button(
      style: active
          ? const ButtonStyle.primary(density: ButtonDensity.compact)
          : const ButtonStyle.secondary(density: ButtonDensity.compact),
      onPressed: onTap,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
