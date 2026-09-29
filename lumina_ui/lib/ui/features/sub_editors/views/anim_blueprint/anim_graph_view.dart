// design-token-exempt: node-graph painter colours (node headers, pose wires, the active-state glow) follow node-graph conventions, not the editor chrome palette.
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../../core/theme/editor_theme.dart';
import '../../view_models/anim_blueprint_editor_view_model.dart';

/// The AnimGraph: the state machine node feeding Output Pose, as lumina's
/// anim blueprint document defines it (the first state machine drives the
/// pose). Double-clicking the state machine opens it.
class AnimGraphOutputView extends StatefulWidget {
  final AnimBlueprintEditorViewModel viewModel;

  const AnimGraphOutputView({super.key, required this.viewModel});

  @override
  State<AnimGraphOutputView> createState() => _AnimGraphViewState();
}

class _AnimGraphViewState extends State<AnimGraphOutputView> {
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final machines = vm.document.stateMachines;
    return Container(
      color: EditorColors.graphCanvas,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _AnimGraphWirePainter(hasMachine: machines.isNotEmpty))),
          if (machines.isNotEmpty)
            Positioned(
              left: 80,
              top: 120,
              child: GestureDetector(
                key: const ValueKey('animgraph_state_machine'),
                onTap: () {
                  final now = DateTime.now();
                  if (now.difference(_lastTap) < const Duration(milliseconds: 400)) {
                    vm.open(AnimGraphLocation.stateMachine(machines.first.name));
                  }
                  _lastTap = now;
                },
                child: _node(
                  title: machines.first.name,
                  subtitle: 'State Machine · ${machines.first.states.length} states',
                  color: const Color(0xFF6A1B9A),
                  icon: LucideIcons.workflow,
                  output: true,
                  trailing: GhostButton(
                    key: const ValueKey('animgraph_open_machine'),
                    size: ButtonSize.xSmall,
                    onPressed: () => vm.open(AnimGraphLocation.stateMachine(machines.first.name)),
                    child: const Text('Open', style: TextStyle(fontSize: 9)),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 440,
            top: 120,
            child: _node(
              key: const ValueKey('animgraph_output_pose'),
              title: 'Output Pose',
              subtitle: vm.document.targetMesh.split('/').last.replaceAll('.lmas', ''),
              color: const Color(0xFF2E7D32),
              icon: LucideIcons.personStanding,
              output: false,
            ),
          ),
          const Positioned(
            right: 14,
            top: 10,
            child: IgnorePointer(
              child: Text('ANIMGRAPH',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0x22FFFFFF), letterSpacing: 1.5)),
            ),
          ),
          if (machines.length > 1)
            Positioned(
              left: 80,
              top: 220,
              child: Text('${machines.length - 1} more state machine(s) are ignored: only the first drives the pose.',
                  style: const TextStyle(fontSize: 10, color: EditorColors.warning)),
            ),
        ],
      ),
    );
  }

  Widget _node({
    Key? key,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool output,
    Widget? trailing,
  }) {
    return Container(
      key: key,
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xF0202226),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xDD000000)),
        // a drop shadow/scrim: black at 45%, not a surface
        boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 13, color: Colors.white),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                if (!output) const Icon(LucideIcons.personStanding, size: 12, color: Color(0xFFB0BEC5)),
                if (!output) const SizedBox(width: 6),
                Expanded(
                  child: Text(output ? subtitle : 'Result · $subtitle',
                      style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
                ),
                if (output) const Icon(LucideIcons.personStanding, size: 12, color: Color(0xFFB0BEC5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimGraphWirePainter extends CustomPainter {
  final bool hasMachine;
  _AnimGraphWirePainter({required this.hasMachine});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFF212327);
    for (var x = 0.0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (!hasMachine) return;
    const a = Offset(300, 170);
    const b = Offset(440, 170);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx + 60, a.dy, b.dx - 60, b.dy, b.dx, b.dy);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFB0BEC5)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _AnimGraphWirePainter oldDelegate) => oldDelegate.hasMachine != hasMachine;
}
