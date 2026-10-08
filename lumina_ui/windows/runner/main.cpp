#include <flutter/dart_project.h>
#include <flutter/flutter_engine.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

namespace {

// The flag an editor starts its own executable with to run one isolated
// plugin's process part (`PluginProcessLaunch.flag` in Dart).
constexpr char kPluginProcessFlag[] = "--lumina-plugin-process";

// The flag a file manager's thumbnailer starts the editor with to render one
// model file's thumbnail (`ModelThumbnailCommand.flag` in Dart).
constexpr char kThumbnailFlag[] = "--lumina-thumbnail";

bool HasFlag(const std::vector<std::string>& arguments, const char* flag) {
  return std::find(arguments.begin(), arguments.end(), flag) !=
         arguments.end();
}

// Both run windowless: a plugin process, and a thumbnail render (which draws
// on Filament's own headless swap chain, never through Flutter).
bool IsHeadless(const std::vector<std::string>& arguments) {
  return HasFlag(arguments, kPluginProcessFlag) ||
         HasFlag(arguments, kThumbnailFlag);
}

// A plugin process has no window: a headless engine runs the same Dart
// entry point (it branches on the flag before anything that needs a view),
// with no view, no surface and no window-bound plugins. The editor's native
// plugins (window_manager, media_kit_video, screen_retriever, mouse capture,
// volume) all expect a view, and media_kit_video dereferences it while
// registering, so none is registered here: a process part reaches native
// code through FFI. The process ends when its Dart code calls exit().
int RunHeadless(const flutter::DartProject& project) {
  flutter::FlutterEngine engine(project);
  if (!engine.Run()) {
    return EXIT_FAILURE;
  }
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }
  return EXIT_SUCCESS;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const bool headless = IsHeadless(command_line_arguments);

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  if (headless) {
    // Nothing is ever drawn: Impeller's startup (its GL context and worker
    // threads, about 25 MB and 60 threads) is skipped, and a laptop's
    // discrete GPU need not wake for the engine's GL display.
    project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);
    project.set_gpu_preference(flutter::GpuPreference::LowPowerPreference);
    const int code = RunHeadless(project);
    ::CoUninitialize();
    return code;
  }

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"lumina_ui", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
