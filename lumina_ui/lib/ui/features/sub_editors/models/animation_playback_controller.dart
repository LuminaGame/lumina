import 'package:flutter/foundation.dart';

/// Manages and broadcasts frame-by-frame animation playback requests to the 3D viewport.
class AnimationPlaybackController extends ChangeNotifier {
  int _clipIndex;
  double _timeSeconds;
  final List<String> callLog;

  AnimationPlaybackController({
    this._clipIndex = 0,
    this._timeSeconds = 0.0,
    List<String>? callLog,
  }) : callLog = callLog ?? [];

  int get clipIndex => _clipIndex;
  double get timeSeconds => _timeSeconds;

  void setPlayback({required int clipIndex, required double timeSeconds}) {
    _clipIndex = clipIndex;
    _timeSeconds = timeSeconds;
    notifyListeners();
  }

  void recordCall(String methodName) {
    callLog.add(methodName);
  }
}
