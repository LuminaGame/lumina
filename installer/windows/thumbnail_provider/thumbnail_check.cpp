// Checks the Lumina Studio thumbnail provider without registering it, or
// through the shell once it is registered.
//
//   thumbnail_check.exe <provider.dll> <model file> <out.png> [size]
//     loads the DLL, creates the provider through its class factory,
//     initialises it with a stream on the file (as the shell's isolated
//     surrogate does) and saves the bitmap it returns.
//   thumbnail_check.exe --shell <model file> <out.png> [size]
//     asks the shell for the file's thumbnail (IShellItemImageFactory,
//     thumbnail only): the registered handler, as Explorer would use it.
//
// Prints the HRESULT, the bitmap size and the time taken; exits 0 on success.
// Built by build.ps1 next to the DLL (not installed).

#include <windows.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <thumbcache.h>
#include <wincodec.h>

#include <chrono>
#include <cstdio>
#include <string>

namespace {

// {4C2F5D1E-8A3B-4E7C-9D21-6B0A5F3E7C18}
constexpr CLSID kClsid = {0x4c2f5d1e, 0x8a3b, 0x4e7c, {0x9d, 0x21, 0x6b, 0x0a, 0x5f, 0x3e, 0x7c, 0x18}};

HRESULT SavePng(HBITMAP bitmap, const wchar_t* path, UINT* width, UINT* height) {
  BITMAP info = {};
  if (GetObjectW(bitmap, sizeof(info), &info) == 0) return E_FAIL;
  *width = static_cast<UINT>(info.bmWidth);
  *height = static_cast<UINT>(info.bmHeight < 0 ? -info.bmHeight : info.bmHeight);
  IWICImagingFactory* factory = nullptr;
  HRESULT hr = CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory));
  if (FAILED(hr)) return hr;
  IWICBitmap* wic = nullptr;
  IWICStream* stream = nullptr;
  IWICBitmapEncoder* encoder = nullptr;
  IWICBitmapFrameEncode* frame = nullptr;
  hr = factory->CreateBitmapFromHBITMAP(bitmap, nullptr, WICBitmapIgnoreAlpha, &wic);
  if (SUCCEEDED(hr)) hr = factory->CreateStream(&stream);
  if (SUCCEEDED(hr)) hr = stream->InitializeFromFilename(path, GENERIC_WRITE);
  if (SUCCEEDED(hr)) hr = factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, &encoder);
  if (SUCCEEDED(hr)) hr = encoder->Initialize(stream, WICBitmapEncoderNoCache);
  if (SUCCEEDED(hr)) hr = encoder->CreateNewFrame(&frame, nullptr);
  if (SUCCEEDED(hr)) hr = frame->Initialize(nullptr);
  if (SUCCEEDED(hr)) hr = frame->WriteSource(wic, nullptr);
  if (SUCCEEDED(hr)) hr = frame->Commit();
  if (SUCCEEDED(hr)) hr = encoder->Commit();
  if (frame) frame->Release();
  if (encoder) encoder->Release();
  if (stream) stream->Release();
  if (wic) wic->Release();
  factory->Release();
  return hr;
}

HRESULT ThroughDll(const wchar_t* dll, const wchar_t* model, UINT size, HBITMAP* out) {
  HMODULE module = LoadLibraryW(dll);
  if (module == nullptr) return HRESULT_FROM_WIN32(GetLastError());
  using GetClassObject = HRESULT(STDAPICALLTYPE*)(REFCLSID, REFIID, void**);
  auto get = reinterpret_cast<GetClassObject>(GetProcAddress(module, "DllGetClassObject"));
  if (get == nullptr) return HRESULT_FROM_WIN32(GetLastError());
  IClassFactory* factory = nullptr;
  HRESULT hr = get(kClsid, IID_PPV_ARGS(&factory));
  IInitializeWithStream* init = nullptr;
  IThumbnailProvider* provider = nullptr;
  IStream* stream = nullptr;
  if (SUCCEEDED(hr)) hr = factory->CreateInstance(nullptr, IID_PPV_ARGS(&init));
  if (SUCCEEDED(hr)) hr = SHCreateStreamOnFileEx(model, STGM_READ | STGM_SHARE_DENY_WRITE, 0, FALSE, nullptr, &stream);
  if (SUCCEEDED(hr)) hr = init->Initialize(stream, STGM_READ);
  if (SUCCEEDED(hr)) hr = init->QueryInterface(IID_PPV_ARGS(&provider));
  WTS_ALPHATYPE alpha = WTSAT_UNKNOWN;
  if (SUCCEEDED(hr)) hr = provider->GetThumbnail(size, out, &alpha);
  if (provider) provider->Release();
  if (stream) stream->Release();
  if (init) init->Release();
  if (factory) factory->Release();
  return hr;
}

HRESULT ThroughShell(const wchar_t* model, UINT size, HBITMAP* out) {
  wchar_t full[MAX_PATH * 4];
  if (GetFullPathNameW(model, ARRAYSIZE(full), full, nullptr) == 0) return HRESULT_FROM_WIN32(GetLastError());
  IShellItemImageFactory* factory = nullptr;
  HRESULT hr = SHCreateItemFromParsingName(full, nullptr, IID_PPV_ARGS(&factory));
  if (SUCCEEDED(hr)) {
    hr = factory->GetImage({static_cast<LONG>(size), static_cast<LONG>(size)}, SIIGBF_THUMBNAILONLY, out);
    factory->Release();
  }
  return hr;
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
  if (argc < 4) {
    fwprintf(stderr, L"usage: thumbnail_check <provider.dll>|--shell <model> <out.png> [size]\n");
    return 64;
  }
  const bool shell = wcscmp(argv[1], L"--shell") == 0;
  const UINT size = argc > 4 ? static_cast<UINT>(_wtoi(argv[4])) : 256;
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  const auto start = std::chrono::steady_clock::now();
  HBITMAP bitmap = nullptr;
  HRESULT hr = shell ? ThroughShell(argv[2], size, &bitmap) : ThroughDll(argv[1], argv[2], size, &bitmap);
  const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - start).count();
  UINT width = 0, height = 0;
  if (SUCCEEDED(hr)) hr = SavePng(bitmap, argv[3], &width, &height);
  if (bitmap) DeleteObject(bitmap);
  wprintf(L"%ls: hr=0x%08lX size=%ux%u time=%lldms\n", argv[2], static_cast<unsigned long>(hr), width, height,
          static_cast<long long>(ms));
  CoUninitialize();
  return SUCCEEDED(hr) ? 0 : 1;
}
