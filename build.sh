#!/bin/bash
# Yakala.app paketini derler. Kullanım:
#   ./build.sh            → build/Yakala.app oluşturur
#   ./build.sh --open     → derler, çalışan Yakala'yı kapatır ve yenisini açar
#   ./build.sh --install  → derler, Uygulamalar klasörüne kurar ve oradan açar
#                           (yazılamıyorsa ~/Applications; INSTALL_DIR ile başka bir klasör seçilebilir)
#   ./build.sh --dmg      → derler ve paylaşılabilir tek dosyalık kurulum paketi üretir: build/Yakala-<sürüm>.dmg
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-}"
case "$MODE" in
  "" | --open | --install | --dmg) ;;
  *)
    echo "Bilinmeyen seçenek: $MODE (kullanım: ./build.sh [--open | --install | --dmg])" >&2
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
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')}"
codesign --force --sign "${IDENTITY:--}" "$APP"

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
    echo "Kuruldu: $DEST"
    open "$DEST"
    ;;
  --dmg)
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
    echo "Kurulum dosyası: $DMG"
    ;;
esac
