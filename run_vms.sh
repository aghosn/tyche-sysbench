#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <rootfs.raw> <nb cores per vm>"
    exit 1
fi

RAW_IMAGE="$1"               # your rootfs.raw
CORES_PER_VM="$2"
RESULTS_DIR="./results_${CORES_PER_VM}_cores"
VM_KERNEL="bzImage" # CHANGE this to your kernel path
MEM_MB=1024

# Detect number of available CPU cores
NUM_CORES=$(nproc)

echo "[+] Detected $NUM_CORES cores"

mkdir -p "$RESULTS_DIR"

# make a copy of the rawfs for each core
for ((i=0; i<NUM_CORES; i+=CORES_PER_VM)); do
    VM_DISK="$RESULTS_DIR/disk_core${i}.raw"
    if [[ ! -f "$VM_DISK" ]]; then
        echo "[+] Creating copy of $RAW_IMAGE → $VM_DISK"
        cp --reflink=auto "$RAW_IMAGE" "$VM_DISK"
    fi
done

NUM_VMS=$(( NUM_CORES / CORES_PER_VM ))

echo "[+] Launching $NUM_VMS VMs…"

PIDS=()

for ((i=0; i<NUM_CORES; i+=CORES_PER_VM)); do
    VM_DISK="$RESULTS_DIR/disk_core${i}.raw"
    LOG_FILE="$RESULTS_DIR/vm-core-$i.log"
    echo "[+] Starting VM $i on core $i"
    KVM_PIN_CORE=$i \
    lkvm run \
        --name="vm-core-$i" \
        --cpus "$CORES_PER_VM" \
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

echo "[+] Running one VM alone..."
VM_DISK="$RESULTS_DIR/disk_alone_core_${CORES_PER_VM}.raw"
LOG_FILE="$RESULTS_DIR/vm-alone-core-${CORES_PER_VM}.log"
cp --reflink=auto "$RAW_IMAGE" "$VM_DISK"
KVM_PIN_CORE=1 \
lkvm run \
    --name="vm-alone-core-${CORES_PER_VM}" \
    --cpus "$CORES_PER_VM" \
    --mem $MEM_MB \
    --disk "$VM_DISK" \
    --console virtio \
    --network virtio \
    --kernel "$VM_KERNEL" \
    --params "root=/dev/vda rw console=ttyS0" \
    --console=ttyS0 > "$LOG_FILE" 2>&1 &
pidalone=($!)

echo "[+] VM alone launched. Waiting for it to finish…"

wait "$pidalone"

echo "[✓] All VMs have exited. Results and logs are in: $RESULTS_DIR/"

