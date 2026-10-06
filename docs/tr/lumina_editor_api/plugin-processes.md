[English](../../en/lumina_editor_api/plugin-processes.md)

# Eklenti süreçleri

Bir eklenti, çökebilecek, takılabilecek ya da bloklayabilecek kısmını kendi sürecinde çalıştırabilir: FFI üzerinden native kütüphaneler, alt süreçler, ağ çağrıları, ağır CPU işi, dosya üretimi. Orada bir native çökme ya da sonsuz döngü yalnızca o süreci bitirir; Lumina Studio çalışmaya devam eder, eklentiyi durmuş olarak işaretler, bir eklenti çökme raporu kaydeder ve Restart önerir. Bu sayfa bu ayrımın süreç tarafını anlatır: bir eklenti sürecinin kayıt yaptığı API, nasıl başlayıp bittiği, editöre ulaştığı proxy'ler ve mevcut, yalnızca veriyle çalışan bir eklentiyi değiştirmeden bir süreçte çalıştıran adaptör. Dosya yolları `lumina_editor_api/` paket dizinine görelidir; tel protokolünün kendisi `lumina_plugin_protocol` paketidir.

## Bir eklenti süreci nasıl çalışır

Bir eklenti `.lmplugin` dosyasında `"isolation": "process"` ile bunu seçer ve `LuminaPluginProcess` alt sınıfını editör modülünün `process_class` alanında adlandırır. Editör bir loopback portu bağlar ve kendi çalıştırılabilir dosyasını `--lumina-plugin-process <name> --lumina-plugin-port <port> --lumina-plugin-token <token> [--lumina-plugin-project <dir>]` ile yeniden başlatır (`PluginProcessLaunch`). Bu kipte çalıştırılabilir dosya pencere açmaz: eklentinin süreç parçasını oluşturur, `runPluginProcessMain(launch, process)` çağırır ve dönen kodla çıkar. Süreçte tam Flutter/Dart çalışma ortamı ve eklentinin editör build'ine zaten paketlenmiş native asset'leri vardır.

`runPluginProcessMain` (`lib/src/process/run_plugin_process.dart`):

