import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// Run by `gpu_test.dart` in a child process with `VK_DEVICE_INDEX` set:
/// prints the device an engine created with no preference lands on.
void main() {
  test('probe', () {
    final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
    // ignore: avoid_print
    print('GPU_PROBE=${engine.gpuName}');
    engine.dispose();
  });
}
