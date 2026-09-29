/// The toolbar Compile badge (the compile status): nothing compiled yet
/// this session, edited since the last compile, or the last compile's result.
enum BlueprintCompileStatus {
  unknown,
  dirty,
  error,
  warning,
  upToDate;

  String get label => switch (this) {
        BlueprintCompileStatus.unknown => 'Unknown',
        BlueprintCompileStatus.dirty => 'Dirty',
        BlueprintCompileStatus.error => 'Error',
        BlueprintCompileStatus.warning => 'Warnings',
        BlueprintCompileStatus.upToDate => 'Up to date',
      };
}
