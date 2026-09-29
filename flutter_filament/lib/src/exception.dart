class FilamentException implements Exception {
  final String message;
  const FilamentException(this.message);

  @override
  String toString() => 'FilamentException: $message';
}
