import 'input_action.dart';

/// Per-trigger evaluation state for a single frame.
enum TriggerEvaluation { none, ongoing, triggered }

/// Base class for input triggers that evaluate action activation conditions.
abstract class LuminaInputTrigger {
  double actuationThreshold;

  LuminaInputTrigger({this.actuationThreshold = 0.5});

  /// Returns true if [v] magnitude exceeds [actuationThreshold].
  bool isActuated(LuminaInputActionValue v) => v.magnitude > actuationThreshold;

  /// Updates and returns the trigger evaluation for this frame.
  TriggerEvaluation update(LuminaInputActionValue value, double deltaTime);

  /// Resets internal state and timers.
  void reset();
}

/// Triggers on the initial actuation frame (press).
class LuminaPressedTrigger extends LuminaInputTrigger {
  bool _wasActuated = false;

  LuminaPressedTrigger({super.actuationThreshold});

  @override
  TriggerEvaluation update(LuminaInputActionValue value, double deltaTime) {
    final actuated = isActuated(value);
    final prev = _wasActuated;
    _wasActuated = actuated;

    if (actuated && !prev) {
      return TriggerEvaluation.triggered;
    }
    return TriggerEvaluation.none;
  }

  @override
  void reset() {
    _wasActuated = false;
  }
}

/// Triggers when actuation ceases (release).
class LuminaReleasedTrigger extends LuminaInputTrigger {
  bool _wasActuated = false;

  LuminaReleasedTrigger({super.actuationThreshold});

  @override
  TriggerEvaluation update(LuminaInputActionValue value, double deltaTime) {
    final actuated = isActuated(value);
    final prev = _wasActuated;
    _wasActuated = actuated;

    if (!actuated && prev) {
      return TriggerEvaluation.triggered;
    }
    if (actuated) {
      return TriggerEvaluation.ongoing;
    }
    return TriggerEvaluation.none;
  }

  @override
  void reset() {
    _wasActuated = false;
  }
}

/// Triggers after an actuation is held for [holdTimeThreshold] seconds.
class LuminaHoldTrigger extends LuminaInputTrigger {
  double holdTimeThreshold;
  bool isOneShot;
  double _heldTime = 0.0;
  bool _hasTriggered = false;

  LuminaHoldTrigger({
    this.holdTimeThreshold = 1.0,
    this.isOneShot = true,
    super.actuationThreshold,
  });

  @override
  TriggerEvaluation update(LuminaInputActionValue value, double deltaTime) {
    final actuated = isActuated(value);
    if (!actuated) {
      _heldTime = 0.0;
      _hasTriggered = false;
      return TriggerEvaluation.none;
    }

    _heldTime += deltaTime;
    if (_heldTime >= holdTimeThreshold - 1e-9) {
      if (isOneShot && _hasTriggered) {
        return TriggerEvaluation.none;
      }
      _hasTriggered = true;
      return TriggerEvaluation.triggered;
    }

    return TriggerEvaluation.ongoing;
  }

  @override
  void reset() {
    _heldTime = 0.0;
    _hasTriggered = false;
  }
}

/// Triggers only when quickly pressed and released before [tapReleaseTimeThreshold] seconds.
class LuminaTapTrigger extends LuminaInputTrigger {
  double tapReleaseTimeThreshold;
  double _heldTime = 0.0;
  bool _wasActuated = false;
  bool _canceled = false;

  LuminaTapTrigger({
    this.tapReleaseTimeThreshold = 0.2,
    super.actuationThreshold,
  });

  @override
  TriggerEvaluation update(LuminaInputActionValue value, double deltaTime) {
    final actuated = isActuated(value);

    if (actuated) {
      if (!_wasActuated) {
        _wasActuated = true;
        _heldTime = 0.0;
        _canceled = false;
      }
      _heldTime += deltaTime;
      if (_heldTime > tapReleaseTimeThreshold) {
        _canceled = true;
        return TriggerEvaluation.none;
      }
      return TriggerEvaluation.ongoing;
    } else {
      if (_wasActuated) {
        _wasActuated = false;
        if (!_canceled && _heldTime <= tapReleaseTimeThreshold) {
          return TriggerEvaluation.triggered;
        }
      }
      return TriggerEvaluation.none;
    }
  }

  @override
  void reset() {
    _heldTime = 0.0;
    _wasActuated = false;
    _canceled = false;
  }
}

/// Triggers repeatedly at [interval] seconds while held.
class LuminaPulseTrigger extends LuminaInputTrigger {
  double interval;
  bool triggerOnStart;
  double _timeSinceLastPulse = 0.0;
  bool _wasActuated = false;

  LuminaPulseTrigger({
    this.interval = 1.0,
    this.triggerOnStart = true,
    super.actuationThreshold,
  });

  @override
  TriggerEvaluation update(LuminaInputActionValue value, double deltaTime) {
    final actuated = isActuated(value);
    if (!actuated) {
      _wasActuated = false;
      _timeSinceLastPulse = 0.0;
      return TriggerEvaluation.none;
    }

    if (!_wasActuated) {
      _wasActuated = true;
      _timeSinceLastPulse = 0.0;
      if (triggerOnStart) {
        return TriggerEvaluation.triggered;
      }
      return TriggerEvaluation.ongoing;
    }

    _timeSinceLastPulse += deltaTime;
    if (_timeSinceLastPulse >= interval - 1e-9) {
      _timeSinceLastPulse -= interval;
      return TriggerEvaluation.triggered;
    }

    return TriggerEvaluation.ongoing;
  }

  @override
  void reset() {
    _wasActuated = false;
    _timeSinceLastPulse = 0.0;
  }
}
