/// The Windows runner's display part of `lumina_window_mode.cpp`: the
/// monitors and their modes, the window's client size and its monitor.
/// `GameWindowRunnerService` puts it in place of `{{DISPLAY}}` inside the
/// anonymous namespace of [kWindowsWindowModeSource]
/// (`windows_sources.dart`), so it uses that file's globals.
library;

const String kWindowsDisplaySource = r'''
// --- Displays: monitors, modes, client size, monitor moves -----------------
//
// Channel methods: getDisplays → {monitors: [{name, device, primary, bounds,
// work, current: [w, h, hz], modes: [[w, h, hz], ...], scale}], current,
// client: [w, h]} (physical pixels); setClientSize {width, height} → [w, h]
// the client area got (windowed; clamped to the work area, centred);
// moveToMonitor {index} → bool. Calls displayChanged {same map} when a
// display changes or the window moves to another monitor.

HMONITOR g_last_monitor = nullptr;

BOOL CALLBACK CollectMonitor(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  reinterpret_cast<std::vector<HMONITOR>*>(data)->push_back(monitor);
  return TRUE;
}

std::vector<HMONITOR> Monitors() {
  std::vector<HMONITOR> list;
  ::EnumDisplayMonitors(nullptr, nullptr, CollectMonitor,
                        reinterpret_cast<LPARAM>(&list));
  return list;
}

std::string Utf8(const wchar_t* text) {
  const int size =
      ::WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) return std::string();
  std::string out(static_cast<size_t>(size - 1), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, text, -1, &out[0], size, nullptr, nullptr);
  return out;
}

// The monitor's model name (for example "DELL U3419W") through the display
// configuration API; empty when it has none.
std::wstring FriendlyName(const wchar_t* gdi_device) {
  UINT32 path_count = 0;
  UINT32 mode_count = 0;
  if (::GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, &path_count,
                                    &mode_count) != ERROR_SUCCESS) {
    return std::wstring();
  }
  std::vector<DISPLAYCONFIG_PATH_INFO> paths(path_count);
  std::vector<DISPLAYCONFIG_MODE_INFO> modes(mode_count);
  if (::QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, &path_count, paths.data(),
                           &mode_count, modes.data(), nullptr) != ERROR_SUCCESS) {
    return std::wstring();
  }
  for (UINT32 i = 0; i < path_count; ++i) {
    DISPLAYCONFIG_SOURCE_DEVICE_NAME source = {};
    source.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME;
    source.header.size = sizeof(source);
    source.header.adapterId = paths[i].sourceInfo.adapterId;
    source.header.id = paths[i].sourceInfo.id;
    if (::DisplayConfigGetDeviceInfo(&source.header) != ERROR_SUCCESS) continue;
    if (wcscmp(source.viewGdiDeviceName, gdi_device) != 0) continue;
    DISPLAYCONFIG_TARGET_DEVICE_NAME target = {};
    target.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
    target.header.size = sizeof(target);
    target.header.adapterId = paths[i].targetInfo.adapterId;
    target.header.id = paths[i].targetInfo.id;
    if (::DisplayConfigGetDeviceInfo(&target.header) == ERROR_SUCCESS &&
        target.monitorFriendlyDeviceName[0] != L'\0') {
      return target.monitorFriendlyDeviceName;
    }
  }
  return std::wstring();
}

EncodableValue ModeValue(DWORD width, DWORD height, DWORD hz) {
  return EncodableValue(EncodableList{
      EncodableValue(static_cast<int32_t>(width)),
      EncodableValue(static_cast<int32_t>(height)),
      EncodableValue(static_cast<int32_t>(hz))});
}

// One monitor: its rectangles, the desktop mode, every mode Windows offers
// for it (EnumDisplaySettingsEx without raw modes: the ones the monitor
// supports; 24/32-bit colour, progressive), its name and scale.
EncodableValue MonitorValue(HMONITOR monitor) {
  MONITORINFOEXW info = {};
  info.cbSize = sizeof(info);
  ::GetMonitorInfoW(monitor, &info);
  DEVMODEW current = {};
  current.dmSize = sizeof(current);
  ::EnumDisplaySettingsExW(info.szDevice, ENUM_CURRENT_SETTINGS, &current, 0);
  EncodableList modes;
  std::set<std::tuple<DWORD, DWORD, DWORD>> seen;
  DEVMODEW mode = {};
  mode.dmSize = sizeof(mode);
  for (DWORD i = 0; ::EnumDisplaySettingsExW(info.szDevice, i, &mode, 0); ++i) {
    if (mode.dmBitsPerPel < 24) continue;
    if ((mode.dmDisplayFlags & DM_INTERLACED) != 0) continue;
    const auto key = std::make_tuple(mode.dmPelsWidth, mode.dmPelsHeight,
                                     mode.dmDisplayFrequency);
    if (!seen.insert(key).second) continue;
    modes.push_back(ModeValue(mode.dmPelsWidth, mode.dmPelsHeight,
                              mode.dmDisplayFrequency));
  }
  std::wstring name = FriendlyName(info.szDevice);
  if (name.empty()) {
    DISPLAY_DEVICEW device = {};
    device.cb = sizeof(device);
    if (::EnumDisplayDevicesW(info.szDevice, 0, &device, 0)) {
      name = device.DeviceString;
    }
  }
  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  return EncodableValue(EncodableMap{
      {EncodableValue("name"), EncodableValue(Utf8(name.c_str()))},
      {EncodableValue("device"), EncodableValue(Utf8(info.szDevice))},
      {EncodableValue("primary"),
       EncodableValue((info.dwFlags & MONITORINFOF_PRIMARY) != 0)},
      {EncodableValue("bounds"), RectValue(info.rcMonitor)},
      {EncodableValue("work"), RectValue(info.rcWork)},
      {EncodableValue("current"),
       ModeValue(current.dmPelsWidth, current.dmPelsHeight,
                 current.dmDisplayFrequency)},
      {EncodableValue("modes"), EncodableValue(modes)},
      {EncodableValue("scale"), EncodableValue(dpi > 0 ? dpi / 96.0 : 1.0)},
  });
}

EncodableValue ClientValue() {
  RECT client = {};
  ::GetClientRect(g_window, &client);
  return EncodableValue(EncodableList{
      EncodableValue(static_cast<int32_t>(client.right - client.left)),
      EncodableValue(static_cast<int32_t>(client.bottom - client.top))});
}

EncodableValue Displays() {
  const std::vector<HMONITOR> monitors = Monitors();
  const HMONITOR mine = ::MonitorFromWindow(g_window, MONITOR_DEFAULTTONEAREST);
  EncodableList list;
  int32_t current = 0;
  for (size_t i = 0; i < monitors.size(); ++i) {
    if (monitors[i] == mine) current = static_cast<int32_t>(i);
    list.push_back(MonitorValue(monitors[i]));
  }
  return EncodableValue(EncodableMap{
      {EncodableValue("monitors"), EncodableValue(list)},
      {EncodableValue("current"), EncodableValue(current)},
      {EncodableValue("client"), ClientValue()},
  });
}

// Windowed: a client area of width × height physical pixels, clamped to the
// work area of the window's monitor (with the frame), centred on it.
// Fullscreen: nothing changes (the game renders the size scaled).
EncodableValue SetClientSize(int32_t width, int32_t height) {
  if (!g_fullscreen) {
    if (::IsZoomed(g_window)) ::ShowWindow(g_window, SW_RESTORE);
    const RECT work = MonitorOf(g_window).rcWork;
    const DWORD style = static_cast<DWORD>(::GetWindowLongPtr(g_window, GWL_STYLE));
    const DWORD ex_style =
        static_cast<DWORD>(::GetWindowLongPtr(g_window, GWL_EXSTYLE));
    RECT frame = {0, 0, 0, 0};
    ::AdjustWindowRectExForDpi(&frame, style, FALSE, ex_style,
                               ::GetDpiForWindow(g_window));
    const LONG frame_w = frame.right - frame.left;
    const LONG frame_h = frame.bottom - frame.top;
    const LONG work_w = work.right - work.left;
    const LONG work_h = work.bottom - work.top;
    const LONG client_w = (std::max)(1L, (std::min)(static_cast<LONG>(width), work_w - frame_w));
    const LONG client_h = (std::max)(1L, (std::min)(static_cast<LONG>(height), work_h - frame_h));
    const LONG window_w = client_w + frame_w;
    const LONG window_h = client_h + frame_h;
    ::SetWindowPos(g_window, nullptr, work.left + (work_w - window_w) / 2,
                   work.top + (work_h - window_h) / 2, window_w, window_h,
                   SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOACTIVATE);
  }
  return ClientValue();
}

// Fullscreen: covers monitor index (and the windowed placement Alt+Enter
// returns to is centred on it). Windowed: the window is centred on its work
// area.
bool MoveToMonitor(int32_t index) {
  const std::vector<HMONITOR> monitors = Monitors();
  if (index < 0 || static_cast<size_t>(index) >= monitors.size()) return false;
  MONITORINFO target = {sizeof(MONITORINFO)};
  ::GetMonitorInfo(monitors[static_cast<size_t>(index)], &target);
  const RECT work = target.rcWork;
  if (g_fullscreen) {
    if (g_have_placement) {
      // rcNormalPosition is in workspace coordinates (the primary monitor's
      // work area origin is 0, 0).
      MONITORINFO primary = {sizeof(MONITORINFO)};
      const POINT origin = {0, 0};
      ::GetMonitorInfo(::MonitorFromPoint(origin, MONITOR_DEFAULTTOPRIMARY),
                       &primary);
      RECT& normal = g_windowed_placement.rcNormalPosition;
      const LONG w = normal.right - normal.left;
      const LONG h = normal.bottom - normal.top;
      normal.left = work.left + ((work.right - work.left) - w) / 2 -
                    (primary.rcWork.left - primary.rcMonitor.left);
      normal.top = work.top + ((work.bottom - work.top) - h) / 2 -
                   (primary.rcWork.top - primary.rcMonitor.top);
      normal.right = normal.left + w;
      normal.bottom = normal.top + h;
    }
    const RECT r = target.rcMonitor;
    ::SetWindowPos(g_window, HWND_TOP, r.left, r.top, r.right - r.left,
                   r.bottom - r.top, SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    FitToMonitor();
    return true;
  }
  if (::IsZoomed(g_window)) ::ShowWindow(g_window, SW_RESTORE);
  RECT r = {};
  ::GetWindowRect(g_window, &r);
  const LONG w = r.right - r.left;
  const LONG h = r.bottom - r.top;
  ::SetWindowPos(g_window, nullptr, work.left + ((work.right - work.left) - w) / 2,
                 work.top + ((work.bottom - work.top) - h) / 2, 0, 0,
                 SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOACTIVATE);
  return true;
}

void NotifyDisplayChanged() {
  if (!g_channel) return;
  g_channel->InvokeMethod("displayChanged",
                          std::make_unique<EncodableValue>(Displays()));
}

// After the window procedure handled [message]: tells the game when a
// display changed or the window ended up on another monitor.
void WatchDisplays(UINT message) {
  if (message == WM_DISPLAYCHANGE) {
    g_last_monitor = ::MonitorFromWindow(g_window, MONITOR_DEFAULTTONEAREST);
    NotifyDisplayChanged();
    return;
  }
  if (message == WM_WINDOWPOSCHANGED || message == WM_DPICHANGED ||
      message == WM_EXITSIZEMOVE) {
    const HMONITOR now = ::MonitorFromWindow(g_window, MONITOR_DEFAULTTONEAREST);
    if (now != g_last_monitor || message == WM_EXITSIZEMOVE) {
      g_last_monitor = now;
      NotifyDisplayChanged();
    }
  }
}

int32_t IntArg(const EncodableValue* args, const char* key, int32_t fallback) {
  const auto* map = std::get_if<EncodableMap>(args);
  if (map == nullptr) return fallback;
  const auto it = map->find(EncodableValue(key));
  if (it == map->end()) return fallback;
  if (const auto* v = std::get_if<int32_t>(&it->second)) return *v;
  if (const auto* v = std::get_if<int64_t>(&it->second)) {
    return static_cast<int32_t>(*v);
  }
  if (const auto* v = std::get_if<double>(&it->second)) {
    return static_cast<int32_t>(*v);
  }
  return fallback;
}

// The display methods; false for any other method.
bool HandleDisplayCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>>& result) {
  const std::string& method = call.method_name();
  if (method == "getDisplays") {
    result->Success(Displays());
  } else if (method == "setClientSize") {
    result->Success(SetClientSize(IntArg(call.arguments(), "width", 0),
                                  IntArg(call.arguments(), "height", 0)));
  } else if (method == "moveToMonitor") {
    result->Success(EncodableValue(MoveToMonitor(IntArg(call.arguments(), "index", -1))));
  } else {
    return false;
  }
  return true;
}
''';
