[English](../../../en/lumina_ui/sub-editors/cloth-settings.md)

# Kumaş ayarları editörü

Bir kumaş ayarları asset'i (`.lmas`, `AssetType.clothSettings`) birden çok kumaşın paylaştığı ayarları tutar: kütle, sertlik, bükülme, sönümleme, sürtünme, kalınlık, iterasyonlar, yerçekimi, rüzgâr sürüklemesi ve türbülansı, atalet ölçeği ve ışınlanma eşikleri ve kendisiyle çarpışma. Yükü JSON olarak bir `LuminaClothSettingsDocument`'tır (lumina_core); anahtarlar kumaş bileşeninin özellik anahtarlarıdır. Asset'i **Cloth Settings** alanında (`clothSettingsAsset`) adlandıran bir Cloth ya da Skinned Cloth bileşeni kurulurken kendi değerleri yerine bunları alır (bkz. [Kumaş](../../lumina/cloth.md)).

| Konu | Dosyalar |
| :--- | :--- |
| Belge | `lumina_core/lib/src/formats/lumina_cloth_settings_document.dart` |
| View model | `lib/ui/features/sub_editors/view_models/cloth_settings_editor_view_model.dart` |
| Görünüm | `lib/ui/features/sub_editors/views/cloth_settings/cloth_settings_sub_editor.dart` |

## Oluşturma

Content Browser → New Asset → **Physics → Cloth Settings (.lmas)**, kumaş bileşeninin varsayılanlarıyla `contents/physics/NewAsset_N.lmas` dosyasını yazar ve onu gömlek simgesiyle listeler. Çift tıklamak editörü açar (alt editör kategorisi `ClothSettings`).

## Editör

- **Araç çubuğu**: asset'in adı (kaydedilmemiş değişiklik varken `*`), **Revert** (kaydedilmiş değerlere dön) ve **Save** (`.lmas`'ı yazar; kimliğini, küçük resmini ve referanslarını korur). Bir okuma ya da yazma hatası araç çubuğunda gösterilir.
- **Sol panel** (yeniden boyutlandırılabilir, 160–360 px): ayar grupları: Material, Simulation, Wind, Motion ve Self Collision; her birinin kaç ayar tuttuğuyla.
- **Sağ panel**: seçili grubun ayarları. Sayılar bir kaydırıcı ve yazılabilen bir alandır (birimleriyle), `LuminaClothSettingsDocument.ranges` aralıklarına kırpılır; iterasyonlar tam sayıdır; kendisiyle çarpışma bir anahtardır. Her alan varsayılanına sıfırlanabilir.

Dosya asenkron okunur ve yazılır; sekme diğer asset editörleri gibi editörün kaydetme sorusuna bağlanır.

## Kullanma

Blueprint editörünün Details panelinde bir Cloth ya da Skinned Cloth bileşeninin **Cloth Settings** alanı asset'i seçer (yalnızca kumaş ayarları asset'leri sunulur). Bileşen eşlemesi referansı Play-In-Editor'da ve üretilen oyunlarda aynı şekilde aktarır. Asset'i okuyamayan bir kumaş kendi ayarlarını korur ve nedenini günlüğe yazar.

---

[Üst: Alt editörler](index.md)
