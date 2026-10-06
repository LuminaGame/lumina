// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'frame_codec.dart';
import 'messages.dart';

/// Handles a request: returns the JSON result (or a future of it). Throwing
/// a [PluginRemoteError] answers with its code; anything else answers
/// [PluginErrorCodes.handlerFailed].
typedef PluginRequestHandler = FutureOr<Object?> Function(Map<String, Object?> args);

/// Handles a notification.
typedef PluginNotificationHandler = void Function(Map<String, Object?> args);

/// One end of a plugin protocol link over a byte stream pair (a socket on
/// both sides): send requests and notifications, answer the other side's
/// requests with registered handlers.
///
/// Every request has a timeout ([defaultTimeout] unless the call gives one);
/// an answer that arrives after it is dropped. When the stream ends or
/// [close] is called, every pending call fails with
/// [PluginErrorCodes.closed] and [done] completes.
class PluginConnection {
  PluginConnection({
    required Stream<List<int>> input,
    required StreamSink<List<int>> output,
    this.defaultTimeout = const Duration(seconds: 10),
    this.onProtocolError,
  }) : _output = output {
    _sub = PluginFrameCodec.decode(input).listen(
      _onMessage,
      onError: (Object e, StackTrace s) {
        onProtocolError?.call(e, s);
        close();
      },
      onDone: close,
    );
  }

  final StreamSink<List<int>> _output;
  late final StreamSubscription<Map<String, Object?>> _sub;
  final Duration defaultTimeout;

  /// Called with a malformed frame or message before the connection closes.
  final void Function(Object error, StackTrace stack)? onProtocolError;

  final Map<String, PluginRequestHandler> _requestHandlers = {};
  final Map<String, PluginNotificationHandler> _notificationHandlers = {};
  final Map<int, _Pending> _pending = {};
  final Completer<void> _done = Completer<void>();
  int _nextId = 1;
  bool _closed = false;

  bool get isClosed => _closed;

  /// Completes once when the connection closes (either side).
  Future<void> get done => _done.future;

  /// Requests waiting for an answer.
  int get pendingCount => _pending.length;

  /// Answers [method] requests with [handler] (replacing an earlier one).
  void onRequest(String method, PluginRequestHandler handler) => _requestHandlers[method] = handler;

  /// Receives [method] notifications with [handler] (replacing an earlier one).
  void onNotification(String method, PluginNotificationHandler handler) => _notificationHandlers[method] = handler;

  /// Sends a request and waits for its answer. Fails with a
  /// [PluginRemoteError]: the other side's error, [PluginErrorCodes.timeout]
  /// after [timeout], or [PluginErrorCodes.closed].
  Future<Object?> request(String method, [Map<String, Object?> args = const {}, Duration? timeout]) {
    if (_closed) {
      return Future.error(PluginRemoteError(code: PluginErrorCodes.closed, message: 'connection closed before $method'));
    }
    final id = _nextId++;
    final completer = Completer<Object?>();
    final limit = timeout ?? defaultTimeout;
    final timer = Timer(limit, () {
      if (_pending.remove(id) != null && !completer.isCompleted) {
        completer.completeError(PluginRemoteError(
          code: PluginErrorCodes.timeout,
          message: '$method did not answer within ${limit.inMilliseconds} ms',
        ));
      }
    });
    _pending[id] = _Pending(completer, timer);
    _send(PluginRequest(id: id, method: method, args: args));
    return completer.future;
  }

  /// Sends a notification (dropped when closed).
  void notify(String method, [Map<String, Object?> args = const {}]) {
    if (_closed) return;
    _send(PluginNotification(method: method, args: args));
  }

  void _send(PluginMessage message) {
    try {
      _output.add(PluginFrameCodec.encode(message.toJson()));
    } catch (e, s) {
      onProtocolError?.call(e, s);
      close();
    }
  }

  void _onMessage(Map<String, Object?> json) {
    final PluginMessage message;
    try {
      message = PluginMessage.fromJson(json);
    } catch (e, s) {
      onProtocolError?.call(e, s);
      return;
    }
    switch (message) {
      case PluginResponse():
        final pending = _pending.remove(message.id);
        if (pending == null) return; // late (timed out) or unknown: dropped
        pending.timer.cancel();
        if (message.ok) {
          pending.completer.complete(message.result);
        } else {
          pending.completer.completeError(message.error!);
        }
      case PluginNotification():
        final handler = _notificationHandlers[message.method];
        if (handler == null) return;
        try {
          handler(message.args);
        } catch (e, s) {
          onProtocolError?.call(e, s);
        }
      case PluginRequest():
        _answer(message);
    }
  }

  Future<void> _answer(PluginRequest request) async {
    final handler = _requestHandlers[request.method];
    if (handler == null) {
      _send(PluginResponse.error(
        request.id,
        PluginRemoteError(code: PluginErrorCodes.unknownMethod, message: 'no handler for ${request.method}'),
      ));
      return;
    }
    try {
      final result = await handler(request.args);
      if (!_closed) _send(PluginResponse.ok(request.id, result));
    } on PluginRemoteError catch (e) {
      if (!_closed) _send(PluginResponse.error(request.id, e));
    } catch (e, s) {
      if (!_closed) {
        _send(PluginResponse.error(
          request.id,
          PluginRemoteError(code: PluginErrorCodes.handlerFailed, message: '$e', stack: '$s'),
        ));
      }
    }
  }

  /// Closes the link: pending calls fail with [PluginErrorCodes.closed].
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final entry in _pending.entries) {
      entry.value.timer.cancel();
      if (!entry.value.completer.isCompleted) {
        entry.value.completer.completeError(
          const PluginRemoteError(code: PluginErrorCodes.closed, message: 'connection closed'),
        );
      }
    }
    _pending.clear();
    await _sub.cancel();
    try {
      await _output.close();
    } catch (_) {
      // the other side is already gone
    }
    if (!_done.isCompleted) _done.complete();
  }
}

class _Pending {
  _Pending(this.completer, this.timer);
  final Completer<Object?> completer;
  final Timer timer;
}
