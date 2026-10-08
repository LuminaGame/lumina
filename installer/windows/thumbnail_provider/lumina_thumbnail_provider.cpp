// Lumina Studio's Windows shell thumbnail provider for 3D model files
// (.glb, .gltf, .fbx, .obj).
//
// Explorer asks a thumbnail provider for a bitmap through IInitializeWithStream
// + IThumbnailProvider, in the shell's isolated surrogate process. This DLL
// renders nothing itself: it copies the stream to a temporary file and runs
// the installed editor windowless,
//
//   lumina_ui.exe --lumina-thumbnail <input> <output.png> --size <px>
//
// which draws the model with the Content Browser's thumbnail renderer. The
// child runs in a job object that kills it (and anything it started) when the
// time limit passes; at most two renders run at once across every surrogate
// (a named semaphore). Any failure returns an error HRESULT, so Explorer keeps
// the file's normal icon; Explorer caches what it gets.
//
// The editor is found next to the setup folder the DLL is installed in
// ({app}\setup\shell\ -> {app}\lumina_ui.exe); LUMINA_THUMBNAIL_EDITOR names
// another executable (the test harness uses it).
//
// Built by installer\windows\build.ps1 (cl /LD /MT, VS 2022); registered
// per-user by lumina-studio.iss under HKCU\Software\Classes\
// SystemFileAssociations\<ext>\ShellEx\{e357fccd-...}, never on the extension
// key or a ProgID, so the default program's own thumbnail handler keeps
// priority. DllRegisterServer / DllUnregisterServer write and remove the same
// keys, for development (regsvr32).

#include <windows.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <thumbcache.h>
#include <wincodec.h>

#include <atomic>
#include <cstdint>
#include <string>
#include <vector>

