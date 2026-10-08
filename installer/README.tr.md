[English](README.md)

# Lumina Studio installer'ları

Lumina motorunun editörü Lumina Studio için native installer'lar. Hiçbiri editörü içine gömmez. Her biri Lumina
projelerini build etmek ve çalıştırmak için gerekenleri kurar, ardından en son editör build'ini
[GitHub releases](https://github.com/LuminaGame/lumina/releases) üzerinden indirir. Sonraki bir güncelleme için
yeni bir installer değil, yalnızca yeni bir release gerekir.

| Platform | Paket | Üreten | Durum |
|---|---|---|---|
| Windows | `lumina-studio-setup-<tag>-windows-x64.exe` (Inno Setup) | `windows/build.ps1` | yayımlanıyor |
| Windows | `lumina-studio-<tag>-windows-x64-store.msix` (editör, imzasız, Microsoft Store için) | `lumina_ui/tool/package_windows.dart --store` | yayımlanıyor |
| Windows | `lumina-studio-<tag>-windows-x64.msix` (editörün kendisi) | `lumina_ui/tool/package_windows.dart` | imzalama secret'ları varsa yayımlanıyor |
| Linux | `lumina-studio_<version>-1_amd64.deb`, `lumina-studio-<version>-1.x86_64.rpm` (nfpm) | `linux/build.sh` | yayımlanıyor |
| macOS | `lumina-studio-<tag>-macos.pkg` (pkgbuild + productbuild) | `macos/build-pkg.sh` | yazıldı, doğrulanmadı, workflow'da kapalı |

Release workflow'u (`.github/workflows/release.yml`) her `v*` tag'i için hepsini build eder. Her asset'in bir
`.sha256` sidecar'ı vardır ve installer'lar editör indirmesini buna göre doğrular.

## Release asset'leri

| Asset | İçerik |
|---|---|
| `lumina-studio-<tag>-windows-x64.zip` | `flutter build windows --release` çıktısı; Visual C++ runtime DLL'leri `lumina_ui.exe`'nin yanında, dosyalar arşivin kökünde |
| `lumina-studio-<tag>-linux-x64.tar.gz` | `flutter build linux --release` bundle'ı (`lumina_ui`, `lib/`, `data/`), arşivin kökünde |
| `openriglogic-<os>-x64.{zip,tar.gz}` | Prebuilt OpenRigLogic statik kütüphanesi (pinlenen tools commit'inden build edilir); editör ilk açılışta indirir |

İki editör build'i de `--dart-define=LUMINA_VERSION=<tag>` ve `--dart-define=LUMINA_COMMIT=<sha>` taşır.

Prebuilt Filament (upstream v1.77.2 + bu repo'nun patch'leri) Lumina release'lerine eklenmez. Her Filament sürümü
(`tool/filament/VERSION`) bir kez, kendi release'inde yayımlanır: `filament-<VERSION>`; içinde
`filament-<VERSION>-windows-x64.zip`, `filament-<VERSION>-linux-x64.tar.gz` ve `.sha256` sidecar'ları bulunur.
Hiçbir zaman Latest olarak işaretlenmeyen ve tamamlandıktan sonra değişmeyen bir pre-release'tir; workflow onu
ihtiyaç duyan ilk tag'den oluşturur (`.github/scripts/filament_release.sh`), sonraki tag'ler notlarında yalnızca
ona bağlantı verir. Editör ilk açılışta oradan indirir; bulamazsa kendi release'inin dosyalarına döner
(v0.0.1-dev.6'ya kadarki release'ler Filament'i orada tutar).

Installer'lar (setup.exe, `install-studio.sh`, "Update Lumina Studio", `lumina-studio --update`) için **"latest"**,
platformun editörünü taşıyorsa `/releases/latest`, değilse onu taşıyan, pre-release'ler dahil en yeni yayımlanmış
release'tir. `filament-*` release'leri, taslaklar ve `lumina-studio-*` dosyası olmayan release'ler hiçbir zaman
seçilmez. `lumina-setup.ps1 -SelectReleaseFrom <dosya>` ve `install-studio.sh --select-release-from <dosya>` bu
seçimi kaydedilmiş bir `GET /repos/<repo>/releases` yanıtına uygular (`tag=` ve `asset=` yazdırır); testler bunu
kullanır.

## Windows: setup.exe

Kullanıcı başına kurulan bir setup. Kendisi yönetici hakkı istemez; makine geneli paketler için yükseltmeyi
winget ister.

1. **winget ile ön koşullar.** Zaten kurulu olanlar atlanır.
   - `Git.Git`
   - `Microsoft.VisualStudio.2022.BuildTools`,
     `--override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"`
     ile. C++ araçları olan mevcut bir Visual Studio (`vswhere` ile bulunur) kurulu sayılır.
   - `gstreamerproject.gstreamer`
   - `Gyan.FFmpeg.Essentials`, yalnızca "Install FFmpeg" görevi seçilirse ya da `/FFMPEG` ile
2. **Flutter.** PATH'te zaten bir `flutter` varsa o kullanılır. Yoksa stable kanalı
   `%LOCALAPPDATA%\Lumina\flutter` klasörüne clone edilir (`git clone --filter=blob:none -b stable`) ve `bin`
   klasörü kullanıcı PATH'ine eklenir.
3. **Lumina Studio.** Setup editörü taşıyan en son release'i bulur (yukarıda: `/releases/latest`, yoksa onu
   taşıyan en yeni pre-release), `lumina-studio-<tag>-windows-x64.zip` dosyasını indirir, SHA-256'sını doğrular ve
   `%LOCALAPPDATA%\Programs\Lumina Studio` klasörüne açar. İndirme başarısız olursa setup yeniden denemeyi önerir.
4. **Kısayollar.** Başlat menüsünde "Lumina Studio", "Update Lumina Studio" (en son release'i yeniden indirir) ve
   uninstaller; isteğe bağlı olarak bir masaüstü kısayolu.

Setup, Inno Setup'ın `RedirectionGuard=no` ayarıyla çalışır. Windows bu korumayı setup'ın başlattığı her sürece
aktarır; bitiş sayfasından başlatılan Lumina Studio da o zaman motor checkout'unun ve projelerin junction'larından
geçemezdi. Lumina Studio da Windows'ta açılışta bu politikayı denetler: onu başlatan süreç redirection trust'ı
zorunlu kıldıysa, aynı argümanlarla Windows kabuğunun alt süreci olarak yeniden başlar; bu mümkün değilse Başlat
menüsünden açılmasını söyler.

Kaldırma editör klasörünü siler. Setup'ın kurduğu bir Flutter SDK'yı silmeden önce sorar ve silerse PATH
girdisini de kaldırır. Git, Build Tools, GStreamer ve FFmpeg kurulu kalır, çünkü başka programlar da
kullanıyor olabilir.

İşi `windows/lumina-setup.ps1` yapar; setup onu `{app}\setup\` altına kurar. Tek başına da çalışır:

```powershell
powershell -ExecutionPolicy Bypass -File installer\windows\lumina-setup.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File installer\windows\lumina-setup.ps1 -StudioOnly   # yalnızca editörü (yeniden) indir
```

Çıkış kodları: 0 tamam, 10 bir ön koşul kurulamadı, 20 Flutter kurulamadı, 30 editör indirilemedi, 1 diğer.
Log dosyası `{app}\setup\install.log`.

### Dry run

```powershell
lumina-studio-setup-v0.1.0-windows-x64.exe /DRYRUN
lumina-studio-setup-v0.1.0-windows-x64.exe /DRYRUN /FFMPEG /DRYRUNLOG=C:\temp\plan.txt /VERYSILENT
```

`/DRYRUN` planı gösterir ve wizard açılmadan 0 ile çıkar. Plan her ön koşulu ya kurulu olarak ya da tam winget
komutuyla listeler; Flutter adımını ve release asset'ini URL'si ve boyutuyla gösterir. Hiçbir şey kurulmaz ya da
indirilmez; tek ağ erişimi release metadata'sının okunmasıdır. Rapor `/DRYRUNLOG` dosyasına yazılır (varsayılan
`%TEMP%\lumina-studio-setup-dryrun.txt`) ve setup `/VERYSILENT` ile çalışmıyorsa bir mesaj kutusunda gösterilir.

### Yerelde build

```powershell
winget install JRSoftware.InnoSetup
./installer/windows/build.ps1 -Version 0.1.0 -Tag v0.1.0 -OutDir dist
```

Sonuç `dist/lumina-studio-setup-v0.1.0-windows-x64.exe` ve `.sha256` dosyasıdır. Setup ikonu
`lumina_ui/windows/runner/resources/app_icon.ico`.

### MSIX

Release editörü bir MSIX olarak da taşır. Bunu mevcut `lumina_ui/tool/package_windows.dart --publish` üretir;
kimlik `lumina_ui/pubspec.yaml` içindeki `msix_config`'ten gelir (Store rezervasyonu `LuminaEngine.LuminaEngine`).
Sertifika GitHub secret'larından gelir (aşağıda). Secret'lar yoksa workflow MSIX'i bir notice ile atlar. Sertifika
ve parolası hiçbir zaman repository'ye ya da log'lara girmez. `.pfx` runner'ın temp klasörüne açılır ve
imzalamadan sonra silinir.

Her release ayrıca Microsoft Store paketini, `lumina-studio-<tag>-windows-x64-store.msix`'i taşır
(`package_windows.dart --store`): imzasızdır, çünkü Store kabul ettiği her paketi yeniden imzalar; publisher
`msix_config`'teki Partner Center publisher'ı `CN=76408633-2846-4256-BED6-0DF8748A95C6`'dır. Secret gerektirmez.
Partner Center'a yüklenir (Store ID `9PHJG2NH6BQF`); Store imzalayana kadar yerelde kurulmaz. Sürümü check job'ının
`msix_version`'ıdır (`tool/release/release_info.dart`): `0.0.1-dev.10` → `1.0.1010.0`, `0.0.1` → `1.0.1999.0`,
`1.0.0` → `2.0.999.0`; böylece her tag'de büyür ve Store kurallarına uyar (dördüncü bölüm 0, birinci 0 değil).
Şema ve manifest kontrolleri `lumina_ui/tool/README.md`'de.

### Windows release'ini imzalamak (Certum)

Bir release'in Windows zip'i ve setup'ı, Certum "Open Source Code Signing in the Cloud" sertifikasıyla Authenticode
imzalı olabilir. Sertifikanın anahtarı Certum'un bulutunda (SimplySign) kalır: yalnızca maintainer'ın Windows
makinesindeki SimplySign Desktop üzerinden, telefondan gelen tek kullanımlık bir kodla açılarak kullanılabilir; bu
yüzden CI onunla imzalayamaz. `LUMINA_WINDOWS_SIGNING=local` repository değişkeniyle release workflow'u release'i
**draft** olarak oluşturur (pre-release, pre-release olarak kalır) ve notları "Windows assets are being signed"
satırıyla başlar; `tool/release/sign_windows_release.ps1` işi o makinede bitirir.

Bir kerelik kurulum:

1. Certum "Open Source Code Signing in the Cloud" sertifikasını sipariş edin. Sertifika bir açık kaynak
   geliştiricisine verilir; geliştiricinin adı sertifikanın subject'inde yer alır.
2. Kimlik doğrulama: Certum sertifikayı vermeden önce kimliğinizi (bir kimlik belgesi; siparişin talimatlarını
   izleyin) ve açık kaynak projeyi doğrular.
3. Windows makinesine SimplySign Desktop'ı, telefona SimplySign uygulamasını kurun ve hesabı Certum'un gönderdiği
   bilgilerle etkinleştirin. SimplySign Desktop'a uygulamadaki bir kodla giriş yapın: sertifika o zaman Windows
   sertifika deposunda görünür. Subject'ini ya da thumbprint'ini not edin:
   ```powershell
   Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Format-List Subject, Thumbprint, NotAfter
   ```
4. Aynı makinede: Windows SDK imzalama araçları (`signtool.exe`), Inno Setup 6, bu repository'nin bir checkout'uyla
   git ve repository'ye yazma yetkisiyle giriş yapmış GitHub CLI (`gh auth login`).
5. `LUMINA_WINDOWS_SIGNING` repository değişkenini `local` yapın (Settings > Secrets and variables > Actions >
   Variables ya da `gh variable set LUMINA_WINDOWS_SIGNING --body local -R LuminaGame/lumina`).

Her release'te, workflow bittikten ve SimplySign Desktop'a giriş yapıldıktan sonra, repository kökünden:

```powershell
powershell -ExecutionPolicy Bypass -File tool\release\sign_windows_release.ps1 -Tag v0.1.0 -CertificateSubject "<subject ya da CN>" -DryRun
powershell -ExecutionPolicy Bypass -File tool\release\sign_windows_release.ps1 -Tag v0.1.0 -CertificateSubject "<subject ya da CN>" -Publish
```

Sertifika `-CertificateSubject` yerine `-Thumbprint <sha1>` ile de seçilebilir. Script:

1. `signtool.exe`, `ISCC.exe`, git, `gh` ve sertifikayı (private key var, Code Signing kullanımı, süresi dolmamış)
   kontrol eder; SimplySign Desktop yoksa "Start SimplySign Desktop and log in" der;
2. draft'tan `lumina-studio-<tag>-windows-x64.zip`, `lumina-studio-setup-<tag>-windows-x64.exe` ve `.sha256`
   dosyalarını indirir, zip'i sidecar'ına karşı doğrular;
3. `lumina_ui.exe`'yi ve bizim DLL'lerimizi imzalar (`signtool sign /fd sha256 /tr http://time.certum.pl /td sha256 /sha1 <thumbprint>`)
   ve her birini doğrular (`signtool verify /pa`). Zaten geçerli bir imzası olan dosyalara, örneğin Microsoft'un
   Visual C++ runtime DLL'lerine dokunmaz;
4. zip'i aynı girdilerle, aynı sırada yeniden yazar ve `.sha256` dosyasını özgün biçimde yazar;
5. setup'ı tag'in `installer/windows` kaynaklarından (`git archive`) aynı sürümle `build.ps1 -SignToolCommand`
   üzerinden yeniden build eder; böylece setup.exe ve kurduğu uninstaller ikisi de imzalı olur (CI'ın build ettiği
   setup.exe'yi sonradan imzalamak uninstaller'ı imzasız bırakırdı) ve `.sha256` dosyasını yeniden yazar;
6. dört dosyayı release'te değiştirir (`gh release upload --clobber`); `-Publish` ile draft'ı yayımlar ve
   notlardaki "being signed" satırını değiştirir. `-Publish` olmadan release, kontrol etmeniz için draft kalır.

Her dosyayı, imzalayanı ve timestamp'iyle birlikte bir tabloda yazdırır. Bütün iş `%TEMP%\lumina-sign-<tag>`
(`-WorkDir`) içinde yapılır ve her çalıştırma indirilen özgün dosyalardan yeniden başlar; yani bir çalıştırma
olduğu gibi tekrarlanabilir. `-TimestampUrl` timestamp sunucusunu değiştirir (varsayılan Certum'un
`http://time.certum.pl` adresi). Çevrimdışı, `-FromDir <klasör>` dört dosyayı bir klasörden alır ve imzalı olanları
GitHub'a dokunmadan `-OutDir` klasörüne (varsayılan `<klasör>\signed`) yazar.
`tool/release/sign_windows_release_test.ps1 -FromDir <klasör> -Tag <tag>` çevrimdışı modu, sonradan atılacak
self-signed bir sertifikayla (`-AllowUntrustedForTest`) uçtan uca çalıştırır ve sertifikayı en sonda siler.

Release'i zaten var olan bir tag için release workflow'unu yeniden çalıştırmak Windows asset'lerini yine imzasız
build'lerle değiştirir; bu modda release de yeniden draft olur, script'i tekrar çalıştırın. Installer kaynakları
imzalı setup build'lerinden eski olan tag'ler `-InstallerSourceRef <commit>` ister.

Yeni bir sertifikanın henüz SmartScreen itibarı yoktur: Windows ilk imzalı indirmelerde hâlâ uyarabilir; uyarı
imzalı indirmeler biriktikçe kaybolur. MSIX ayrıca, CI'da imzalanır (yukarıda).

## Linux: .deb ve .rpm

Editor ve projeleri build ettiği libc++ glibc 2.38 ya da üstünü ister (Ubuntu 24.04, Debian 13, Fedora 39 ve sonrası). Paket build ve çalışma bağımlılıklarını bildirir:

| Debian / Ubuntu | Fedora / RHEL | Neden |
|---|---|---|
| `git`, `curl`, `ca-certificates`, `tar`, `unzip`, `xz-utils`, `zip` | aynısı (`xz`) | Flutter, indirmeler |
| `clang`, `cmake`, `ninja-build`, `pkg-config` | `clang`, `cmake`, `ninja-build`, `pkgconf-pkg-config` | `flutter build linux`, native-assets hook'ları |
| `libgtk-3-dev`, `liblzma-dev`, `libstdc++-1{4,3,2}-dev` | `gtk3-devel`, `xz-devel`, `libstdc++-devel` | Flutter Linux runner'ı |
| `libwayland-dev`, `wayland-protocols` | `wayland-devel`, `wayland-protocols-devel` | pointer capture (Wayland) |
| `libgstreamer1.0-0`, `gstreamer1.0-plugins-base`, `gstreamer1.0-plugins-good`, `gstreamer1.0-tools` | `gstreamer1`, `gstreamer1-plugins-base`, `gstreamer1-plugins-good`, `gstreamer1-plugins-base-tools` | video kaydı |
| `libgl1`, `libvulkan1` | `libglvnd-glx`, `vulkan-loader` | renderer'ın OpenGL / Vulkan backend'leri |
| `libasound2-dev`, `libmpv-dev` | `alsa-lib-devel`, `mpv-devel` | ses ve video oynatma (media_kit) |

Paketin kurdukları:

- `/usr/bin/lumina-studio`: launcher. `/opt/lumina/flutter/bin`'i PATH'in başına koyar ve editörü başlatır.
  Editör yoksa önce onu indirir. `lumina-studio --update` en son release'i indirir.
- `/usr/lib/lumina-studio/install-studio.sh`: Linux tarball'ını indirir, doğrular ve yerine koyar.
- `/usr/share/applications/io.github.luminagame.LuminaStudio.desktop`: "Update Lumina Studio" action'ı olan menü girdisi.
- 3D model MIME türleri, `lumina-thumbnailer` ve onun `.thumbnailer` girdisi (aşağıda "3D model dosyaları").
- `/usr/share/icons/hicolor/scalable/apps/lumina-studio.svg` ve `/usr/share/pixmaps/lumina-studio.png`:
  `lumina_ui/assets/app_icon.png` ikonu (Lumina amblemi).

Postinstall script'i:

1. `lumina` system group'unu oluşturur. `/opt/lumina` bu gruba aittir (setgid, grup yazabilir) ve `sudo` /
   `pkexec` çalıştıran kullanıcı gruba eklenir; üyelik bir sonraki oturum açılışında geçerli olur. Grup üyeleri
   editörü güncelleyebilir ve ortak Flutter SDK'yı kullanabilir.
2. `/opt/lumina/flutter` içinde ya da PATH'te zaten bir Flutter varsa onu korur. Yoksa stable kanalını
   `/opt/lumina/flutter` klasörüne clone eder, system git config'e bir `safe.directory` girdisi ekler,
   `flutter precache --linux` çalıştırır ve ağacı gruba devreder.
3. En son `lumina-studio-<tag>-linux-x64.tar.gz` dosyasını `/opt/lumina/studio` klasörüne indirir.
4. `clang` 19'dan eskiyse uyarır. Motorun native kodu kendi taşıdığı libc++ 21 header'larıyla build edilir;
   eski dağıtımlarda <https://apt.llvm.org> üzerinden daha yeni bir clang kurun.

Ağ sorunları kurulumu hiçbir zaman başarısız yapmaz. GitHub'a ulaşılamazsa script bunu söyler ve launcher
editörü ilk çalıştırmada indirir. `LUMINA_SKIP_DOWNLOAD=1` bütün indirmeleri atlar. `/opt/lumina`'ya yazamayan
bir kullanıcı editörü `~/.local/share/lumina/studio` altına alır.

Kaldırmada (`apt remove`, `dnf remove`; upgrade'de değil) paket `/opt/lumina/studio`'yu siler; paket kurduysa
`/opt/lumina/flutter`'ı ve onun `safe.directory` girdisini de siler. Purge (deb) ya da erase (rpm) `lumina`
grubunu da kaldırır. `~/.local/share/lumina` altındaki kullanıcı indirmeleri kalır.

### Yerelde build

```bash
installer/linux/build.sh 0.1.0 v0.1.0 dist    # PATH'teki nfpm'i kullanır ya da nfpm 2.47.0'ı build/nfpm/ altına indirir
dpkg-deb -I dist/lumina-studio_0.1.0-1_amd64.deb
dpkg-deb -c dist/lumina-studio_0.1.0-1_amd64.deb
```

Windows'ta WSL içinde çalıştırın. Pre-release sürümler nfpm'in semver kurallarına uyar (`0.1.0-beta.1`, .deb
içinde `0.1.0~beta.1` olur).

## 3D model dosyaları: "Birlikte aç" ve thumbnail'lar

İki installer da Lumina Studio'yu `.glb`, `.gltf`, `.fbx` ve `.obj` dosyaları için kaydeder. Bu türlerin varsayılan programını hiçbir zaman değiştirmez.

**Birlikte aç.** Bir model dosyasını Lumina Studio ile açmak editörü yolu argüman olarak vererek başlatır (`lumina_ui <file>` ya da `--import <file>`). Projesiz bir dosyanın projesi olmadığından launcher, "Don't import" düğmesiyle birlikte "Open or create a project to import <file> into it." notunu gösterir. Kullanıcının sıradaki açtığı ya da oluşturduğu proje dosyaları normal import kuyruğuyla import eder (`contents/` altında otomatik düzenlenir) ve ilkini mesh editöründe açar. Proje kendi proje editöründe açılıyorsa dosyalar `--import` argümanları olarak ona geçer. Her "Birlikte aç" yeni bir editör süreci başlatır.

**Thumbnail'lar.** Kurulu editör bir dosyanın thumbnail'ını pencere açmadan çizer:

```text
lumina_ui --lumina-thumbnail <input> <output.png> [--size <px>]
```

Dosyayı bir import gibi çevirir ve Content Browser'ın thumbnail renderer'ıyla çizer: stüdyo ışık düzeni, sınırlara oturtulmuş üç çeyrek görünüm, PBR Neutral tone mapping, editörün Graphics Device ayarındaki GPU'da. Görselleri eksik bir `.gltf` beyaz dokularla çizilir. Çıkış kodları: 0 yazıldı, 64 hatalı argümanlar, 65 eksik, desteklenmeyen ya da okunamayan dosya, 70 hiçbir şey çizilmedi, 73 PNG yazılamadı. Her çağrı editörü başlatır (masaüstü GPU'sunda bir saniyenin epey altında). Dosya yöneticileri sonucu önbellekte tutar.

### Windows

Setup'ın "3D model files" görevi (varsayılan olarak açık) kullanıcı başına `HKCU\Software\Classes` altına şunları yazar:

| Anahtar | Değer |
|---|---|
| `LuminaStudio.Model` | "3D model", `DefaultIcon`, `shell\open\command` = `"{app}\lumina_ui.exe" "%1"` |
| `.glb`, `.gltf`, `.fbx`, `.obj` `\OpenWithProgids` | `LuminaStudio.Model` (boş değer): "Birlikte aç"ta Lumina Studio |
| `Applications\lumina_ui.exe` | `FriendlyAppName` "Lumina Studio", `SupportedTypes` (dört uzantı), `shell\open\command` |
| `CLSID\{4C2F5D1E-8A3B-4E7C-9D21-6B0A5F3E7C18}\InprocServer32` | `{app}\setup\shell\lumina_thumbnails.dll`, `ThreadingModel` = `Apartment` |
| `SystemFileAssociations\<ext>\ShellEx\{e357fccd-a995-4576-b01f-234630154e96}` | provider'ın CLSID'si |

Uzantı anahtarlarının varsayılan değerleri hiçbir zaman yazılmaz. Thumbnail handler'ı yalnızca `SystemFileAssociations` altındadır; kendi thumbnail'larını getiren bir varsayılan program onları korur. Kaldırma, setup'ın eklediği her değeri ve anahtarı siler (uzantı anahtarlarını yalnızca boşsa); `ChangesAssociations=yes` Explorer'ın bunları yeniden okumasını sağlar.

Thumbnail provider'ı (`windows/thumbnail_provider/`), `IInitializeWithStream` ve `IThumbnailProvider` uygulayan küçük bir C++ COM DLL'idir. Kendisi hiçbir şey çizmez. Explorer'ın verdiği stream'i `%TEMP%\LuminaThumbnails\` içine kopyalar, `{app}\lumina_ui.exe --lumina-thumbnail`'ı gizli, normalin altındaki önceliğe sahip ve 30 saniye sonra süreç ağacını öldüren bir job object içinde çalıştırır ve PNG'yi WIC ile yükler. Adlandırılmış bir semaphore aynı anda iki render'a izin verir. Her hata `WTS_E_FAILEDEXTRACTION` gibi bir hata döndürür; Explorer normal ikonu korur. Explorer onu yalnızca stream (yol değil) alan yalıtılmış surrogate sürecinde çalıştırır; bu yüzden harici `.bin`/görselleri olan bir `.gltf` ikonunu korur, bir `.obj` ise `.mtl`'si olmadan çizilir. `LUMINA_THUMBNAIL_EDITOR` DLL'i başka bir editör çalıştırılabilirine yönlendirir. Explorer'ın hâlâ tuttuğu bir DLL, bir güncelleme üzerine yazmadan ya da kaldırma klasörü silmeden önce kenara alınır (`lumina_thumbnails-<time>.old`).

`build.ps1` provider'ı Visual Studio 2022 C++ araçlarıyla derler (`windows/thumbnail_provider/build.ps1`: `vswhere`, `vcvars64.bat`, `cl /O2 /MT /W4 /WX`; Visual C++ runtime'ına ihtiyaç duymaz) ve setup.exe içine gömer. İmzalı bir setup build'i DLL'i de imzalar. `-SkipThumbnailProvider` onsuz bir setup üretir (yalnızca "Birlikte aç"). Aynı script kurulmayan `thumbnail_check.exe`'yi de derler:

```powershell
installer\windows\thumbnail_provider\build.ps1 -OutDir build\thumbnail_provider
$env:LUMINA_THUMBNAIL_EDITOR = 'lumina_ui\build\windows\x64\runner\Release\lumina_ui.exe'
build\thumbnail_provider\thumbnail_check.exe build\thumbnail_provider\lumina_thumbnails.dll model.glb out.png 256
# DLL'i kaydetmeden yükler, dosyayı stream olarak verir, bitmap'i kaydeder
regsvr32 build\thumbnail_provider\lumina_thumbnails.dll        # setup'ın yaptığı gibi kullanıcı başına kayıt
build\thumbnail_provider\thumbnail_check.exe --shell model.glb out.png 256   # shell üzerinden
regsvr32 /u build\thumbnail_provider\lumina_thumbnails.dll     # kaydı yeniden siler
```

`regsvr32` ile DLL, `LUMINA_THUMBNAIL_EDITOR` verilmemişse editörü iki klasör yukarıda bulur (`<dir>\..\..\lumina_ui.exe`). Microsoft Store MSIX'i henüz dosya türü bildirmiyor.

### Linux

Paket şunları kurar:

- `/usr/share/mime/packages/lumina-studio-models.xml`: `model/gltf-binary` (`*.glb`, `glTF` magic), `model/gltf+json` (`*.gltf`), `model/x-fbx` (`*.fbx`, `Kaydara FBX Binary` magic) ve `model/obj` (`*.obj`, eski TGIF glob'unun üstünde ağırlıkla). Güncel shared-mime-info glTF ve OBJ türlerini zaten bilir; FBX yenidir.
- `Exec=lumina-studio %F` ve bu dört türü içeren `MimeType=` ile `.desktop` girdisi: Lumina Studio "Birlikte aç" adayı olur.
- `/usr/bin/lumina-thumbnailer <input> <output> [size]`: kurulu editörün `--lumina-thumbnail`'ını (önce `~/.local/share/lumina/studio`, sonra `/opt/lumina/studio`) `timeout 30` altında çalıştırır. Hiçbir şey indirmez: editör yoksa 1 ile çıkar.
- `/usr/share/thumbnailers/lumina-studio.thumbnailer`: dört tür için `Exec=lumina-thumbnailer %i %o %s`.

postinstall ve postremove script'leri, varsa `update-mime-database` ve `update-desktop-database` çalıştırır. Thumbnailer'lar Nemo, Caja, Thunar (tumbler üzerinden) ve `.thumbnailer` dosyalarını kullanan diğer dosya yöneticilerinde çalışır. GNOME Files onları `/opt`'a ve GPU'ya erişimi olmayan bir bubblewrap sandbox'ında çalıştırır; editör orada başlayamaz ve Nautilus ikonu korur. Dolphin `.thumbnailer` dosyaları yerine KIO eklentilerini kullanır.

## macOS: .pkg (doğrulanmadı)

`macos/build-pkg.sh <version> [<tag>] [<out-dir>]` bir `.pkg` build eder; payload'u yalnızca
`/usr/local/bin/lumina-studio` launcher'ı ve bir indirme script'idir. Postinstall script'i:

1. Xcode Command Line Tools'u kontrol eder, eksikse installer'ını başlatır;
2. `git cmake ninja gstreamer` paketlerini oturumdaki kullanıcı olarak Homebrew ile kurar, Homebrew yoksa
   komutu yazdırır;
3. PATH'te bir Flutter yoksa Flutter'ı (stable) `/opt/lumina/flutter` klasörüne clone eder;
4. en son `lumina-studio-<tag>-macos-*.zip` dosyasını `/Applications/Lumina Studio.app` olarak indirir.

`LUMINA_PKG_SIGN_IDENTITY`, ürünü bir Developer ID Installer kimliğiyle imzalar. Henüz hiçbir macOS build'i
doğrulanmadığı için release workflow'unun macOS job'u kapalıdır (`if: false`). Neyin eksik olduğunu job'un
yorumu listeler.

## GitHub yapılandırması

| Ad | Tür | Kullanım |
|---|---|---|
| `LUMINA_MSIX_PUBLISHER` | secret | MSIX: sertifika subject'i; paket publisher'ına eşit olmalı |
| `LUMINA_MSIX_CERT_BASE64` | secret | MSIX: code-signing `.pfx` dosyası, base64 |
| `LUMINA_MSIX_CERT_PASSWORD` | secret | MSIX: `.pfx` parolası |
| `LUMINA_MSIX_TIMESTAMP_URL` | variable (isteğe bağlı) | MSIX: RFC 3161 timestamp sunucusu |
| `LUMINA_WINDOWS_SIGNING` | variable (isteğe bağlı) | `local`: release'ler draft olarak oluşturulur, Windows zip'i ve setup'ı `tool/release/sign_windows_release.ps1` ile imzalanır (yukarıda) |

Geri kalan her şey workflow'un kendi `GITHUB_TOKEN`'ını kullanır. Yalnızca `release` job'u `contents: write`
alır.
