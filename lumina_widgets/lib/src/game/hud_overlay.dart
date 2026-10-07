import 'package:flutter/widgets.dart';
import 'package:lumina/src/controller/player_state.dart';
import 'package:lumina/src/game/game_state.dart';
import 'package:lumina/src/game/lumina_game.dart';
import 'package:lumina/src/world/debug_shapes.dart';
import 'package:lumina/src/world/world.dart';

typedef LuminaHudBuilder = Widget Function(BuildContext context, LuminaGame game);

class LuminaHudOverlay extends StatefulWidget {
  final LuminaGame game;
  final LuminaHudBuilder hudBuilder;

  const LuminaHudOverlay({
    super.key,
    required this.game,
    required this.hudBuilder,
  });

  @override
  State<LuminaHudOverlay> createState() => _LuminaHudOverlayState();
}

class _LuminaHudOverlayState extends State<LuminaHudOverlay> {
  LuminaWorld? _currentWorld;
  LuminaGameState? _currentGameState;
  LuminaPlayerState? _currentPlayerState;

  @override
  void initState() {
    super.initState();
    _subscribeToGame();
  }

  @override
  void didUpdateWidget(LuminaHudOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game) {
      _unsubscribeFromGame(oldWidget.game);
      _subscribeToGame();
    }
  }

  @override
  void dispose() {
    _unsubscribeFromGame(widget.game);
    super.dispose();
  }

  void _subscribeToGame() {
    widget.game.gameInstance.addListener(_onWorldChanged);
    _onWorldChanged();
  }

  void _unsubscribeFromGame(LuminaGame game) {
    game.gameInstance.removeListener(_onWorldChanged);
    _unsubscribeFromWorld();
  }

  void _unsubscribeFromWorld() {
    _currentGameState?.removeListener(_onStateChanged);
    _currentPlayerState?.removeListener(_onStateChanged);
    _currentWorld = null;
    _currentGameState = null;
    _currentPlayerState = null;
  }

  void _onWorldChanged() {
    final world = widget.game.gameInstance.world;
    if (_currentWorld != world) {
      _unsubscribeFromWorld();
      _currentWorld = world;
      
      if (world != null) {
        _currentGameState = world.gameState;
        _currentGameState?.addListener(_onStateChanged);

        final pc = widget.game.gameInstance.primaryPlayerController;
        if (pc != null) {
          _currentPlayerState = pc.playerState;
          _currentPlayerState?.addListener(_onStateChanged);
        }
      }
      
      _onStateChanged();
    }
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.hudBuilder(context, widget.game),
        Positioned(
          left: 8,
          top: 8,
          child: LuminaScreenMessagesView(world: widget.game.gameInstance.world),
        ),
      ],
    );
  }
}

/// The lines `Print String` printed to the screen, newest
/// last, in their colours: what the PIE overlay and the generated game's HUD
/// draw top-left. Rebuilds on every frame the host ticks.
class LuminaScreenMessagesView extends StatelessWidget {
  final LuminaWorld? world;
  const LuminaScreenMessagesView({super.key, required this.world});

  @override
  Widget build(BuildContext context) {
    final messages = world?.screenMessages.values.toList() ?? const <LuminaScreenMessage>[];
    if (messages.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in messages)
            Text(
              m.text,
              style: TextStyle(
                color: Color.fromARGB(
                  (m.color.length > 3 ? m.color[3] * 255 : 255).round().clamp(0, 255),
                  (m.color.isNotEmpty ? m.color[0] * 255 : 0).round().clamp(0, 255),
                  (m.color.length > 1 ? m.color[1] * 255 : 255).round().clamp(0, 255),
                  (m.color.length > 2 ? m.color[2] * 255 : 0).round().clamp(0, 255),
                ),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(color: Color(0xFF000000), blurRadius: 2)],
              ),
            ),
        ],
      ),
    );
  }
}
