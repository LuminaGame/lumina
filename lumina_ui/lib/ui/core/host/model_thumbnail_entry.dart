import 'dart:io';

import 'package:lumina_editor_data/lumina_editor.dart' show ModelThumbnailCommand;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/core/services/editor_scene_environment.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_graphics_preferences.dart';

/// `lumina_ui --lumina-thumbnail <input> <output.png> [--size <px>]`: the
/// editor executable renders one model file's thumbnail without a window
/// and exits ([ModelThumbnailCommand]). The file managers call it: the
/// Windows shell thumbnail provider and the Linux `.thumbnailer` the
/// installers register.
///
/// The runners start a windowless engine for the flag (as for a plugin
/// process), so no window flashes. The render uses the GPU the editor's
/// Graphics Device setting chose (then `FILAMENT_GPU`) and the studio IBL the
/// Content Browser's thumbnails are lit with.
Future<int> runModelThumbnailEntry(List<String> args) async {
  final parsed = ModelThumbnailCommand.parse(args);
  final request = parsed.request;
  if (request == null) {
    stderr.writeln(parsed.error);
    return ModelThumbnailCommand.exitUsage;
  }
  WidgetsFlutterBinding.ensureInitialized();
  try {
    EditorGraphicsPreferences().apply();
  } catch (e) {
    // An unreadable preferences file leaves the default device.
    stderr.writeln('Graphics device preference ignored: $e');
  }
  await EditorAssets.configure();
  final ibl = await EditorSceneEnvironment.ensureAssetsLoaded();
  return ModelThumbnailCommand.run(request, ibl: ibl, log: stderr.writeln);
}
