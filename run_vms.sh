#!/bin/bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <rootfs.raw> <nb cores per vm> <lkvm|qemu>"
    exit 1
fi

RAW_IMAGE="$1"               # your rootfs.raw
CORES_PER_VM="$2"
RESULTS_DIR="./results_${CORES_PER_VM}_cores"
VM_KERNEL="bzImage" # CHANGE this to your kernel path
MEM_MB=1024
HYPERVISOR="$3"

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
    if [[ "$HYPERVISOR" == "lkvm" ]]; then
        KVM_PIN_CORES=$i \
        lkvm run \
            --name="vm-core-$i" \
            --cpus "$CORES_PER_VM" \
            --mem "$MEM_MB" \
            --disk "$VM_DISK" \
            --console virtio \
            --network virtio \
            --kernel "$VM_KERNEL" \
            --params "root=/dev/vda rw console=ttyS0" \
            --console=ttyS0 > "$LOG_FILE" 2>&1 &
    elif [[ "$HYPERVISOR" == "qemu" ]]; then
        start_core=$i
        cores=$CORES_PER_VM
         
        # Compute the range string (for taskset)
        core_range="$start_core-$((start_core + cores - 1))"
        
        # Expand core_range into a comma-separated list for --cpu-affinity
        cpu_affinity_list=""
        for ((c=start_core; c<start_core+cores; c++)); do
            cpu_affinity_list+="$c,"
        done
        cpu_affinity_list="${cpu_affinity_list%,}"
        host_cores="$i-$((i + CORES_PER_VM - 1))"
        taskset -c "$host_cores" \
        qemu-system-x86_64 \
            -enable-kvm \
            -name "vm-core-$i" \
            -smp "$CORES_PER_VM" \
            -m "$MEM_MB" \
            -drive file="$VM_DISK",if=virtio,format=raw \
            -nographic \
            -kernel "$VM_KERNEL" \
            -append "root=/dev/vda rw console=ttyS0" \
            -netdev user,id=net0 \
            -device virtio-net-pci,netdev=net0 > "$LOG_FILE" 2>&1 &
    else
        echo "Unknown hypervisor: $HYPERVISOR"
        exit 1
    fi
    PIDS+=($!)
done

echo "[+] All VMs launched. Waiting for them to finish…"

for pid in "${PIDS[@]}"; do
    wait "$pid"
done

echo "[✓] All VMs have exited. Results and logs are in: $RESULTS_DIR/"

echo "[+] Running one VM alone..."
VM_DISK="$RESULTS_DIR/disk_alone_core_${CORES_PER_VM}.raw"
LOG_FILE="$RESULTS_DIR/vm-alone-core-${CORES_PER_VM}.log"
cp --reflink=auto "$RAW_IMAGE" "$VM_DISK"

if [[ "$HYPERVISOR" == "lkvm" ]]; then
    KVM_PIN_CORES=0 \
    lkvm run \
        --name="vm-alone-core-${CORES_PER_VM}" \
        --cpus "$CORES_PER_VM" \
        --mem "$MEM_MB" \
        --disk "$VM_DISK" \
        --console virtio \
        --network virtio \
        --kernel "$VM_KERNEL" \
        --params "root=/dev/vda rw console=ttyS0" \
        --console=ttyS0 > "$LOG_FILE" 2>&1 &
    pidalone=$!

elif [[ "$HYPERVISOR" == "qemu" ]]; then
    taskset -c 0-$((CORES_PER_VM-1)) \
    qemu-system-x86_64 \
        -enable-kvm \
        -name "vm-alone-core-${CORES_PER_VM}" \
        -smp "$CORES_PER_VM" \
        -m "$MEM_MB" \
        -drive file="$VM_DISK",if=virtio,format=raw \
        -nographic \
        -kernel "$VM_KERNEL" \
        -append "root=/dev/vda rw console=ttyS0" \
        -netdev user,id=net0 \
        -device virtio-net-pci,netdev=net0 > "$LOG_FILE" 2>&1 &
    pidalone=$!