namespace {

// {4C2F5D1E-8A3B-4E7C-9D21-6B0A5F3E7C18}
constexpr CLSID kClsid = {0x4c2f5d1e, 0x8a3b, 0x4e7c, {0x9d, 0x21, 0x6b, 0x0a, 0x5f, 0x3e, 0x7c, 0x18}};
constexpr wchar_t kClsidString[] = L"{4C2F5D1E-8A3B-4E7C-9D21-6B0A5F3E7C18}";
constexpr wchar_t kThumbnailHandlerKey[] = L"ShellEx\\{e357fccd-a995-4576-b01f-234630154e96}";
constexpr const wchar_t* kExtensions[] = {L".glb", L".gltf", L".fbx", L".obj"};

constexpr DWORD kRenderTimeoutMs = 30000;
constexpr LONG kConcurrentRenders = 2;
constexpr ULONGLONG kMaxInputBytes = 1ull << 30;  // 1 GiB

HMODULE g_module = nullptr;
std::atomic<long> g_objects{0};
std::atomic<long> g_locks{0};

std::wstring ModuleDirectory() {
  wchar_t path[MAX_PATH * 4];
  const DWORD n = GetModuleFileNameW(g_module, path, ARRAYSIZE(path));
  if (n == 0 || n >= ARRAYSIZE(path)) return {};
  std::wstring dir(path, n);
  const size_t slash = dir.find_last_of(L"\\/");
  return slash == std::wstring::npos ? std::wstring() : dir.substr(0, slash);
}

std::wstring FullPath(const std::wstring& path) {
  wchar_t out[MAX_PATH * 4];
  const DWORD n = GetFullPathNameW(path.c_str(), ARRAYSIZE(out), out, nullptr);
  return n == 0 || n >= ARRAYSIZE(out) ? path : std::wstring(out, n);
}

// The editor executable: LUMINA_THUMBNAIL_EDITOR, else {app}\lumina_ui.exe
// two folders above this DLL ({app}\setup\shell\).
std::wstring EditorExecutable() {
  wchar_t env[MAX_PATH * 4];
  const DWORD n = GetEnvironmentVariableW(L"LUMINA_THUMBNAIL_EDITOR", env, ARRAYSIZE(env));
  if (n > 0 && n < ARRAYSIZE(env)) return std::wstring(env, n);
  const std::wstring dir = ModuleDirectory();
  if (dir.empty()) return {};
  return FullPath(dir + L"\\..\\..\\lumina_ui.exe");
}

std::wstring Lower(std::wstring s) {
  for (auto& c : s) c = static_cast<wchar_t>(towlower(c));
  return s;
}

bool IsSupportedExtension(const std::wstring& ext) {
  for (const auto* e : kExtensions) {
    if (ext == e) return true;
  }
  return false;
}

// The extension of the stream's name, else one guessed from its first bytes.
std::wstring ExtensionFor(IStream* stream) {
  STATSTG stat = {};
  if (SUCCEEDED(stream->Stat(&stat, STATFLAG_DEFAULT)) && stat.pwcsName != nullptr) {
    std::wstring name(stat.pwcsName);
    CoTaskMemFree(stat.pwcsName);
    const size_t dot = name.find_last_of(L'.');
    if (dot != std::wstring::npos) {
      const std::wstring ext = Lower(name.substr(dot));
      if (IsSupportedExtension(ext)) return ext;
    }
  }
  char head[24] = {};
  ULONG read = 0;
  LARGE_INTEGER zero = {};
  if (FAILED(stream->Seek(zero, STREAM_SEEK_SET, nullptr)) || FAILED(stream->Read(head, sizeof(head), &read))) return {};
  stream->Seek(zero, STREAM_SEEK_SET, nullptr);
  if (read >= 4 && memcmp(head, "glTF", 4) == 0) return L".glb";
  if (read >= 18 && memcmp(head, "Kaydara FBX Binary", 18) == 0) return L".fbx";
  if (read >= 1 && head[0] == '{') return L".gltf";
  return {};
}

std::wstring TempFolder() {
  wchar_t temp[MAX_PATH + 1];
  const DWORD n = GetTempPathW(ARRAYSIZE(temp), temp);
  if (n == 0 || n > MAX_PATH) return {};
  std::wstring dir = std::wstring(temp, n) + L"LuminaThumbnails";
  CreateDirectoryW(dir.c_str(), nullptr);
  return dir;
}

std::wstring UniqueStem() {
  static std::atomic<unsigned long> counter{0};
  wchar_t stem[96];
  swprintf_s(stem, L"thumb-%lu-%llu-%lu", GetCurrentProcessId(), GetTickCount64(), ++counter);
  return stem;
}

HRESULT CopyStreamToFile(IStream* stream, const std::wstring& path) {
  LARGE_INTEGER zero = {};
  HRESULT hr = stream->Seek(zero, STREAM_SEEK_SET, nullptr);
  if (FAILED(hr)) return hr;
  HANDLE file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_TEMPORARY, nullptr);
  if (file == INVALID_HANDLE_VALUE) return HRESULT_FROM_WIN32(GetLastError());
  std::vector<char> buffer(1 << 20);
  ULONGLONG total = 0;
  hr = S_OK;
  for (;;) {
    ULONG read = 0;
    const HRESULT r = stream->Read(buffer.data(), static_cast<ULONG>(buffer.size()), &read);
    if (FAILED(r)) {
      hr = r;
      break;
    }
    if (read == 0) break;
    total += read;
    if (total > kMaxInputBytes) {
      hr = E_OUTOFMEMORY;
      break;
    }
    DWORD written = 0;
    if (!WriteFile(file, buffer.data(), read, &written, nullptr) || written != read) {
      hr = HRESULT_FROM_WIN32(GetLastError());
      break;
    }
    if (r == S_FALSE) break;
  }
  CloseHandle(file);
  return hr;
}

