import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/src/packaging/android/android_manifest_composer.dart';

/// Run with `LUMINA_UPDATE_GOLDENS=1` to rewrite the golden manifests.
final bool _update = Platform.environment['LUMINA_UPDATE_GOLDENS'] == '1';

String _fixture(String name) => File('test/packaging/fixtures/$name').readAsStringSync();

PluginAndroidContributions _contributions(String name) =>
    PluginAndroidContributions.fromJson(jsonDecode(_fixture(name)) as Map<String, dynamic>);

void _golden(String name, String actual) {
  final file = File('test/packaging/goldens/$name');
  if (_update || !file.existsSync()) file.writeAsStringSync(actual);
  expect(actual, file.readAsStringSync(), reason: 'golden $name');
}

void main() {
  final template = _fixture('flutter_template_AndroidManifest.xml');
  final openxr = (plugin: 'lumina_plugin_openxr', android: _contributions('openxr_android.json'));
  final metaxr = (plugin: 'lumina_plugin_metaxr', android: _contributions('metaxr_android.json'));
  const quest = ProjectAndroidSettings.quest();

  test('without plugins only the project settings are added', () {
    final out = AndroidManifestComposer.compose(template: template, settings: quest);
    _golden('no_plugins.xml', out.xml);
    expect(out.xml, contains('io.flutter.embedding.android.EnableImpeller'));
    expect(out.xml, isNot(contains('vr.headtracking')));
  });

  test('openxr makes an immersive launcher with the loader broker queries', () {
    final out = AndroidManifestComposer.compose(template: template, settings: quest, plugins: [openxr]);
    _golden('openxr.xml', out.xml);
    expect(out.xml, contains('<uses-feature android:name="android.hardware.vr.headtracking" android:required="true" android:version="1" />'));
    expect(out.xml, contains('android:launchMode="singleTask"'));
    expect(out.xml, isNot(contains('android:launchMode="singleTop"')));
    final config = RegExp(r'android:configChanges="([^"]*)"').firstMatch(out.xml)!.group(1)!.split('|');
    expect(config, containsAll(['density', 'navigation', 'uiMode', 'orientation']));
  });

  test('openxr + metaxr with passthrough used: the golden Quest manifest', () {
    final out = AndroidManifestComposer.compose(
      template: template,
      settings: quest,
      plugins: [openxr, metaxr],
      usedClasses: {'LuminaMetaPassthroughComponent'},
    );
    _golden('openxr_metaxr_passthrough.xml', out.xml);
    final xml = out.xml;
    expect(xml, contains('<category android:name="com.oculus.intent.category.VR" />'));
    expect(xml, contains('<category android:name="org.khronos.openxr.intent.category.IMMERSIVE_HMD" />'));
    expect(xml, contains('android:name="android.hardware.vr.headtracking" android:required="true"'));
    expect(xml, contains('<uses-feature android:name="com.oculus.feature.PASSTHROUGH" android:required="true" />'));
    expect(xml, contains('org.khronos.openxr.runtime_broker;org.khronos.openxr.system_runtime_broker'));
    expect(xml, contains('org.khronos.openxr.OpenXRRuntimeService'));
    expect(xml, contains('android:name="com.oculus.supportedDevices" android:value="quest3|quest3s|quest2|questpro"'));
    // Hand tracking is not used: neither its feature nor its permission.
    expect(xml, isNot(contains('HAND_TRACKING')));
    expect(xml, isNot(contains('PROPERTY_XR_ACTIVITY_START_MODE')));
    // The categories sit in the launcher's MAIN filter.
    final filter = RegExp(r'<intent-filter>.*?</intent-filter>', dotAll: true).firstMatch(xml)!.group(0)!;
    expect(filter, contains('IMMERSIVE_HMD'));
    expect(filter, contains('android.intent.action.MAIN'));
    // Every generated line names its source for the preview.
    final sources = {for (final l in out.lines) l.text.trim(): l.source};
    expect(sources['<uses-feature android:name="com.oculus.feature.PASSTHROUGH" android:required="true" />'], 'lumina_plugin_metaxr');
    expect(sources['<category android:name="com.oculus.intent.category.VR" />'], 'lumina_plugin_openxr');
    expect(sources['<action android:name="android.intent.action.MAIN"/>'], 'template');
  });

  test('passthrough unused stays optional; a required contributor wins over an optional one', () {
    final out = AndroidManifestComposer.compose(template: template, settings: quest, plugins: [openxr, metaxr]);
    expect(out.xml, contains('<uses-feature android:name="com.oculus.feature.PASSTHROUGH" android:required="false" />'));
    final other = (
      plugin: 'other',
      android: const PluginAndroidContributions(usesFeatures: [AndroidUsesFeature(name: 'com.oculus.feature.PASSTHROUGH', required: true)]),
    );
    final merged = AndroidManifestComposer.compose(template: template, settings: quest, plugins: [metaxr, other]);
    expect(RegExp('PASSTHROUGH').allMatches(merged.xml), hasLength(1));
    expect(merged.xml, contains('android:name="com.oculus.feature.PASSTHROUGH" android:required="true"'));
  });

  test('composing again keeps a user meta-data outside the markers and does not grow', () {
    final first = AndroidManifestComposer.compose(template: template, settings: quest, plugins: [openxr, metaxr]).xml;
    const user = '        <meta-data android:name="com.example.user_setting" android:value="kept" />\n';
    final edited = first.replaceFirst('    </application>', '$user    </application>');
    final again = AndroidManifestComposer.compose(template: edited, settings: quest, plugins: [openxr, metaxr]).xml;
    expect(again, contains('com.example.user_setting'));
    expect(RegExp(RegExp.escape(AndroidManifestComposer.begin)).allMatches(again).length,
        RegExp(RegExp.escape(AndroidManifestComposer.begin)).allMatches(first).length);
    expect(again.replaceFirst(user, ''), first);
    // Disabling the plugins removes what they added.
    final none = AndroidManifestComposer.compose(template: again, settings: const ProjectAndroidSettings()).xml;
    expect(none, isNot(contains('IMMERSIVE_HMD')));
    expect(none, contains('com.example.user_setting'));
  });

  test('a copied Android XR start-mode property is dropped', () {
    final copied = template.replaceFirst('<application',
        '<property android:name="android.window.PROPERTY_XR_ACTIVITY_START_MODE" android:value="XR_ACTIVITY_START_MODE_FULL_SPACE_UNMANAGED" />\n    <application');
    final out = AndroidManifestComposer.compose(template: copied, settings: quest, plugins: [openxr]);
    expect(out.xml, isNot(contains('PROPERTY_XR_ACTIVITY_START_MODE')));
  });
}
