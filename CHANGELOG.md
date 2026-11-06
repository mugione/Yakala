# Değişiklik Günlüğü (Windows)

Yakala'nın Windows sürümündeki tüm önemli değişiklikler bu dosyada, en yeni sürüm en üstte olacak şekilde listelenir.
Biçim [Keep a Changelog](https://keepachangelog.com/tr-TR/1.1.0/) düzenine, sürüm numaraları
[Anlamsal Sürümleme](https://semver.org/lang/tr/) kurallarına dayanır. Windows sürümleri `windows-v` önekli
etiketlerle yayımlanır. macOS sürümünün değişiklikleri: [CHANGELOG.md](https://github.com/mugione/Yakala/blob/main/CHANGELOG.md).

## [1.6.0] - 2026-11-06

### Eklenenler
- **PrtScn** tuşu tek başına alan seçimini başlatır (Ayarlar › Kısayollar'dan kapatılabilir). Windows bu tuşu Ekran
  Alıntısı Aracı'na veriyorsa ayarlarda nasıl değiştirileceği gösterilir.
- **Zamanlayıcı:** bildirim alanı menüsünden 3, 5 ya da 10 saniye sonra alan seçimi; ekranın altında geri sayım.
- **Kırp** aracı (C): sürükle ve bırak; şekiller görüntüyle birlikte kayar, Ctrl+Z geri alır.
- **JPG** kaydetme ve kalite ayarı; **dosya adı şablonu** ({tarih}, {saat}, {yıl}, {ay}, {gün}).
- **Yakınlaştırma:** Ctrl+tekerlek, Ctrl+0 (sığdır), Ctrl+1 (gerçek boyut), Ctrl+/Ctrl−; alt çubukta yakınlık
  düğmesi; büyütülmüşken tekerlek ya da orta tuşla kaydırma.
- **İngilizce arayüz:** Ayarlar › Genel › Arayüz dili (Sistem / Türkçe / English).

### Düzeltilenler
- %125, %150 ve %175 ölçekli ekranlarda Güzelleştir açıkken kaydedilen ve kopyalanan görüntü yarım piksel kayıp
  bulanıklaşıyordu; yerleşim artık fiziksel piksellerde hesaplanıyor.
- Düzenleyicideki önizleme ekran pikseline oturtuluyor; pencere ekranın %85'ine kadar büyüyor.
- Güzelleştir paneli açılınca pencere ekranda yer varsa panel kadar genişliyor; görüntü panel yüzünden küçülmüyor.
  Boşluk artık 0'a kadar indirilebiliyor.
- Yakalama ve düzenleyici kapandıktan sonra bellek toplanıp Windows'a geri veriliyor.

## [1.5.0]

İlk Windows sürümü: macOS 1.5'in tüm özellikleri, aynı Türkçe arayüzle.

### Eklenenler
- Bildirim alanında çalışan, görev çubuğunda yer kaplamayan ekran görüntüsü aracı; sol tık alan seçimi, sağ tık menü.
- **Ctrl+Shift+2** ile dondurulmuş ekran üzerinde alan seçimi; tek tıkla tüm ekran; **Ctrl+Shift+1** ya da
  **Boşluk** ile pencere seçimi. Windows 11'de pencere köşeleri saydam alınır.
- Birden fazla ve farklı ölçekli ekran desteği (ör. %100 ve %300 yan yana).
- Düzenleyici: ok, dikdörtgen, yuvarlak, kalem, vurgulayıcı, metin, etiket, numara, damga, büyüteç, bulanıklaştırma ve
  pikselleştirme; 7 renk, 3 kalınlık; seçme, taşıma, silme; geri al / yinele.
- **Güzelleştir:** 8 arka plan, boşluk, köşe, gölge, oranlar ve Windows 11 tarzı pencere çerçevesi (— □ ✕).
- **Kopyala (Ctrl+C)**, **Kaydet (Ctrl+S)** ve **Farklı Kaydet (Ctrl+Shift+S)**; işlemden sonra önceki pencereye dönülür.
- Hızlı mod, otomatik kayıt, kısayolları değiştirme, Windows açılışında başlatma.
- Açık / koyu tema, sekmeli ayarlar, ilk açılışta karşılama penceresi.
- Aynı anda yalnızca bir Yakala çalışır; yeniden açılınca ayarlar penceresi gelir.
