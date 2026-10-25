#!/bin/bash
# Yakala.app paketini derler. Kullanım:
#   ./build.sh            → build/Yakala.app oluşturur
#   ./build.sh --open     → derler, çalışan Yakala'yı kapatır ve yenisini açar
#   ./build.sh --install  → derler, Uygulamalar klasörüne kurar ve oradan açar
#                           (yazılamıyorsa ~/Applications; INSTALL_DIR ile başka bir klasör seçilebilir)
#   ./build.sh --dmg      → derler ve paylaşılabilir tek dosyalık kurulum paketi üretir: build/Yakala-<sürüm>.dmg
#                           (yanında SHA-256 özeti: build/Yakala-<sürüm>.dmg.sha256)
#   ./build.sh --release  → --dmg gibi, ama Developer ID ile imzalar, Apple'a noterletir ve onayı DMG'ye iliştirir.
#                           Gerekenler: Xcode'da "Developer ID Application" sertifikası ve bir kez
#                           "xcrun notarytool store-credentials yakala-notary --team-id <TEAM_ID>"
#                           (profil adı NOTARY_PROFILE ile değiştirilebilir)
#   ./build.sh --appstore → Mac App Store'a yüklenecek imzalı kurulum paketini üretir: build/Yakala-<sürüm>-AppStore.pkg
#                           Gerekenler: "Apple Distribution" ve "Mac Installer Distribution" sertifikaları ve
#                           Support/AppStore.provisionprofile (APPSTORE_PROFILE ile başka bir yol verilebilir)
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-}"
case "$MODE" in
  "" | --open | --install | --dmg | --release | --appstore) ;;
  *)
    echo "Bilinmeyen seçenek: $MODE (kullanım: ./build.sh [--open | --install | --dmg | --release | --appstore])" >&2
    exit 1
    ;;
esac

swift build -c release

APP="build/Yakala.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Yakala "$APP/Contents/MacOS/Yakala"
cp Support/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns" # yeniden üretmek için: swift Support/make-icon.swift

# Xcode'da oluşturulan "Apple Development" sertifikası varsa onunla imzala: imza sabit kalır,
# ekran kaydı izni yeniden derlemelerde kaybolmaz. Yoksa ad-hoc ("-") imzala.
# Sandbox ve izinler Support/Yakala.entitlements'ta; "runtime" notarization için gereken sertleştirilmiş çalışma ortamı.
# --release her zaman "Developer ID Application" ile ve zaman damgasıyla imzalar (noterleme bunları ister).
# Adı değil SHA-1 parmak izini döndürür: aynı adda birden çok sertifika olunca codesign adı belirsiz bulur.
find_identity() { security find-identity -v -p codesigning | awk -F'"' -v kind="$1" '$2 ~ kind { split($1, f, " "); print f[2]; exit }'; }
if [[ "$MODE" == --release ]]; then
  IDENTITY="${SIGN_IDENTITY:-$(find_identity "Developer ID Application")}"
  if [[ -z "$IDENTITY" ]]; then
    echo "Durduruldu: \"Developer ID Application\" sertifikası bulunamadı (Xcode › Settings › Accounts › Manage Certificates)." >&2
    exit 1
  fi
  codesign --force --options runtime --timestamp --entitlements Support/Yakala.entitlements --sign "$IDENTITY" "$APP"
elif [[ "$MODE" == --appstore ]]; then
  IDENTITY="${SIGN_IDENTITY:-$(find_identity "Apple Distribution")}"
  INSTALLER_IDENTITY="$(security find-identity -v | awk -F'"' '$2 ~ /(Mac Installer Distribution|3rd Party Mac Developer Installer)/ { split($1, f, " "); print f[2]; exit }')"
  PROFILE="${APPSTORE_PROFILE:-Support/AppStore.provisionprofile}"
  for need in "Apple Distribution:$IDENTITY" "Mac Installer Distribution:$INSTALLER_IDENTITY"; do
    if [[ -z "${need#*:}" ]]; then
      echo "Durduruldu: \"${need%%:*}\" sertifikası bulunamadı (Xcode › Settings › Accounts › Manage Certificates)." >&2
      exit 1
    fi
  done
  if [[ ! -f "$PROFILE" ]]; then
    echo "Durduruldu: $PROFILE yok. developer.apple.com › Profiles'tan Mac App Store profilini indirip buraya koy." >&2
    exit 1
  fi
  # App Store, profili uygulamanın içinde ve profildeki kimlikleri yetkilerde ister.
  cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
  PROFILE_PLIST="$(mktemp)"
  security cms -D -i "$PROFILE" > "$PROFILE_PLIST"
  TEAM_ID="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$PROFILE_PLIST")"
  APP_ID="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$PROFILE_PLIST")"
  rm -f "$PROFILE_PLIST"
  ENTITLEMENTS="$(mktemp).entitlements"
  cp Support/Yakala.entitlements "$ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $APP_ID" \
    -c "Add :com.apple.developer.team-identifier string $TEAM_ID" "$ENTITLEMENTS"
  codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP"
  rm -f "$ENTITLEMENTS"
