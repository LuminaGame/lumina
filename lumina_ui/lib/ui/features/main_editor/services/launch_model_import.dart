import 'package:lumina_ui/ui/core/host/launch_model_files.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// Imports the model files Lumina Studio was started with
/// ([LaunchModelFiles.pending], taken once) into [viewModel]'s project
/// through the background import queue, as the Import dialog does
/// (auto-organised under `contents/`), then opens the first imported asset
/// in its sub-editor. Failures are reported by the import panel and the
/// Output Log like any import. Does nothing when no file waits.
Future<void> importLaunchModelFiles(EditorViewModel viewModel) async {
  final files = LaunchModelFiles.take();
  if (files.isEmpty) return;
  viewModel.logger.log(
    'Importing ${files.length == 1 ? files.single : '${files.length} files'} opened with Lumina Studio',
    level: 'info',
    source: 'Import',
  );
  final results = await viewModel.importAssetFiles(files);
  for (final r in results) {
    final path = r.result?.lmasPath;
    if (path != null) {
      viewModel.openAssetEditorByPath(path);
      return;
    }
  }
}
