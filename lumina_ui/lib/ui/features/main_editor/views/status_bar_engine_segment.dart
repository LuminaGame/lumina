import 'package:lumina/lumina.dart' show LuminaRenderBackendInfo;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The status bar's `Filament <version>` segment: Filament's
/// logo tinted to the muted foreground (so it reads on every theme), the
/// linked version, a tooltip with the material version, and [onPressed]
/// (Help ▸ About).
class FilamentStatusSegment extends StatelessWidget {
  /// The raster mark (transparent, 64 px high) — tinted, a flat shape reads
  /// better than the SVG's gloss at 12 px.
  static const String logoAsset = 'assets/third_party/filament/filament_logo_64.png';

  final VoidCallback? onPressed;
  const FilamentStatusSegment({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground);
    return Tooltip(
      tooltip: (context) => TooltipContainer(
        child: Text(
          'Rendered by Filament ${LuminaRenderBackendInfo.filamentVersion} '
          '(material ${LuminaRenderBackendInfo.filamentMaterialVersion})',
        ),
      ),
      child: Clickable(
        key: const ValueKey('status_filament_segment'),
        mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              logoAsset,
              key: const ValueKey('status_filament_logo'),
              height: 12,
              color: EditorColors.mutedForeground,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(width: 4),
            Text('Filament ${LuminaRenderBackendInfo.filamentVersion}', style: style),
          ],
        ),
      ),
    );
  }
}
