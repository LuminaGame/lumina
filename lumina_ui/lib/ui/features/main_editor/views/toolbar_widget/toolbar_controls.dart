part of '../toolbar_widget.dart';

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToolBtn({required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GhostButton(
        onPressed: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active ? EditorColors.primary.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: active ? Border.all(color: EditorColors.primary) : null,
          ),
          child: Icon(
            icon,
            size: 14,
            color: active ? EditorColors.primary : EditorColors.foreground,
          ),
        ),
      ),
    );
  }
}


class _SnapCluster extends StatelessWidget {
  final EditorViewModel vm;
  const _SnapCluster(this.vm);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SnapToggleWithMenu(
          key: const Key("toggle_translate_snap"),
          icon: LucideIcons.magnet,
          active: vm.translateSnapEnabled,
          onToggle: () => vm.updateTranslateSnapEnabled(!vm.translateSnapEnabled),
          value: vm.translateSnapStep,
          options: SnapService.translateSteps,
          format: SnapService.formatLength,
          onChanged: vm.updateTranslateSnapStep,
        ),
        _SnapToggleWithMenu(
          key: const Key("toggle_rotate_snap"),
          icon: LucideIcons.rotateCcw,
          active: vm.rotateSnapEnabled,
          onToggle: () => vm.updateRotateSnapEnabled(!vm.rotateSnapEnabled),
          value: vm.rotateSnapStep,
          options: SnapService.rotateSteps,
          onChanged: vm.updateRotateSnapStep,
        ),
        _SnapToggleWithMenu(
          key: const Key("toggle_scale_snap"),
          icon: LucideIcons.maximize2,
          active: vm.scaleSnapEnabled,
          onToggle: () => vm.updateScaleSnapEnabled(!vm.scaleSnapEnabled),
          value: vm.scaleSnapStep,
          options: SnapService.scaleSteps,
          onChanged: vm.updateScaleSnapStep,
        ),
        const VerticalDivider(width: 16),
        _GridPopover(key: const Key("toggle_grid_snap"), vm: vm),
      ],
    );
  }
}

class _SnapToggleWithMenu extends StatefulWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onToggle;
  final double value;
  final List<double> options;
  final ValueChanged<double> onChanged;

  /// How a step reads (e.g. with its unit); plain numbers by default.
  final String Function(double)? format;

  const _SnapToggleWithMenu({super.key,
    this.format,
    required this.icon,
    required this.active,
    required this.onToggle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_SnapToggleWithMenu> createState() => _SnapToggleWithMenuState();
}

class _SnapToggleWithMenuState extends State<_SnapToggleWithMenu> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolBtn(
          icon: widget.icon,
          active: widget.active,
          onTap: widget.onToggle,
        ),
        GestureDetector(
          key: _key,
          onTap: () {
            final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final offset = renderBox.localToGlobal(Offset.zero);
              final position = Offset(offset.dx, offset.dy + renderBox.size.height + 2);
              showDropdown(
                context: context,
                // An explicit position is where the menu opens; following the
                // anchor widget would drag it to that widget's bottom centre.
                follow: false,
                // Top-left corner at the point, as editor context menus open.
                alignment: Alignment.topLeft,
                anchorAlignment: Alignment.topLeft,
                position: position,
                builder: (context) => DropdownMenu(
                  children: widget.options.map((step) {
                    return MenuButton(
                      onPressed: (ctx) {
                        widget.onChanged(step);
                      },
                      trailing: widget.value == step ? const Icon(LucideIcons.check, size: 12) : null,
                      child: Text(widget.format?.call(step) ?? step.toString(), style: const TextStyle(fontSize: 10)),
                    );
                  }).toList(),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: EditorColors.cardHeader,
            ),
            child: Text(widget.format?.call(widget.value) ?? widget.value.toString(), style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _GridPopover extends StatefulWidget {
  final EditorViewModel vm;
  const _GridPopover({super.key, required this.vm});

  @override
  State<_GridPopover> createState() => _GridPopoverState();
}

class _GridPopoverState extends State<_GridPopover> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolBtn(
          icon: LucideIcons.layoutGrid,
          active: widget.vm.gridVisible,
          onTap: () => widget.vm.updateGridVisible(!widget.vm.gridVisible),
        ),
        GestureDetector(
          key: _key,
          onTap: () {
            final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final offset = renderBox.localToGlobal(Offset.zero);
              final position = Offset(offset.dx, offset.dy + renderBox.size.height + 2);
              showDropdown(
                context: context,
                // An explicit position is where the menu opens; following the
                // anchor widget would drag it to that widget's bottom centre.
                follow: false,
                // Top-left corner at the point, as editor context menus open.
                alignment: Alignment.topLeft,
                anchorAlignment: Alignment.topLeft,
                position: position,
                builder: (context) => DropdownMenu(
                  children: SnapService.gridSteps.map((step) {
                    return MenuButton(
                      onPressed: (ctx) {
                        widget.vm.updateGridStep(step);
                      },
                      trailing: widget.vm.editorGridStep == step ? const Icon(LucideIcons.check, size: 12) : null,
                      child: Text(SnapService.formatLength(step), style: const TextStyle(fontSize: 10)),
                    );
                  }).toList(),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: EditorColors.cardHeader,
            ),
            child: const Icon(LucideIcons.chevronDown, size: 10, color: EditorColors.mutedForeground),
          ),
        ),
      ],
    );
  }
}