else
    echo "Unknown hypervisor: $HYPERVISOR"
    exit 1
fi

wait "$pidalone"

echo "[✓] Done running one VM alone."


echo "[+] Attempting to run two VMs pinned to the same set of cores..."

if (( NUM_CORES >= CORES_PER_VM )); then
    SHARED_CORES_RANGE="1-$((CORES_PER_VM))"

    VM_DISK1="$RESULTS_DIR/disk_shared_vm1.raw"
    VM_DISK2="$RESULTS_DIR/disk_shared_vm2.raw"
    LOG_FILE1="$RESULTS_DIR/vm-shared-1.log"
    LOG_FILE2="$RESULTS_DIR/vm-shared-2.log"

    cp --reflink=auto "$RAW_IMAGE" "$VM_DISK1"
    cp --reflink=auto "$RAW_IMAGE" "$VM_DISK2"

    PIDS_SHARED=()

    if [[ "$HYPERVISOR" == "lkvm" ]]; then
        KVM_PIN_CORES=$SHARED_CORES_RANGE \
        lkvm run \
            --name="vm-shared-1" \
            --cpus "$CORES_PER_VM" \
            --mem "$MEM_MB" \
            --disk "$VM_DISK1" \
            --console virtio \
            --network virtio \
            --kernel "$VM_KERNEL" \
            --params "root=/dev/vda rw console=ttyS0" \
            --console=ttyS0 > "$LOG_FILE1" 2>&1 &
        PIDS_SHARED+=($!)

        KVM_PIN_CORES=$SHARED_CORES_RANGE \
        lkvm run \
            --name="vm-shared-2" \
            --cpus "$CORES_PER_VM" \
            --mem "$MEM_MB" \
            --disk "$VM_DISK2" \
            --console virtio \
            --network virtio \
            --kernel "$VM_KERNEL" \
            --params "root=/dev/vda rw console=ttyS0" \
            --console=ttyS0 > "$LOG_FILE2" 2>&1 &
        PIDS_SHARED+=($!)

    elif [[ "$HYPERVISOR" == "qemu" ]]; then
        taskset -c "$SHARED_CORES_RANGE" \
        qemu-system-x86_64 \
            -enable-kvm \
            -name "vm-shared-1" \
            -smp "$CORES_PER_VM" \
            -m "$MEM_MB" \
            -drive file="$VM_DISK1",if=virtio,format=raw \
            -nographic \
            -kernel "$VM_KERNEL" \
            -append "root=/dev/vda rw console=ttyS0" \
            -netdev user,id=net0 \
            -device virtio-net-pci,netdev=net0 > "$LOG_FILE1" 2>&1 &
        PIDS_SHARED+=($!)

        taskset -c "$SHARED_CORES_RANGE" \
        qemu-system-x86_64 \
            -enable-kvm \
            -name "vm-shared-2" \
            -smp "$CORES_PER_VM" \
            -m "$MEM_MB" \
            -drive file="$VM_DISK2",if=virtio,format=raw \
            -nographic \
            -kernel "$VM_KERNEL" \
            -append "root=/dev/vda rw console=ttyS0" \
            -netdev user,id=net0 \
            -device virtio-net-pci,netdev=net0 > "$LOG_FILE2" 2>&1 &
        PIDS_SHARED+=($!)

    else
        echo "Unknown hypervisor: $HYPERVISOR"
        exit 1
    fi

    echo "[+] Waiting for the two VMs (sharing cores) to finish…"
    for pid in "${PIDS_SHARED[@]}"; do
        wait "$pid"
    done
    echo "[✓] Both VMs sharing cores have exited."

else
    echo "[!] Not enough cores to run two VMs pinned to the same set of $CORES_PER_VM cores."
fi
