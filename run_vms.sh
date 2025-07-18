#!/bin/bash
set -euo pipefail

RAW_IMAGE="$1"               # your rootfs.raw
RESULTS_DIR="./results"
VM_KERNEL="bzImage" # CHANGE this to your kernel path
MEM_MB=1024

# Detect number of available CPU cores
NUM_CORES=$(nproc)

echo "[+] Detected $NUM_CORES cores"

mkdir -p "$RESULTS_DIR"

# make a copy of the rawfs for each core
for ((i=0; i<NUM_CORES; i++)); do
    VM_DISK="$RESULTS_DIR/disk_core${i}.raw"
    if [[ ! -f "$VM_DISK" ]]; then
        echo "[+] Creating copy of $RAW_IMAGE → $VM_DISK"
        cp --reflink=auto "$RAW_IMAGE" "$VM_DISK"
    fi
done

echo "[+] Launching $NUM_CORES VMs…"

PIDS=()

for ((i=0; i<NUM_CORES; i++)); do
    VM_DISK="$RESULTS_DIR/disk_core${i}.raw"
    LOG_FILE="$RESULTS_DIR/vm-core-$i.log"
    echo "[+] Starting VM $i on core $i"
    KVM_PIN_CORE=$i \
    lkvm run \
        --name="vm-core-$i" \
        --cpus 1 \
        --mem $MEM_MB \
        --disk "$VM_DISK" \
        --console virtio \
        --network virtio \
        --kernel "$VM_KERNEL" \
        --params "root=/dev/vda rw console=ttyS0" \
        --console=ttyS0 > "$LOG_FILE" 2>&1 &
    PIDS+=($!)
done

echo "[+] All VMs launched. Waiting for them to finish…"

for pid in "${PIDS[@]}"; do
    wait "$pid"
done

echo "[✓] All VMs have exited. Results and logs are in: $RESULTS_DIR/"

