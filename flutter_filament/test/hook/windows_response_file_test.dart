import 'package:flutter_test/flutter_test.dart';

import '../../hook/windows_cl_response.dart';

/// From a long package root (a project's editor copy) the Windows `cl` line outgrew cmd.exe's 8 191 characters.
/// Includes, sources and link inputs go to a response file instead.
void main() {
  // 120 characters, with a space, as under `…\Lumina Projects\<Game>\`.
  final root = r'C:\Users\someone\Lumina Projects\A Rather Long Game Name For Testing\.lumina\editor\more\and\more\to\reach\120\x';
  final includes = [for (var i = 0; i < 28; i++) '$root\\filament\\libs\\lib$i\\include'];
  final sources = [for (var i = 0; i < 50; i++) '$root\\flutter_filament\\src\\file_number_${i}_c.cpp'];
  final libs = [for (var i = 0; i < 54; i++) '$root\\filament\\out\\cmake-release-windows\\libs\\lib$i\\lib$i.lib'];

  test('every include, source and library is in the response file, quoted, one per line', () {
    final rsp = windowsClResponse(includes: includes, sources: sources, libraries: libs);
    final lines = rsp.split('\r\n');
    expect(lines, hasLength(28 + 50 + 54));
    expect(lines.first, '/I"${includes.first}"');
    expect(lines[28], '"${sources.first}"');
    expect(lines.last, '"${libs.last}"');
  });

  test('a trailing backslash cannot escape the closing quote', () {
    final rsp = windowsClResponse(includes: [r'C:\a b\inc\'], sources: const [], libraries: const []);
    expect(rsp, r'/I"C:\a b\inc"');
  });

  test('what stays on the command line is far under 8 191 characters', () {
    final rspPath = '$root\\.dart_tool\\hooks_runner\\shared\\flutter_filament\\build\\0123456789\\flutter_filament_cl.rsp';
    final flags = ['/std:c++20', '/EHsc', '/Zc:__cplusplus', '/utf-8', '/bigobj', '/W0', '/MT', '/DWIN32', windowsClResponseFlag(rspPath)];
    final commandLine = [...flags, '/LD', '/Fe:$root\\out\\flutter_filament.dll', '/link', '/MACHINE:X64'].join(' ');
    expect(commandLine.length, lessThan(1000));
    expect(windowsClResponseFlag(rspPath), '@$rspPath');
    final everything = [...includes.map((i) => '/I$i'), ...sources, ...libs].join(' ');
    expect(everything.length, greaterThan(8191), reason: 'the case the response file exists for');
  });
}
