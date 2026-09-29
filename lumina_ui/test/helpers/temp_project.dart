import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives async file IO a widget test started to its end.
///
/// Under `testWidgets` every step of an async read (open, length, read,
/// close) needs the real event loop and then a pump to run its callback, so
/// a read started by an action (e.g. `AssetRepository.loadMeshFromDisk`
/// after a Content Browser refresh) keeps its file open — and Windows
/// refuses to delete an open file. Call after such an action.
Future<void> drainRealIo(WidgetTester tester, {int rounds = 20}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// Deletes a test's temp project once Windows lets go of it.
///
/// Source control runs git probes with the project folder as their working
/// directory, and Windows refuses to delete a folder a live process works in.
/// Plain tests `await vm.close()`, which waits for the probe; a widget test
/// cannot (the probe's completion lands in its fake-async zone, which never
/// runs again after the test), so it disposes and deletes here with a short
/// real-time retry instead — the git process itself exits within a second.
/// Call it from `tearDown` / `tearDownAll`, which run on the real clock.
Future<void> deleteTempProject(Directory dir, {Duration timeout = const Duration(seconds: 10)}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      return;
    } on FileSystemException {
      if (DateTime.now().isAfter(deadline)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
}