// Runs the editor's thumbnail mode; S_OK once it wrote [output].
HRESULT RunThumbnailer(const std::wstring& exe, const std::wstring& input, const std::wstring& output, UINT size) {
  if (GetFileAttributesW(exe.c_str()) == INVALID_FILE_ATTRIBUTES) return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
  const ULONGLONG deadline = GetTickCount64() + kRenderTimeoutMs;

  HANDLE slots = CreateSemaphoreW(nullptr, kConcurrentRenders, kConcurrentRenders, L"Local\\LuminaStudioThumbnailer");
  if (slots == nullptr) return HRESULT_FROM_WIN32(GetLastError());
  if (WaitForSingleObject(slots, kRenderTimeoutMs) != WAIT_OBJECT_0) {
    CloseHandle(slots);
    return HRESULT_FROM_WIN32(ERROR_TIMEOUT);
  }

  HRESULT hr = E_FAIL;
  HANDLE job = CreateJobObjectW(nullptr, nullptr);
  if (job != nullptr) {
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits));

    std::wstring command = L"\"" + exe + L"\" --lumina-thumbnail \"" + input + L"\" \"" + output + L"\" --size " +
                           std::to_wstring(size);
    std::wstring workdir = exe.substr(0, exe.find_last_of(L"\\/"));
    STARTUPINFOW startup = {sizeof(startup)};
    startup.dwFlags = STARTF_USESHOWWINDOW;
    startup.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION process = {};
    if (CreateProcessW(exe.c_str(), command.data(), nullptr, nullptr, FALSE,
                       CREATE_NO_WINDOW | CREATE_SUSPENDED | BELOW_NORMAL_PRIORITY_CLASS, nullptr,
                       workdir.empty() ? nullptr : workdir.c_str(), &startup, &process)) {
      AssignProcessToJobObject(job, process.hProcess);
      ResumeThread(process.hThread);
      const ULONGLONG now = GetTickCount64();
      const DWORD wait = now >= deadline ? 0 : static_cast<DWORD>(deadline - now);
      if (WaitForSingleObject(process.hProcess, wait) == WAIT_OBJECT_0) {
        DWORD code = 1;
        GetExitCodeProcess(process.hProcess, &code);
        hr = code == 0 && GetFileAttributesW(output.c_str()) != INVALID_FILE_ATTRIBUTES ? S_OK : E_FAIL;
      } else {
        TerminateJobObject(job, 1);
        hr = HRESULT_FROM_WIN32(ERROR_TIMEOUT);
      }
      CloseHandle(process.hThread);
      CloseHandle(process.hProcess);
    } else {
      hr = HRESULT_FROM_WIN32(GetLastError());
    }
    CloseHandle(job);  // kills whatever is still running in it
  } else {
    hr = HRESULT_FROM_WIN32(GetLastError());
  }
  ReleaseSemaphore(slots, 1, nullptr);
  CloseHandle(slots);
  return hr;
}

// The PNG at [path] as a top-down 32-bit DIB no larger than [size] square.
HRESULT LoadPng(const std::wstring& path, UINT size, HBITMAP* out) {
  IWICImagingFactory* factory = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory));
  if (FAILED(hr)) return hr;
  IWICBitmapDecoder* decoder = nullptr;
  IWICBitmapFrameDecode* frame = nullptr;
  IWICBitmapScaler* scaler = nullptr;
  IWICFormatConverter* converter = nullptr;
  hr = factory->CreateDecoderFromFilename(path.c_str(), nullptr, GENERIC_READ, WICDecodeMetadataCacheOnDemand, &decoder);
  if (SUCCEEDED(hr)) hr = decoder->GetFrame(0, &frame);
  UINT width = 0, height = 0;
  if (SUCCEEDED(hr)) hr = frame->GetSize(&width, &height);
  IWICBitmapSource* source = frame;
  if (SUCCEEDED(hr) && (width > size || height > size) && size > 0) {
    const double scale = static_cast<double>(size) / (width > height ? width : height);
    const UINT w = static_cast<UINT>(width * scale + 0.5), h = static_cast<UINT>(height * scale + 0.5);
    hr = factory->CreateBitmapScaler(&scaler);
    if (SUCCEEDED(hr)) hr = scaler->Initialize(frame, w > 0 ? w : 1, h > 0 ? h : 1, WICBitmapInterpolationModeFant);
    if (SUCCEEDED(hr)) {
      source = scaler;
      width = w > 0 ? w : 1;
      height = h > 0 ? h : 1;
    }
  }
  if (SUCCEEDED(hr)) hr = factory->CreateFormatConverter(&converter);
  if (SUCCEEDED(hr)) {
    hr = converter->Initialize(source, GUID_WICPixelFormat32bppBGRA, WICBitmapDitherTypeNone, nullptr, 0.0,
                               WICBitmapPaletteTypeCustom);
  }
  if (SUCCEEDED(hr)) {
    BITMAPINFO info = {};
    info.bmiHeader.biSize = sizeof(info.bmiHeader);
    info.bmiHeader.biWidth = static_cast<LONG>(width);
    info.bmiHeader.biHeight = -static_cast<LONG>(height);  // top-down
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;
    void* bits = nullptr;
    HBITMAP bitmap = CreateDIBSection(nullptr, &info, DIB_RGB_COLORS, &bits, nullptr, 0);
    if (bitmap == nullptr) {
      hr = E_OUTOFMEMORY;
    } else {
      hr = converter->CopyPixels(nullptr, width * 4, width * height * 4, static_cast<BYTE*>(bits));
      if (SUCCEEDED(hr)) {
        *out = bitmap;
      } else {
        DeleteObject(bitmap);
      }
    }
  }
  if (converter) converter->Release();
  if (scaler) scaler->Release();
  if (frame) frame->Release();
  if (decoder) decoder->Release();
  factory->Release();
  return hr;
}

