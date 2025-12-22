#!/bin/bash

# Francisdrake Linux Build Script
# Basierend auf Kali Linux Remastering
# Pfade anpassen falls nötig

set -e # Abbruch bei Fehler

# Konfiguration
ISO_SOURCE="/mnt/d/Downloads/kali-linux-2025.4-live-amd64.iso"
WORK_DIR="$HOME/francisdrake-build"
ISO_DIR="$WORK_DIR/iso-content"
SQUASH_DIR="$WORK_DIR/squashfs-root"
OUTPUT_ISO="/mnt/d/Downloads/francisdrake-linux-v1.iso"
PROJECT_ROOT="/mnt/c/Dev/Repos/SonnerStudio/Francisdrake-Linux"

# Farben für Output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}>>> Starte Francisdrake Linux Build Prozess${NC}"

# 0. Prüfungen & Mounts
if [ ! -f "$ISO_SOURCE" ]; then
    echo -e "${RED}ISO Datei nicht gefunden. Prüfe Mounts...${NC}"
    # Versuch D: zu mounten falls nötig
    if [ ! -d "/mnt/d" ] || [ -z "$(ls -A /mnt/d 2>/dev/null)" ]; then
        echo -e "${GREEN}>>> Laufwerk D: scheint nicht gemountet. Versuche Mount...${NC}"
        sudo mkdir -p /mnt/d
        sudo mount -t drvfs D: /mnt/d
    fi
fi

if [ ! -f "$ISO_SOURCE" ]; then
    echo -e "${RED}Fehler: ISO Datei immer noch nicht gefunden unter $ISO_SOURCE${NC}"
    echo -e "${RED}Bitte sicherstellen, dass Laufwerk D: in WSL verfügbar ist.${NC}"
    exit 1
fi

if ! command -v xorriso &> /dev/null; then
    echo -e "${RED}Fehler: xorriso ist nicht installiert. Bitte 'sudo apt install xorriso squashfs-tools' ausführen.${NC}"
    exit 1
fi

# 1. Arbeitsverzeichnis vorbereiten
echo -e "${GREEN}>>> Bereinige Arbeitsverzeichnis...${NC}"
sudo rm -rf "$WORK_DIR"
mkdir -p "$ISO_DIR"

# 2. ISO extrahieren
echo -e "${GREEN}>>> Extrahiere ISO Inhalt...${NC}"
xorriso -osirrox on -indev "$ISO_SOURCE" -extract / "$ISO_DIR"

# 3. Dateisystem entpacken (SquashFS)
echo -e "${GREEN}>>> Entpacke Filesystem (das kann dauern)...${NC}"
sudo unsquashfs -d "$SQUASH_DIR" "$ISO_DIR/live/filesystem.squashfs"

# 4. Anpassungen in Chroot (Branding Injektion)
echo -e "${GREEN}>>> Injiziere Branding...${NC}"

# 4a. Hintergrundbilder kopieren
# Wir kopieren unsere Artworks in den Standard-Hintergrund-Ordner von Kali
# Pfade können je nach Kali-Version variieren, wir zielen auf /usr/share/backgrounds/kali/
TARGET_BG_DIR="$SQUASH_DIR/usr/share/backgrounds/kali"
sudo mkdir -p "$TARGET_BG_DIR"
sudo cp "$PROJECT_ROOT/artworks/Francisdrake-Linux.png" "$TARGET_BG_DIR/default-16x9.png"
sudo cp "$PROJECT_ROOT/artworks/Francisdrake-Linux.png" "$TARGET_BG_DIR/default-4x3.png"

# 4b. OS-Release anpassen
echo -e "${GREEN}>>> Kopiere System-Konfiguration...${NC}"
sudo cp "$PROJECT_ROOT/config/os-release" "$SQUASH_DIR/etc/os-release"

# 4c. Dokumentation hinzufügen
sudo mkdir -p "$SQUASH_DIR/usr/share/francisdrake"
sudo cp "$PROJECT_ROOT/README.md" "$SQUASH_DIR/usr/share/francisdrake/"
sudo cp "$PROJECT_ROOT/README_DE.md" "$SQUASH_DIR/usr/share/francisdrake/"
sudo cp "$PROJECT_ROOT/LICENSE" "$SQUASH_DIR/usr/share/francisdrake/"

# 4d. Bootloader Branding (Isolinux/Grub)
echo -e "${GREEN}>>> Passe Bootloader Labels an...${NC}"
# Schreibrechte geben
sudo chmod -R +w "$ISO_DIR/isolinux" "$ISO_DIR/boot" 2>/dev/null || true

# Ersetze Text in Konfigurationsdateien
find "$ISO_DIR/isolinux" -name "*.cfg" -print0 | xargs -0 sudo sed -i 's/Kali Linux/Francisdrake Linux/g'
find "$ISO_DIR/boot/grub" -name "*.cfg" -print0 | xargs -0 sudo sed -i 's/Kali Linux/Francisdrake Linux/g'

# Optional: Splash Image ersetzen (experimentell, falls Dimensionen passen)
# sudo cp "$PROJECT_ROOT/artworks/Francisdrake-Linux.png" "$ISO_DIR/isolinux/splash.png" || true

# 5. Dateisystem wieder packen
echo -e "${GREEN}>>> Packe Filesystem neu (das dauert noch länger)...${NC}"
sudo rm "$ISO_DIR/live/filesystem.squashfs"
sudo mksquashfs "$SQUASH_DIR" "$ISO_DIR/live/filesystem.squashfs" -comp xz -b 1M -noappend

# 6. Checksummen aktualisieren
echo -e "${GREEN}>>> Aktualisiere Checksummen...${NC}"
cd "$ISO_DIR"
# Falls md5sum.txt existiert, könnte es read-only sein. Löschen oder Rechte ändern.
sudo rm -f md5sum.txt
find . -type f ! -name 'md5sum.txt' -print0 | xargs -0 md5sum | sudo tee md5sum.txt >/dev/null

# 7. ISO erstellen
echo -e "${GREEN}>>> Erstelle Bootfähige ISO...${NC}"
xorriso -as mkisofs \
    -r -V "Francisdrake Linux" \
    -o "$OUTPUT_ISO" \
    -J -joliet-long \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot -isohybrid-gpt-basdat \
    "$ISO_DIR"

echo -e "${GREEN}>>> Fertig! ISO gespeichert unter: $OUTPUT_ISO${NC}"
