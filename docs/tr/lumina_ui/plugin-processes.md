[English](../../en/lumina_ui/plugin-processes.md)

# Eklenti süreçleri (editör tarafı)

Lumina Studio'nun `.lmplugin` dosyası `"isolation": "process"` isteyen eklentileri nasıl çalıştırdığı, izlediği ve
yeniden başlattığı. Eklenti tarafı (`LuminaPluginProcess`, `runPluginProcessMain`, vekiller)
[Eklenti süreçleri](../lumina_plugin_process/plugin-processes.md) sayfasında, tel protokolü `lumina_plugin_protocol`
paketindedir. Dosya yolları `lumina_ui/` paket dizinine görelidir.

## Kısaca

- Yalıtılmış bir eklentinin süreç parçası kendi sürecinde çalışır: editörün kendi çalıştırılabilir dosyası
  `--lumina-plugin-process <ad> --lumina-plugin-port <port> --lumina-plugin-token <token> [--lumina-plugin-project <dizin>]`
  ile yeniden başlatılır. Bu kipte `runLuminaEditor` pencere göstermez, çökme oturumu başlatmaz, eklenti kaydını
  yüklemez; `LuminaEditorHost.pluginProcesses[ad]` parçasını `runPluginProcessMain` ile çalıştırır ve onun koduyla
  çıkar (bilinmeyen ad stderr'e bir mesajla 64 koduyla çıkar).
- **Windows'ta başsız (headless)**: runner (`windows/runner/main.cpp`, her proje editörüne kopyalanır) bayrağı görür
  ve aynı giriş noktası argümanlarıyla bir `flutter::FlutterEngine` ile mesaj döngüsü çalıştırır: pencere, görünüm ve
  yüzey yok, Impeller kapalı, düşük güçlü GPU tercih edilir. Hiçbir yerel eklentiyi kaydetmez (editörünküler
  window_manager, media_kit, screen_retriever, fare yakalama ve ses düzeyidir; hepsi bir görünüm ister, media_kit_video
  kayıt sırasında onu kullanır) ve eklenti DLL'leri gecikmeli yüklenir (`windows/CMakeLists.txt`), bu yüzden libmpv de
  hiç yüklenmez. Süreç parçası yerel koda FFI ile ulaşır; method channel kullanan bir eklenti `MissingPluginException`
  döner. Release bir proje editöründe ölçülen: eklenti süreci başına yaklaşık 102 MB çalışma kümesi / 117 MB özel bellek
  ve 52 iş parçacığı; gizli runner penceresiyle 136 MB / 157 MB ve 118 iş parçacığıydı.
- **Linux hiç gösterilmeyen bir pencereyi korur**: flutter_linux 3.47 `fl_engine_new_headless` fonksiyonunu (düz bir
  `fl_engine_new`) dışa açar ama `fl_engine_start` fonksiyonunu açmaz; bir engine'i başlatmanın tek açık yolu bir
  `FlView`'ı bir `GtkWindow` içinde realize etmektir (`GtkOffscreenWindow` içindeki bir `FlView` da başlar, ama GDK
  engine'in monitör aramasında assertion verir, Wayland'de her seferinde). Bu yüzden runner
  (`linux/runner/my_application.cc`, her proje editörüne kopyalanır) görünümü hiç map edilmeyen ve odak almayan düz 1×1
  bir üst düzey pencerede realize eder: X11'de hiçbir pencere yöneticisinin, görev çubuğunun ya da çalışma alanı
  değiştiricinin listelemediği map edilmemiş bir pencere, Wayland'de hiçbir compositor'ın göstermediği, kabuk rolü
  olmayan bir yüzey. Engine flutter_linux'un yazılım çizicisini kullanır (görünüm oluşturulurken
  `FLUTTER_LINUX_RENDERER=software`, sonra eski değeri geri yüklenir, uyarısı süzülür); böylece görünüm GDK GL bağlamı ya
  da GL compositor oluşturmaz ve Windows'taki gibi hiçbir yerel eklenti kaydedilmez (kaydetmek ses aygıtlarını da
  açıyordu). Eklenti `.so` dosyaları bağlı kalır, Linux'ta gecikmeli yükleme yoktur. WSLg altında (Mesa llvmpipe)
  release bir proje editöründe ölçülen: eklenti süreci başına yaklaşık 209 MB RSS / 77 MB özel kirli bellek ve 77 iş
  parçacığı; gizli bir `GtkApplicationWindow`, GL çizici ve kayıtlı eklentilerle 271 MB / 131 MB ve 142 iş parçacığıydı.
