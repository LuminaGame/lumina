import 'package:lumina/lumina.dart';

/// A runner's answer for this machine's kind of setup: a 3440×1440 main
/// monitor (100, 60, 50 Hz; several lower modes, some at two refresh rates)
/// and a 1920×1080 second monitor to its right.
Map<String, Object?> twoMonitorReport({int current = 0, List<int> client = const [1280, 720]}) => {
      'monitors': [
        {
          'name': 'DELL U3419W',
          'device': r'\\.\DISPLAY1',
          'primary': true,
          'bounds': [0, 0, 3440, 1440],
          'work': [0, 0, 3440, 1392],
          'current': [3440, 1440, 60],
          'modes': [
            [3440, 1440, 60],
            [3440, 1440, 50],
            [3440, 1440, 100],
            [1920, 1080, 60],
            [1920, 1080, 100],
            [1920, 1080, 60],
            [2560, 1080, 60],
            [1280, 720, 60],
            [800, 600, 60],
            [1280, 1024, 60],
          ],
          'scale': 1.0,
        },
        {
          'name': 'Second Screen',
          'device': r'\\.\DISPLAY2',
          'primary': false,
          'bounds': [3440, 0, 5360, 1080],
          'work': [3440, 0, 5360, 1040],
          'current': [1920, 1080, 60],
          'modes': [
            [1920, 1080, 60],
            [1280, 720, 60],
          ],
          'scale': 1.0,
        },
      ],
      'current': current,
      'client': client,
    };

/// A generated runner's window as the engine sees it: mode toggles, client
/// resizes clamped to the monitor's work area (minus a 16×39 frame), moves
/// between monitors, and display reports.
class FakeRunnerWindow implements LuminaWindowModeBackend, LuminaDisplayBackend {
  FakeRunnerWindow({this.current = LuminaWindowMode.windowed, this.canResize = true});

  LuminaWindowMode current;
  final bool canResize;
  int monitor = 0;
  (int, int) client = (1280, 720);
  final List<LuminaWindowMode> appliedModes = [];
  final List<(int, int)> resizes = [];
  final List<int> moves = [];
  void Function(LuminaWindowMode mode)? _modeListener;
  void Function(LuminaDisplayInfo info)? displayListener;

  LuminaDisplayInfo get report =>
      LuminaDisplayInfo.fromMap(twoMonitorReport(current: monitor, client: [client.$1, client.$2]))!;

  @override
  Future<LuminaWindowMode?> getMode() async => current;

  @override
  Future<bool> setMode(LuminaWindowMode mode) async {
    appliedModes.add(mode);
    current = mode;
    return true;
  }

  @override
  set onModeChanged(void Function(LuminaWindowMode mode)? listener) => _modeListener = listener;

  void playerToggles() {
    current = current == LuminaWindowMode.windowed ? LuminaWindowMode.borderlessFullscreen : LuminaWindowMode.windowed;
    _modeListener?.call(current);
  }

  @override
  Future<LuminaDisplayInfo?> queryDisplays() async => report;

  @override
  Future<(int, int)?> setClientSize(int width, int height) async {
    if (!canResize) return null;
    resizes.add((width, height));
    final work = report.current!.workArea;
    client = (
      width.clamp(1, work.right - work.left - 16),
      height.clamp(1, work.bottom - work.top - 39),
    );
    return client;
  }

  @override
  Future<bool> moveToMonitor(int index) async {
    moves.add(index);
    monitor = index;
    return true;
  }

  @override
  set onDisplayChanged(void Function(LuminaDisplayInfo info)? listener) => displayListener = listener;
}

/// Installs [window] as both backends.
void installRunner(FakeRunnerWindow window) {
  LuminaGameWindow.backend = window;
  LuminaGameDisplay.backend = window;
}

/// Back to a fresh process.
void resetDisplay() {
  LuminaGameWindow.resetForTesting();
  LuminaGameDisplay.resetForTesting();
  LuminaGameUserSettingsFile.resetForTesting();
}
