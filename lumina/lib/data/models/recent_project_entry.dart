import 'dart:io';
import 'lumina_project.dart';

/// Represents a tracked project entry in the launcher's recent projects list.
class RecentProjectEntry {
  final LuminaProject project;
  final String projectDir;
  final DateTime lastOpened;
  final String? coverImage;
  final bool isMissing;

  const RecentProjectEntry({
    required this.project,
    required this.projectDir,
    required this.lastOpened,
    this.coverImage,
    this.isMissing = false,
  });

  RecentProjectEntry copyWith({
    LuminaProject? project,
    String? projectDir,
    DateTime? lastOpened,
    String? coverImage,
    bool? isMissing,
  }) {
    return RecentProjectEntry(
      project: project ?? this.project,
      projectDir: projectDir ?? this.projectDir,
      lastOpened: lastOpened ?? this.lastOpened,
      coverImage: coverImage ?? this.coverImage,
      isMissing: isMissing ?? this.isMissing,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'project': project.toMap(),
      'project_dir': projectDir,
      'last_opened': lastOpened.toIso8601String(),
      'cover_image': coverImage,
    };
  }

  factory RecentProjectEntry.fromMap(Map<String, dynamic> map) {
    LuminaProject proj;
    String dir = '';
    DateTime opened = DateTime.now();
    String? cover;

    if (map.containsKey('project') && map['project'] is Map) {
      proj = LuminaProject.fromMap(map['project'] as Map<String, dynamic>);
      dir = map['project_dir'] as String? ?? '';
      opened = DateTime.tryParse(map['last_opened'] as String? ?? '') ?? DateTime.now();
      cover = map['cover_image'] as String?;
    } else {
      // Legacy flat shape migration
      proj = LuminaProject.fromMap(map);
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
      dir = map['project_dir'] as String? ?? (home.isNotEmpty ? '$home/Lumina Projects/${proj.projectName}' : proj.projectName);
      opened = DateTime.tryParse(proj.lastModifiedTimestamp) ?? DateTime.now();
    }

    final dirExists = dir.isNotEmpty && Directory(dir).existsSync();
    final manifestExists = dir.isNotEmpty && (File('$dir/${proj.projectName}.lmproject').existsSync() ||
        (dirExists && Directory(dir).listSync().any((f) => f.path.endsWith('.lmproject'))));
    final isMissing = !dirExists || !manifestExists;

    return RecentProjectEntry(
      project: proj,
      projectDir: dir,
      lastOpened: opened,
      coverImage: cover,
      isMissing: isMissing,
    );
  }
}
