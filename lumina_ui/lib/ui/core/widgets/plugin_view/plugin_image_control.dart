import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../theme/editor_theme.dart';
import 'plugin_view_scope.dart';

/// [PluginControlKind.image]: a PNG/JPEG from `path` (an absolute file, or
/// one relative to the project) or from `base64` bytes, `height` (default
/// 160), fitted inside the box. Files are read asynchronously and large
/// base64 strings decoded on a background isolate; the box shows a loading
/// line meanwhile and a muted error line when the image cannot be read.
class PluginImageControl extends StatefulWidget {
  const PluginImageControl({super.key, required this.control});

  final PluginControl control;

  /// Base64 strings longer than this are decoded off the UI isolate.
  static const int inlineDecodeLimit = 64 * 1024;

  @override
  State<PluginImageControl> createState() => _PluginImageControlState();
}

class _PluginImageControlState extends State<PluginImageControl> {
  Uint8List? _bytes;
  String? _error;

  /// The source the bytes were loaded for (`path:` or `b64:` + identity).
  Object? _source;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first load needs the scope (the project directory resolves
    // relative paths), so it starts here rather than in initState.
    if (_source == null) _load();
  }

  @override
  void didUpdateWidget(PluginImageControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.control.string('path') != oldWidget.control.string('path') ||
        widget.control.string('base64') != oldWidget.control.string('base64')) {
      _load();
    }
  }

  String _resolve(String path) {
    if (File(path).isAbsolute) return path;
    final dir = PluginViewScope.of(context).projectDir;
    return dir == null ? path : '$dir/$path';
  }

  /// Starts loading the current source. Called before a build, so what is
  /// known at once is set directly; what arrives later goes through setState.
  void _load() {
    final c = widget.control;
    final path = c.string('path');
    final b64 = c.string('base64');
    if (path == null && b64 == null) {
      _source = '';
      _bytes = null;
      _error = 'no image';
      return;
    }
    final Object source = path != null ? 'path:$path' : 'b64:${b64!.length}:${b64.hashCode}';
    if (source == _source) return;
    _source = source;
    if (path == null && b64!.length <= PluginImageControl.inlineDecodeLimit) {
      try {
        _bytes = base64Decode(b64);
        _error = null;
      } on FormatException {
        _bytes = null;
        _error = 'invalid image data';
      }
      return;
    }
    _bytes = null;
    _error = null;
    final Future<Uint8List> pending =
        path != null ? File(_resolve(path)).readAsBytes() : Isolate.run(() => base64Decode(b64!));
    pending.then((bytes) {
      if (!mounted || _source != source) return;
      setState(() {
        _bytes = bytes;
        _error = null;
      });
    }, onError: (Object e) {
      if (!mounted || _source != source) return;
      setState(() {
        _bytes = null;
        _error = path != null ? 'cannot read $path' : 'invalid image data';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.control;
    final height = c.number('height')?.toDouble() ?? 160;
    const muted = TextStyle(fontSize: EditorTypography.captionSize, color: EditorColors.mutedForeground);
    final bytes = _bytes;
    final Widget content = bytes != null
        ? Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => const Center(child: Text('invalid image data', style: muted)),
          )
        : Center(child: Text(_error ?? 'loading…', style: muted));
    final box = Container(
      height: height,
      decoration: BoxDecoration(
        color: EditorColors.viewportBackdrop,
        border: Border.all(color: EditorColors.border),
        borderRadius: BorderRadius.circular(3),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
    return withPluginTooltip(c.tooltip, PluginFieldRow(label: c.label, alignTop: true, child: box));
  }
}
