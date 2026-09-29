import 'package:flutter_filament/src/gltf_loader.dart';

/// A simple state machine that wraps [FilamentAnimator] to manage playback and cross-fading.
class AnimationStateMachine {
  final FilamentAnimator _animator;
  
  int _currentIndex = -1;
  double _currentTime = 0.0;
  
  int _previousIndex = -1;
  double _previousTime = 0.0;
  
  double _alpha = 1.0;
  Duration _fadeDuration = const Duration(milliseconds: 300);
  double _fadeTime = 0.0;

  /// Creates a state machine for the given [animator].
  AnimationStateMachine(this._animator);

  /// The index of the currently playing animation.
  int get currentIndex => _currentIndex;

  /// Jumps immediately to the given animation [index].
  void play(int index) {
    if (index < 0 || index >= _animator.animationCount) {
      throw RangeError.range(index, 0, _animator.animationCount - 1, 'index');
    }
    _currentIndex = index;
    _currentTime = 0.0;
    _alpha = 1.0; // fully transition
    _previousIndex = -1;
  }

  /// Begins a cross-fade transition to the given animation [index].
  void crossFadeTo(int index, {Duration fade = const Duration(milliseconds: 300)}) {
    if (index < 0 || index >= _animator.animationCount) {
      throw RangeError.range(index, 0, _animator.animationCount - 1, 'index');
    }
    if (_currentIndex == index) return;
    if (_currentIndex == -1) {
      play(index);
      return;
    }

    _previousIndex = _currentIndex;
    _previousTime = _currentTime;
    _currentIndex = index;
    _currentTime = 0.0;
    _fadeDuration = fade;
    _fadeTime = 0.0;
    _alpha = 0.0; // start blending from previous
  }

  /// Advances the animation by [dt] (in seconds) and applies it to the [FilamentAnimator].
  ///
  /// This will:
  /// 1. Advance time and alpha.
  /// 2. Apply the current animation.
  /// 3. If fading, apply cross-fade with the previous animation.
  /// 4. Update the bone matrices.
  void tick(double dt) {
    if (_currentIndex == -1) return;

    _currentTime += dt;

    if (_alpha < 1.0) {
      _previousTime += dt;
      _fadeTime += dt;
      
      final fadeSec = _fadeDuration.inMicroseconds / 1000000.0;
      if (fadeSec > 0) {
        _alpha = (_fadeTime / fadeSec).clamp(0.0, 1.0);
      } else {
        _alpha = 1.0;
      }
    }

    // Wrap time based on duration (assuming loop)
    final duration = _animator.getAnimationDuration(_currentIndex);
    if (duration > 0) {
        _currentTime %= duration;
    }
    
    // Apply the next clip first
    _animator.applyAnimation(_currentIndex, _currentTime);
    
    // Then apply cross-fade with the previous clip if blending
    if (_alpha < 1.0 && _previousIndex != -1) {
      final prevDuration = _animator.getAnimationDuration(_previousIndex);
      if (prevDuration > 0) {
         _previousTime %= prevDuration;
      }
      _animator.applyCrossFade(_previousIndex, _previousTime, _alpha);
    }
    
    // Finally, submit bone matrices to the GPU
    _animator.updateBoneMatrices();
  }
}
