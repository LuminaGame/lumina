import 'dart:io';

import 'package:lumina_ui/tooling/windows_packaging/certificates.dart' show runPowerShell;
import 'package:path/path.dart' as p;

/// Windows desktop helpers for smokes that drive a separate app process
/// (the installed MSIX). Windows only; plain Dart, no
/// Flutter, so a scratch `dart run` can use them too.

/// Git Bash's sh.exe (the `tool/*.sh` scripts are POSIX).
String? findGitSh() {
  final where = Process.runSync('where', ['git'], runInShell: true);
  for (final line in (where.stdout as String).split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty)) {
    // …\Git\cmd\git.exe or …\Git\mingw64\bin\git.exe → …\Git\bin\sh.exe
    var dir = p.dirname(line.trim());
    for (var i = 0; i < 3; i++) {
      final sh = p.join(dir, 'bin', 'sh.exe');
      if (File(sh).existsSync()) return sh;
      dir = p.dirname(dir);
    }
  }
  const fallback = r'C:\Program Files\Git\bin\sh.exe';
  return File(fallback).existsSync() ? fallback : null;
}

/// Ids of the running [processName] processes whose image path matches the
/// PowerShell wildcard [pathLike].
Future<List<int>> processIds(String processName, {String pathLike = '*'}) async {
  final r = await runPowerShell(
    r"Get-Process -Name $env:LPW_NAME -ErrorAction SilentlyContinue | "
    r"Where-Object { $_.Path -like $env:LPW_LIKE } | ForEach-Object { $_.Id }",
    environment: {'LPW_NAME': processName, 'LPW_LIKE': pathLike},
  );
  return [for (final l in (r.stdout as String).split(RegExp(r'\s+'))) if (int.tryParse(l) != null) int.parse(l)];
}

const String _win32 = r'''
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class LpwWin {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@
function Find-LpwWindow([uint32]$procId) {
  $script:found = [IntPtr]::Zero
  [LpwWin]::EnumWindows({ param($h, $l)
    $wp = 0; [void][LpwWin]::GetWindowThreadProcessId($h, [ref]$wp)
    if ($wp -eq $procId -and [LpwWin]::IsWindowVisible($h)) {
      $r = New-Object LpwWin+RECT; [void][LpwWin]::GetWindowRect($h, [ref]$r)
      if (($r.R - $r.L) -gt 200 -and ($r.B - $r.T) -gt 200) { $script:found = $h; return $false }
    }
    return $true }, [IntPtr]::Zero) | Out-Null
  return $script:found
}
''';

