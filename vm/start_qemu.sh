#!/bin/bash
# Start Francisdrake Linux in QEMU (WSL)

ISO_PATH="/mnt/d/Downloads/francisdrake-linux-v1.iso"

if [ ! -f "$ISO_PATH" ]; then
    echo "Error: ISO not found at $ISO_PATH"
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
