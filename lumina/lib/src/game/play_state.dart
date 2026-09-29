/// Editor-facing play state of a [LuminaGame] (Play-In-Editor toolbar state).
///
/// Transitions: `stopped` → `playing` on `mountGame`, `playing` ⇄ `paused` via
/// `pause()` / `resume()`, and any state → `stopped` on `disposeGame`.
enum LuminaPlayState {
  /// No world is mounted (before `mountGame` / after `disposeGame`).
  stopped,

  /// The world ticks every frame.
  playing,

  /// The world is frozen: `tickGame` is a no-op, only `step` advances it.
  paused,
}
