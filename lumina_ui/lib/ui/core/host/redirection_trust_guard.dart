/// Startup guard against an inherited Windows redirection trust policy
/// (RedirectionGuard).
///
/// A process that enforces redirection trust cannot traverse NTFS junctions
/// created by a non-elevated user, and every process it starts inherits the
/// policy, which a process cannot turn off for itself. Lumina Studio's engine
/// checkout, its prebuilt folders, project engine links and editor hosts are
/// exactly such junctions, so a Studio started by a launcher that enforces the
/// policy (an installer's "Launch" checkbox, for one) cannot create or build a
/// project. [RedirectionTrustGuard.startup] relaunches the editor as a child
/// of the Windows shell, which does not carry the policy.
///
/// Pure `dart:ffi` (no Flutter imports), so a test can compile it into a
/// stand-in executable.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'package_identity.dart';

/// What startup does about the process's redirection trust policy.
enum RedirectionTrustAction {
  /// Junctions can be traversed (or the policy is unknown): start normally.
  proceed,

  /// Redirection trust is enforced: start a copy without it and exit.
  relaunch,

  /// A relaunched copy is still enforced: tell the user how to start Studio.
  explain,
}

/// `PROCESS_MITIGATION_REDIRECTION_TRUST_POLICY.EnforceRedirectionTrust`.
const int enforceRedirectionTrustFlag = 0x1;

/// Set in the environment of the relaunched copy, so it never relaunches
/// again.
const String redirectionTrustRelaunchedVariable = 'LUMINA_REDIRECTION_TRUST_RELAUNCHED';

/// The text shown when Studio cannot shed the policy by itself.
const String redirectionTrustMessage =
    'Lumina Studio was started with a Windows security option that blocks its engine folders; '
    'start it from the Start menu.';

/// The decision for [policyFlags] (`null` when they cannot be read) in a
/// process that was ([relaunched]) or was not started by this guard.
///
/// A [packaged] process (MSIX package identity) never relaunches: the copy
/// would start the packaged executable outside its package, without the
/// package's identity and its view of AppData, so the engine data would
/// split between two places. It explains instead.
RedirectionTrustAction decideRedirectionTrustAction({required int? policyFlags, required bool relaunched, bool packaged = false}) {
  if (policyFlags == null || policyFlags & enforceRedirectionTrustFlag == 0) return RedirectionTrustAction.proceed;
  return relaunched || packaged ? RedirectionTrustAction.explain : RedirectionTrustAction.relaunch;
}

/// This process's redirection trust policy flags, or `null` off Windows or
/// on a Windows without the policy (before Windows 10 22H2).
int? queryRedirectionTrustPolicyFlags() {
  if (!Platform.isWindows) return null;
  final flags = calloc<Uint32>();
  try {
    final ok = _Win32.instance.getProcessMitigationPolicy(_Win32.instance.getCurrentProcess(), _processRedirectionTrustPolicy, flags.cast(), 4);
    return ok == 0 ? null : flags.value;
  } finally {
    calloc.free(flags);
  }
}

/// [argv] as one Windows command line that `CommandLineToArgvW` (and the
/// C runtime) splits back into the same arguments.
String windowsCommandLine(List<String> argv) => argv.map(_quoteArgument).join(' ');

