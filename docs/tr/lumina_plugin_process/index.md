[English](../../en/lumina_plugin_process/index.md)

# lumina_plugin_process (bir eklentinin saf Dart süreç tarafı)

`lumina_plugin_process`, bir Lumina Studio eklentisinin kendi sürecinde çalışan kısmını saf Dart olarak tutar: import grafiğinin hiçbir yerinde Flutter, `dart:ui` ya da FFI yoktur. Ona karşı yazılmış bir eklenti süreci `dart run` ile, testleri `dart test` ile çalışabilir. İçerdikleri:

- süreç tarafı API'si: `LuminaPluginProcess`, `PluginProcessContext` ve bir sürecin kaydettikleri (`PluginProcessCommand`, `PluginProcessSlotButton`, `PluginProcessViewPanel`, `PluginProcessImporter`, MCP araçları, konsol komutları);
- çalışma zamanı: `runPluginProcessMain`, `servePluginProcess`, istek dağıtımı (`installPluginProcessHandlers`), level proxy'si (`PluginLevelProxy`) ve level JSON kodlayıcıları (`EditorLevelJson`);
- okuyup yazdığı editör verisi: açık level (`PluginLevelAccess`, `EditorLevelOperations`, `EditorActorSnapshot`, `EditorComponentSnapshot`, `EditorActorSpec`, `EditorComponentSpec`), `PluginStorage`, `EditorProjectInfo`, `LuminaPluginCrashReporter` ve MCP tipleri (`McpTool`, `McpArgs`, `McpToolResult`, `EditorMcp`, …);
- editör tarafının bir sürece hattı `PluginProcessLink` ve durum tipleri (`PluginProcessState`, `PluginProcessStatus`, `PluginProcessEvent`, `PluginProgress`);
- bir loopback test host'u, `LoopbackHost` (`package:lumina_plugin_process/testing.dart`).

Süreç API'si, yaşam döngüsü, çıkış kodları ve proxy'ler [Eklenti süreçleri](plugin-processes.md) sayfasında anlatılır.

## Mimarideki yeri

Paket lumina repository'sinde (`lumina_plugin_process/`) durur ve onun pub workspace'inin bir üyesidir. Yalnızca `lumina_plugin_protocol`'e (tel protokolü), `lumina_core`'a (saf temel), `path`'e ve `meta`'ya bağımlıdır. `lumina_editor_api` ona bağımlıdır ve tüm genel API'sini Flutter adaptörleriyle birlikte yeniden dışa aktarır; böylece eklentiler ve editör `package:lumina_editor_api/lumina_editor_api.dart`'ı import etmeyi sürdürür ve değişmeden derlenir:

| `lumina_editor_api`'de kalan (Flutter) | Neden |
| :--- | :--- |
| `PluginProcessAdapter` | Bir Flutter `LuminaEditorPlugin`'ini sarar. |
| `pluginIconOf(IconData)`, `iconDataOf(PluginIconSpec)` | `IconData` bir Flutter tipidir; saf bir süreç `PluginIconSpec(codePoint, fontFamily: ...)`'i kendisi yazar. |
| `PluginProcessChannel` | Widget'lar için `ValueListenable` durumlu kabuk hattı; `PluginProcessChannel.ofLink(link)` bir `PluginProcessLink`'i sarar. |
| `EditorLevelAccess` | Flutter `Listenable changes`'li editör level'ı; her işlemi `EditorLevelOperations` üzerinden `PluginLevelAccess` ile paylaşır. |
| `asValueListenable()`, `asListenable()`, `asObservable()`, `asChangeSignal()`, `asEditorLevelAccess()`, `asPluginLevelAccess()` | Saf tipler ile Flutter'ınkiler arasındaki görünümler; her biri aynı kaynak için aynı görünümü döner. |
| `package:lumina_editor_api/testing.dart`'ın `LoopbackHost`'u | Saf host artı bir `PluginProcessChannel` olan `channel`. |

Bkz. [Katmanlı mimari](../overview/layers.md).

## Flutter'sız canlı değerler

Bir eklenti sürecinin canlı değerleri, bu paketin yeniden dışa aktardığı `lumina_core` değişim tipleridir (bkz. [lumina_core](../lumina_core/index.md)):

| Değer | Tip |
| :--- | :--- |
| `PluginProcessContext.pluginSettings` | `Observable<Map<String, Object?>>` |
| `PluginProcessSlotButton.state` | `Observable<PluginButtonStateSpec>` (genellikle sürecin atadığı bir `ObservableValue`) |
| `registerMenuItem(..., checked:)` | `Observable<bool>?` |
| `PluginLevelAccess.changes` | `ChangeSignal` |
| `PluginProcessLink.state` | `Observable<PluginProcessState>` |

Flutter'ın `ValueListenable`'ındaki üyelere (`value`, `addListener`, `removeListener`) sahiptirler; yalnızca bunları çağıran süreç kodu her iki durumda da aynıdır.

