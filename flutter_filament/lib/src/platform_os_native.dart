/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'dart:io' show Platform;

/// Whether the process runs on Android (native builds).
bool get hostIsAndroid => Platform.isAndroid;
