/// The Windows runner's presentation window part of `lumina_window_mode.cpp`:
/// the child window a game presenting directly renders into.
/// `GameWindowRunnerService` puts it in place of `{{SURFACE}}` inside the
/// anonymous namespace of [kWindowsWindowModeSource] (`windows_sources.dart`),
/// after the display part, so it uses that file's globals.
library;

const String kWindowsSurfaceSource = r'''
// --- Presentation window: where a game presenting directly renders ---------
//
// Channel methods: createSurface → {handle, width, height} (the window's HWND
// and its client size in physical pixels; created once, shown again after a
// destroySurface); destroySurface → hides and destroys it. Calls
// surfaceChanged {handle, width, height} when the Flutter view is resized,
// and with 0 x 0 while the game window is minimised.
//
// The window is a child of the Flutter view covering its client area. It is
// disabled and transparent to hit tests, so the mouse goes to the Flutter
// view under it and the keyboard focus stays there; it never erases or paints
// (Filament's swap chain owns its pixels). The Flutter view gets
// WS_CLIPCHILDREN, so its own presents never draw over the window.
//
// It lives on a thread of its own that does nothing but pump its messages:
// presenting to a window can send it messages from the GPU driver's threads,
// which must never wait for the platform thread (it may itself be waiting for
// the renderer). The platform thread only posts to it, or waits for it while
// handling the messages sent to its own windows.

constexpr wchar_t kSurfaceClass[] = L"LuminaPresentationSurface";
HWND g_surface = nullptr;
bool g_surface_class = false;
std::thread g_surface_thread;

// Waits for [handle] while handling only the messages other threads send to
// this thread's windows (never the posted ones: no Flutter task runs here).
void WaitHandlingSentMessages(HANDLE handle) {
  while (::MsgWaitForMultipleObjects(1, &handle, FALSE, INFINITE,
                                     QS_SENDMESSAGE) == WAIT_OBJECT_0 + 1) {
    MSG msg;
    ::PeekMessage(&msg, nullptr, 0, 0, PM_NOREMOVE | PM_QS_SENDMESSAGE);
  }
}

LRESULT CALLBACK SurfaceProc(HWND hwnd, UINT message, WPARAM wparam,
                             LPARAM lparam) {
  switch (message) {
    case WM_NCHITTEST:
      return HTTRANSPARENT;
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
    case WM_ERASEBKGND:
      return 1;
    case WM_PAINT: {
      PAINTSTRUCT paint;
      ::BeginPaint(hwnd, &paint);
      ::EndPaint(hwnd, &paint);
      return 0;
    }
    case WM_CLOSE:
      ::DestroyWindow(hwnd);
      return 0;
    case WM_DESTROY:
      ::PostQuitMessage(0);
      return 0;
    default:
      return ::DefWindowProc(hwnd, message, wparam, lparam);
  }
}

SIZE SurfaceSize() {
  if (::IsIconic(g_window)) return SIZE{0, 0};
  RECT client = {};
  ::GetClientRect(g_view ? g_view : g_window, &client);
  return SIZE{client.right - client.left, client.bottom - client.top};
}

EncodableValue SurfaceValue() {
  const SIZE size = g_surface ? SurfaceSize() : SIZE{0, 0};
  return EncodableValue(EncodableMap{
      {EncodableValue("handle"),
       EncodableValue(static_cast<int64_t>(reinterpret_cast<intptr_t>(g_surface)))},
      {EncodableValue("width"), EncodableValue(static_cast<int32_t>(size.cx))},
      {EncodableValue("height"), EncodableValue(static_cast<int32_t>(size.cy))},
  });
}

// Keeps the window over the whole Flutter view and tells the game its size.
void FitSurface() {
  if (!g_surface) return;
  const SIZE size = SurfaceSize();
  if (size.cx > 0 && size.cy > 0) {
    ::SetWindowPos(g_surface, HWND_TOP, 0, 0, size.cx, size.cy,
                   SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_ASYNCWINDOWPOS);
  }
  if (g_channel) {
    g_channel->InvokeMethod("surfaceChanged",
                            std::make_unique<EncodableValue>(SurfaceValue()));
  }
}

bool CreateSurface() {
  if (g_surface) {
    ::ShowWindowAsync(g_surface, SW_SHOWNA);
    return true;
  }
  HINSTANCE instance = ::GetModuleHandle(nullptr);
  if (!g_surface_class) {
    WNDCLASSEXW cls = {sizeof(WNDCLASSEXW)};
    cls.style = CS_OWNDC;
    cls.lpfnWndProc = SurfaceProc;
    cls.hInstance = instance;
    cls.hCursor = nullptr;
    cls.hbrBackground = nullptr;
    cls.lpszClassName = kSurfaceClass;
    if (!::RegisterClassExW(&cls) &&
        ::GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
      return false;
    }
    g_surface_class = true;
  }
  HWND parent = g_view ? g_view : g_window;
  // The parent must not draw over this window. The Flutter view keeps
  // presenting its own frames (the UI the game blends in); without
  // WS_CLIPCHILDREN each of them covered the game's frame with the view's
  // pixels (black and the HUD) until the game presented again, so 10-45% of
  // the frames on screen showed no 3D.
  ::SetWindowLongPtr(parent, GWL_STYLE,
                     ::GetWindowLongPtr(parent, GWL_STYLE) | WS_CLIPCHILDREN);
  const SIZE size = SurfaceSize();
  HANDLE created = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (!created) return false;
  HWND window = nullptr;
  DWORD error = 0;
  g_surface_thread = std::thread([&window, &error, created, parent, size,
                                  instance]() {
    HWND hwnd = ::CreateWindowExW(
        WS_EX_NOPARENTNOTIFY, kSurfaceClass, L"",
        WS_CHILD | WS_VISIBLE | WS_DISABLED | WS_CLIPSIBLINGS, 0, 0,
        size.cx > 0 ? size.cx : 1, size.cy > 0 ? size.cy : 1, parent, nullptr,
        instance, nullptr);
    window = hwnd;
    error = hwnd ? 0 : ::GetLastError();
    ::SetEvent(created);
    if (!hwnd) return;
    MSG msg;
    while (::GetMessageW(&msg, nullptr, 0, 0) > 0) {
      ::TranslateMessage(&msg);
      ::DispatchMessageW(&msg);
    }
  });
  // Creating a child window sends messages to its parent (this thread).
  WaitHandlingSentMessages(created);
  ::CloseHandle(created);
  if (!window) {
    g_surface_thread.join();
    ::SetLastError(error);
    return false;
  }
  g_surface = window;
  ::SetWindowPos(g_surface, HWND_TOP, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_ASYNCWINDOWPOS);
  return true;
}

void DestroySurface() {
  if (!g_surface) return;
  ::PostMessage(g_surface, WM_CLOSE, 0, 0);
  g_surface = nullptr;
  if (g_surface_thread.joinable()) {
    WaitHandlingSentMessages(g_surface_thread.native_handle());
    g_surface_thread.join();
  }
}

// After the Flutter view's procedure handled [message].
void WatchSurfaceView(UINT message) {
  if (g_surface && message == WM_SIZE) FitSurface();
}

// After the game window's procedure handled [message]: minimise and restore.
void WatchSurfaceWindow(UINT message, WPARAM wparam) {
  if (!g_surface || message != WM_SIZE) return;
  if (wparam == SIZE_MINIMIZED || wparam == SIZE_RESTORED ||
      wparam == SIZE_MAXIMIZED) {
    FitSurface();
  }
}

// The presentation window methods; false for any other method.
bool HandleSurfaceCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>>& result) {
  const std::string& method = call.method_name();
  if (method == "createSurface") {
    if (CreateSurface()) {
      result->Success(SurfaceValue());
    } else {
      result->Error("unsupported", "the presentation window could not be created (error " +
                                       std::to_string(::GetLastError()) + ")");
    }
  } else if (method == "destroySurface") {
    DestroySurface();
    result->Success(EncodableValue(true));
  } else {
    return false;
  }
  return true;
}
''';
