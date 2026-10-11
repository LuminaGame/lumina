import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';

/// `flutter doctor -v` of this Windows host with a ready Android toolchain
/// (captured 2026-10-11, trimmed to the sections the parser reads).
const String _doctorAndroidReady = '''
[√] Flutter (Channel master, 3.47.0-1.0.pre-247, on Microsoft Windows [Version 10.0.26200], locale en-US) [1,2s]
    • Flutter version 3.47.0-1.0.pre-247 on channel master at C:\\Users\\canus\\flutter
[√] Windows Version (11 Pro 64-bit, 25H2, 2009) [2,4s]
[√] Android toolchain - develop for Android devices (Android SDK version 36.0.0) [639ms]
    • Android SDK at C:\\Users\\canus\\AppData\\Local\\Android\\sdk
    • Emulator version 37.2.12.0 (build_id 16428233) (CL:N/A)
    • Platform android-37.0, build-tools 36.0.0
    • Java binary at: C:\\Program Files\\Android\\Android Studio\\jbr\\bin\\java
    • All Android licenses accepted.
[√] Visual Studio - develop Windows apps (Visual Studio Community 2022 17.14.13) [196ms]
• No issues found!
''';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('host_targets_android_'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('a ready Android toolchain and the Filament archives on disk make Android buildable', () {
    final filament = '${temp.path}/filament';
    File(HostBuildTargets.androidArchive(filament))
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(16, 0));
    final host = HostBuildTargets.parseDoctor(_doctorAndroidReady, operatingSystem: 'windows');
    expect(host.toolchainReason('android'), isNull);
    final reasons = host.reasonsFor('android', engineReason: (p) => HostBuildTargets.engineUnsupportedReason(p, filamentDir: filament));
    expect(reasons, isEmpty);
  });

  test('without the archives the reason names fetch_prebuilt.dart', () {
    final host = HostBuildTargets.parseDoctor(_doctorAndroidReady, operatingSystem: 'windows');
    final filament = '${temp.path}/filament';
    Directory('$filament/out/android-release/filament/lib/arm64-v8a').createSync(recursive: true);
    final reasons = host.reasonsFor('android', engineReason: (p) => HostBuildTargets.engineUnsupportedReason(p, filamentDir: filament));
    expect(reasons, hasLength(1));
    expect(reasons.single, contains('fetch_prebuilt.dart'));
    expect(reasons.single, contains('libfilament.a'));
  });
}
