import 'dart:convert';
import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

/// The `android` section of an OpenXR-style plugin descriptor.
Map<String, dynamic> _openXrAndroid() => {
      'uses_features': [
        {'name': 'android.hardware.vr.headtracking', 'required': true, 'version': 1},
      ],
      'permissions': ['org.khronos.openxr.permission.OPENXR', 'org.khronos.openxr.permission.OPENXR_SYSTEM'],
      'intent_categories': ['com.oculus.intent.category.VR', 'org.khronos.openxr.intent.category.IMMERSIVE_HMD'],
      'meta_data': [
        {'name': 'com.oculus.supportedDevices', 'value': 'quest3|quest3s'},
      ],
      'queries': [
        '<provider android:authorities="org.khronos.openxr.runtime_broker;org.khronos.openxr.system_runtime_broker" />',
        '<intent><action android:name="org.khronos.openxr.OpenXRRuntimeService" /></intent>',
      ],
      'activity_attributes': {'screenOrientation': 'landscape', 'launchMode': 'singleTask'},
    };

Future<File> _writeManifest(Directory dir, Map<String, dynamic> android) async {
  final plugin = Directory('${dir.path}/lumina_plugin_openxr')..createSync(recursive: true);
  final file = File('${plugin.path}/lumina_plugin_openxr.lmplugin');
  await file.writeAsString(jsonEncode({
    'name': 'lumina_plugin_openxr',
    'version': '0.1.0',
    'modules': [
      {
        'name': 'lumina_plugin_openxr_runtime',
        'type': 'runtime',
        'entry_library': 'lib/runtime.dart',
        'registration_class': 'LuminaOpenXrRuntime',
      },
    ],
    'android': android,
  }));
  return file;
}

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('plugin_android_'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('the android section of a descriptor parses into its contributions', () async {
    final manifest = await _writeManifest(temp, _openXrAndroid());
    final descriptor = await PluginRepository(roots: const []).load(manifest);
    final android = descriptor.android!;
    expect(android.usesFeatures.single.name, 'android.hardware.vr.headtracking');
    expect(android.usesFeatures.single.required, isTrue);
    expect(android.usesFeatures.single.version, 1);
    expect(android.permissions.map((p) => p.name), contains('org.khronos.openxr.permission.OPENXR_SYSTEM'));
    expect(android.intentCategories, contains('org.khronos.openxr.intent.category.IMMERSIVE_HMD'));
    expect(android.metaData.single.value, 'quest3|quest3s');
    expect(android.queries, hasLength(2));
    expect(android.activityAttributes['launchMode'], 'singleTask');
    // The section is not kept as an unknown extra, and it round-trips.
    expect(descriptor.extras.containsKey('android'), isFalse);
    expect(PluginAndroidContributions.fromJson(descriptor.toJson()['android'] as Map<String, dynamic>).toJson(), android.toJson());
    // The runtime module is the game-side entry.
    expect(descriptor.runtimeModules.single.registrationClass, 'LuminaOpenXrRuntime');
  });

  test('an unknown key in the android section is a schema error naming it', () async {
    final manifest = await _writeManifest(temp, {..._openXrAndroid(), 'uses_featurez': []});
    await expectLater(
      PluginRepository(roots: const []).load(manifest),
      throwsA(isA<PluginManifestException>()
          .having((e) => e.error.kind, 'kind', PluginErrorKind.schemaViolation)
          .having((e) => e.error.message, 'message', contains('uses_featurez'))),
    );
    // An unknown key inside an entry is named with its path.
    final nested = await _writeManifest(temp, {
      'uses_features': [
        {'name': 'android.hardware.vr.headtracking', 'requird': true},
      ],
    });
    await expectLater(
      PluginRepository(roots: const []).load(nested),
      throwsA(isA<PluginManifestException>().having((e) => e.error.message, 'message', contains('uses_features[0].requird'))),
    );
  });

  test('a query that is not a provider or an intent is refused', () {
    expect(
      () => PluginAndroidContributions.fromJson({
        'queries': ['<package android:name="com.example" />'],
      }),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('queries[0]'))),
    );
  });

  test('values come out XML-escaped', () {
    final android = PluginAndroidContributions.fromJson({
      'meta_data': [
        {'name': 'com.example.note', 'value': '"<script>" & more'},
      ],
      'activity_attributes': {'label': '<script>'},
    });
    final line = android.metaData.single.toXml();
    expect(line, contains('&quot;&lt;script&gt;&quot; &amp; more'));
    expect(line, isNot(contains('<script>')));
    expect(PluginAndroidContributions.escapeXml('<script>'), '&lt;script&gt;');
  });
}
