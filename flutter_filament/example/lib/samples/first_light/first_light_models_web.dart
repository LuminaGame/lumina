import 'dart:typed_data';

/// The web build has no file system: the first light sample shows nothing.
Future<List<(String, Uint8List)>> loadFirstLightModels(String applicationId) async => const [];

/// Where the sample looks for its models, for the on-screen hint.
String firstLightModelFolder(String applicationId) => '(not available on the web)';
