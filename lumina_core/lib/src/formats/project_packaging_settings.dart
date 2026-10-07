/// The project's packaging targets (`.lmproject` `packaging`).
library;

import 'package:lumina_core/src/formats/project_web_loading_style.dart';

/// Platforms a project can be packaged for, in display order.
const List<String> kPackagingPlatforms = ['linux', 'windows', 'macos', 'android', 'ios', 'web'];

/// The name a platform id is shown under.
String packagingPlatformLabel(String id) => switch (id) {
      'linux' => 'Linux',
      'windows' => 'Windows',
      'macos' => 'macOS',
      'android' => 'Android',
      'ios' => 'iOS',
      'web' => 'Web',
      _ => id,
    };

/// The `flutter build` subcommand that packages [id] (`android` builds an APK).
String flutterBuildSubcommand(String id) => id == 'android' ? 'apk' : id;

/// The single `target_os` labels manifests stored before multi-target packaging, and
/// the platform each one migrates to.
const Map<String, String> kLegacyPackagingTargetLabels = {
  'Linux x64': 'linux',
  'Windows x64': 'windows',
  'Android APK': 'android',
};

/// The legacy single-target label → `flutter build` subcommand map.
@Deprecated('Use kPackagingPlatforms with flutterBuildSubcommand')
const Map<String, String> kPackagingTargets = {
  'Linux x64': 'linux',
  'Windows x64': 'windows',
  'Android APK': 'apk',
};

/// `packaging` section: the platforms Package Project builds, and where the
/// packages go.
class ProjectPackagingSettings {
  /// Platform ids ([kPackagingPlatforms] order, no duplicates). Ids this
  /// editor does not know are kept, so validation can name them.
  final List<String> targets;

  /// Relative to the project, or absolute.
  final String outputDir;

  /// The web build's HTML loading screen.
  final ProjectWebLoadingStyle webLoadingStyle;

  const ProjectPackagingSettings({
    this.targets = const ['linux'],
    this.outputDir = 'build',
    this.webLoadingStyle = const ProjectWebLoadingStyle(),
  });

  /// [ids] in [kPackagingPlatforms] order, unknown ids last, no duplicates.
  static List<String> ordered(Iterable<String> ids) {
    final unique = <String>{...ids};
    return [
      for (final p in kPackagingPlatforms)
        if (unique.contains(p)) p,
      for (final id in unique)
        if (!kPackagingPlatforms.contains(id)) id,
    ];
  }

  bool isSelected(String id) => targets.contains(id);

  /// The selection with [id] ticked or unticked.
  ProjectPackagingSettings withTarget(String id, bool selected) => copyWith(
        targets: ordered(selected ? [...targets, id] : targets.where((t) => t != id)),
      );

  /// [outputDir] resolved against [projectDir] (empty means `build`).
  String outputDirIn(String projectDir) {
    String trim(String p) => p.length > 1 && p.endsWith('/') ? p.substring(0, p.length - 1) : p;
    final out = outputDir.trim().isEmpty ? 'build' : trim(outputDir.trim());
    return out.startsWith('/') ? out : '${trim(projectDir)}/$out';
  }

  /// Where [id]'s package is copied: `<output dir>/package/<id>`. Not
  /// `<output dir>/<id>`: with the default `build`, `build/linux` and
  /// `build/web` are Flutter's own build trees.
  String packageDirFor(String projectDir, String id) => '${outputDirIn(projectDir)}/package/$id';

  /// The legacy single-target label of the first target, for code that still
  /// reads the single-target field.
  @Deprecated('Use targets')
  String get targetOs {
    if (targets.isEmpty) return '';
    final first = targets.first;
    return kLegacyPackagingTargetLabels.entries.firstWhere((e) => e.value == first, orElse: () => MapEntry(first, first)).key;
  }

  Map<String, dynamic> toMap() => {'targets': targets, 'output_dir': outputDir, 'web_loading_style': webLoadingStyle.toMap()};

  /// A manifest with `targets` reads it; one written before multi-target
  /// packaging migrates its `target_os` label; one with neither reads `['linux']`.
  factory ProjectPackagingSettings.fromMap(Map<String, dynamic> map) {
    final raw = map['targets'];
    final legacy = map['target_os'];
    final List<String> targets;
    if (raw is List) {
      targets = ordered(raw.whereType<String>());
    } else if (legacy is String && legacy.isNotEmpty) {
      targets = [kLegacyPackagingTargetLabels[legacy] ?? legacy];
    } else {
      targets = const ['linux'];
    }
    final style = map['web_loading_style'];
    return ProjectPackagingSettings(
      targets: targets,
      outputDir: map['output_dir'] as String? ?? 'build',
      webLoadingStyle: style is Map ? ProjectWebLoadingStyle.fromMap(Map<String, dynamic>.from(style)) : const ProjectWebLoadingStyle(),
    );
  }

  ProjectPackagingSettings copyWith({
    List<String>? targets,
    String? outputDir,
    ProjectWebLoadingStyle? webLoadingStyle,
    @Deprecated('Use targets') String? targetOs,
  }) =>
      ProjectPackagingSettings(
        targets: targets ?? (targetOs != null ? [kLegacyPackagingTargetLabels[targetOs] ?? targetOs] : this.targets),
        outputDir: outputDir ?? this.outputDir,
        webLoadingStyle: webLoadingStyle ?? this.webLoadingStyle,
      );
}
