import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lumina/lumina.dart' show LuminaGraphicsDevices, LuminaRelease, LuminaRenderBackendInfo;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';

/// The renderer the status bar and About name: `RHI: Vulkan · <gpu>`, the GPU
/// the editor renders on.
String rhiLabel(String? gpu) => 'RHI: Vulkan${gpu == null ? '' : ' · $gpu'}';

/// Filament's logo in the variant that reads on the current theme: the
/// light-on-dark mark on the dark themes, the dark mark on the light one
/// (`assets/third_party/filament/`, Apache-2.0, unmodified artwork).
class FilamentLogo extends StatelessWidget {
  static const String onDarkAsset = 'assets/third_party/filament/filament_logo.svg';
  static const String onLightAsset = 'assets/third_party/filament/filament_logo_on_light.svg';

  final double height;
  const FilamentLogo({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return SvgPicture.asset(light ? onLightAsset : onDarkAsset, height: height, semanticsLabel: 'Filament');
  }
}

/// Help ▸ About: Lumina's version (and, in a release build, its release tag
/// and commit), then what renders it —
/// Filament's logo, version, material version and licence, read from the
/// linked library through package:lumina.
void showAboutLuminaDialog(BuildContext context, {required String engineVersion}) {
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (c) => AboutLuminaDialog(engineVersion: engineVersion, onClose: () => Navigator.of(c).pop()),
  );
}

class AboutLuminaDialog extends StatelessWidget {
  final String engineVersion;
  final VoidCallback onClose;

  /// The release tag and commit (`LUMINA_VERSION` / `LUMINA_COMMIT`, empty
  /// in a dev build); default [LuminaRelease].
  final String releaseVersion;
  final String releaseCommit;

  const AboutLuminaDialog({
    super.key,
    required this.engineVersion,
    required this.onClose,
    this.releaseVersion = LuminaRelease.version,
    this.releaseCommit = LuminaRelease.commit,
  });

  /// `Release v0.1.0 · commit 0123abc…`, or null in a dev build.
  String? get releaseLine {
    if (releaseVersion.isEmpty && releaseCommit.isEmpty) return null;
    return [
      if (releaseVersion.isNotEmpty) 'Release $releaseVersion',
      if (releaseCommit.isNotEmpty) 'commit $releaseCommit',
    ].join(' · ');
  }

  String get _filament => 'Filament ${LuminaRenderBackendInfo.filamentVersion}';

  /// What Copy version info puts on the clipboard.
  String versionInfo() => [
        'Lumina Engine $engineVersion',
        ?releaseLine,
        '$_filament (material ${LuminaRenderBackendInfo.filamentMaterialVersion})',
        rhiLabel(LuminaGraphicsDevices.inUse.value),
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 11, color: EditorColors.mutedForeground);
    return AlertDialog(
      title: const Text('About Lumina Studio'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset('assets/logo_color.png', height: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lumina Engine $engineVersion', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      if (releaseLine != null)
                        Text(releaseLine!, key: const ValueKey('about_release'), style: muted),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Rendering', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.mutedForeground)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FilamentLogo(key: ValueKey('about_filament_logo'), height: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_filament, style: const TextStyle(fontSize: 12)),
                      Text(
                        'Material version ${LuminaRenderBackendInfo.filamentMaterialVersion} · ${LuminaRenderBackendInfo.filamentLicense}',
                        style: muted,
                      ),
                      Text(LuminaRenderBackendInfo.filamentUrl, style: muted),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        OutlineButton(
          key: const ValueKey('about_copy_version_info'),
          onPressed: () => Clipboard.setData(ClipboardData(text: versionInfo())),
          child: const Text('Copy version info'),
        ),
        PrimaryButton(key: const ValueKey('about_close'), onPressed: onClose, child: const Text('Close')),
      ],
    );
  }
}
