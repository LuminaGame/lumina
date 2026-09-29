import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../theme/editor_theme.dart';

class CurveField extends StatefulWidget {
  final Map<String, dynamic> value; // { 'keys': [[t,v], [t,v]], 'interpolation': 'linear' }
  final ValueChanged<Map<String, dynamic>> onCommit;

  const CurveField({
    super.key,
    required this.value,
    required this.onCommit,
  });

  @override
  State<CurveField> createState() => _CurveFieldState();
}

class _CurveFieldState extends State<CurveField> {
  void _openEditor() {
    // simplified curve editor logic here
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) {
        return AlertDialog(
          title: const Text('Curve Editor (Mini)', style: TextStyle(fontSize: 12)),
          content: SizedBox(
            width: 300,
            height: 200,
            child: _CurveEditorCanvas(
              initialValue: widget.value,
              onCommit: (val) {
                widget.onCommit(val);
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> keys = widget.value['keys'] ?? [];
    return GestureDetector(
      onTap: _openEditor,
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          // a drop shadow/scrim: black at 12%, not a surface
          color: const Color(0x1F000000),
          border: Border.all(color: EditorColors.mutedForeground),
          borderRadius: BorderRadius.circular(4),
        ),
        child: CustomPaint(
          painter: _CurveSparklinePainter(keys: keys),
        ),
      ),
    );
  }
}

class _CurveSparklinePainter extends CustomPainter {
  final List<dynamic> keys;

  _CurveSparklinePainter({required this.keys});

  @override
  void paint(Canvas canvas, Size size) {
    if (keys.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < keys.length; i++) {
      final point = keys[i];
      final t = point[0] as double;
      final v = point[1] as double;
      
      final x = t * size.width;
      final y = size.height - (v * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CurveSparklinePainter oldDelegate) {
    return oldDelegate.keys != keys;
  }
}

class _CurveEditorCanvas extends StatefulWidget {
  final Map<String, dynamic> initialValue;
  final ValueChanged<Map<String, dynamic>> onCommit;

  const _CurveEditorCanvas({required this.initialValue, required this.onCommit});

  @override
  State<_CurveEditorCanvas> createState() => _CurveEditorCanvasState();
}

class _CurveEditorCanvasState extends State<_CurveEditorCanvas> {
  late List<List<double>> _keys;

  @override
  void initState() {
    super.initState();
    final List<dynamic> initial = widget.initialValue['keys'] ?? [];
    _keys = initial.map((e) => [e[0] as double, e[1] as double]).toList();
  }

  void _addKey() {
    setState(() {
      _keys.add([1.0, 1.0]);
      _keys.sort((a, b) => a[0].compareTo(b[0]));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            // a drop shadow/scrim: black at 26%, not a surface
            color: const Color(0x42000000),
            child: CustomPaint(
              painter: _CurveSparklinePainter(keys: _keys),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PrimaryButton(
              onPressed: _addKey,
              child: const Text('Add Key'),
            ),
            PrimaryButton(
              onPressed: () {
                widget.onCommit({'keys': _keys, 'interpolation': 'linear'});
              },
              child: const Text('Save'),
            ),
          ],
        )
      ],
    );
  }
}
