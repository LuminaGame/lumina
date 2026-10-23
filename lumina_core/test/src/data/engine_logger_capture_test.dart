import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

/// Log lines produced inside a captured body are buffered, not emitted, and
/// come back to the caller; an asynchronous body is captured until its future
/// completes. Replaying emits them with their original timestamps.
void main() {
  test('captureLogs and captureLogsAsync buffer what the body logs', () async {
    final logger = EngineLoggerService();
    final before = logger.logs.length;
    final sync = logger.captureLogs(() => logger.log('sync line', source: 'Capture'));
    expect(sync.single.message, 'sync line');
    final async = await logger.captureLogsAsync(() async {
      logger.log('before the await', source: 'Capture');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      logger.log('after the await', source: 'Capture');
    });
    expect([for (final e in async) e.message], ['before the await', 'after the await']);
    expect(logger.logs.length, before, reason: 'nothing captured was emitted');
    logger.replay(async);
    expect(logger.logs.length, before + 2);
    expect(logger.logs.last.message, 'after the await');
  });
}
