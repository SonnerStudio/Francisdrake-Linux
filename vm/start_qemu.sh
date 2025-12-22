#!/bin/bash
# Start Francisdrake Linux in QEMU (WSL)

ISO_PATH_PROJECT="/mnt/c/Dev/Repos/SonnerStudio/Francisdrake-Linux/francisdrake-linux-v1.iso"
ISO_PATH_DOWNLOADS="/mnt/d/Downloads/francisdrake-linux-v1.iso"

if [ -f "$ISO_PATH_PROJECT" ]; then
    ISO_PATH="$ISO_PATH_PROJECT"
    echo "Found ISO in Project Root: $ISO_PATH"
elif [ -f "$ISO_PATH_DOWNLOADS" ]; then
    ISO_PATH="$ISO_PATH_DOWNLOADS"
    echo "Found ISO in Downloads: $ISO_PATH"
else
    echo "Error: ISO not found in $ISO_PATH_PROJECT or $ISO_PATH_DOWNLOADS"
    exit 1
fi

echo "Starting QEMU..."
qemu-system-x86_64 \
    -name "Francisdrake Linux" \
    -m 4G \
    -smp 2 \
    -cdrom "$ISO_PATH" \
    -boot d \
    -vga virtio \
    -display default \
    -enable-kvm \
    &
