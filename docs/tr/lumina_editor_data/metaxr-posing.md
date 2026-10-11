[English](../../en/lumina_editor_data/metaxr-posing.md)

# MetaXR poz verme örnek projesi

`lib/src/samples/metaxr_posing/`, Meta Quest için bir örnek proje kurar. Gözlük kullanıcının odasını passthrough ile gösterir; odada bir MetaHuman durur. Kullanıcı karakterin ellerini, dirseklerini, ayaklarını, dizlerini, başını, göğsünü ya da leğenini kumandalarla tutup poz verir: uzuvlar IK ile takip eder, bırakınca poz kalır.

MetaHuman karakteri Epic'e aittir; bu yüzden proje, Game Animation Sample gibi, onu kuran makinede kalır. Kurucu, çalıştırıcı ve testler Lumina'nın parçasıdır; testler test-assets mankenini kullanır.

`package:lumina_editor_data/lumina_editor_data.dart` tarafından dışa aktarılır.

## Ne kurar

| Adım | Sınıf | Sonuç |
| :--- | :--- | :--- |
| Proje | `MetaXrPosingBuilder.createProject` | Yoksa `ProjectRepository.createProject` (boş şablon) ile `<projeler>/<ad>`. |
| Eklentiler ve hedef | `MetaXrPosingBuilder` | `lumina_plugin_openxr` ve `lumina_plugin_metaxr` etkin. Hedef yalnızca Android, Meta Quest profiliyle (`ProjectAndroidSettings.quest`): `com.lumina.metaxr_posing`, 72 Hz, multiview, minSdk 32 / targetSdk 34. |
| Karakter | | Verilen GLB skeletal mesh olarak içe aktarılır (yeniden kurulumda korunur). |
| Blueprint'ler | `MetaXrPosingContent` | Aşağıda. |
| HUD | `MetaXrPosingWidgets` | `W_WristHud`: üç metin (slot, tutulan tutamaç, kare hızı); grafiği kare hızını günceller. Lumina'da henüz dünya uzayında widget olmadığı için gözlükte çizilmez. |
| Level | `MetaXrPosingLevel` | `L_Room`, aşağıda anlatılır. |
| Proje | | Input, Maps & Modes (`L_Room`, `BP_PosingGameMode`, varsayılan pawn `BP_XRPlayer`), derlenmiş Blueprint'ler, level kodu, Blueprint kaydı ve `lib/main.dart`. Eklenti tanımlayıcıları verilirse Android uygulamasını ve eklentilerin runtime modüllerini de oluşturur ([Paketleme (Android)](packaging.md)). |

Blueprint'ler:

- `BP_PosedCharacter`: mesh ve `LuminaPoseAuthoringComponent` (ağırlık 1, hedefleri tutar). BeginPlay'de Enable Input çalıştırır, sonra şunları işler:
  - sıfırlama: Menu 1 sn basılı;
  - dört poz slotu: A sonraki slota geçip onu yükler, A 0,8 sn basılı tutulursa geçerli slota kaydeder, X geri gider;
  - döndürme (sağ çubuk X, 90°/sn) ve kaydırma (sol çubuk, 80 cm/sn).
- `BP_XRPlayer`: XR orijinindeki pawn. İçinde şunlar vardır:
  - bir `LuminaPoseGrabInteractor` (10 cm tutma yarıçapı, masaüstünde fare);
  - geri alma (B / Y) ve passthrough aç/kapa (sol çubuk tıklaması, MetaXR'ın *Set Passthrough Enabled* düğümüyle);
  - masaüstünde oynamak için 160 cm'de bir kamera;
  - iki `LuminaMetaHandTrackingComponent` eli (manifestte el takibini bildirir; böylece Horizon OS uygulamayı kumanda elde olmadan da açar).
- `BP_RoomPassthrough`: bir `LuminaMetaPassthroughComponent` alt katmanı.
- `BP_PosingGameMode`.

`L_Room`'da zemin ya da gökyüzü yoktur. İçinde şunlar vardır:

- orijinde (LOCAL_FLOOR) oyun moduna bağlı oyuncu başlangıcı;
- bir ana ışık ve bir dolgu ışığı;
- passthrough aktörü;
- oyuncunun 120 cm önünde (+Y), kullanıcıya dönük karakter.

Her düğmenin bir masaüstü tuşu da vardır: Z geri al, R sıfırla, E/Q slotlar, P passthrough.

## Gözlükte

Quest derlemesinde openxr eklentisinin runtime modülü, `OpenXrGamePresenter`'ı oyun host'unun immersive sunucusu olarak kurar (`LuminaGameHost.immersivePresenter`). Sunucu:

- OpenXR oturumunu başlatır ve projenin yenileme hızını ister;
- dünyayı runtime'ın Vulkan cihazında çalışan Filament'e bağlar (multiview, iki göz compositor'ün swapchain'inde);
- dünyayı XR kare döngüsüyle tick'ler;
- oyuncunun pawn'ında bir XR orijini oluşturur;
- iki kumandayı dünyadaki tutma etkileşimlerine kaydeder.

MetaXR runtime modülü dünyanın passthrough bileşenlerini `XR_FB_passthrough` katmanına bağlar. Kare sayıları her 5 sn'de logcat'e `[lumina_xr] frames … late … missed` satırları olarak yazılır.

## Çalıştırma

```bash
LUMINA_METAXR_MESH=<mobil MetaHuman .glb> [LUMINA_METAXR_COOK=release] \
  flutter test tool/metaxr_posing/build_metaxr_posing_test.dart
```

Çalıştırıcı OpenXR ve MetaXR checkout'larını projenin `plugins/` klasörüne bağlar, projeyi motora bağlar, kurar ve `LUMINA_METAXR_COOK` verilmişse APK'yı derler. `Saved/MetaXrPosing/report.json` dosyasını yazar. Karakter mobil MetaHuman dışa aktarımıdır (MetaHuman eklentisinin Export penceresinde *Mobile (Quest)*).

Masaüstü smoke testi (`test/smoke/metaxr_posing_smoke_test.dart`, proje kurulu değilse atlanır) `L_Room`'u GPU'da çizer. Betikli bir kumanda sağ eli, sol dirseği, başı, sağ ayağı ve leğeni tutar. Ardından slot 1'e kaydeder, sıfırlar ve slot 1'i yeniden yükler; çözüm ve kare sürelerini kaydeder.

---

[Yukarı: lumina_editor_data](index.md)
