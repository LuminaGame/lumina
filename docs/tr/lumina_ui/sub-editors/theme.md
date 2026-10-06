[English](../../../en/lumina_ui/sub-editors/theme.md)

# Tema Alt Editörü (Theme Sub-Editor)

Tema Alt Editörü, geliştiricilerin UI Temalarını (`AssetType.theme` türündeki `.lmas` varlıkları) oluşturmasını, özelleştirmesini ve canlı olarak önizlemesini sağlar.

Lumina, editörün masaüstü arayüz temasını oyun içi widget temalarından bağımsız tutar. Her projede editör açılışında `contents/themes/DefaultTheme.lmas` yolunda varsayılan bir tema otomatik olarak oluşturulur (shadcn dark paleti temel alınarak). İçerik Tarayıcısından (Content Browser) bir tema `.lmas` dosyasına tıklandığında Tema Alt Editörü açılır.

## Düzen ve Paneller

Editör çalışma alanı birbiriyle senkronize iki ana panelden oluşur:

1. **Sol Panel: Tema Nesneleri Ağacı ve Özellik Denetçisi**
   - **Ağaç Hiyerarşisi**:
     - *Global Belirteçler (Tokens)*: Renk Paleti (Color Palette), Geometri ve Köşe Yuvarlaklığı (Geometry & Radius), Tipografi (Typography).
     - *Bileşen Stilleri (Component Styles)*: Buton, Kart, Metin Girişi, Rozet, Switch, Slider, Onay Kutusu (Checkbox), Sekmeler (Tabs), İlerleme Çubuğu (Progress), İletişim Penceresi (Dialog).
     - *Özel Stiller (Custom Styles)*: Kullanıcı tarafından tanımlanmış adlandırılmış özel stil varyantları.
   - **Özellik Denetçisi (Inspector)**: Ağaçta o an seçili olan nesnenin tüm değiştirilebilir özelliklerini (HEX renkleri, sayısal kaydırıcılar, iç boşluklar, yazı boyutları vb.) listeler ve anlık düzenlemeye olanak tanır.

2. **Sağ Panel: Canlı Önizleme Vitrini (Showcase)**
   - Temadan stil alan tüm kullanıcı arayüzü bileşenlerinin canlı önizlemesini sunar.
   - **"Stil Oluştur" Butonu**: Eğer sağdaki vitrinde yer alan bir bileşenin sol ağaçta henüz özel bir stil tanımı yoksa, ilgili bileşenin önizleme kartının altında "Stil Oluştur" butonu görüntülenir. Bu butona tıklandığında o bileşene ait stil oluşturulup ağaca eklenir ve doğrudan denetçide açılır.
   - **Özel Stiller Bölümü**: Tanımlanan özel stilleri önizler ve "Düzenle" butonuyla hızlı erişim sağlar.

## UMG (Widget Tasarımcısı) ile Entegrasyon

Temalar, UMG Widget Tasarımcısında (`AssetType.widget` tipindeki `.lmas` dosyaları) oluşturulan oyun arayüzlerine doğrudan uygulanır:
- **Belge Düzeyinde Tema**: Tasarımcı üst araç çubuğu ve kök Canvas Panel'in Görünüm (Appearance) denetçisi üzerinden widget belgesinin temel `.lmas` tema asset'i seçilebilir (`themePath`). Kanvastaki bileşenler (örn. Butonlar) temanın renkleri ve geometrisiyle çizilir.
- **Bileşen Düzeyinde Tema Ezmesi**: Tek tek bileşenler (örn. Butonlar), belge temasını herhangi bir proje tema asset'i ile ezebilir veya widget temasından devralacak şekilde ayarlanabilir.
- **Stil Varyantları ve Özel Stiller**: Butonlar stillendirilirken, tasarımcılar standart varyantlardan (`primary`, `secondary`, `outline`, `ghost`, `destructive`) veya aktif temada tanımlanmış herhangi bir adlandırılmış özel stilden (`LuminaCustomStyle`) seçim yapabilir.

## Mimari

- **Görünüm (View)**: `ThemeSubEditor` (`lib/ui/features/sub_editors/views/theme/theme_sub_editor.dart`), modüler olarak `theme_tree_panel.dart`, `theme_property_inspector.dart`, `theme_preview_showcase.dart`, `theme_preview_components.dart` ve `theme_custom_style_dialog.dart` dosyalarına ayrılmıştır.
- **Görünüm Modeli (ViewModel)**: `ThemeEditorViewModel` (`lib/ui/features/sub_editors/view_models/theme_editor_view_model.dart`).
- **Veri Katmanı**: `package:lumina` içinde `LuminaThemeDocument` ve `LuminaThemeService`.

---

[Önceki: Widget (UMG) tasarımcısı](umg.md) | [Üst: Alt editörler](index.md)

