part of '../engine_bootstrap.dart';

/// The prebuilt Filament, OpenRigLogic and Jolt Physics links, `flutter pub get` and
/// deleting a checkout.
extension _EngineBootstrapArtifacts on EngineBootstrap {
  // ---------------------------------------------------------------------------
  // Filament

  String _filamentVersion() {
    final file = File(p.join(checkoutDir.path, 'tool', 'filament', 'VERSION'));
    if (!file.existsSync()) {
      throw EngineBootstrapException('The engine source has no tool/filament/VERSION: it does not say which Filament build it needs.',
          step: EngineBootstrapStep.filament);
    }
    final v = file.readAsStringSync().trim();
    if (v.isEmpty) throw const EngineBootstrapException('tool/filament/VERSION is empty.', step: EngineBootstrapStep.filament);
    return v;
  }

  Future<String> _ensureFilament(String filamentVersion, void Function(EngineBootstrapEvent) emit) async {
    const step = EngineBootstrapStep.filament;
    final FilamentProvider provider = filament ?? EngineBootstrap.defaultFilamentProvider ?? FilamentPrebuilt.ensure;
    emit(EngineBootstrapProgress(step, 'Filament $filamentVersion', fraction: 0));
    final Directory dir;
    try {
      dir = await provider(
        version: filamentVersion,
        releaseTag: version,
        cacheRoot: filamentRoot,
        onProgress: (fraction, message) => emit(EngineBootstrapProgress(step, message, fraction: fraction)),
      );
    } on EngineBootstrapException {
      rethrow;
    } catch (e) {
      throw EngineBootstrapException('Could not get the prebuilt Filament $filamentVersion: $e', step: step);
    }
    final target = p.normalize(dir.absolute.path);
    if (!Directory(target).existsSync()) {
      throw EngineBootstrapException('The prebuilt Filament $filamentVersion is missing at $target.', step: step);
    }
    await _link(EngineBootstrap.filamentLink, target, step);
    emit(EngineBootstrapLog(step, 'Linked ${p.join(checkoutDir.path, EngineBootstrap.filamentLink)} -> $target'));
    emit(EngineBootstrapProgress(step, 'Filament $filamentVersion ready', fraction: 1));
    return target;
  }

  // ---------------------------------------------------------------------------
  // OpenRigLogic

  /// Links the release's prebuilt OpenRigLogic as `<checkout>/openriglogic`:
  /// flutter_riglogic comes from git (the pub cache), where its hook finds no
  /// built library, so the root pubspec's `riglogic_lib_dir` names
  /// `openriglogic/lib`.
  Future<String> _ensureOpenRigLogic(void Function(EngineBootstrapEvent) emit) async {
    const step = EngineBootstrapStep.openriglogic;
    final OpenRigLogicProvider provider = openriglogic ?? EngineBootstrap.defaultOpenRigLogicProvider ?? OpenRigLogicPrebuilt.ensure;
    emit(const EngineBootstrapProgress(step, 'OpenRigLogic', fraction: 0));
    final Directory dir;
    try {
      dir = await provider(
        releaseTag: version,
        cacheRoot: openriglogicRoot,
        onProgress: (fraction, message) => emit(EngineBootstrapProgress(step, message, fraction: fraction)),
      );
    } on EngineBootstrapException {
      rethrow;
    } catch (e) {
      throw EngineBootstrapException('Could not get the prebuilt OpenRigLogic of $version: $e', step: step);
    }
    final target = p.normalize(dir.absolute.path);
    if (!Directory(target).existsSync()) {
      throw EngineBootstrapException('The prebuilt OpenRigLogic of $version is missing at $target.', step: step);
    }
    await _link(EngineBootstrap.openriglogicLink, target, step);
    emit(EngineBootstrapLog(step, 'Linked ${p.join(checkoutDir.path, EngineBootstrap.openriglogicLink)} -> $target'));
    emit(const EngineBootstrapProgress(step, 'OpenRigLogic ready', fraction: 1));
    return target;
  }

  // ---------------------------------------------------------------------------
  // Jolt Physics