## Saf Dart bir eklenti süreci

`example/pure_process.dart` eksiksiz bir örnektir: bir menü komutu, `ObservableValue` durumu değişen bir slot butonu, bir MCP aracı ve level'ı editör üzerinden düzenleyen handler'lar.

```dart
import 'dart:io';

import 'package:lumina_plugin_process/lumina_plugin_process.dart';

class PureSampleProcess extends LuminaPluginProcess {
  final status = ObservableValue(const PluginButtonStateSpec(icon: PluginIconSpec(0xe88e), tooltip: 'Idle'));

  @override
  String get pluginName => 'pure_sample';

  @override
  void register(PluginProcessContext context) {
    context.handle('placeCrates', (args) => context.level.runTransaction('Place crates', () {
          return context.level.addActors([
            for (var i = 0; i < (args['count'] as int); i++)
              EditorActorSpec(name: 'Crate$i', type: 'StaticMesh', location: [i * 100.0, 0, 0]),
          ]);
        }));
    context.registerSlotButton(PluginProcessSlotButton(
      id: 'pure_sample.status',
      slot: 'statusBarRight',
      state: status,
      command: PluginProcessCommand(id: 'pure_sample.status', label: 'Status', run: () {}),
    ));
  }
}

Future<void> main(List<String> args) async {
  final launch = PluginProcessLaunch.parse(args);
  if (launch == null) exit(64);
  exit(await runPluginProcessMain(launch, PureSampleProcess()));
}
```

Editör bugün eklenti süreci olarak hâlâ kendi çalıştırılabilir dosyasını başlatır. Bunun yerine bunun gibi saf Dart bir çalıştırılabilir dosyayı başlatmak (eklenti başına bir `dart build cli` ikilisi) sonraki bir adımdır; API ve protokol bunun için değişmez.

## LoopbackHost ile test

`LoopbackHost.start()` bir loopback portu bağlar ve gerçek bir soket üzerinden editörün tarafını oynar: el sıkışmayı yanıtlar, katkıları alır (`host.contributions`), `host.*` isteklerine kendi küçük level'ına (`host.level`, etiketli adımlardan oluşan bir geri alma yığınıyla) ve gerçek dizinlere (`host.root`) karşı hizmet eder ve her bildirimi kaydeder (`host.notifications`, `host.next(method)`). `host.call(method, args)` bir `core.*` isteği gönderir; `host.link` bir UI kabuğunun aldığı hattır.

Test edilen süreç testin kendi isolate'inde çalışabilir:

```dart
final host = await LoopbackHost.start();
final exit = runPluginProcessMain(host.launch('pure_sample'), PureSampleProcess());
await host.contributions;
expect(await host.link.call('placeCrates', {'count': 2}), hasLength(2));
await host.call(PluginMethods.shutdown);
expect(await exit, PluginProcessExitCodes.ok);
```

ya da `host.launch(name).toArgs()` ile başlatılan ayrı bir program olarak. `test/two_process_test.dart`, `dart run example/pure_process.dart`'ı gerçek bir alt süreç olarak başlatır ve el sıkışmayı, katkıları, `core.ping`'i, `core.call`'u, ayar güncellemelerini, bir level transaction'ını, bir MCP aracını, bir menü komutunu ve 0 çıkış koduyla temiz bir kapanışı denetler.

Flutter testleri bunun yerine `package:lumina_editor_api/testing.dart`'ı import eder: onun `LoopbackHost`'u, bir kabuk widget'ının aldığı `PluginProcessChannel` olan `channel` eklenmiş aynı host'tur.

## Paketin testleri

`lumina_plugin_process/` içinden `dart test` ile çalışır (Flutter devrede değildir):

| Dosya | Kapsadığı |
| :--- | :--- |
| `test/architecture/pure_dart_test.dart` | Paketin her kütüphanesini ve import ettiği her paketi gezer; Flutter, `dart:ui`, FFI, engine ya da editörde başarısız olur. |
| `test/run_plugin_process_handshake_test.dart` | Hello, token ve sürüm denetimleri, çıkış kodları, eklenti klasörü, çökme raporları, başarısız kayıt. |
| `test/run_plugin_process_requests_test.dart` | `core.call`, komutlar, MCP araçları, importer'lar, konsol komutları, bildirimsel görünümler, canlı slot ve menü durumu, ayarlar, olaylar, ilerleme, editör çağrıları, proje kancaları. |
| `test/level_proxy_test.dart` | Level proxy'si: anlık görüntüler, transaction'lar, senkron düzenlemeler, `core.levelChanged`, JSON kodlayıcıları. |
| `test/two_process_test.dart` | Gerçek bir `dart run` alt süreci olarak saf Dart bir eklenti süreci. |

---

[Önceki: MCP araçları API'si](../lumina_editor_api/mcp.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: Eklenti süreçleri](plugin-processes.md)
