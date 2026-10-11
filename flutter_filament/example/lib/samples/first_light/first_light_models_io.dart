import 'dart:io';
import 'dart:typed_data';

/// The glTF binaries the first light sample shows, read from disk:
/// - on Android, the app's external files folder (`adb push model.glb
///   /sdcard/Android/data/APPLICATION_ID/files/first_light/`);
/// - elsewhere, `LUMINA_TEST_ASSETS` or the workspace's `test-assets`,
///   `Props/Barrels`.
Future<List<(String, Uint8List)>> loadFirstLightModels(String applicationId) async {
  final Directory dir;
  if (Platform.isAndroid) {
    dir = Directory('/storage/emulated/0/Android/data/$applicationId/files/first_light');
  } else {
    final root = Platform.environment['LUMINA_TEST_ASSETS'] ?? '../../../test-assets';
    dir = Directory('$root/Props/Barrels');
  }
  if (!await dir.exists()) return const [];
  final files = [
    await for (final entity in dir.list())
      if (entity is File && entity.path.toLowerCase().endsWith('.glb')) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files.take(3)) (file.uri.pathSegments.last, await file.readAsBytes()),
  ];
}

/// Where the sample looks for its models, for the on-screen hint.
String firstLightModelFolder(String applicationId) => Platform.isAndroid
    ? '/sdcard/Android/data/$applicationId/files/first_light/'
    : r'$LUMINA_TEST_ASSETS/Props/Barrels';