class ThumbnailProvider final : public IInitializeWithStream, public IThumbnailProvider {
 public:
  ThumbnailProvider() { ++g_objects; }

  // IUnknown
  IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
    if (ppv == nullptr) return E_POINTER;
    if (riid == IID_IUnknown || riid == IID_IInitializeWithStream) {
      *ppv = static_cast<IInitializeWithStream*>(this);
    } else if (riid == IID_IThumbnailProvider) {
      *ppv = static_cast<IThumbnailProvider*>(this);
    } else {
      *ppv = nullptr;
      return E_NOINTERFACE;
    }
    AddRef();
    return S_OK;
  }
  IFACEMETHODIMP_(ULONG) AddRef() override { return ++refs_; }
  IFACEMETHODIMP_(ULONG) Release() override {
    const long left = --refs_;
    if (left == 0) delete this;
    return left;
  }

  // IInitializeWithStream
  IFACEMETHODIMP Initialize(IStream* stream, DWORD) override {
    if (stream == nullptr) return E_INVALIDARG;
    if (stream_ != nullptr) return HRESULT_FROM_WIN32(ERROR_ALREADY_INITIALIZED);
    extension_ = ExtensionFor(stream);
    if (extension_.empty()) return E_INVALIDARG;
    stream_ = stream;
    stream_->AddRef();
    return S_OK;
  }

  // IThumbnailProvider
  IFACEMETHODIMP GetThumbnail(UINT cx, HBITMAP* phbmp, WTS_ALPHATYPE* alpha) override {
    if (phbmp == nullptr || alpha == nullptr) return E_POINTER;
    *phbmp = nullptr;
    *alpha = WTSAT_RGB;
    if (stream_ == nullptr) return E_UNEXPECTED;
    const std::wstring exe = EditorExecutable();
    const std::wstring dir = TempFolder();
    if (exe.empty() || dir.empty()) return E_FAIL;
    const UINT size = cx < 16 ? 16 : (cx > 1024 ? 1024 : cx);
    const std::wstring stem = dir + L"\\" + UniqueStem();
    const std::wstring input = stem + extension_;
    const std::wstring output = stem + L".png";
    HRESULT hr = CopyStreamToFile(stream_, input);
    if (SUCCEEDED(hr)) hr = RunThumbnailer(exe, input, output, size);
    if (SUCCEEDED(hr)) hr = LoadPng(output, cx, phbmp);
    DeleteFileW(input.c_str());
    DeleteFileW(output.c_str());
    DeleteFileW((output + L".tmp").c_str());
    return hr;
  }

 private:
  ~ThumbnailProvider() {
    if (stream_ != nullptr) stream_->Release();
    --g_objects;
  }

  std::atomic<long> refs_{1};
  IStream* stream_ = nullptr;
  std::wstring extension_;
};

class ClassFactory final : public IClassFactory {
 public:
  IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
    if (ppv == nullptr) return E_POINTER;
    if (riid == IID_IUnknown || riid == IID_IClassFactory) {
      *ppv = static_cast<IClassFactory*>(this);
      AddRef();
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }
  IFACEMETHODIMP_(ULONG) AddRef() override { return 2; }
  IFACEMETHODIMP_(ULONG) Release() override { return 1; }

  IFACEMETHODIMP CreateInstance(IUnknown* outer, REFIID riid, void** ppv) override {
    if (ppv == nullptr) return E_POINTER;
    *ppv = nullptr;
    if (outer != nullptr) return CLASS_E_NOAGGREGATION;
    auto* provider = new (std::nothrow) ThumbnailProvider();
    if (provider == nullptr) return E_OUTOFMEMORY;
    const HRESULT hr = provider->QueryInterface(riid, ppv);
    provider->Release();
    return hr;
  }
  IFACEMETHODIMP LockServer(BOOL lock) override {
    if (lock) {
      ++g_locks;
    } else {
      --g_locks;
    }
    return S_OK;
  }
};

ClassFactory g_factory;

