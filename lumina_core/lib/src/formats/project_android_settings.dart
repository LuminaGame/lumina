/// The project's Android packaging settings (`.lmproject`
/// `packaging.android`).
library;

/// The XR profiles an Android build can target.
const List<String> kAndroidXrProfiles = ['none', 'quest'];

/// The name an XR profile is shown under.
String androidXrProfileLabel(String profile) => switch (profile) {
      'quest' => 'Meta Quest',
      _ => 'None (phone / tablet)',
    };

/// The Android API levels Meta's Horizon Store asks of Quest apps,
/// recommended for every in-lifecycle Quest (read from Meta's
/// "Meta Horizon Apps Must Target Android 14" notice and its manifest
/// requirements page on 2026-10-11): minSdk 32, targetSdk 34.
const int kQuestMinSdk = 32;
const int kQuestTargetSdk = 34;

/// The display refresh rates a Quest profile can ask for.
const List<int> kQuestRefreshRates = [72, 90, 120];

/// `packaging.android`: what an Android (APK) build of the game is.
class ProjectAndroidSettings {
  /// The application id; empty means `com.lumina.<project_snake>`
  /// ([applicationIdFor]).
  final String applicationId;
  final String versionName;
  final int versionCode;
  final int minSdk;
  final int targetSdk;

  /// The ABIs the APK carries (`arm64-v8a` only for a Quest).
  final List<String> abis;

  /// Flutter's Impeller renderer for the app's own UI (off by default for a
  /// Quest: the game renders through Filament on the runtime's device).
  final bool impeller;

  /// `none` or `quest` ([kAndroidXrProfiles]).
  final String xr;

  /// The display refresh rate an immersive game asks the headset for (Hz).
  final int refreshRate;

  /// Both eyes in one multiview pass.
  final bool multiview;

  /// A release keystore (relative to the project, or absolute) and its key
  /// alias; empty signs with Flutter's debug key. Passwords are never stored
  /// here: they come from the OS keychain or the environment.
  final String keystorePath;
  final String keyAlias;

  const ProjectAndroidSettings({
    this.applicationId = '',
    this.versionName = '1.0.0',
    this.versionCode = 1,
    this.minSdk = 24,
    this.targetSdk = 34,
    this.abis = const ['arm64-v8a'],
    this.impeller = true,
    this.xr = 'none',
    this.refreshRate = 72,
    this.multiview = true,
    this.keystorePath = '',
    this.keyAlias = '',
  });

  /// The settings a new Meta Quest target starts from.
  const ProjectAndroidSettings.quest({
    this.applicationId = '',
    this.versionName = '1.0.0',
    this.versionCode = 1,
    this.refreshRate = 72,
    this.multiview = true,
    this.keystorePath = '',
    this.keyAlias = '',
  })  : minSdk = kQuestMinSdk,
        targetSdk = kQuestTargetSdk,
        abis = const ['arm64-v8a'],
        impeller = false,
        xr = 'quest';

  bool get isQuest => xr == 'quest';

  /// Whether a release keystore is configured.
  bool get hasReleaseKeystore => keystorePath.trim().isNotEmpty && keyAlias.trim().isNotEmpty;

  /// `My Game 2` → `my_game_2`: the last segment of the default id.
  static String snakeName(String projectName) {
    var s = projectName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (s.isEmpty) s = 'game';
    if (RegExp(r'^[0-9]').hasMatch(s)) s = 'g_$s';
    return s;
  }

  /// The application id the build uses for [projectName].
  String applicationIdFor(String projectName) =>
      applicationId.trim().isEmpty ? 'com.lumina.${snakeName(projectName)}' : applicationId.trim();

  /// Why [id] is not a valid application id, or null.
  static String? applicationIdProblem(String id) {
    if (id.isEmpty) return null;
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$').hasMatch(id)) {
      return 'An application id is two or more dot-separated segments, each starting with a letter (com.studio.game).';
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
        if (applicationId.isNotEmpty) 'application_id': applicationId,
        'version_name': versionName,
        'version_code': versionCode,
        'min_sdk': minSdk,
        'target_sdk': targetSdk,
        'abis': abis,
        'impeller': impeller,
        'xr': xr,
        'refresh_rate': refreshRate,
        'multiview': multiview,
        if (keystorePath.isNotEmpty) 'keystore_path': keystorePath,
        if (keyAlias.isNotEmpty) 'key_alias': keyAlias,
      };

  factory ProjectAndroidSettings.fromMap(Map<String, dynamic> map) {
    int i(String key, int fallback) => map[key] is num ? (map[key] as num).toInt() : fallback;
    final xr = map['xr'] is String && kAndroidXrProfiles.contains(map['xr']) ? map['xr'] as String : 'none';
    final quest = xr == 'quest';
    final abis = map['abis'] is List ? (map['abis'] as List).whereType<String>().toList() : const ['arm64-v8a'];
    return ProjectAndroidSettings(
      applicationId: map['application_id'] as String? ?? '',
      versionName: map['version_name'] as String? ?? '1.0.0',
      versionCode: i('version_code', 1),
      minSdk: i('min_sdk', quest ? kQuestMinSdk : 24),
      targetSdk: i('target_sdk', kQuestTargetSdk),
      abis: abis.isEmpty ? const ['arm64-v8a'] : abis,
      impeller: map['impeller'] is bool ? map['impeller'] as bool : !quest,
      xr: xr,
      refreshRate: i('refresh_rate', 72),
      multiview: map['multiview'] is bool ? map['multiview'] as bool : true,
      keystorePath: map['keystore_path'] as String? ?? '',
      keyAlias: map['key_alias'] as String? ?? '',
    );
  }

  ProjectAndroidSettings copyWith({
    String? applicationId,
    String? versionName,
    int? versionCode,
    int? minSdk,
    int? targetSdk,
    List<String>? abis,
    bool? impeller,
    String? xr,
    int? refreshRate,
    bool? multiview,
    String? keystorePath,
    String? keyAlias,
  }) =>
      ProjectAndroidSettings(
        applicationId: applicationId ?? this.applicationId,
        versionName: versionName ?? this.versionName,
        versionCode: versionCode ?? this.versionCode,
        minSdk: minSdk ?? this.minSdk,
        targetSdk: targetSdk ?? this.targetSdk,
        abis: abis ?? this.abis,
        impeller: impeller ?? this.impeller,
        xr: xr ?? this.xr,
        refreshRate: refreshRate ?? this.refreshRate,
        multiview: multiview ?? this.multiview,
        keystorePath: keystorePath ?? this.keystorePath,
        keyAlias: keyAlias ?? this.keyAlias,
      );

  /// The profile switched to [profile], with that profile's floors and
  /// defaults (Quest: minSdk 32 / targetSdk 34, arm64 only, Impeller off).
  ProjectAndroidSettings withXrProfile(String profile) => profile == 'quest'
      ? copyWith(
          xr: 'quest',
          minSdk: minSdk < kQuestMinSdk ? kQuestMinSdk : minSdk,
          targetSdk: targetSdk < kQuestTargetSdk ? kQuestTargetSdk : targetSdk,
          abis: const ['arm64-v8a'],
          impeller: false)
      : copyWith(xr: 'none', impeller: true);

  @override
  bool operator ==(Object other) =>
      other is ProjectAndroidSettings && _mapEquals(toMap(), other.toMap());

  @override
  int get hashCode => toMap().toString().hashCode;

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) => a.toString() == b.toString();
}
