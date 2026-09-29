// Builds an MSIX package of Lumina Studio.
// Run through tool/package-windows.sh (or `dart run tool/package_windows.dart`
// from lumina_ui/); `--help` lists the options.
import 'dart:io';

import 'package:lumina_ui/tooling/windows_packaging/windows_packaging.dart';

Future<void> main(List<String> args) async {
  // lumina_ui/ (tool/package-windows.sh runs from there).
  final fromScript = Platform.script.scheme == 'file' ? File.fromUri(Platform.script).parent.parent.path : null;
  final packageRoot = fromScript != null && File('$fromScript/pubspec.yaml').existsSync() ? fromScript : Directory.current.path;
  final code = await runPackageWindows(
    args,
    PackagingContext(
      packageRoot: packageRoot,
      environment: Platform.environment,
      out: stdout,
      err: stderr,
    ),
  );
  await stdout.flush();
  await stderr.flush();
  exit(code);
}
