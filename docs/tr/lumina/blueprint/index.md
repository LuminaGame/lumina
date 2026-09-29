[English](../../../en/lumina/blueprint/index.md)

# Blueprint'ler

Blueprint'ler Lumina'nın görsel programlama sistemidir. Bir Blueprint, bir `.lmas` asset'inde saklanan bir node graph'ıdır; aynı graph editörde bir sanal makine (VM) üzerinden çalışır ve oyunlarda üretilen Dart kodu olarak yayınlanır. İki yol da tek bir node kütüphanesini ve tek bir fonksiyon kütüphanesini paylaştığı için aynı şekilde davranır.

## Blueprint'ler nasıl çalışır

Tüm Blueprint kodu `lib/src/blueprint/` altındadır ve `blueprint.dart` tarafından birlikte export edilir.

- **Belgeler**: bir Blueprint sınıfı, payload'ı bir `LuminaBlueprintDocument` olan bir `.lmas` asset'idir: component ağacı, değişkenler, event graph, fonksiyonlar, macro'lar, event dispatcher'lar ve timeline'lar. Interface'ler, enum'lar, save-game sınıfları, montage'lar, Level Blueprint'ler, Widget Blueprint'ler ve Animation Blueprint'lerin kendi belge tipleri vardır.
- **Node kütüphanesi**: `LuminaBlueprintNodeLibrary`, editör paletinin, VM'in ve kod üretecinin okuduğu tek node kataloğudur. Her node tanımı pin'lerini ve çalışmaya nasıl katıldığını bildirir.
- **Fonksiyon kütüphanesi**: her pure ve impure node'un davranışı `LuminaBlueprintFunctionLibrary` içinde bir kez yazılır.
- **İki çalışma yolu**:
  - Editörde (Play-In-Editor) VM (`LuminaBlueprintClass`, `LuminaBlueprintInterpreter`) graph'ları node node çalıştırır.
  - Yayınlanan bir oyunda kod üreteci her Blueprint'i, fonksiyon kütüphanesinin static metotlarını doğrudan çağıran bir Dart sınıfına dönüştürür.
  - İkisi de `LuminaBlueprintRuntime` mixin'ini, component eşlemesini ve fonksiyon kütüphanesini paylaşır; böylece bir Blueprint her iki yolda da aynı davranır.
- **Node olarak Dart fonksiyonları**: `@BlueprintCallable` (exec pin'li impure node) ve `@BlueprintPure` (bir çıkışı çekildiğinde hesaplanan pure node), public top-level ya da static fonksiyonları işaretler. Editörün tarayıcısı bunları kaynaktan okur, pin'leri parametrelerden ve dönüş tipinden türetir ve Flutter'da runtime reflection olmadığı için VM'in kullandığı kaydı üretir. `LuminaBlueprintFunctionRegistry` bu proje node'larını tutar.
- **Doğrulama**: validator, Blueprint editörünün gösterdiği derleyici sonuç satırlarını (`LuminaBlueprintDiagnostic`) üretir.

Editör tarafı `lumina_ui` içindedir: bkz. [Blueprint editörü](../../lumina_ui/sub-editors/blueprint.md).

## Referans sayfaları

| Sayfa | Kapsam |
|---|---|
| [Blueprint belgeleri ve asset'leri](model.md) | Pin'ler, node'lar, wire'lar, graph'lar, fonksiyonlar, macro'lar, interface'ler, enum'lar, save-game ve montage asset'leri, doğrulama. |
| [Blueprint runtime'ı, VM ve node kütüphanesi](runtime.md) | Node kataloğu, yorumlayıcı, Blueprint actor'leri, level ve widget Blueprint'leri, delegate'ler. |
| [Blueprint fonksiyon kütüphanesi](function-library.md) | VM ve üretilen kodun paylaştığı, her pure ve impure node'un davranışı. |
| [Animation Blueprint'ler](animation.md) | Animation Blueprint belgeleri, state machine'ler, blend space'ler, aim offset'ler ve instance'ları. |

---

[Önceki: Kayıt (save game)](../save.md) | [Üst: lumina (engine çekirdeği)](../index.md) | [Sonraki: Blueprint belgeleri ve asset'leri](model.md)
