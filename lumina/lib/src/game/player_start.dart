import '../object/actor.dart';

/// An actor that specifies a spawn point for players in the level.
class LuminaPlayerStart extends LuminaActor {
  /// Optional tag used by the GameMode to match a specific start.
  final String? playerStartTag;

  LuminaPlayerStart({
    super.key,
    super.location,
    super.rotation,
    this.playerStartTag,
  });
}