- **Thumbnail kipi aynı yolu kullanır**: iki runner da `--lumina-thumbnail` (`ModelThumbnailCommand`) için aynı pencere
  açmayan engine'i başlatır; bu kip dosya yöneticileri için bir model dosyasının thumbnail'ını Filament'in kendi
  headless swap chain'inde çizer (bkz. [Launcher ve detaylar](launcher-and-details.md#dosya-yöneticisinden-açılan-model-dosyaları)).
- **Linux'ta doğrulandı** (WSL2 + WSLg içinde Ubuntu 26.04, Flutter 3.47.5): `lumina_ui`'nin ve üç yalıtılmış eklentili
  bir proje editörünün `flutter build linux` derlemesi (debug ve release); `lumina_ui`, `lumina_editor_api` ve
  `lumina_plugin_protocol` eklenti süreci testleri; bilinmeyen bir eklenti adı yarım saniyenin altında 64 ile çıkar;
  X11 altında (`GDK_BACKEND=x11`) `xwininfo` her eklenti sürecinin penceresini `IsUnMapped` 1×1 olarak listeler ve
  etkin pencere editörünki kalır, Windows yalnızca editörün WSLg penceresini listeler, Wayland altında `WAYLAND_DEBUG`
  hiçbir `xdg_surface`/`get_toplevel`, `attach` ya da `commit` isteği göstermez; eklentilerin MCP araçları yanıt verir;
  bir eklenti sürecine `kill -9` bir `plugin_crash` raporu oluşturur ve süreci 1, 2 ve 4 sn sonra yeniden başlatır,
  ardından eklenti Restart'a kadar durur; editör içi çalıştırma ve geri dönüş çalışır; editörü öldürmek her eklenti
  sürecini sonlandırır.
- Editör her eklenti için 0 portunda bir loopback soketi açar, sürecin `host.hello` mesajını (protokol sürümü ve rastgele
  token) denetler ve `host.register` katkılarını eklentinin adıyla kaydeder: menü öğeleri, yuva düğmeleri, MCP araçları,
  içe aktarıcılar, konsol komutları ve bildirimsel paneller. Eylemleri süreçte çalışır. Komut satırındaki proje
  klasörü ve hello yanıtındaki her klasör (proje, kullanıcı ve proje depolaması, eklentinin kurulu olduğu klasör)
  normalleştirilir: tek bir ayırıcı biçimi, `.` ya da `..` parçası yok.
- Süreçteki yerel bir çökme, takılma ya da sızıntı editörü asla düşürmez. Editör süreci 2 sn'de bir yoklar; art arda üç
  yanıtsız yoklama **hung** (takıldı) demektir: tüm süreç ağacı öldürülür ve eklenti yeniden başlar. Kendiliğinden biten
  süreç **crashed** (çöktü) olur: bir `plugin_crash` çökme raporu açılır ve eklenti yeniden başlar. Otomatik yeniden
  başlatmalar 1, 2 ve 4 sn bekler; üçüncüden sonra eklenti kullanıcı Restart'a basana dek **stopped** (durdu) kalır
  (Restart sayacı sıfırlar; bir dakika sorunsuz çalışmak da).
- Eklenti çalışmazken katkıları yerinde kalır ama kullanılamaz: menü öğeleri ve yuva düğmeleri "`<eklenti>` stopped:
  `<neden>`" ipucuyla devre dışıdır (düz ya da işaretlenebilir, her menü satırı aynı biçimde: soluk etiket ve simge, üzerine
  gelince vurgu yok), MCP araçları hata sonucu döner, panelleri, sekmeleri ve varlık editörleri süreç
  korumasını gösterir. Yeniden başlatma onları tekrar kaydeder (yerine koyar, asla çoğaltmaz).
