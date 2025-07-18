#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <nb_cores> <results folder>"
    exit 1
fi

CORE="$1"
DISK_DIR="$2"
MOUNT_DIR=/tmp/mount/vm-disk
CPU_OUT="sysbench_cpu_$CORE_$(date +%Y%m%d_%H%M%S).txt"
MEM_OUT="sysbench_mem_$CORE_$(date +%Y%m%d_%H%M%S).txt"

CPU_FILE="root/sysbench-results/result_cpu.txt"
MEM_FILE="root/sysbench-results/result_mem.txt"

sudo mkdir -p "$MOUNT_DIR"

echo "[+] Extracting sysbench results from disks in: $DISK_DIR"
echo "[+] Writing CPU results to: $CPU_OUT"
echo "[+] Writing MEM results to: $MEM_OUT"
echo

for disk in "$DISK_DIR"/*.raw; do
    echo "[+] Mounting $disk …"
    loopdev=$(sudo losetup --show -fP "$disk")
    sudo mount "${loopdev}" "$MOUNT_DIR"

    echo "[+] Reading from $disk …"

    if [ -f "$MOUNT_DIR/$CPU_FILE" ]; then
        echo "===== Results from $disk =====" >> "$CPU_OUT"
        cat "$MOUNT_DIR/$CPU_FILE" >> "$CPU_OUT"
        echo >> "$CPU_OUT"
    else
        echo "[-] CPU result not found in $disk"
    fi

    if [ -f "$MOUNT_DIR/$MEM_FILE" ]; then
        echo "===== Results from $disk =====" >> "$MEM_OUT"
        cat "$MOUNT_DIR/$MEM_FILE" >> "$MEM_OUT"
        echo >> "$MEM_OUT"
    else
        echo "[-] MEM result not found in $disk"
    fi

    echo "[+] Unmounting $disk …"
    sudo umount "$MOUNT_DIR"
    sudo losetup -d "$loopdev"
    echo
done

echo "[✓] Done. Results:"
echo "    CPU: $CPU_OUT"
echo "    MEM: $MEM_OUT"
