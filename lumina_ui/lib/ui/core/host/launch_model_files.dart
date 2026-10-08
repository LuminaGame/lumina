import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show ModelFileThumbnailer;
import 'package:path/path.dart' as p;

/// Model files Lumina Studio was started with: a file manager's "Open with"
/// on a `.glb`, `.gltf`, `.fbx` or `.obj` passes the path as an argument
/// (the installers register the editor for those types), and a hand-off to a
/// project editor passes them on as `--import <path>`.
///
/// A loose file has no project, so the launcher asks for one
/// (`PendingModelImportBanner`); the editor that opens the project imports
/// [pending] through its import queue and opens the first in its sub-editor
/// (`importLaunchModelFiles`).
abstract final class LaunchModelFiles {
  static const String importFlag = '--import';

  /// Editor flags followed by a value that is not a model file to import.
  static const Set<String> _flagsWithValue = {'--project', '--launcher-exe', '--size'};

  /// The files still to import, absolute; emptied by [take] or by the
  /// launcher's "Don't import".
  static final ValueNotifier<List<String>> pending = ValueNotifier(const []);

  /// The model files in [args] that exist: every positional argument and
  /// every `--import <path>` / `--import=<path>` naming a supported model
  /// file (any case of extension), absolute, each once, in order.
  static Future<List<String>> resolve(List<String> args) async {
    final candidates = <String>[];
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      if (a == importFlag) {
        if (i + 1 < args.length) candidates.add(args[++i]);
      } else if (a.startsWith('$importFlag=')) {
        candidates.add(a.substring(importFlag.length + 1));
      } else if (_flagsWithValue.contains(a)) {
        i++;
      } else if (!a.startsWith('-')) {
        candidates.add(a);
      }
    }
    final files = <String>[];
    for (final c in candidates) {
      if (!ModelFileThumbnailer.supports(c)) continue;
      final path = p.normalize(File(c).absolute.path);
      if (files.contains(path) || !await File(path).exists()) continue;
      files.add(path);
    }
    return files;
  }

  /// `--import <path>` for each of [files]: what a hand-off appends so the
  /// next editor imports them.
  static List<String> handOffArguments(List<String> files) => [
        for (final f in files) ...[importFlag, f],
      ];

  /// The pending files, once: the list is empty afterwards.
  static List<String> take() {
    final files = pending.value;
    pending.value = const [];
    return files;
  }
}