1. `127.0.0.1:<port>` adresine bağlanır ve protokol sürümü, eklenti adı, token ve pid ile `host.hello` gönderir. Reddedilen bir hello (yanlış token, başka protokol sürümü) sıfır olmayan bir kodla biter.
2. Yanıttan `PluginProcessContext`'i kurar: açık proje, eklentinin proje ayarları, `PluginStorage` dizinleri. Açık bir proje varsa level anlık görüntüsünü alır.
3. `register(context)` çağırır, ardından kaydedilen her şeyi bir kez `host.register` ile gönderir. Bundan sonra slot butonu durumları ve menü onay işaretleri değiştikçe gönderilir.
4. Açık bir proje varsa `onProjectOpened` çağırır, sonra editörün isteklerine hizmet eder: `core.ping` (her 2 sn'de sağlık denetimi), `core.call` (kabuğun kanal çağrıları), `core.command`, `core.canExecute`, `core.mcpTool`, `core.import`, `core.console`, `core.viewEvent`, `core.projectOpened`, `core.projectClosing`, `core.shutdown` ile `core.settings` ve `core.levelChanged` bildirimleri.

Hata fırlatan bir handler isteğini bir hatayla yanıtlar ve hatayı eklentinin adıyla editör loguna yazar; döngü sürer. Eklentinin kodu korumalı bir zone'da çalışır, böylece yakalanmamış asenkron bir hata da süreci bitirmek yerine aynı şekilde loglanır. `LuminaPluginCrashReporter`'ı başka bir şey karşılamadığında (plugin sürecinde hep böyledir) eklentinin kendi çökme raporları eklenti kaynak olarak editör loguna hata düzeyinde gider; handler döngü bitince kaldırılır, süreç içi geçersiz kılmada editörün çökme raporlayıcısı yetkili kalır. `host.register` yanıtından önce gelen bir `core.shutdown` süreci temiz biçimde (kod 0) bitirir. CPU ağırlıklı iş yine `Isolate.run`'a aittir: isolate'i bloklayan bir handler sağlık ping'ini de durdurur ve üç kaçırılmış ping'den sonra editör süreci yeniden başlatır.

`servePluginProcess({input, output, pluginName, token, process})` aynı el sıkışmayı ve döngüyü çağıranın elindeki bir bayt akışı çifti üzerinden (örneğin kendi bağladığı bir soket) çalıştırır.

### Çıkış kodları

`PluginProcessExitCodes`:

| Kod | Ad | Anlamı |
|---|---|---|
| 0 | `ok` | `core.shutdown` yanıtlandı (`onShutdown` çalıştı). |
| 1 | `connectionLost` | Editör bağlantıyı kapattı ya da kapanma olmadan gitti. |
| 2 | `connectFailed` | Editörün portuna ulaşılamadı. |
| 3 | `refused` | Editör hello'yu reddetti (token ya da protokol sürümü). |
| 4 | `registerFailed` | `register` hata fırlattı ya da editör katkıları reddetti; hata editör logundadır. |

## LuminaPluginProcess

`lib/src/process/plugin_process.dart`. Bir eklentinin süreç parçası.

| Üye | Açıklama |
|---|---|
| `String get pluginName` | `.lmplugin` `name` değeri; kabuğun `LuminaEditorPlugin.pluginName` değeriyle aynı. |
| `FutureOr<void> register(PluginProcessContext context)` | Handler'ları ve katkıları kaydeder; el sıkışmadan sonra süreç çalışması başına bir kez çağrılır. |
| `FutureOr<void> onProjectOpened(EditorProjectInfo project)` | Bir proje açıldı (açık bir proje varsa `register`'dan hemen sonra da). |
| `Future<void> onProjectClosing()` | Proje kapanıyor: bekleyen yazmaları bitir. Editör tarafından süre sınırlıdır. |
| `Future<void> onShutdown()` | Süreç çıkmak üzere: alt süreçleri durdur, native kaynakları bırak. |

## PluginProcessContext

Bir eklenti sürecinin kayıt yaptığı ve editöre ulaştığı yer. Her şey sınırı veri olarak geçer.

| Üye | Açıklama |
|---|---|
| `project`, `pluginSettings`, `storage` | Açık proje, eklentinin uygulanmış proje ayarları (`core.settings` ile güncellenir) ve `PluginStorage`'ı (editörün hello'da verdiği dizinler; proje deposu `core.projectOpened` / `core.projectClosing`'i izler). |
| `level` | Açık level, bir `EditorLevelAccess` proxy'si olarak; aşağıya bakın. |
| `handle(method, handler)` | Kabuğun `PluginProcessChannel.call(method, args)` çağrısını yanıtlar; handler JSON döner. |
| `emit(name, [data])` | Kabuk için bir olay (`PluginProcessChannel.events`). |
| `progress(task, step:, done:, total:, message:, finished:)` | Uzun bir işin ilerlemesi; kabuk ve Plugin Manager gösterir. |
| `log(message, level:)` | Editör logunda eklentinin adıyla bir satır. |
| `saveAsset(relativePath:, bytes:, generateThumbnail:)` | Bir asset'i editör üzerinden kaydeder (küçük resim, Content Browser yenilemesi). |
| `registerMenu`, `registerMenuItem`, `registerSlotButton` | Komutları (`PluginProcessCommand`) süreçte çalışan menüler, menü öğeleri (isteğe bağlı bir `checked` listenable ile) ve slot butonları; `canExecute`'u olan bir komut editör onu etkinleştirmeden önce sorulur. |
| `registerMcpTool`, `registerImporter`, `registerConsoleCommand` | Süreçte işlenen MCP araçları, importer'lar (`PluginProcessImporter`; o mesajla başarısız olmak için `PluginImportError(message)` fırlatın) ve konsol komutları. |
| `registerViewPanel(PluginProcessViewPanel)` | Bildirimsel bir panel: editör `PluginViewSpec`'ini çizer, olaylar `onEvent`'e, `replace` / `patch` ile onu güncelleyen bir `PluginViewHandle` ile gelir. Kontrol kimlikleri bölümler ve satırlar dahil tüm görünümde tekil olmalıdır (`PluginViewSpec.duplicateControlIds()` çakışmaları listeler). |
| `pluginDir` | Eklentinin kurulu olduğu klasör (`.lmplugin` dosyasını tutan), hello yanıtından: birlikte gönderdiği dosyaları (çalıştırılabilirler, modeller) bulduğu yer. `Isolate.resolvePackageUri` release derlemesinde çalışmaz. Editör bilmiyorsa null. |
| `view(viewId)` | Kayıtlı bir görünümün `PluginViewHandle`'ı; onu kendi olayları dışında (bir MCP aracı çağrısından, biten bir işten sonra) güncellemek için; bilinmeyen kimlikte null. |
| `showPanel`, `hidePanel`, `openTab`, `callMcpTool` | Panel görünürlüğü, kabuğun sekmeleri ve herhangi bir editör MCP aracı. |

Katkılar bir kez gönderilir: `register` döndükten sonra bir menü öğesi, buton, araç, importer, konsol komutu ya da panel kaydetmek bir `StateError`'dır. `handle` her zaman çalışır. Gerçekleme `ConnectedPluginProcessContext`'tir (`lib/src/process/process_context.dart`); istek handler'larını `installPluginProcessHandlers` kurar (`lib/src/process/process_dispatch.dart`).

## Level proxy'si

`PluginLevelProxy` (`lib/src/process/level_proxy.dart`), `EditorLevelAccess`'i `host.level` istekleri üzerinden gerçekler; editör her düzenlemeyi, süreç içi bir eklentide olduğu gibi, kendi level'ının geri alınabilir bir transaction'ı olarak yapar.

- Senkron getter'lar (`actors`, `selectedActorIds`, `undoTopLabel`, `activeLevelPath`, `projectDirPath`) son `snapshot`'ı okur: el sıkışmadan sonra, proxy'nin kendi her düzenlemesinden sonra ve her `core.levelChanged`'de, `changes` tetiklenmeden önce alınır.
- `removeActors`, `setComponentProperty` ve `selectActors` API'de senkrondur: yerel kopyayı hemen günceller, isteği gönderir ve yanıtlanınca yeniler; bir hata editör loguna yazılır. Transaction dışında yapılan etiketli bir düzenleme hemen `undoTopLabel` olur ve `undoIfTop` bu etiketten yanıt verir (editör geri almadan önce yeniden denetler).
- `addActors`, `saveLevel` ve `openLevel` editörü bekler (dosya yükledikleri için 60 sn'ye kadar).
- `runTransaction(label, body)` `beginTransaction` gönderir, `body`'yi zone'unda transaction kimliğiyle çalıştırır ve `endTransaction` gönderir; içinde yapılan her düzenleme kimliği taşır, böylece editör onları tek bir geri alma adımı olarak kaydeder. Bir başkasının içindeki çağrı ona katılır.

`EditorLevelJson` (`lib/src/process/level_json.dart`) iki tarafın kullandığı aktör anlık görüntüsü ve aktör tanımı JSON'unu kodlar ve çözer.

## Mevcut bir eklentiyi süreçte çalıştırmak: PluginProcessAdapter

`PluginProcessAdapter(plugin)` (`lib/src/process/plugin_process_adapter.dart`), katkıları veri olan değiştirilmemiş bir `LuminaEditorPlugin`'i çalıştıran bir `LuminaPluginProcess`'tir. `register`'ı şunları eşleyen bir `LuminaEditorHostContext` (`PluginAdapterContext`) alır:

| Süreç içi API | Eklenti sürecinde |
|---|---|
| `registerMenu`, `registerMenuItem` (order, section, `checked`) | menü katkıları; komutlar null bir `BuildContext` ile çalışır, `canExecute`'u editör sorar |
| `registerSlotButton`, `registerToolbarButton` | slot butonları; `EditorButtonState` değişiklikleri oldukları anda gönderilir; bir toolbar butonu `group`'unun adlandırdığı slota (yoksa `levelToolbarEnd`) gider |
| `registerConsoleCommand`, `registerImporter`, `mcp.registerTool` | konsol komutları, importer'lar (bir `ImportResult.failure` editörün hatası olur) ve MCP araçları |
| `mcp.callTool`, `storage`, `pluginSettings`, `saveAsset`, `openTab`, `panels.show` / `hide` | süreç context'i üzerinden editör; `panels.isVisible` / `visibility` eklentinin kendi çağrılarını izler |
| `level` (`context is LuminaEditorHostContext` ile) | level proxy'si |
| `reportCrash` | editör logunda bir hata satırı |
| `onProjectOpened`, `onProjectClosing` | iletilir |
| `onEditorShutdown`, ardından `unregister` | `core.shutdown`'da |

Widget kuran şey editörün sürecinden çıkamaz. `registerPanel`, `registerTab`, `registerAssetType`, `registerDetailsCustomization`, `registerProjectSettingsSection`, `build3DViewport` ve `buildAssetPicker` `UnsupportedError('<API> needs the editor process: …')` fırlatır; böylece kayıt editör logunda bu mesajla başarısız olur (çıkış kodu 4). Böyle bir eklenti bu parçaları, süreç parçasıyla `LuminaEditorContext.processChannel(pluginName)` üzerinden konuşan süreç içi UI kabuğunda tutar ya da panellerini `PluginProcessViewPanel` ile tarif eder.

```dart
// Yalnızca veriyle çalışan bir eklenti, değiştirilmeden, editör modülünün süreç sınıfı olarak.
class MyPluginProcess extends PluginProcessAdapter {
  MyPluginProcess() : super(MyPlugin());
}
```

## Veri olarak ikonlar

Komutlar, slot butonu durumları ve bildirimsel butonlar ikonları `PluginIconSpec` olarak taşır (kod noktası, font ailesi, font paketi, metin yönü). `pluginIconOf(IconData)` bir Flutter ikonundan bir tane kurar; `iconDataOf(PluginIconSpec)` onu editörün çizmesi için bir `IconData`'ya geri çevirir (`lib/src/process/plugin_icons.dart`). Glif editörün paketlenmiş ikon fontlarından gelir: süreç editörün çalıştırılabilir dosyasından çalışır, böylece bir eklentinin adlandırdığı const ikonlar, release build'ler fontları tree-shake ettiğinde gliflerini korur.

---

[Önceki: MCP araçları API'si](mcp.md) | [Üst: lumina_editor_api](index.md) | [Sonraki: Editör eklentileri](../plugins/index.md)