else
  IDENTITY="${SIGN_IDENTITY:-$(find_identity "Apple Development")}"
  codesign --force --options runtime --entitlements Support/Yakala.entitlements --sign "${IDENTITY:--}" "$APP"
fi

echo "Hazır: $APP (imza: ${IDENTITY:-ad-hoc})"

# Çalışan Yakala'yı kapatır ve tamamen çıkmasını bekler; çıkmadan açmaya çalışmak -600 hatası verir.
quit_running_yakala() {
  pkill -x Yakala || return 0
  for _ in {1..50}; do
    pgrep -x Yakala >/dev/null || return 0
    sleep 0.1
  done
}

case "$MODE" in
  --open)
    quit_running_yakala
    open "$APP"
    ;;
  --install)
    DEST_DIR="${INSTALL_DIR:-/Applications}"
    if [[ -z "${INSTALL_DIR:-}" && ! -w "$DEST_DIR" ]]; then
      DEST_DIR="$HOME/Applications"
    fi
    mkdir -p "$DEST_DIR"
    DEST="$DEST_DIR/Yakala.app"

    # Aynı adda başka bir uygulama varsa üzerine yazma; sadece önceki Yakala kurulumu değiştirilir.
    BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Support/Info.plist)"
    if [[ -e "$DEST" ]]; then
      EXISTING_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DEST/Contents/Info.plist" 2>/dev/null || true)"
      if [[ "$EXISTING_ID" != "$BUNDLE_ID" ]]; then
        echo "Durduruldu: $DEST başka bir uygulamaya ait (${EXISTING_ID:-kimliği okunamadı}), dokunulmadı." >&2
        exit 1
      fi
    fi

    quit_running_yakala
    rm -rf "$DEST"
    ditto "$APP" "$DEST"
    # macOS derleme klasöründeki kopyayı ayrı bir uygulama sanıp (ör. "Çık ve Yeniden Aç"ta) onu açmasın.
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$PWD/$APP" 2>/dev/null || true
    echo "Kuruldu: $DEST"
    open "$DEST"
    ;;
  --appstore)
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
    PKG="build/Yakala-$VERSION-AppStore.pkg"
    rm -f "$PKG"
    productbuild --component "$APP" /Applications --sign "$INSTALLER_IDENTITY" "$PKG"
    echo "App Store paketi: $PKG (Transporter uygulamasıyla yükle; her yüklemede CFBundleVersion artmalı)"
    ;;
  --dmg | --release)
    # Açılınca Yakala ve Uygulamalar klasörünü yan yana gösteren disk görüntüsü;
    # kurmak için Yakala'yı Uygulamalar'a sürüklemek yeter.
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
    DMG="build/Yakala-$VERSION.dmg"
    STAGING="$(mktemp -d)"
    trap 'rm -rf "$STAGING"' EXIT
    ditto "$APP" "$STAGING/Yakala.app"
    ln -s /Applications "$STAGING/Uygulamalar"
    rm -f "$DMG"
    hdiutil create -volname "Yakala" -srcfolder "$STAGING" -fs HFS+ -format UDZO -quiet "$DMG"

    if [[ "$MODE" == --release ]]; then
      codesign --force --timestamp --sign "$IDENTITY" "$DMG"
      echo "Apple'a noterlemeye gönderiliyor (birkaç dakika sürebilir)…"
      xcrun notarytool submit "$DMG" --keychain-profile "${NOTARY_PROFILE:-yakala-notary}" --wait
      # Onay DMG'ye iliştirilir; böylece Gatekeeper internet olmadan da doğrulayabilir.
      xcrun stapler staple "$DMG"
      spctl --assess --type open --context context:primary-signature -v "$DMG"
    fi
    # Özet en son hesaplanır: iliştirme DMG'yi değiştirir.
    # İndiren kişi dosyanın değiştirilmediğini "shasum -a 256 -c Yakala-<sürüm>.dmg.sha256" ile doğrulayabilir.
    (cd build && shasum -a 256 "Yakala-$VERSION.dmg" > "Yakala-$VERSION.dmg.sha256")
    echo "Kurulum dosyası: $DMG"
    echo "SHA-256: $(cut -d' ' -f1 "$DMG.sha256")  ($DMG.sha256)"
    ;;
esac
