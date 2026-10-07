import 'dart:async';

class EngineLogEntry {
  final String timestamp;
  final String level;
  final String source;
  final String message;

  const EngineLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'level': level,
        'source': source,
        'message': message,
      };

  factory EngineLogEntry.fromJson(Map<String, dynamic> json) => EngineLogEntry(
        timestamp: json['timestamp'] as String? ?? '',
        level: json['level'] as String? ?? 'info',
        source: json['source'] as String? ?? 'System',
        message: json['message'] as String? ?? '',
      );
}

class EngineLoggerService {
  static final EngineLoggerService _instance = EngineLoggerService._internal();

  factory EngineLoggerService() => _instance;

  EngineLoggerService._internal();

  final StreamController<EngineLogEntry> _controller = StreamController<EngineLogEntry>.broadcast();
  final List<EngineLogEntry> _logs = [];

  Stream<EngineLogEntry> get logStream => _controller.stream;
  List<EngineLogEntry> get logs => List.unmodifiable(_logs);

  List<EngineLogEntry>? _captureBuffer;

  /// Runs [body] with its log output buffered instead of emitted, and returns what
  /// it logged. Used to carry log lines out of a background isolate: that isolate
  /// owns its own [EngineLoggerService] singleton, so anything it logs never reaches
  /// the editor's Output Log. The caller sends the captured entries back and hands
  /// them to [replay].
  List<EngineLogEntry> captureLogs(void Function() body) {
    final previous = _captureBuffer;
    final buffer = <EngineLogEntry>[];
    _captureBuffer = buffer;
    try {
      body();
    } finally {
      _captureBuffer = previous;
    }
    return buffer;
  }

  /// Emits previously captured entries, keeping the moment each was produced
  /// rather than the moment it was replayed.
  void replay(Iterable<EngineLogEntry> entries) {
    for (final entry in entries) {
      _emit(entry);
    }
  }

  void log(String message, {String level = 'info', String source = 'Engine'}) {
    final now = DateTime.now();
    final timestamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final entry = EngineLogEntry(
      timestamp: timestamp,
      level: level,
      source: source,
      message: message,
    );

    final buffer = _captureBuffer;
    if (buffer != null) {
      buffer.add(entry);
      return;
    }
    _emit(entry);
  }

  void _emit(EngineLogEntry entry) {
    final timestamp = entry.timestamp;
    final level = entry.level;
    final source = entry.source;
    final message = entry.message;
    _logs.add(entry);
    _controller.add(entry);

    final colorCode = switch (level) {
      'error' => '\x1B[31m[ERROR]\x1B[0m',
      'warning' => '\x1B[33m[WARN]\x1B[0m',
      'success' => '\x1B[32m[SUCCESS]\x1B[0m',
      _ => '\x1B[36m[INFO]\x1B[0m',
    };
    // ignore: avoid_print
    print('[$timestamp] $colorCode [$source] $message');
  }

  void clear() {
    _logs.clear();
  }
}
