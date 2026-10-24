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

/// Drives a widget test's async file IO until [done] holds (or [timeout]).
///
/// [drainRealIo] runs a fixed number of rounds; a big level's mesh stream can
/// still be reading when they are over, and once the test body has ended
/// nothing pumps again, so each read keeps its file open. Pass what says the
/// work has landed, e.g. `vm.meshLoadsInFlight == 0`.
Future<void> drainRealIoUntil(WidgetTester tester, bool Function() done, {Duration timeout = const Duration(seconds: 20)}) async {
  final clock = Stopwatch()..start();
  while (!done() && clock.elapsed < timeout) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await drainRealIo(tester);
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
      if (DateTime.now().isAfter(deadline)) {
        // Name the files still held open: usually a read the test started
        // in its fake-async zone and never let finish (see [drainRealIo]).
        final locked = <String>[];
        for (final e in dir.listSync(recursive: true).whereType<File>()) {
          try {
            e.deleteSync();
          } on FileSystemException {
            locked.add(e.path);
          }
        }
        throw FileSystemException('Files still open after $timeout: ${locked.join(', ')}', dir.path);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
}
