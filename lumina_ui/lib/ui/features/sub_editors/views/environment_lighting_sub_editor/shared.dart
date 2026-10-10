part of '../environment_lighting_sub_editor.dart';

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground));

Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged, Key key) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 9, color: EditorColors.foreground)),
      Switch(key: key, value: value, onChanged: onChanged),
    ],
  );
}

Color _toColor(Vector3 rgb) => Color.fromARGB(
      255,
      (rgb.x.clamp(0.0, 1.0) * 255).round(),
      (rgb.y.clamp(0.0, 1.0) * 255).round(),
      (rgb.z.clamp(0.0, 1.0) * 255).round(),
    );
