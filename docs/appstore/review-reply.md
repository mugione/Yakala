# App Review'a yanıt (Guideline 2.1 - Information Needed)

App Store Connect › Yakala › **Uygulama İncelemesi** (App Review) › mesajın altındaki **Yanıtla** kutusuna
aşağıdaki İngilizce metni yapıştır ve ekran kaydını ekle. Aynı metni sürüm sayfasındaki
**Uygulama İnceleme Bilgileri › Notlar** alanına da yapıştır (Apple ikisini de istiyor).

## Yanıt metni

```
Hello App Review team,

Thank you for reviewing Yakala. Please find the requested information below. The screen recording is attached.

1. SCREEN RECORDING
Attached: recorded on a MacBook Pro running the latest macOS. It starts by launching Yakala from the Applications folder and shows the typical flow: the welcome window, granting Screen Recording permission, capturing an area with Shift-Command-2, annotating (arrow, text label, numbered steps, pixelate), Beautify, copying with Command-C and pasting into another app, capturing a single window with Shift-Command-1, and the Settings window.
Yakala has no account registration or login, no user-generated content shared with others, and no paid content or in-app purchases.

2. PURPOSE AND TARGET AUDIENCE
Yakala is a screenshot and annotation tool for the Mac menu bar. It helps people who explain things with screenshots (support staff, developers, designers, teachers, students and everyday Mac users) to capture part of the screen, mark it up with arrows, text and numbered steps, hide private information (blur/pixelate), optionally place it on a clean background, and paste it into an email, chat or document in a few seconds. It replaces a slow multi-app workflow with a single shortcut, and it works fully offline, so screenshots never leave the user's Mac.

3. HOW TO USE THE MAIN FEATURES
No login, credentials or sample files are needed.
- Yakala is a menu bar app (LSUIElement), so it has no Dock icon. On first launch a welcome window explains the shortcuts.
- Grant Screen Recording permission when macOS asks (System Settings > Privacy & Security > Screen & System Audio Recording), then relaunch Yakala.
- Click the Yakala icon in the menu bar or press Shift-Command-2, then drag to select an area (a single click captures the whole screen). Press Shift-Command-1 and click a window to capture one window.
- The editor opens: choose tools from the toolbar (arrow, rectangle, ellipse, pen, highlighter, text, label, numbers, stamps, magnifier, blur, pixelate). Click "Güzelleştir" (Beautify) to add a background. Press Command-C to copy or Command-S to save.
- Right-click the menu bar icon for the menu: Settings, About, Quit.
- The user interface is in Turkish.

4. EXTERNAL SERVICES
None. Yakala does not use any external services, SDKs, analytics, AI services, authentication or payment providers. It has no network entitlement and does not connect to the internet. It uses only Apple system frameworks (ScreenCaptureKit, AppKit, SwiftUI).

5. REGIONAL DIFFERENCES
None. The app works the same in all regions. It does not depend on location or any online content.

6. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
Not applicable. Yakala does not operate in a regulated industry and contains no protected third-party material. The sample dashboard shown in the screenshots ("Pusula") is fictional and was created for the App Store images.

Yakala is open source: https://github.com/mugione/Yakala
Privacy policy: https://github.com/mugione/Yakala/blob/main/PRIVACY.md

Best regards,
Murat Gülsen
```

## Ekran kaydı nasıl çekilir

Mac'in kendi kayıt aracıyla, gerçek Mac'te, en son macOS'ta. Toplam 1–2 dakika yeterli.

1. Kayda başlamadan önce Yakala'dan çık (menü çubuğu simgesine sağ tık › Çık).
   Karşılama ekranının videoda görünmesi için Terminal'de bir kez:
   `defaults delete io.github.mugione.Yakala didShowWelcome`
2. **⇧⌘5** › alttaki çubukta **Tüm Ekranı Kaydet** › **Kaydet**.
3. Kayıtta sırayla:
   1. Finder › Uygulamalar › **Yakala**'ya çift tıkla → karşılama ekranı görünür, **Başla**.
   2. (İzin zaten verildiyse yeşil onay görünür; verilmediyse **Ekran Kaydı İznini Ver**'i göster.)
   3. **⇧⌘2** → bir alanı sürükleyerek seç.
   4. Düzenleyicide: bir **ok**, bir **etiket** (L) yaz, iki **numara** (N) koy, bir yeri **pikselleştir** (X).
   5. **Güzelleştir**'e bas, farklı bir arka plan seç, tekrar kapat.
   6. **⌘C** → Notlar ya da TextEdit'i aç, **⌘V** ile yapıştır.
   7. **⇧⌘1** → bir pencereye tıkla → düzenleyicide **⌘S** ile kaydet.
   8. Menü çubuğu simgesine **sağ tık** → **Ayarlar…** → sekmeler arasında gez.
4. Menü çubuğundaki **■** simgesiyle kaydı durdur. Video masaüstüne `.mov` olarak kaydedilir.