  /// Links the release's prebuilt Jolt Physics as `<checkout>/jolt`:
  /// flutter_jolt comes from git (the pub cache), where its hook finds no
  /// Jolt build, so the root pubspec's `jolt_dir` names `jolt`. Jolt is
  /// optional: a release without the archive (or a failed download) leaves
  /// no link and returns '' — the hook then builds no Jolt and the engine
  /// runs its Dart physics.
  Future<String> _ensureJolt(void Function(EngineBootstrapEvent) emit) async {
    const step = EngineBootstrapStep.jolt;
    final JoltProvider provider = jolt ?? EngineBootstrap.defaultJoltProvider ?? JoltPrebuilt.ensure;
    emit(const EngineBootstrapProgress(step, 'Jolt Physics', fraction: 0));
    try {
      final dir = await provider(
        releaseTag: version,
        cacheRoot: joltRoot,
        onProgress: (fraction, message) => emit(EngineBootstrapProgress(step, message, fraction: fraction)),
      );
      final target = p.normalize(dir.absolute.path);
      if (!Directory(target).existsSync()) throw StateError('missing at $target');
      await _link(EngineBootstrap.joltLink, target, step);
      emit(EngineBootstrapLog(step, 'Linked ${p.join(checkoutDir.path, EngineBootstrap.joltLink)} -> $target'));
      emit(const EngineBootstrapProgress(step, 'Jolt Physics ready', fraction: 1));
      return target;
    } catch (e) {
      emit(EngineBootstrapLog(step, 'No prebuilt Jolt Physics for $version ($e): games build with the Dart physics.'));
      return '';
    }
  }

  /// `<checkout>/<name>` → [target]: a directory junction on Windows (no
  /// admin rights needed), a symlink elsewhere. The root pubspec's hook
  /// settings (and every hook's `../filament` fallback) name these folders.
  Future<void> _link(String name, String target, EngineBootstrapStep step) async {
    final path = p.join(checkoutDir.path, name);
    final link = Link(path);
    if (link.existsSync()) {
      if (_sameDir(link.targetSync(), target)) return;
      link.deleteSync();
    } else if (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound) {
      FileSystemEntity.typeSync(path, followLinks: false) == FileSystemEntityType.directory
          ? Directory(path).deleteSync(recursive: true)
          : File(path).deleteSync();
    }
    if (!_windows) {
      link.createSync(target);
      return;
    }
    // `Link.create` makes a symbolic link on Windows, which needs Developer
    // Mode or admin rights; a junction needs neither.
    final cmd = p.join(_env('SystemRoot') ?? r'C:\Windows', 'System32', 'cmd.exe');
    final r = await Process.run(cmd, ['/c', 'mklink', '/J', p.normalize(path), p.normalize(target)],
        environment: environment, includeParentEnvironment: false);
    if (r.exitCode != 0) {
      throw EngineBootstrapException('Could not link $path to $target: ${'${r.stderr}'.trim()} ${'${r.stdout}'.trim()}',
          step: step);
    }
  }

  bool _linkOk(String name, String target) {
    final link = Link(p.join(checkoutDir.path, name));
    try {
      return link.existsSync() && _sameDir(link.targetSync(), target) && Directory(target).existsSync();
    } on FileSystemException {
      return false;
    }
  }

  bool _sameDir(String a, String b) {
    String norm(String s) {
      var n = p.normalize(s.startsWith(r'\\?\') ? s.substring(4) : s);
      if (_windows) n = n.toLowerCase();
      return n;
    }

    return norm(a) == norm(b);
  }

  // ---------------------------------------------------------------------------
  // Packages

  Future<void> _pubGet(String flutter, void Function(EngineBootstrapEvent) emit) async {
    const step = EngineBootstrapStep.packages;
    emit(const EngineBootstrapProgress(step, 'flutter pub get'));
    final code = await _stream(flutter, ['pub', 'get'],
        step: step,
        emit: emit,
        workingDirectory: checkoutDir.path,
        environment: environment,
        runInShell: _windows && !flutter.toLowerCase().endsWith('.exe'));
    if (code != 0) {
      throw EngineBootstrapException('`flutter pub get` failed (exit code $code). Check the network connection and retry.', step: step);
    }
    emit(const EngineBootstrapProgress(step, 'Packages resolved', fraction: 1));
  }

  // ---------------------------------------------------------------------------

  /// Deletes [dir] without following links (the targets of the `filament`
  /// and `openriglogic` links are shared), clearing the read-only flag git
  /// sets on pack files.
  Future<void> _wipe(Directory dir) async {
    if (!dir.existsSync()) return;
    for (final name in [EngineBootstrap.filamentLink, EngineBootstrap.openriglogicLink, EngineBootstrap.joltLink]) {
      final link = Link(p.join(dir.path, name));
      if (link.existsSync()) link.deleteSync();
    }
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      if (_windows) {
        await Process.run('attrib', ['-R', '${dir.path}\\*', '/S', '/D'], runInShell: true);
      } else {
        await Process.run('chmod', ['-R', 'u+w', dir.path]);
      }
      await dir.delete(recursive: true);
    }
  }
}
