import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;

/// Writes a kernel plugin's package (no `flutter create`: it is pure Dart):
/// pubspec, analysis options, the process library and entry, and its
/// tests. The manifest, icon, README and pack script are the generator's
/// shared stages.
void writeKernelPluginPackage(
  Directory targetDir, {
  required String name,
  required String pascalName,
  required String friendlyName,
  required String description,
}) {
  void write(String rel, String content) => File(p.join(targetDir.path, rel))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  write(
    'pubspec.yaml',
    KernelPluginSources.pubspec(
      pluginName: name,
      description: description,
      engineRepo: LuminaWorkspace.engineRepo ?? kLuminaGitUrl,
      engineRef: LuminaWorkspace.engineCommit,
    ),
  );
  write('analysis_options.yaml', KernelPluginSources.analysisOptions);
  write('.gitignore', '.dart_tool/\nbuild/\n');
  write('lib/$name.dart', KernelPluginSources.library(name));
  write('lib/src/${name}_process.dart',
      KernelPluginSources.processSource(pluginName: name, pascalName: pascalName, friendlyName: friendlyName));
  write(KernelPluginSources.entryPath(name), KernelPluginSources.entry(pluginName: name, pascalName: pascalName));
  write('test/${name}_process_test.dart', KernelPluginSources.processTest(pluginName: name, pascalName: pascalName));
  write('test/architecture/process_entry_reach_test.dart', KernelPluginSources.reachTest(pluginName: name));
}
