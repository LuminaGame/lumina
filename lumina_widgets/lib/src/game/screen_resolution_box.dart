import 'package:flutter/widgets.dart';

import 'package:lumina/lumina_runtime.dart';
import 'package:lumina_widgets/src/foundation/observable_adapters.dart';
import 'package:lumina_widgets/src/game/render_space.dart';

/// Lays out the game view for the player's screen resolution
/// (`LuminaGameDisplay.renderResolution`): without one the view fills the
/// space; with one, [builder] gets that fixed render size and the view is
/// scaled to the largest box of its aspect ratio, centred on black
/// ([LuminaRenderSpace]).
///
/// [overlay] (the game's UI) is laid out in the same box, at the chosen
/// resolution's logical size ([LuminaRenderSpace.layoutSize]) and scaled
/// with the picture, so it is drawn and hit where the picture is and never
/// on the bars.
///
/// The widget tree is the same either way, so the view (and its engine
/// resources) survives a resolution change.
class LuminaScreenResolutionBox extends StatelessWidget {
  const LuminaScreenResolutionBox({super.key, required this.builder, this.resolution, this.overlay});

  /// Builds the view for a fixed render size in physical pixels (null: the
  /// layout size).
  final Widget Function(BuildContext context, Size? renderResolution) builder;

  /// What decides the render size; [LuminaGameDisplay.renderResolution] by
  /// default.
  final ObservableValue<(int, int)?>? resolution;

  /// Laid out over the view in render space (the game's UI).
  final Widget? overlay;

  /// The size, in the [space] given, of the largest box with the aspect
  /// ratio of [render] (the whole space without one).
  static Size fit(Size space, (int, int)? render) =>
      LuminaRenderSpace(space: space, renderResolution: render).rect.size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<(int, int)?>(
      valueListenable: (resolution ?? LuminaGameDisplay.renderResolution).asValueListenable(),
      builder: (context, render, _) => ColoredBox(
        color: const Color(0xFF000000),
        child: LayoutBuilder(builder: (context, constraints) {
          final space = constraints.biggest;
          final renderSpace = LuminaRenderSpace(
            space: space,
            renderResolution: render,
            devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0,
          );
          final box = space.isFinite ? renderSpace.rect.size : space;
          final view = builder(context, render == null ? null : Size(render.$1.toDouble(), render.$2.toDouble()));
          final ui = overlay;
          return Center(
            child: SizedBox(
              width: box.width.isFinite ? box.width : null,
              height: box.height.isFinite ? box.height : null,
              child: ui == null
                  ? view
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        view,
                        // Always the same shape, so the UI keeps its state
                        // when the resolution changes (no resolution: the
                        // layout size is the box itself).
                        if (!space.isFinite)
                          ui
                        else
                          FittedBox(
                            fit: BoxFit.fill,
                            child: SizedBox.fromSize(size: renderSpace.layoutSize, child: ui),
                          ),
                      ],
                    ),
            ),
          );
        }),
      ),
    );
  }
}
