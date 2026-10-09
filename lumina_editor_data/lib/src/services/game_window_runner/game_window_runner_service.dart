import 'dart:io';

import 'package:lumina_editor_data/src/services/game_window_runner/linux_display_sources.dart';
import 'package:lumina_editor_data/src/services/game_window_runner/linux_sources.dart';
import 'package:lumina_editor_data/src/services/game_window_runner/windows_display_sources.dart';
import 'package:lumina_editor_data/src/services/game_window_runner/windows_sources.dart';

/// What [GameWindowRunnerService.apply] did.
class GameWindowRunnerReport {
  const GameWindowRunnerReport({this.files = const [], this.warnings = const []});

  /// Project-relative paths written (only files whose content changed).
  final List<String> files;

  /// Runner files whose anchor was not found: that platform's game has no
  /// window modes until the runner is regenerated (`flutter create`).
  final List<String> warnings;
}

/// Gives a game project's desktop runners their window modes: windowed and
/// borderless fullscreen, the project's Start Fullscreen at launch, Alt+Enter
/// and F11 toggles, the monitors and the window size for the game's screen
/// resolution, and the `lumina/game_window` channel `LuminaGameWindow` and
/// `LuminaGameDisplay` drive.
///
/// Writes `windows/runner/lumina_window_mode.{h,cpp}` and
/// `linux/runner/lumina_window_mode.{h,cc}` (regenerated each time) and hooks
/// them into the runners `flutter create` wrote: the source lists in the
/// runner `CMakeLists.txt`, one call in `flutter_window.cpp` /
/// `my_application.cc`. Idempotent; a file is only written when its content
/// changes, so an unchanged project does not rebuild its runner.
abstract final class GameWindowRunnerService {
  static const String blockBegin = '// BEGIN LUMINA WINDOW MODE (generated: Project Settings > Start Fullscreen)';
  static const String blockEnd = '// END LUMINA WINDOW MODE';

  /// Writes and hooks the window-mode sources into [projectDir]'s Windows and
  /// Linux runners (a platform without a runner folder is skipped).
  static GameWindowRunnerReport apply(String projectDir, {required bool startFullscreen}) {
    final files = <String>[];
    final warnings = <String>[];
    if (Directory('$projectDir/windows/runner').existsSync()) {
      _windows(projectDir, startFullscreen, files, warnings);
    }
    if (Directory('$projectDir/linux').existsSync()) {
      _linux(projectDir, startFullscreen, files, warnings);
    }
    return GameWindowRunnerReport(files: files, warnings: warnings);
  }

  /// The Windows `.cpp` for [startFullscreen].
  static String windowsSource({required bool startFullscreen}) =>
      kWindowsWindowModeSource
          .replaceFirst('{{START_FULLSCREEN}}', '$startFullscreen')
          .replaceFirst('{{DISPLAY}}', kWindowsDisplaySource.trim())
          .trimLeft();

  /// The Linux `.cc` for [startFullscreen].
  static String linuxSource({required bool startFullscreen}) =>
      kLinuxWindowModeSource
          .replaceFirst('{{START_FULLSCREEN}}', startFullscreen ? 'TRUE' : 'FALSE')
          .replaceFirst('{{DISPLAY}}', kLinuxDisplaySource.trim())
          .trimLeft();

  static void _windows(String projectDir, bool startFullscreen, List<String> files, List<String> warnings) {
    const runner = 'windows/runner';
    _write(projectDir, '$runner/lumina_window_mode.h', kWindowsWindowModeHeader.trimLeft(), files);
    _write(projectDir, '$runner/lumina_window_mode.cpp', windowsSource(startFullscreen: startFullscreen), files);
    _patch(projectDir, '$runner/CMakeLists.txt', (s) => addSource(s, 'lumina_window_mode.cpp', after: 'main.cpp'), files,
        warnings, 'no add_executable(... "main.cpp" ...) to add lumina_window_mode.cpp to');
    _patch(projectDir, '$runner/flutter_window.cpp', patchFlutterWindow, files, warnings,
        'no SetChildContent(...) line to attach the window modes after');
    // The screen-sized window earlier versions wrote is the template window
    // again: fullscreen is the window mode now.
    _patch(projectDir, '$runner/main.cpp', revertScreenSizedMainCpp, files, warnings, null);
  }

