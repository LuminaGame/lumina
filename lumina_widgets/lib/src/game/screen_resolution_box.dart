import 'package:flutter/widgets.dart';

import 'package:lumina/lumina_runtime.dart';
import 'package:lumina_widgets/src/foundation/observable_adapters.dart';

/// Lays out the game view for the player's screen resolution
/// (`LuminaGameDisplay.renderResolution`): without one the view fills the
/// space; with one, [builder] gets that fixed render size and the view is
/// scaled to the largest box of its aspect ratio, centred on black.
///
/// The widget tree is the same either way, so the view (and its engine
/// resources) survives a resolution change.
class LuminaScreenResolutionBox extends StatelessWidget {
  const LuminaScreenResolutionBox({super.key, required this.builder, this.resolution});

  /// Builds the view for a fixed render size in physical pixels (null: the
  /// layout size).
  final Widget Function(BuildContext context, Size? renderResolution) builder;

  /// What decides the render size; [LuminaGameDisplay.renderResolution] by
  /// default.
  final ObservableValue<(int, int)?>? resolution;

  /// The size, in the [space] given, of the largest box with the aspect
  /// ratio of [render] (the whole space without one).
  static Size fit(Size space, (int, int)? render) {
    if (render == null || render.$1 <= 0 || render.$2 <= 0) return space;
    final scale = (space.width / render.$1) < (space.height / render.$2)
        ? space.width / render.$1
        : space.height / render.$2;
    return Size(render.$1 * scale, render.$2 * scale);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<(int, int)?>(
      valueListenable: (resolution ?? LuminaGameDisplay.renderResolution).asValueListenable(),
      builder: (context, render, _) => ColoredBox(
        color: const Color(0xFF000000),
        child: LayoutBuilder(builder: (context, constraints) {
          final space = constraints.biggest;
          final box = space.isFinite ? fit(space, render) : space;
          return Center(
            child: SizedBox(
              width: box.width.isFinite ? box.width : null,
              height: box.height.isFinite ? box.height : null,
              child: builder(context, render == null ? null : Size(render.$1.toDouble(), render.$2.toDouble())),
            ),
          );
        }),
      ),
    );
  }
}
