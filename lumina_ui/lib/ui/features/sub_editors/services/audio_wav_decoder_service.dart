import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Typed failure raised by [WavDecoderService]. The audio editor renders this
/// message instead of drawing a fabricated waveform.
class WavDecodeException implements Exception {
  final String message;
  const WavDecodeException(this.message);

  @override
  String toString() => 'WavDecodeException: $message';
}

/// Per-channel min/max peak envelope, one entry per bin.
class AudioPeakEnvelope {
  final Float32List mins;
  final Float32List maxs;

  const AudioPeakEnvelope(this.mins, this.maxs);

  int get binCount => mins.length;
}

/// Fully decoded, normalized (±1.0) PCM from a RIFF/WAVE file.
class DecodedAudio {
  final int sampleRate;
  final int bitDepth;
  final int channels;
  final bool isFloat;

  /// One [Float32List] per channel, each [frameCount] long, normalized to ±1.
  final List<Float32List> samples;

  DecodedAudio({
    required this.sampleRate,
    required this.bitDepth,
    required this.channels,
    required this.isFloat,
    required this.samples,
  });

  int get frameCount => samples.isEmpty ? 0 : samples.first.length;

  /// Total decoded sample count across all channels.
  int get totalSampleCount => frameCount * channels;

  double get duration => sampleRate <= 0 ? 0.0 : frameCount / sampleRate;

  /// Min/max peak envelope computed from the decoded samples (never from a
  /// previously rendered image), optionally over a zoom window.
  ///
  /// Bin `i` covers frames `[start + i*span/binCount, start + (i+1)*span/binCount)`
  /// with exact integer boundaries.
  List<AudioPeakEnvelope> peakEnvelope(int binCount, {int startFrame = 0, int? endFrame}) {
    if (binCount <= 0) throw ArgumentError.value(binCount, 'binCount', 'must be > 0');
    final end = (endFrame ?? frameCount).clamp(0, frameCount);
    final start = startFrame.clamp(0, end);
    final span = end - start;

    return List.generate(channels, (c) {
      final mins = Float32List(binCount);
      final maxs = Float32List(binCount);
      final data = samples[c];
      for (var b = 0; b < binCount; b++) {
        final from = start + (span * b) ~/ binCount;
        var to = start + (span * (b + 1)) ~/ binCount;
        if (to <= from) to = math.min(from + 1, end);
        var lo = 0.0;
        var hi = 0.0;
        var seen = false;
        for (var i = from; i < to; i++) {
          final v = data[i];
          if (!seen) {
            lo = v;
            hi = v;
            seen = true;
          } else {
            if (v < lo) lo = v;
            if (v > hi) hi = v;
          }
        }
        mins[b] = lo;
        maxs[b] = hi;
      }
      return AudioPeakEnvelope(mins, maxs);
    });
  }

  /// Running peak magnitude of [channel] in a window ending at [seconds] —
  /// the VU meter source (real PCM, not a decorative animation).
  double peakAt(int channel, double seconds, {double window = 0.05}) {
    if (channel < 0 || channel >= channels || frameCount == 0) return 0.0;
    final data = samples[channel];
    final centre = (seconds * sampleRate).round().clamp(0, frameCount - 1);
    final half = math.max(1, (window * sampleRate / 2).round());
    final from = math.max(0, centre - half);
    final to = math.min(frameCount, centre + half);
    var peak = 0.0;
    for (var i = from; i < to; i++) {
      final v = data[i].abs();
      if (v > peak) peak = v;
    }
    return peak;
  }
}

/// Pure-Dart RIFF/WAVE decoder: PCM 16/24/32-bit integer and IEEE float32,
/// mono or stereo. No native dependency, no audio package.
///
/// NOTE: this service belongs in `package:lumina`
/// (`lib/data/services/wav_decoder_service.dart`). It lives here for now; the
/// file can be lifted into lumina verbatim.
class WavDecoderService {
  static const int _riff = 0x46464952; // 'RIFF' little-endian
  static const int _wave = 0x45564157; // 'WAVE'

