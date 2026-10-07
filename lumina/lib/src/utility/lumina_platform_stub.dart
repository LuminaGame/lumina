import 'package:lumina/src/utility/lumina_platform.dart';

/// Without `dart:io` (a web build) the platform is the web.
LuminaPlatform detectPlatform() => LuminaPlatform.web;
