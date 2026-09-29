// ignore_for_file: file_names
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/testing.dart';

void main() {
  test(
    '00_test_report smoke test: captures screenshot and generates smoke report',
    () async {
      // 1. Save a minimal 1x1 PNG smoke screenshot artifact
    final png1x1 = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG Header
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, // RGBA
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ]);

    final testName = '00_test_report smoke test: captures screenshot and generates smoke report';
    final savedFile = SmokeArtifacts.saveScreenshot(testName, png1x1);
    expect(savedFile.existsSync(), isTrue);

    final tempDir = Directory.systemTemp.createTempSync('smoke_test_isolated_');
    try {
      final tempArtifacts = Directory('${tempDir.path}/artifacts')..createSync(recursive: true);
      final tempEvents = File('${tempDir.path}/events.jsonl');
      // Its own report file: the suite's build/smoke_report.html is left alone.
      final tempReport = File('${tempDir.path}/smoke_report.html');
      SmokeArtifacts.saveScreenshotToDir(testName, png1x1, tempArtifacts);

      // 2. Run tool/smoke_report.dart in isolated environment
      final result = await Process.run(
        'dart',
        ['run', 'tool/smoke_report.dart', 'test/src/testing/smoke_report_test.dart'],
        runInShell: Platform.isWindows,
        environment: {
          'LUMINA_SMOKE_OUT': tempArtifacts.path,
          'LUMINA_SMOKE_EVENTS_OUT': tempEvents.path,
          'LUMINA_SMOKE_REPORT_OUT': tempReport.path,
        },
      );

      expect(result.exitCode, equals(0), reason: 'smoke_report runner must exit with 0 on pass: ${result.stderr}');
      final htmlReport = tempReport;
      expect(htmlReport.existsSync(), isTrue, reason: 'the report must be generated');
      final htmlContent = htmlReport.readAsStringSync();
      expect(htmlContent, contains('Smoke & Test Report'));
      expect(htmlContent, contains('Summary'));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  },
  // A whole nested `flutter test` run (compile + native hooks + the report
  // tests' real 1024×768 video encodes); under the full suite's load it can
  // take well over two minutes.
  timeout: const Timeout(Duration(minutes: 6)),
  );
}