  static void _linux(String projectDir, bool startFullscreen, List<String> files, List<String> warnings) {
    const runner = 'linux/runner';
    final app = File('$projectDir/$runner/my_application.cc');
    if (!app.existsSync()) {
      warnings.add('$runner/my_application.cc is missing: the Linux game has no window modes');
      return;
    }
    _write(projectDir, '$runner/lumina_window_mode.h', kLinuxWindowModeHeader.trimLeft(), files);
    _write(projectDir, '$runner/lumina_window_mode.cc', linuxSource(startFullscreen: startFullscreen), files);
    // Current templates list the sources in linux/runner/CMakeLists.txt,
    // older ones in linux/CMakeLists.txt (as runner/my_application.cc).
    final runnerCmake = File('$projectDir/$runner/CMakeLists.txt');
    if (runnerCmake.existsSync() && runnerCmake.readAsStringSync().contains('"my_application.cc"')) {
      _patch(projectDir, '$runner/CMakeLists.txt', (s) => addSource(s, 'lumina_window_mode.cc', after: 'my_application.cc'),
          files, warnings, 'no add_executable(... "my_application.cc" ...)');
    } else {
      _patch(projectDir, 'linux/CMakeLists.txt',
          (s) => addSource(s, 'runner/lumina_window_mode.cc', after: 'runner/my_application.cc'), files, warnings,
          'no add_executable(... "runner/my_application.cc" ...)');
    }
    _patch(projectDir, '$runner/my_application.cc', patchMyApplication, files, warnings,
        'no fl_register_plugins(...) line to attach the window modes after');
  }

  /// [cmake] with `"<source>"` added after the `"<after>"` entry of its
  /// `add_executable`; unchanged when present; null without the anchor.
  static String? addSource(String cmake, String source, {required String after}) {
    if (cmake.contains('"$source"')) return cmake;
    final anchor = RegExp('^([ \\t]*)"${RegExp.escape(after)}"[ \\t]*\$', multiLine: true).firstMatch(cmake);
    if (anchor == null) return null;
    final indent = anchor.group(1)!;
    return cmake.replaceRange(anchor.end, anchor.end, '\n$indent"$source"');
  }

  /// `flutter_window.cpp` with the include and the attach call after
  /// `SetChildContent` (the Flutter view's window exists from there); null
  /// without that line.
  static String? patchFlutterWindow(String source) {
    var s = _stripBlock(source);
    final child = RegExp(r'^[ \t]*SetChildContent\(.*\);[ \t]*$', multiLine: true).firstMatch(s);
    if (child == null) return null;
    s = s.replaceRange(child.end, child.end, '''

  $blockBegin
  LuminaWindowModeAttach(flutter_controller_->engine()->messenger(), GetHandle(),
                         flutter_controller_->view()->GetNativeWindow());
  $blockEnd''');
    return _addInclude(s, 'flutter_window.h');
  }

  /// `my_application.cc` with the include and the attach call after
  /// `fl_register_plugins`; null without that line.
  static String? patchMyApplication(String source) {
    var s = _stripBlock(source);
    final plugins = RegExp(r'^[ \t]*fl_register_plugins\(.*\);[ \t]*$', multiLine: true).firstMatch(s);
    if (plugins == null) return null;
    s = s.replaceRange(plugins.end, plugins.end, '''

  $blockBegin
  lumina_window_mode_attach(window, view);
  $blockEnd''');
    return _addInclude(s, 'my_application.h');
  }

  /// `main.cpp` with the screen-sized window of earlier versions back to the
  /// template's 1280×720 at (10, 10).
  static String revertScreenSizedMainCpp(String source) => source.replaceAll(
        RegExp(r'Win32Window::Point origin\(0,\s*0\);(\s*)Win32Window::Size size\(GetSystemMetrics\(SM_CXSCREEN\),\s*GetSystemMetrics\(SM_CYSCREEN\)\);'),
        'Win32Window::Point origin(10, 10);\n  Win32Window::Size size(1280, 720);',
      );

  static String _addInclude(String source, String afterHeader) {
    const include = '#include "lumina_window_mode.h"';
    if (source.contains(include)) return source;
    final anchor = RegExp('^#include "${RegExp.escape(afterHeader)}"[ \\t]*\$', multiLine: true).firstMatch(source);
    if (anchor == null) return '$include\n$source';
    return source.replaceRange(anchor.end, anchor.end, '\n$include');
  }

  static String _stripBlock(String source) {
    final start = source.indexOf(blockBegin);
    if (start < 0) return source;
    final stop = source.indexOf(blockEnd, start);
    if (stop < 0) return source;
    // From the blank line before the block to the end of its last line.
    var from = source.lastIndexOf('\n', start);
    if (from > 0 && source.substring(source.lastIndexOf('\n', from - 1) + 1, from).trim().isEmpty) {
      from = source.lastIndexOf('\n', from - 1);
    }
    return source.substring(0, from) + source.substring(stop + blockEnd.length);
  }

  static void _write(String projectDir, String rel, String content, List<String> files) {
    final file = File('$projectDir/$rel');
    if (file.existsSync() && file.readAsStringSync() == content) return;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content, flush: true);
    files.add(rel);
  }

  static void _patch(String projectDir, String rel, String? Function(String) patch, List<String> files,
      List<String> warnings, String? missingAnchor) {
    final file = File('$projectDir/$rel');
    if (!file.existsSync()) {
      if (missingAnchor != null) warnings.add('$rel is missing: $missingAnchor');
      return;
    }
    final before = file.readAsStringSync();
    final after = patch(before);
    if (after == null) {
      if (missingAnchor != null) warnings.add('$rel: $missingAnchor');
      return;
    }
    if (after == before) return;
    file.writeAsStringSync(after, flush: true);
    files.add(rel);
  }
}
