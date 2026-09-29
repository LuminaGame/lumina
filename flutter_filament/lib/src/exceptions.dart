/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// Exception thrown when a Filament engine operation fails.
class FilamentException implements Exception {
  final String message;
  const FilamentException(this.message);

  @override
  String toString() => 'FilamentException: $message';
}
