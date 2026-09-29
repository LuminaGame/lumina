import 'dart:io';

/// Shared input validation for the use-case layer. Returns an error message or null.
String? validateProjectDir(String projectDir) {
  if (projectDir.trim().isEmpty) return 'Project directory is empty.';
  if (!Directory(projectDir).existsSync()) {
    return 'Project directory does not exist: $projectDir';
  }
  return null;
}

/// A level name must be a plain file stem: no separators, no parent references.
String? validateLevelName(String levelName) {
  if (levelName.trim().isEmpty) return 'Level name is empty.';
  if (levelName.contains('/') || levelName.contains('\\') || levelName.contains('..')) {
    return 'Level name "$levelName" must not contain path separators or "..".';
  }
  return null;
}
