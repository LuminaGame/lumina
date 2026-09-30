// A stand-in for the editor executable in redirection_trust_guard_test.dart,
// compiled with `dart compile exe`: it runs the same startup guard as
// `runLuminaEditor`, then writes what the process that went on starting saw.
//
//   fixture.exe [--enforce-and-start] --report <file> --junction <dir> [args...]
//
// `--enforce-and-start` makes this process a launcher that enforces
// redirection trust on itself (as Inno Setup does) and starts the fixture
// again as its child, which inherits the policy. The first process that
// runs the guard also records its own policy flags in `<report>.first`.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:lumina_ui/ui/core/host/redirection_trust_guard.dart';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == '--enforce-and-start') {
    exit(await _enforceAndStart(args.sublist(1)));
  }
  final report = args[args.indexOf('--report') + 1];
  final first = File('$report.first');
  if (!first.existsSync()) {
    first.writeAsStringSync(jsonEncode({'pid': pid, 'policyFlags': queryRedirectionTrustPolicyFlags()}));
  }
  String? explained;
  if (!RedirectionTrustGuard.startup(args, explain: (message) => explained = message)) exit(0);

  final junction = args[args.indexOf('--junction') + 1];
  String junctionResult;
  try {
    junctionResult = File('$junction\\probe.txt').readAsStringSync();
  } on FileSystemException catch (e) {
    junctionResult = e.toString();
  }
  final rest = [...args];
  for (final flag in ['--report', '--junction']) {
    final i = rest.indexOf(flag);
    rest.removeRange(i, i + 2);
  }
  File(report).writeAsStringSync(jsonEncode({
    'pid': pid,
    'policyFlags': queryRedirectionTrustPolicyFlags(),
    'relaunched': RedirectionTrustGuard.relaunched(Platform.environment),
    'explained': explained,
    'junction': junctionResult,
    'args': rest,
    'cwd': Directory.current.path,
  }));
}

Future<int> _enforceAndStart(List<String> args) async {
  final flags = calloc<Uint32>()..value = 0x1;
  try {
    final set = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<Int32 Function(Int32, Pointer<Uint32>, IntPtr), int Function(int, Pointer<Uint32>, int)>(
            'SetProcessMitigationPolicy')(16, flags, 4);
    if (set == 0) {
      stderr.writeln('SetProcessMitigationPolicy failed');
      return 2;
    }
  } finally {
    calloc.free(flags);
  }
  final child = await Process.start(
    Platform.resolvedExecutable,
    args,
    mode: ProcessStartMode.inheritStdio,
  );
  return child.exitCode;
}
