import 'dart:async';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Panic and Log Bridge Tests', () {
    setUp(() {
      FilamentDiagnostics.installPanicHandler();
      FilamentDiagnostics.installLogHandler();
    });

    tearDown(() {
      FilamentDiagnostics.clearPanicHandler();
      FilamentDiagnostics.clearLogHandler();
    });

    test('Triggering panic populates lastPanic and fires onPanic', () async {
      expect(FilamentDiagnostics.lastPanic, isNull);

      final panicCompleter = Completer<FilamentPanicException>();
      final sub = FilamentDiagnostics.onPanic.listen((ex) {
        if (!panicCompleter.isCompleted) {
          panicCompleter.complete(ex);
        }
      });

      FilamentDiagnostics.testTriggerPanic();
      
      // Wait for the isolate to process the NativeCallable message
      final panic = await panicCompleter.future.timeout(Duration(seconds: 1));

      // 1. Fallback poll checking
      final lastPanic = FilamentDiagnostics.lastPanic;
      expect(lastPanic, isNotNull);
      expect(lastPanic, contains('Test panic message'));

      // 2. Exception stream checking
      expect(panic.message, contains('Test panic message'));
      
      await sub.cancel();
    });

    test('Log bridge correctly routes logs', () async {
      final logCompleter = Completer<FilamentLogRecord>();
      
      final subscription = FilamentDiagnostics.onLog.listen((record) {
        if (!logCompleter.isCompleted) {
          logCompleter.complete(record);
        }
      });

      FilamentDiagnostics.testLog('Test log message');

      final record = await logCompleter.future.timeout(Duration(seconds: 1));
      
      expect(record.message, contains('Test log message'));
      expect(record.priority, 5); // Warning
      
      await subscription.cancel();
    });

    test('Engine operations generate real logs', () async {
      final records = <FilamentLogRecord>[];
      final subscription = FilamentDiagnostics.onLog.listen((record) {
        records.add(record);
      });

      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      engine.dispose();

      // Wait a moment for logs to flush
      await Future.delayed(Duration(milliseconds: 100));
      
      expect(records, isNotEmpty);
      await subscription.cancel();
    });
  });
}