- **Run in editor process (debugging)**: projenin `.lmproject` `plugin_isolation: {"<ad>": "in_process"}` girdisi
  (Eklenti Yöneticisi'ndeki anahtar) aynı süreç parçasını aynı loopback protokolüyle editörün içinde çalıştırır, durum
  **in process** olur; editöre bağlı hata ayıklayıcı eklenti kodunda durabilir. Oradaki bir çökme ya da takılma editörü
  etkiler.

## Kernel eklentileri

- Bir kernel eklentisi ([Editör eklentileri](../plugins/index.md#kernel-eklentileri-editör-yeniden-derlenmeden))
  `LuminaEditorHost.pluginProcesses` içinde değildir: `PluginProcessManager.syncKernelPlugins`, her etkinleştirme,
  kapatma, yeniden tarama, kurulum ve kaldırmadan sonra eklenti kayıt defterinin `enabledKernelPlugins` listesini alır
  (`EditorViewModel` onu `_updatePluginState` içinden çağırır). Yenisi bir denetçi alır ve başlar; listeden çıkan ya
  da başka sürüm veya klasörle geri gelen `core.shutdown` alır (sonra öldürülür) ve katkılarını, panellerini, MCP
  araçlarını ve diyaloglarını kaybeder; güncellenen yeniden başlar. `PluginRegistryService.setEnabled` onun için
  yeniden başlatma işaretlemez.
- Denetçisinin bir `prepareLaunch` adımı vardır (`KernelPluginPreparer`, `kernel_plugin_preparer.dart`): gelen `.dill`
  `.sha256` ile eşleşmelidir (yoksa eklenti nedeniyle durdurulur, hiç başlatılmaz); `process_kernel_sdk` VM'nin SDK
  sürümüne (`dart --version`) eşitse gelen kernel çalışır; değilse `process_entry` derlenir (`PluginKernelCompiler`,
  arka plan isolate'ında: paket yapılandırması yoksa önce `pub get --offline`, sonra çevrimiçi; erişim denetimi;
  `dart compile kernel`) ve `<LuminaDataDir>/plugin_kernels/<ad>/<sürüm>/<sdk>/<kaynak özeti>.dill` dosyasına yazılır;
  orada duran bir kernel yeniden kullanılır. Süreç eklenti klasöründe `<dart-sdk>/bin/dart <kernel> <başlatma
  bayrakları>` olarak başlar (`PluginProcessLauncher.kernel`). Hazırlık sürerken durum "Preparing `<eklenti>` for
  Dart `<x>`…" nedeniyle `starting` olur; her aşama eklentinin ilerleme akışına ve günlüğüne gider.
- stderr'i VM'nin kernel'i reddettiğini gösteren bir çalışma ("Invalid SDK hash", "Can't load Kernel binary") çökme
  sayılmaz: bir sonraki başlatma hemen yeniden derler (arka arkaya bir kez). Derleme hatası eklentiyi "could not be
  prepared" ile durdurur ve derleyici çıktısını Eklenti Yöneticisi için `preparationError` içinde tutar; çökme raporu
  ve yeniden başlatma döngüsü yoktur. Çalışan bir kernel eklentisinin çökmesi, takılması ya da öldürülmesi derlenmiş
  yalıtılmış bir eklentideki gibi işlenir.
- Dart SDK'sı, editörün proje derlemeleri için kullandığı Flutter SDK'sının içindekidir (`KernelDartSdk`:
  `FLUTTER_ROOT`, editörün paket yapılandırması, PATH'teki `flutter`); bulunamazsa hazırlık bu nedenle başarısız olur.

## Eklenti sürecinin açtığı diyaloglar

`host.showDialog` (bir `PluginDialogSpec`: gövde kontrolleri ve eylemleriyle `dialog` ya da `confirm`)
`PluginDialogQueue.shared` (`plugin_dialog_queue.dart`) kuyruğuna girer ve `PluginDialogLayer`
(`lib/ui/core/widgets/plugin_view/plugin_process_dialog.dart`, `editor_entry.dart` içinde her pencereyi sarar)
tarafından gösterilir: karartılmış bir bariyer üstünde, gövdesini `PluginViewRenderer` çizen ve düğmeleri eylemler olan
(primary, destructive ya da outline) bir shadcn `AlertDialog`. Aynı anda tek diyalog görünür; bu yüzden bir eklentinin
iki diyaloğu açık olmaz, ikinci istek bekler. Bir düğme `{action, values}` yanıtını verir (gövde kontrollerinin
kimliğe göre değerleri; metin alanı, odak düğmeye geçince yazılanı işler); diyalog kapatılabilirse Escape ya da dışına
tıklama `{action: null}` yanıtını verir. `host.closeDialog` onu süreç tarafından kapatır. Çıkan bir süreç
diyaloglarını kapatır (`closeAllOf`). Bir eklentinin diyaloğu açıkken istek zaman aşımları (komutlar, MCP araçları,
kanal çağrıları) işlemez.

## Durumlar

`PluginProcessState.status` (`lumina_editor_api`), Eklenti Yöneticisi ve korumanın gösterdiği haliyle:

| Durum | Anlamı |
|---|---|
| `starting` | Başlatıldı; el sıkışma ya da `host.register` bitmedi (60 sn sınır, sonra takılmış sayılır). |
| `running` | Kayıtlı ve yoklamalara yanıt veriyor. |
| `inProcess` | Editörün içinde çalışıyor (projenin geçersiz kılması). |
| `hung` | Üç yoklama kaçırdı (ya da hiç başlamadı): öldürülüyor, ardından yeniden başlatma. |
| `crashed` | Kendiliğinden bitti (`exitCode`, `reason` "exited with code N"; sürecin kendi çıkış kodları açıklanır: 1 bağlantı koptu, 2 bağlanamadı, 3 el sıkışma reddedildi, 4 `register()` hata fırlattı); ardından yeniden başlatma. |
| `stopped` | Otomatik yeniden başlatmalardan sonra vazgeçildi ya da bilerek durduruldu; Restart başlatır. |
| `disabled` | Eklenti devre dışı (süreci olmayan eklentinin bağsız kanalı). |

## `lib/ui/core/services/plugin_process/plugin_process_supervisor.dart`

### `class PluginProcessSupervisor`

Yalıtılmış her eklenti için bir tane; aynı zamanda o eklentinin `PluginProcessChannel` nesnesidir, yani
`context.processChannel(ad)` çağrısının eklentinin süreç içi kabuğuna verdiği nesne.

| Üye | Amaç |
|---|---|
| `start()` | Bir süreç çalıştırması: loopback port, token, başlatma (ya da süreç içi çalıştırıcı), el sıkışma, kayıt, yoklamalar. |
| `restart()` | Kullanıcının Restart'ı: nazik `core.shutdown`, 3 sn sonra hâlâ yaşıyorsa öldürme, sonra `start`; otomatik yeniden başlatma sayacını sıfırlar. |
| `stop({reason})` / `shutdown()` | Kalıcı durdurma (`core.shutdown`, sonra öldürme); `shutdown` denetleyiciyi de bırakır (editör çıkışı). |
| `projectClosing()` / `projectOpened(project)` | `core.projectClosing` (5 sn sınırlı) / `core.projectOpened`. Hello yanıtı açık projeyi zaten bildirir. |
| `call(method, args, timeout)` | Kabuğun çağrısı (`core.call`), varsayılan 30 sn; çalışmıyorken `unavailable`, `timeout`, ya da süreç ölünce hemen `closed`. |
| `events([name])`, `progress` | Sürecin `host.event` ve `host.progress` mesajları. |
| `state`, `unavailableReason`, `lastExitCode`, `reportedPid`, `startCount` | Güncel durum, "`<eklenti>` stopped: `<neden>`", son çıkış kodu, sürecin hello'da bildirdiği pid, şimdiye dek başlatma sayısı. |
| `logTail`, `logRevision` | Sürecin stdout ve stderr çıktısı, `host.log` satırları ve denetleyicinin notları (son 300 satır); `logRevision` eklemeleri sayar. |
| `viewOf(viewId)`, `sendViewEvent(event)` | Bildirimsel bir panelin güncel tanımı (`host.view` değiştirir ya da yamalar) ve bir kullanıcı eyleminin gönderimi (`core.viewEvent`). |
| `inProcessRunner` | Süreç içi geçersiz kılma için ayarlanır (bir sonraki başlatmada geçerli olur). |

Sürecin istekleri burada yanıtlanır (`supervisor_host_handlers.dart`): açık seviye üzerinden `host.level`
(`EditorLevelJson` biçimleri; `beginTransaction`/`endTransaction` tek bir geri alma adımını sarar, içindeki — ya da onun
`tx` değerini taşıyan — her düzenleme ona katılır, açık bir işlem bağlantı kapanınca biter; seviye yokken `snapshot`
null döner), `host.saveAsset` (bayt olmadan yalnızca İçerik Tarayıcısını ve küçük resmi yeniler), `host.panels`,
`host.tabs`, `host.mcp.call`, eklentinin adıyla (ya da verdiği `source` ile) Çıktı Günlüğüne `host.log`,
`host.slotState`, `host.menuChecked`. Proje Ayarları eklentinin bloğunu uyguladığında sürece `core.settings`, seviye
değiştiğinde (gecikmeli) `core.levelChanged` bildirilir.

Sınırlar (`PluginSupervisorTimings`): yoklama 2 sn × 3, yeniden başlatma 1/2/4 sn, başlatma 60 sn, `call` 30 sn, menü
ve konsol komutları 30 sn, MCP araçları ve içe aktarıcılar 30 dk (bir üretim dakikalar sürebilir: takılmayı yoklamalar
yakalar, ölen süreç çağrıyı hemen düşürür), `core.projectClosing` 5 sn, kapanma payı 3 sn.

### `class ProcessBackedCommand`

Bir süreç menü öğesinin, yuva düğmesinin ya da yuva menü girdisinin `EditorCommand` nesnesi: `core.command` çalıştırır,
süreç çalışmazken `unavailableReason` ile devre dışıdır; menü çubuğu nedeni ipucu olarak gösterir.

## `lib/ui/core/services/plugin_process/plugin_process_manager.dart`

### `class PluginProcessManager`

Editöre derlenmiş yalıtılmış eklentilerin (`LuminaEditorHost.pluginProcesses`), süreç içi kabuğu olmayanlar dahil,
denetleyicileri. `EditorViewModel.pluginProcesses` onu oluşturur, kabuklar kaydolmadan önce uzantı kaydına bağlar ve
onlardan sonra her süreci başlatır. `supervisorOf(ad)`, `isIsolated(ad)`, `startAll()`,
`setRunInEditorProcess(ad, bool)` (kipi değiştirip yeniden başlatır; kanal nesnesi aynı kalır), `projectClosing()`,
`shutdownAll()` (`shutdownPlugins` içine bağlıdır; böylece `EditorHandOff.beforeExit` ve projenin kapanması süreçleri
durdurur).

## Diğer dosyalar

| Dosya | Amaç |
|---|---|
| `plugin_process_launcher.dart` | `PluginProcessLauncher`: program (varsayılan `Platform.resolvedExecutable`) ve `PluginProcessLaunch.toArgs()`, stdout/stderr borulu; testler bir Dart betiği başlatır. `killProcessTree` (`taskkill /T /F`, ya da `pgrep -P` + SIGKILL). |
| `plugin_process_host.dart` | `PluginProcessHost`: denetleyicinin editörden istedikleri; `PluginExtensionRegistry` uygular. |
| `plugin_isolation_overrides.dart` | Projenin `plugin_isolation` süreç içi geçersiz kılmasını okur ve yazar. |
| `plugin_process_entry.dart` | `runPluginProcessFromArgs`: `runLuminaEditor` fonksiyonunun eklenti süreci kipi. |
| `lucide_icon_table.dart` | Kod noktasına göre Lucide simgeleri: veri olarak gelen simge bir sabite döner, böylece sürüm derlemeleri simge yazı tiplerini budamaya devam eder (diğer yazı tipleri fiş simgesini gösterir). |
| `lib/ui/core/widgets/plugin_process_guard.dart` | `PluginProcessGuard`: çalışırken panel olduğu gibi, başlarken küçük bir dönen gösterge, aksi halde panel "`<eklenti>` stopped: `<neden>`" kartının altında soluk, **Restart** ve **Details** (günlük kuyruğu) ile. |
| `lib/ui/core/widgets/plugin_process_view_panel.dart` | `PluginProcessPanelView`: bildirimsel panelin gövdesi, güncel tanım üzerinde `PluginViewRenderer`. |
| `lib/ui/core/plugin_extension_registry_processes.dart` | Kaydın süreç tarafı: yalıtılmış eklentilerin kabuk panelleri, sekmeleri ve varlık editörleri korumaya sarılır; süreç katkıları kabuğunkilerden ayrı tutulur, böylece biri diğerini silmeden yeniden kaydolur. |

## Çökme raporları

Süreç ölümü `CrashReportKind.pluginCrash` (tel adı `plugin_crash`) olur: `CrashReporter.recordPluginCrash` onu eklenti
adı, çıkış kodu ve sürecin günlük kuyruğuyla açar; çökme raporu ekranı "A PLUGIN PROCESS STOPPED" gösterir. Editörün
oturum işaretçisine dokunulmaz. Editörün sonlandırdığı bir takılma çökme raporu değildir.

## Editör panelleri

Bir eklentinin editör paneli Widget Blueprint'leri (`content/EPW_*.lmas`, bkz. [Editör panelleri](editor-panels.md))
süreciyle konuşur: Call Plugin Process denetleyicinin `call` yolundan gider (`core.call`, 30 sn; süreç kapalıyken hemen
`unavailable`), On Plugin Process Event `host.event`'i alır, On Plugin Process State Changed denetleyicinin durumunu
izler ve `host.panelState` yamaları (`PluginProcessSupervisor.panelStates`) panellerin öğe durumlarını doğrudan, panel
başına saniyede en çok 30 kez ayarlar.