String _quoteArgument(String arg) {
  if (arg.isNotEmpty && !arg.contains(RegExp(r'[\s"]'))) return arg;
  final out = StringBuffer('"');
  var backslashes = 0;
  for (final unit in arg.split('')) {
    if (unit == r'\') {
      backslashes++;
      continue;
    }
    if (unit == '"') {
      out.write(r'\' * (backslashes * 2 + 1));
    } else {
      out.write(r'\' * backslashes);
    }
    backslashes = 0;
    out.write(unit);
  }
  out
    ..write(r'\' * (backslashes * 2))
    ..write('"');
  return out.toString();
}

abstract final class RedirectionTrustGuard {
  /// Whether [environment] marks a copy this guard relaunched.
  static bool relaunched(Map<String, String> environment) => environment[redirectionTrustRelaunchedVariable] == '1';

  /// Checks the policy at startup. Returns `false` when a relaunched copy has
  /// taken over (the caller exits at once); `true` when this process goes on
  /// starting, after [explain] (a message box by default) when the policy
  /// could not be shed.
  static bool startup(List<String> args, {void Function(String message)? explain}) {
    if (!Platform.isWindows) return true;
    final action = decideRedirectionTrustAction(
      policyFlags: queryRedirectionTrustPolicyFlags(),
      relaunched: relaunched(Platform.environment),
      packaged: currentPackageFamilyName() != null,
    );
    if (action == RedirectionTrustAction.proceed) return true;
    if (action == RedirectionTrustAction.relaunch && _relaunchUnderShell(args)) return false;
    (explain ?? _messageBox)(redirectionTrustMessage);
    return true;
  }

  /// Starts this executable again with [args], the same working directory
  /// and environment (plus the relaunch marker) as a child of the shell's
  /// `explorer.exe`, so it inherits the shell's mitigation policies instead
  /// of this process's. The copy is created suspended and resumed only when
  /// it no longer enforces redirection trust.
  static bool _relaunchUnderShell(List<String> args) {
    final w = _Win32.instance;
    final shell = w.getShellWindow();
    if (shell == 0) return false;
    return using((arena) {
      final shellPid = arena<Uint32>();
      w.getWindowThreadProcessId(shell, shellPid);
      if (shellPid.value == 0) return false;
      final parent = w.openProcess(_processCreateProcess, 0, shellPid.value);
      if (parent == 0) return false;
      try {
        final listSize = arena<IntPtr>();
        w.initializeProcThreadAttributeList(nullptr, 1, 0, listSize);
        final list = arena<Uint8>(listSize.value);
        if (w.initializeProcThreadAttributeList(list.cast(), 1, 0, listSize) == 0) return false;
        try {
          final parentValue = arena<IntPtr>()..value = parent;
          if (w.updateProcThreadAttribute(list.cast(), 0, _procThreadAttributeParentProcess, parentValue.cast(), sizeOf<IntPtr>(), nullptr, nullptr) == 0) {
            return false;
          }
          final startup = arena<_StartupInfoEx>();
          startup.ref.startupInfo.cb = sizeOf<_StartupInfoEx>();
          startup.ref.attributeList = list.cast();
          final info = arena<_ProcessInformation>();
          final commandLine = windowsCommandLine([Platform.resolvedExecutable, ...args]).toNativeUtf16(allocator: arena);
          final environment = _environmentBlock({...Platform.environment, redirectionTrustRelaunchedVariable: '1'}, arena);
          final created = w.createProcess(
            nullptr,
            commandLine,
            nullptr,
            nullptr,
            0,
            _extendedStartupInfoPresent | _createUnicodeEnvironment | _createSuspended | _createNoWindow,
            environment.cast(),
            Directory.current.path.toNativeUtf16(allocator: arena),
            startup.cast(),
            info,
          );
          if (created == 0) return false;
          final process = info.ref.hProcess, thread = info.ref.hThread;
          try {
            final childFlags = arena<Uint32>();
            final queried = w.getProcessMitigationPolicy(process, _processRedirectionTrustPolicy, childFlags.cast(), 4);
            if (queried == 0 || childFlags.value & enforceRedirectionTrustFlag != 0) {
              w.terminateProcess(process, 1);
              return false;
            }
            w.resumeThread(thread);
            return true;
          } finally {
            w.closeHandle(thread);
            w.closeHandle(process);
          }
        } finally {
          w.deleteProcThreadAttributeList(list.cast());
        }
      } finally {
        w.closeHandle(parent);
      }
    });
  }

  static void _messageBox(String message) {
    using((arena) {
      _Win32.instance.messageBox(0, message.toNativeUtf16(allocator: arena), 'Lumina Studio'.toNativeUtf16(allocator: arena), _mbOk | _mbIconWarning);
    });
  }
}

/// A `CREATE_UNICODE_ENVIRONMENT` block: `name=value\0` entries sorted by
/// name (case-insensitively), then one more `\0`.
Pointer<Uint16> _environmentBlock(Map<String, String> environment, Allocator allocator) {
  final names = environment.keys.toList()..sort((a, b) => a.toUpperCase().compareTo(b.toUpperCase()));
  final block = <int>[
    for (final name in names) ...[...'$name=${environment[name]}'.codeUnits, 0],
    0,
    if (names.isEmpty) 0,
  ];
  final out = allocator<Uint16>(block.length);
  out.asTypedList(block.length).setAll(0, block);
  return out;
}

const int _processRedirectionTrustPolicy = 16;
const int _processCreateProcess = 0x0080;
const int _procThreadAttributeParentProcess = 0x00020000;
const int _extendedStartupInfoPresent = 0x00080000;
const int _createUnicodeEnvironment = 0x00000400;
const int _createSuspended = 0x00000004;
const int _createNoWindow = 0x08000000;
const int _mbOk = 0x0;
const int _mbIconWarning = 0x30;

final class _StartupInfo extends Struct {
  @Uint32()
  external int cb;
  external Pointer<Utf16> lpReserved;
  external Pointer<Utf16> lpDesktop;
  external Pointer<Utf16> lpTitle;
  @Uint32()
  external int dwX;
  @Uint32()
  external int dwY;
  @Uint32()
  external int dwXSize;
  @Uint32()
  external int dwYSize;
  @Uint32()
  external int dwXCountChars;
  @Uint32()
  external int dwYCountChars;
  @Uint32()
  external int dwFillAttribute;
  @Uint32()
  external int dwFlags;
  @Uint16()
  external int wShowWindow;
  @Uint16()
  external int cbReserved2;
  external Pointer<Uint8> lpReserved2;
  @IntPtr()
  external int hStdInput;
  @IntPtr()
  external int hStdOutput;
  @IntPtr()
  external int hStdError;
}

final class _StartupInfoEx extends Struct {
  external _StartupInfo startupInfo;
  external Pointer<Void> attributeList;
}

final class _ProcessInformation extends Struct {
  @IntPtr()
  external int hProcess;
  @IntPtr()
  external int hThread;
  @Uint32()
  external int dwProcessId;
  @Uint32()
  external int dwThreadId;
}

class _Win32 {
  _Win32._() {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final user32 = DynamicLibrary.open('user32.dll');
    getCurrentProcess = kernel32.lookupFunction<IntPtr Function(), int Function()>('GetCurrentProcess');
    getProcessMitigationPolicy = kernel32
        .lookupFunction<Int32 Function(IntPtr, Int32, Pointer<Void>, IntPtr), int Function(int, int, Pointer<Void>, int)>(
            'GetProcessMitigationPolicy');
    openProcess = kernel32.lookupFunction<IntPtr Function(Uint32, Int32, Uint32), int Function(int, int, int)>('OpenProcess');
    closeHandle = kernel32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');
    initializeProcThreadAttributeList = kernel32.lookupFunction<Int32 Function(Pointer<Void>, Uint32, Uint32, Pointer<IntPtr>),
        int Function(Pointer<Void>, int, int, Pointer<IntPtr>)>('InitializeProcThreadAttributeList');
    updateProcThreadAttribute = kernel32.lookupFunction<
        Int32 Function(Pointer<Void>, Uint32, IntPtr, Pointer<Void>, IntPtr, Pointer<Void>, Pointer<IntPtr>),
        int Function(Pointer<Void>, int, int, Pointer<Void>, int, Pointer<Void>, Pointer<IntPtr>)>('UpdateProcThreadAttribute');
    deleteProcThreadAttributeList =
        kernel32.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('DeleteProcThreadAttributeList');
    createProcess = kernel32.lookupFunction<
        Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Void>, Pointer<Void>, Int32, Uint32, Pointer<Void>, Pointer<Utf16>,
            Pointer<Void>, Pointer<_ProcessInformation>),
        int Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Void>, Pointer<Void>, int, int, Pointer<Void>, Pointer<Utf16>,
            Pointer<Void>, Pointer<_ProcessInformation>)>('CreateProcessW');
    resumeThread = kernel32.lookupFunction<Uint32 Function(IntPtr), int Function(int)>('ResumeThread');
    terminateProcess = kernel32.lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>('TerminateProcess');
    getShellWindow = user32.lookupFunction<IntPtr Function(), int Function()>('GetShellWindow');
    getWindowThreadProcessId =
        user32.lookupFunction<Uint32 Function(IntPtr, Pointer<Uint32>), int Function(int, Pointer<Uint32>)>('GetWindowThreadProcessId');
    messageBox = user32.lookupFunction<Int32 Function(IntPtr, Pointer<Utf16>, Pointer<Utf16>, Uint32),
        int Function(int, Pointer<Utf16>, Pointer<Utf16>, int)>('MessageBoxW');
  }

  static final _Win32 instance = _Win32._();

  late final int Function() getCurrentProcess;
  late final int Function(int, int, Pointer<Void>, int) getProcessMitigationPolicy;
  late final int Function(int, int, int) openProcess;
  late final int Function(int) closeHandle;
  late final int Function(Pointer<Void>, int, int, Pointer<IntPtr>) initializeProcThreadAttributeList;
  late final int Function(Pointer<Void>, int, int, Pointer<Void>, int, Pointer<Void>, Pointer<IntPtr>) updateProcThreadAttribute;
  late final void Function(Pointer<Void>) deleteProcThreadAttributeList;
  late final int Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Void>, Pointer<Void>, int, int, Pointer<Void>, Pointer<Utf16>,
      Pointer<Void>, Pointer<_ProcessInformation>) createProcess;
  late final int Function(int) resumeThread;
  late final int Function(int, int) terminateProcess;
  late final int Function() getShellWindow;
  late final int Function(int, Pointer<Uint32>) getWindowThreadProcessId;
  late final int Function(int, Pointer<Utf16>, Pointer<Utf16>, int) messageBox;
}
