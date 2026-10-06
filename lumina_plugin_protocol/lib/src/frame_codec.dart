import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Frames are a 4-byte big-endian payload length followed by that many bytes
/// of UTF-8 JSON encoding one object.
abstract final class PluginFrameCodec {
  /// The largest payload accepted (64 MiB): a bigger length is a corrupt
  /// stream, not a message.
  static const int maxPayload = 64 * 1024 * 1024;

  /// One frame for [message].
  static Uint8List encode(Map<String, Object?> message) {
    final payload = utf8.encode(jsonEncode(message));
    if (payload.length > maxPayload) {
      throw ArgumentError('a plugin protocol message of ${payload.length} bytes exceeds $maxPayload');
    }
    final out = Uint8List(4 + payload.length);
    ByteData.sublistView(out).setUint32(0, payload.length, Endian.big);
    out.setRange(4, out.length, payload);
    return out;
  }

  /// Splits a byte stream into decoded messages, whatever the chunking.
  /// A frame whose payload is not a JSON object, or a length above
  /// [maxPayload], ends the stream with a [FormatException].
  static Stream<Map<String, Object?>> decode(Stream<List<int>> bytes) {
    final controller = StreamController<Map<String, Object?>>(sync: true);
    final buffer = BytesBuilder(copy: false);
    var pending = Uint8List(0);
    StreamSubscription<List<int>>? sub;

    void fail(Object error) {
      controller.addError(error);
      sub?.cancel();
      controller.close();
    }

    void drain() {
      var offset = 0;
      while (pending.length - offset >= 4) {
        final length = ByteData.sublistView(pending, offset, offset + 4).getUint32(0, Endian.big);
        if (length > maxPayload) {
          fail(FormatException('plugin protocol frame of $length bytes exceeds $maxPayload'));
          return;
        }
        if (pending.length - offset - 4 < length) break;
        final payload = Uint8List.sublistView(pending, offset + 4, offset + 4 + length);
        offset += 4 + length;
        Object? decoded;
        try {
          decoded = jsonDecode(utf8.decode(payload));
        } on FormatException catch (e) {
          fail(FormatException('plugin protocol frame is not JSON: ${e.message}'));
          return;
        }
        if (decoded is! Map) {
          fail(const FormatException('plugin protocol frame is not a JSON object'));
          return;
        }
        controller.add(decoded.cast<String, Object?>());
      }
      pending = offset == 0 ? pending : Uint8List.fromList(Uint8List.sublistView(pending, offset));
    }

    controller.onListen = () {
      sub = bytes.listen(
        (chunk) {
          buffer.add(pending);
          buffer.add(chunk);
          pending = buffer.takeBytes();
          drain();
        },
        onError: controller.addError,
        onDone: () {
          if (pending.isNotEmpty && !controller.isClosed) {
            controller.addError(FormatException('plugin protocol stream ended inside a frame (${pending.length} bytes left)'));
          }
          if (!controller.isClosed) controller.close();
        },
      );
    };
    controller.onPause = () => sub?.pause();
    controller.onResume = () => sub?.resume();
    controller.onCancel = () => sub?.cancel();
    return controller.stream;
  }
}
