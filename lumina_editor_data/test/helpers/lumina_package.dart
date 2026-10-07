import 'dart:io';

/// A file of the engine package (`lumina/`, next to this package in the
/// workspace), such as the Third Person mannequin bundle
/// (`LuminaThirdPersonContent.bundledMeshPath`), which is a path relative to
/// the engine package.
String luminaPackageFile(String relative) => '${Directory.current.parent.path}/lumina/$relative';
