#!/bin/bash

# Francisdrake Linux Build Script
# Basierend auf Kali Linux Remastering
# Pfade anpassen falls nötig

set -e # Abbruch bei Fehler

# Konfiguration
ISO_SOURCE="/mnt/d/Downloads/kali-linux-2025.4-live-amd64.iso"
PROJECT_ROOT="/mnt/c/Dev/Repos/SonnerStudio/Francisdrake-Linux"
WORK_DIR="$HOME/francisdrake-build"
ISO_DIR="$WORK_DIR/iso-content"
SQUASH_DIR="$WORK_DIR/squashfs-root"
OUTPUT_ISO="$PROJECT_ROOT/francisdrake-linux-v1.iso"

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

# 4a. Hintergrundbilder kopieren (Aggressiv)
# Wir kopieren unsere Artworks in den Standard-Hintergrund-Ordner von Kali
# Pfade können je nach Kali-Version variieren, wir zielen auf /usr/share/backgrounds/kali/
TARGET_BG_DIR="$SQUASH_DIR/usr/share/backgrounds/kali"
sudo mkdir -p "$TARGET_BG_DIR"
sudo cp "$PROJECT_ROOT/artworks/Francisdrake-Linux.png" "$TARGET_BG_DIR/default-16x9.png"
sudo cp "$PROJECT_ROOT/artworks/Francisdrake-Linux.png" "$TARGET_BG_DIR/default-4x3.png"

# BRUTE FORCE: Suche nach ALLEN Kali-Hintergründen und ersetze sie
echo -e "${GREEN}>>> Branding: Brute-Force Desktop Wallpaper Replacement...${NC}"
find "$SQUASH_DIR/usr/share/backgrounds" -type f \( -name "*kali*" -o -name "default*" \) -name "*.png" -print0 | while IFS= read -r -d '' bg_img; do
     echo " -> [Brand] Overwriting Desktop Wallpaper: $bg_img"
     sudo cp "$PROJECT_ROOT/artworks/Francisdrake-Linux.png" "$bg_img"
done

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

# 4e. Bootloader Image Overwrite (Comprehensive + EFI Fix)
echo -e "${GREEN}>>> Branding: Comprehensive Bootloader Replacement...${NC}"

# 1. ISO Boot Directory (Isolinux/GRUB)
echo -e "${GREEN}>>> Replacing ISO boot images...${NC}"
REPLACED_COUNT=0
find "$ISO_DIR/isolinux" "$ISO_DIR/boot" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.svg" \) 2>/dev/null | while read -r img; do
    echo " -> [Brand] Overwriting Boot Image: $img"
    sudo cp --remove-destination "$PROJECT_ROOT/artworks/Francisdrake-Linux.png" "$img"
    ((REPLACED_COUNT++))
done
echo "Replaced $REPLACED_COUNT boot images"

# 2. Extract and Modify EFI Image (Critical for UEFI Boot!)
EFI_IMG="$ISO_DIR/boot/grub/efi.img"
if [ -f "$EFI_IMG" ]; then
    echo -e "${GREEN}>>> Modifying EFI Image...${NC}"
    EFI_MNT="$WORK_DIR/efi_mnt"
    sudo mkdir -p "$EFI_MNT"
    
    # Mount EFI image
    sudo mount -o loop "$EFI_IMG" "$EFI_MNT" 2>/dev/null || true
    
    if mountpoint -q "$EFI_MNT"; then
        # Replace images inside EFI
        find "$EFI_MNT" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.tga" \) 2>/dev/null | while read -r efi_img; do
            echo " -> [EFI] Overwriting: $efi_img"
            sudo cp --remove-destination "$PROJECT_ROOT/artworks/Francisdrake-Linux.png" "$efi_img"
        done
        
        # Fix GRUB theme configs in EFI
        find "$EFI_MNT" -name "theme.txt" -o -name "*.cfg" | while read -r cfg; do
            sudo sed -i 's/Kali Linux/Francisdrake Linux/g' "$cfg" 2>/dev/null || true
        done
        
        sudo umount "$EFI_MNT"
        echo "EFI Image modified successfully"
    else
        echo "WARNING: Could not mount EFI image"
    fi
fi

# 3. GRUB Themes in ISO Boot Directory (CRITICAL - This is what shows at boot!)
echo -e "${GREEN}>>> Fixing GRUB Theme Configurations in ISO...${NC}"
find "$ISO_DIR/boot/grub" -name "theme.txt" 2>/dev/null | while read -r theme_file; do
    echo " -> [Boot Theme] Fixing: $theme_file"
    # Replace all text references to Kali
    sudo sed -i 's/Kali Linux/Francisdrake Linux/g' "$theme_file"
    sudo sed -i 's/Live Boot Menu/Francisdrake Linux Live Menu/g' "$theme_file"
    # Ensure splash image path is correct
    sudo sed -i 's|desktop-image:.*|desktop-image: "../splash.png"|g' "$theme_file"
done

# 4. GRUB Themes in SquashFS (for installed system)
GRUB_THEME_DIR="$SQUASH_DIR/usr/share/grub/themes"
if [ -d "$GRUB_THEME_DIR" ]; then
    echo -e "${GREEN}>>> Fixing GRUB Themes in SquashFS...${NC}"
    
    # Replace all images
    find "$GRUB_THEME_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.tga" \) 2>/dev/null | while read -r theme_img; do
        echo " -> [SquashFS Theme] Overwriting: $theme_img"
        sudo cp --remove-destination "$PROJECT_ROOT/artworks/Francisdrake-Linux.png" "$theme_img"
    done
    
    # Fix theme.txt files
    find "$GRUB_THEME_DIR" -name "theme.txt" 2>/dev/null | while read -r theme_file; do
        echo " -> [SquashFS Theme] Fixing config: $theme_file"
        sudo sed -i 's/Kali Linux/Francisdrake Linux/g' "$theme_file"
        sudo sed -i 's/desktop-image:.*/desktop-image: "background.png"/g' "$theme_file"
    done
fi

# 5. Desktop Backgrounds
echo -e "${GREEN}>>> Nuking Desktop Backgrounds...${NC}"
find "$SQUASH_DIR/usr/share/backgrounds" "$SQUASH_DIR/usr/share/wallpapers" -type f \( -name "*.png" -o -name "*.jpg" \) 2>/dev/null | while read -r bg_img; do
    echo " -> [Desktop] Overwriting: $bg_img"
    sudo cp --remove-destination "$PROJECT_ROOT/artworks/Francisdrake-Linux.png" "$bg_img"
done

# 5. XFCE Config Injection
XFCE_BG_DIR="$SQUASH_DIR/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
sudo mkdir -p "$XFCE_BG_DIR"
cat <<EOF | sudo tee "$XFCE_BG_DIR/xfce4-desktop.xml" >/dev/null
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="image-path" type="string" value="/usr/share/backgrounds/kali/default-16x9.png"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/kali/default-16x9.png"/>
      </property>
    </property>
  </property>
</channel>
EOF

# 6. .disk/info Branding
if [ -d "$ISO_DIR/.disk" ]; then
    sudo sed -i 's/Kali Linux/Francisdrake Linux/g' "$ISO_DIR/.disk/info" 2>/dev/null || true
fi

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
