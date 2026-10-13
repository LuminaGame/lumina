[English](../../../en/lumina_ui/sub-editors/garment.md)

# Giysi editörü

Bir giysi asset'i (`.lmas`, `AssetType.garment`) herhangi bir mesh'i giyilebilir yapar: giysinin yapıldığı **kaynak mesh**'i (statik ya da skeletal mesh), üzerinde hazırlandığı **referans gövde**'yi (skeletal mesh), kaynak mesh'in o gövdede nerede durduğunu (cm cinsinden konum, X sonra Y sonra Z uygulanan derece cinsinden dönüş, ölçek; gövde mesh'inin kendi uzayında: Y yukarı, cm), adlı **landmark**'ları (giysi üzerinde bir nokta ve gövdedeki karşılığı), uydurulan giysinin tenden koruduğu **kalınlığı**, doldurduğu **slot**'u (`Torso`, `Legs`, `Feet`, …) ve bir Cloth Settings asset'iyle **skinned cloth** olarak giyilip giyilmeyeceğini adlandırır. Payload'ı JSON olarak bir `LuminaGarmentDocument`'tır (lumina_core). Başka gövdelere uydurmayı motor yapar (bkz. [Karakter slotları](../../lumina/character-slots.md)).

| Konu | Dosyalar |
| :--- | :--- |
| Doküman | `lumina_core/lib/src/formats/lumina_garment_document.dart` |
| Seçme ve hizalama matematiği | `lumina_core/lib/src/garment/garment_math.dart` (`LuminaGarmentMath.raycast`, `fitSimilarity`, Euler ↔ kuaterniyon) |
| View model | `lib/ui/features/sub_editors/view_models/garment_editor_view_model.dart` |
| View | `lib/ui/features/sub_editors/views/garment/` (`garment_sub_editor.dart`, ayrıntı, landmark ve viewport parçaları; barrel `garment.dart`) |
| 3B sahne | `lib/ui/features/sub_editors/services/garment_preview_scene.dart` |

## Oluşturma

Content Browser → New Asset → **Character → Garment (.lmas)**, `contents/characters/NewAsset_N.lmas` dosyasını yazar (Torso, 0.5 cm, henüz mesh yok) ve gömlek simgesiyle listeler. Çift tıklamak editörü açar (alt editör kategorisi `Garment`).

## Editör

- **Araç çubuğu**: asset'in adı (kaydedilmemiş değişiklik varken `*`), **Move / Rotate / Resize** (gizmo'nun modları), **Pick on garment / Pick on body** (viewport'taki bir tıklamanın seçili landmark'ı nereye koyacağı), **Align**, **Revert**, **Save**. Hatalar (okunamayan bir mesh) araç çubuğunda görünür.
- **Sol panel** (yeniden boyutlanır, 200–460 px): küçük resimli Source Mesh, Reference Body ve Preview On (giysiye başka bir gövdede bakmak için; kaydedilmez) seçicileri; Slot; Thickness; Simulate as cloth ve onun Cloth Settings'i; Location / Rotation / Scale satırları olarak yerleşim.
- **Viewport**: başlangıç noktasında gövde ve yerleşimindeki giysi bir editör dünyasında; gizmo giysiyi taşır, döndürür ve boyutlandırır (sürüklemesi yerleşimi yazar); landmark çarpıları sahnenin üzerine çizilir (giysi noktaları kehribar, gövde noktaları camgöbeği, her çiftin arasında bir çizgi, seçili olan daha büyük). Bir seçme modunda gizmo gizlenir ve bir tıklama kameranın ışınını atar (`SubEditor3DViewport.onRayTap`): yerleştirilmiş giysi üzerinde seçili landmark'ın giysi noktasını (kaynak mesh'in uzayına geri dönüştürülerek saklanır, böylece giysi taşınınca yerinde kalır), gövde üzerinde gövde noktasını belirler.
- **Sağ panel** (yeniden boyutlanır, 180–420 px): **Add a landmark…** henüz yerleştirilmemiş hazır noktaları listeler (Neck, Shoulder L/R, Elbow L/R, Wrist L/R, Chest, Waist, Hip L/R, Knee L/R, Ankle L/R, Foot L/R); özel bir ad da eklenebilir. Her landmark 24 px'lik bir ağaç satırıdır (ok, iki nokta da yerleşince camgöbeğine dönen bir iğne, yerleşince aralarındaki mesafe, silme) ve altında Garment ve Body noktaları vardır; bir nokta satırına tıklamak landmark'ı seçer ve o seçme moduna geçer.
- **Align** giysiyi landmark'ları gövdedekilerin üzerine gelecek şekilde yerleştirir: tam çiftler üzerinden en iyi benzerlik dönüşümü (tek düze ölçek, dönüş, öteleme); üçten az çiftle dönüş korunur, yalnızca ölçek ve öteleme uydurulur.

Mesh'ler worker isolate'larda okunur ve ayrıştırılır (Draco ile sıkıştırılmış kaynaklar da orada çözülür) ve önbelleğe alınır; bir seçme önbellekteki üçgenler üzerinde çalışır. Projenin mesh ve kumaş ayarları listeleri de bir worker isolate'ta taranır. Sekme, diğer asset editörleri gibi editörün kaydetme sorusuna bağlanır.