LSTATUS SetString(HKEY root, const std::wstring& subkey, const wchar_t* name, const std::wstring& value) {
  HKEY key = nullptr;
  LSTATUS s = RegCreateKeyExW(root, subkey.c_str(), 0, nullptr, 0, KEY_WRITE, nullptr, &key, nullptr);
  if (s != ERROR_SUCCESS) return s;
  s = RegSetValueExW(key, name, 0, REG_SZ, reinterpret_cast<const BYTE*>(value.c_str()),
                     static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(key);
  return s;
}

// Deletes [subkey] only when it holds no value and no subkey: another
// program's association on the same extension key stays intact.
void DeleteIfEmpty(HKEY root, const std::wstring& subkey) {
  HKEY key = nullptr;
  if (RegOpenKeyExW(root, subkey.c_str(), 0, KEY_READ, &key) != ERROR_SUCCESS) return;
  DWORD subkeys = 0, values = 0;
  const LSTATUS s = RegQueryInfoKeyW(key, nullptr, nullptr, nullptr, &subkeys, nullptr, nullptr, &values, nullptr,
                                     nullptr, nullptr, nullptr);
  RegCloseKey(key);
  if (s == ERROR_SUCCESS && subkeys == 0 && values == 0) RegDeleteKeyW(root, subkey.c_str());
}

}  // namespace

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID) {
  if (reason == DLL_PROCESS_ATTACH) {
    g_module = module;
    DisableThreadLibraryCalls(module);
  }
  return TRUE;
}

STDAPI DllGetClassObject(REFCLSID clsid, REFIID riid, void** ppv) {
  if (ppv == nullptr) return E_POINTER;
  *ppv = nullptr;
  if (clsid != kClsid) return CLASS_E_CLASSNOTAVAILABLE;
  return g_factory.QueryInterface(riid, ppv);
}

STDAPI DllCanUnloadNow() { return g_objects == 0 && g_locks == 0 ? S_OK : S_FALSE; }

// Per-user registration (HKCU\Software\Classes), the same keys setup writes;
// for development (`regsvr32 [/u] lumina_thumbnails.dll`).
STDAPI DllRegisterServer() {
  wchar_t path[MAX_PATH * 4];
  const DWORD n = GetModuleFileNameW(g_module, path, ARRAYSIZE(path));
  if (n == 0 || n >= ARRAYSIZE(path)) return E_FAIL;
  const std::wstring classes = L"Software\\Classes\\";
  const std::wstring clsidKey = classes + L"CLSID\\" + kClsidString;
  if (SetString(HKEY_CURRENT_USER, clsidKey, nullptr, L"Lumina Studio 3D model thumbnail provider") != ERROR_SUCCESS ||
      SetString(HKEY_CURRENT_USER, clsidKey + L"\\InprocServer32", nullptr, std::wstring(path, n)) != ERROR_SUCCESS ||
      SetString(HKEY_CURRENT_USER, clsidKey + L"\\InprocServer32", L"ThreadingModel", L"Apartment") != ERROR_SUCCESS) {
    return E_ACCESSDENIED;
  }
  // Only under SystemFileAssociations: a thumbnail handler of the file type's
  // default program (on its ProgID or the extension key) still wins.
  for (const auto* ext : kExtensions) {
    const std::wstring key = classes + L"SystemFileAssociations\\" + ext + L"\\" + kThumbnailHandlerKey;
    if (SetString(HKEY_CURRENT_USER, key, nullptr, kClsidString) != ERROR_SUCCESS) return E_ACCESSDENIED;
  }
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
  return S_OK;
}

STDAPI DllUnregisterServer() {
  const std::wstring classes = L"Software\\Classes\\";
  RegDeleteTreeW(HKEY_CURRENT_USER, (classes + L"CLSID\\" + kClsidString).c_str());
  for (const auto* ext : kExtensions) {
    const std::wstring base = classes + L"SystemFileAssociations\\" + ext;
    const std::wstring key = base + L"\\" + kThumbnailHandlerKey;
    // Only this provider's entry; another program's handler stays.
    wchar_t value[64] = {};
    DWORD bytes = sizeof(value) - sizeof(wchar_t);
    if (RegGetValueW(HKEY_CURRENT_USER, key.c_str(), nullptr, RRF_RT_REG_SZ, nullptr, value, &bytes) == ERROR_SUCCESS &&
        _wcsicmp(value, kClsidString) == 0) {
      RegDeleteTreeW(HKEY_CURRENT_USER, key.c_str());
    }
    // The keys this registration created, when nothing else is left in them.
    DeleteIfEmpty(HKEY_CURRENT_USER, base + L"\\ShellEx");
    DeleteIfEmpty(HKEY_CURRENT_USER, base);
  }
  SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
  return S_OK;
}