/// Moves [pid]'s main window onto DISPLAY1 (the non-Samsung monitor), sized
/// [width]×[height] (clamped to the monitor), brings it to the front and
/// returns its screen rectangle (x, y, w, h); null while it has no window.
Future<(int, int, int, int)?> placeOnDisplay1(int pid, {int width = 1600, int height = 1000}) async {
  const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::AllScreens | Where-Object { $_.DeviceName -eq '\\.\DISPLAY1' }
if (-not $screen) { [Console]::Error.WriteLine('DISPLAY1 not found'); exit 3 }
$h = Find-LpwWindow ([uint32]$env:LPW_PID)
if ($h -eq [IntPtr]::Zero) { exit 4 }
$wa = $screen.WorkingArea
[void][LpwWin]::ShowWindow($h, 9)
$w = [Math]::Min([int]$env:LPW_W, $wa.Width - 80); $hh = [Math]::Min([int]$env:LPW_H, $wa.Height - 80)
[void][LpwWin]::SetWindowPos($h, [IntPtr]::Zero, $wa.X + 40, $wa.Y + 40, $w, $hh, 0x0040)
[void][LpwWin]::SetForegroundWindow($h)
Start-Sleep -Milliseconds 300
$r = New-Object LpwWin+RECT; [void][LpwWin]::GetWindowRect($h, [ref]$r)
[Console]::Out.Write("$($r.L) $($r.T) $($r.R - $r.L) $($r.B - $r.T)")
''';
  final r = await runPowerShell(_win32 + script, environment: {'LPW_PID': '$pid', 'LPW_W': '$width', 'LPW_H': '$height'});
  if (r.exitCode == 3) throw StateError('DISPLAY1 not found: ${r.stderr}');
  if (r.exitCode != 0) return null;
  final v = (r.stdout as String).trim().split(' ').map(int.parse).toList();
  return (v[0], v[1], v[2], v[3]);
}

/// A PNG of [pid]'s window alone (PrintWindow with full content), never the
/// desktop.
Future<File> windowPng(int pid, String out) async {
  const script = r'''
Add-Type -AssemblyName System.Drawing
$h = Find-LpwWindow ([uint32]$env:LPW_PID)
if ($h -eq [IntPtr]::Zero) { exit 4 }
$r = New-Object LpwWin+RECT; [void][LpwWin]::GetWindowRect($h, [ref]$r)
$bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
$g = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
[void][LpwWin]::PrintWindow($h, $hdc, 2)
$g.ReleaseHdc($hdc); $g.Dispose()
$bmp.Save($env:LPW_OUT, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
''';
  final r = await runPowerShell(_win32 + script, environment: {'LPW_PID': '$pid', 'LPW_OUT': out});
  if (r.exitCode != 0) throw StateError('window capture failed (${r.exitCode}): ${r.stderr}');
  return File(out);
}

/// Distinct colours in a coarse sample of [png] (a blank window has ~1).
Future<int> distinctColours(File png) async {
  final r = await runPowerShell(r'''
Add-Type -AssemblyName System.Drawing
$b = [System.Drawing.Bitmap]::FromFile($env:LPW_PNG); $set = @{}
for ($y = 0; $y -lt $b.Height; $y += 17) { for ($x = 0; $x -lt $b.Width; $x += 17) { $set[$b.GetPixel($x, $y).ToArgb()] = 1 } }
$b.Dispose(); [Console]::Out.Write($set.Count)
''', environment: {'LPW_PNG': png.path});
  return int.tryParse((r.stdout as String).trim()) ?? 0;
}

/// ffmpeg: on PATH or WinGet's links folder.
String findFfmpeg() {
  for (final c in [
    'ffmpeg',
    p.join(Platform.environment['LOCALAPPDATA'] ?? '', 'Microsoft', 'WinGet', 'Links', 'ffmpeg.exe'),
  ]) {
    try {
      if (Process.runSync(c, ['-version']).exitCode == 0) return c;
    } on ProcessException {
      continue;
    }
  }
  throw StateError('ffmpeg not found (winget install Gyan.FFmpeg.Essentials)');
}

/// Records the screen rectangle ([x], [y], [w]×[h]) for [seconds] at 30 fps
/// (ffmpeg gdigrab of that region only) and encodes it as a smoke WebM with
/// the libvpx settings of `SmokeArtifacts.encodeWebmFromRawFile`. Start it,
/// drive the app, then await the returned future.
Future<File> recordRegionWebm({
  required int x,
  required int y,
  required int w,
  required int h,
  required String outWebm,
  int seconds = 12,
}) async {
  final ffmpeg = findFfmpeg();
  final raw = p.setExtension(outWebm, '.mkv');
  final evenW = w - w % 2, evenH = h - h % 2;
  final record = await Process.run(ffmpeg, [
    '-y', '-loglevel', 'error', '-f', 'gdigrab', '-framerate', '30', '-draw_mouse', '0',
    '-offset_x', '$x', '-offset_y', '$y', '-video_size', '${evenW}x$evenH', '-i', 'desktop',
    '-t', '$seconds', '-c:v', 'libx264rgb', '-preset', 'ultrafast', '-qp', '0', raw,
  ]);
  if (record.exitCode != 0) throw StateError('gdigrab recording failed: ${record.stderr}');
  final encode = await Process.run(ffmpeg, [
    '-y', '-loglevel', 'error', '-i', raw,
    '-c:v', 'libvpx', '-crf', '6', '-qmin', '0', '-qmax', '16', '-b:v', '20M',
    '-deadline', 'good', '-cpu-used', '2', '-g', '150', '-auto-alt-ref', '0',
    '-pix_fmt', 'yuv420p', '-r', '30', '-f', 'webm', outWebm,
  ]);
  if (encode.exitCode != 0) throw StateError('WebM encoding failed: ${encode.stderr}');
  File(raw).deleteSync();
  return File(outWebm);
}

/// Kills [pid] and its children.
Future<void> killTree(int pid) => Process.run('taskkill', ['/PID', '$pid', '/T', '/F']);
