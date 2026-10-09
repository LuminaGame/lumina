part of '../project_repository.dart';

enum ProjectCreationStep {
  folderSetup,
  flutterCreate,
  contentsTree,
  pubspecPatch,
  pubGet,
  manifestAndLevel,
  openingEditor,
}

class ProjectCreationProgress {
  final ProjectCreationStep step;
  final double progress;
  final String message;

  ProjectCreationProgress(this.step, this.progress, this.message);
}

class ProjectCreationException implements Exception {
  final ProjectCreationStep step;
  final String message;

  ProjectCreationException(this.step, this.message);
  
  @override
  String toString() => 'ProjectCreationException(step: $step, message: $message)';
}

typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments, {String? workingDirectory, bool runInShell});