  static DecodedAudio decode(Uint8List bytes) {
    if (bytes.length < 44) {
      throw const WavDecodeException('Not a WAV file: fewer than 44 bytes.');
    }
    final view = ByteData.sublistView(bytes);
    if (view.getUint32(0, Endian.little) != _riff || view.getUint32(8, Endian.little) != _wave) {
      throw WavDecodeException(
        'Not a RIFF/WAVE file (found "${_tag(bytes, 0)}"). Lumina decodes uncompressed .wav only — '
        'mp3/ogg need a decoder that is not part of the stack yet.',
      );
    }

    int? audioFormat;
    int? channels;
    int? sampleRate;
    int? bitDepth;
    int? dataOffset;
    int? dataSize;

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = _tag(bytes, offset);
      final size = view.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      if (id == 'fmt ') {
        if (body + 16 > bytes.length) {
          throw const WavDecodeException('Truncated "fmt " chunk.');
        }
        audioFormat = view.getUint16(body, Endian.little);
        channels = view.getUint16(body + 2, Endian.little);
        sampleRate = view.getUint32(body + 4, Endian.little);
        bitDepth = view.getUint16(body + 14, Endian.little);
        if (audioFormat == 0xFFFE && body + 26 <= bytes.length) {
          // WAVE_FORMAT_EXTENSIBLE: the real format tag is the first GUID word.
          audioFormat = view.getUint16(body + 24, Endian.little);
        }
      } else if (id == 'data') {
        dataOffset = body;
        dataSize = size;
        if (body + size > bytes.length) {
          throw WavDecodeException(
            'Truncated "data" chunk: header declares $size bytes but only ${bytes.length - body} are present.',
          );
        }
      }
      offset = body + size + (size.isOdd ? 1 : 0);
    }

    if (audioFormat == null || channels == null || sampleRate == null || bitDepth == null) {
      throw const WavDecodeException('Missing "fmt " chunk.');
    }
    if (dataOffset == null || dataSize == null) {
      throw const WavDecodeException('Missing "data" chunk.');
    }
    if (channels < 1 || channels > 2) {
      throw WavDecodeException('Unsupported channel count $channels — mono and stereo only.');
    }
    final isFloat = audioFormat == 3;
    if (audioFormat != 1 && !isFloat) {
      throw WavDecodeException('Unsupported WAV encoding (format tag $audioFormat) — PCM and IEEE float only.');
    }
    if (isFloat && bitDepth != 32) {
      throw WavDecodeException('Unsupported float bit depth $bitDepth — 32-bit only.');
    }
    if (!isFloat && bitDepth != 16 && bitDepth != 24 && bitDepth != 32) {
      throw WavDecodeException('Unsupported PCM bit depth $bitDepth — 16, 24 or 32-bit only.');
    }

    final bytesPerSample = bitDepth ~/ 8;
    final blockAlign = bytesPerSample * channels;
    if (blockAlign == 0) throw const WavDecodeException('Invalid block alignment.');
    final frames = dataSize ~/ blockAlign;
    if (frames == 0) {
      throw const WavDecodeException('The "data" chunk holds no complete audio frames.');
    }

    final out = List.generate(channels, (_) => Float32List(frames));
    for (var f = 0; f < frames; f++) {
      final base = dataOffset + f * blockAlign;
      for (var c = 0; c < channels; c++) {
        final p = base + c * bytesPerSample;
        double v;
        if (isFloat) {
          v = view.getFloat32(p, Endian.little);
        } else if (bitDepth == 16) {
          v = view.getInt16(p, Endian.little) / 32768.0;
        } else if (bitDepth == 24) {
          // 3-byte little-endian with explicit sign extension.
          final raw = bytes[p] | (bytes[p + 1] << 8) | (bytes[p + 2] << 16);
          final signed = (raw & 0x800000) != 0 ? raw - 0x1000000 : raw;
          v = signed / 8388608.0;
        } else {
          v = view.getInt32(p, Endian.little) / 2147483648.0;
        }
        if (v.isNaN || v.isInfinite) v = 0.0;
        out[c][f] = v.clamp(-1.0, 1.0);
      }
    }

    return DecodedAudio(
      sampleRate: sampleRate,
      bitDepth: bitDepth,
      channels: channels,
      isFloat: isFloat,
      samples: out,
    );
  }

  static String _tag(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return '';
    return ascii.decode(bytes.sublist(offset, offset + 4), allowInvalid: true);
  }
}
