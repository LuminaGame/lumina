import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show EngineLoggerService;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/services/crash_reporter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/crash_report_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The crash report screen over a running editor shell: an uncaught error
/// is filed, the screen appears, the user describes it and sends it to a
/// real local HTTP server standing in for the marketplace endpoint.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Crash Report Smoke: an uncaught error shows the report screen, which sends what the user typed', (tester) async {
    const name = 'Crash Report Smoke: an uncaught error shows the report screen, which sends what the user typed';
    final dataDir = Directory.systemTemp.createTempSync('lumina_crash_smoke_');
    final received = <Map<String, Object?>>[];
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      received.add((jsonDecode(body) as Map).cast<String, Object?>());
      request.response
        ..statusCode = 201
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'id': 'smoke-${received.length}', 'receivedAt': DateTime.now().toUtc().toIso8601String()}));
      await request.response.close();
    });
    final reporter = CrashReporter(dataDir: dataDir, serverUrl: () => Uri.parse('http://127.0.0.1:${http.port}/'));
    try {
      await reporter.startSession();
      EngineLoggerService().log('Level L_Main opened', level: 'info', source: 'Editor');
      EngineLoggerService().log('Material editor opened M_Barrel', level: 'info', source: 'MaterialEditor');

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: RepaintBoundary(
            key: boundaryKey,
            child: CrashReportOverlay(
              reporter: reporter,
              child: Container(
                color: EditorColors.background,
                alignment: Alignment.center,
                child: const Text('Lumina Studio', style: TextStyle(fontSize: 24, color: EditorColors.mutedForeground)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      Future<void> shot(String label) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($label)', png);
      }

      // The uncaught error, as the installed handlers would file it.
      try {
        <int>[].first;
      } catch (e, s) {
        reporter.record(e, s, context: 'laying out the material graph');
      }
      await tester.pumpAndSettle();
      expect(find.byType(CrashReportView), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      await shot('screen');

      // A few characters typed on camera, then the whole sentence at once.
      await rec.typeText(find.byKey(const ValueKey('crash_description')), 'Deleted the output');
      await tester.enterText(find.byKey(const ValueKey('crash_description')), 'Deleted the output node of M_Barrel and pressed Compile.');
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('crash_toggle_details')));
      await tester.pumpAndSettle();
      await rec.hold(const Duration(seconds: 2));
      await shot('what is sent');

      await tester.tap(find.byKey(const ValueKey('crash_send')));
      await tester.pump();
      for (var i = 0; i < 100 && received.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      await rec.hold(const Duration(seconds: 2));
      expect(received, hasLength(1));
      expect(received.single['description'], 'Deleted the output node of M_Barrel and pressed Compile.');
      expect((received.single['logTail'] as List).join('\n'), contains('M_Barrel'));
      expect(find.byKey(const ValueKey('crash_sent')), findsOneWidget);
      await shot('sent');

      await tester.tap(find.byKey(const ValueKey('crash_continue')));
      await tester.pumpAndSettle();
      expect(find.byType(CrashReportView), findsNothing);
      await rec.hold(const Duration(seconds: 2));
      rec.save(name);
      await reporter.flush();
      expect(reporter.fileOf(reporter.filed.single).existsSync(), isTrue);
    } finally {
      await reporter.dispose();
      await http.close(force: true);
      dataDir.deleteSync(recursive: true);
    }
  });
}
