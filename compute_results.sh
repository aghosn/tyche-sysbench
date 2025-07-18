#!/bin/bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <host_cpu.txt> <host_mem.txt> <vms_cpu.txt> <vms_mem.txt>"
    exit 1
fi

HOST_CPU_FILE="$1"
HOST_MEM_FILE="$2"
VMS_CPU_FILE="$3"
VMS_MEM_FILE="$4"

echo "=== Sysbench Slowdown Report ==="
echo ""

# extract host CPU events per second
host_cpu_eps=$(awk '/events per second/ {print $4}' "$HOST_CPU_FILE")
echo "[Host] CPU events/sec: $host_cpu_eps"

# extract host MEM MiB/sec
host_mem_rate=$(awk '
  /MiB transferred/ {mib=$1}
  /total time/ {time=$3}
  END {if (mib && time) printf "%.2f", mib/time}' "$HOST_MEM_FILE")
echo "[Host] MEM MiB/sec:   $host_mem_rate"

echo ""
printf "%-10s %-20s %-20s\n" "VM" "CPU slowdown" "MEM slowdown"

vm_idx=0

paste <(awk '/events per second/ {print $4}' "$VMS_CPU_FILE") \
      <(awk '
         /MiB transferred/ {mib=$1}
         /total time/ {time=$3; if (mib && time) {printf "%.2f\n", mib/time; mib=0; time=0}}' "$VMS_MEM_FILE") |
while read -r vm_cpu_eps vm_mem_rate; do
    cpu_slowdown=$(awk -v h="$host_cpu_eps" -v v="$vm_cpu_eps" 'BEGIN {printf "%.2fx", h/v}')
    mem_slowdown=$(awk -v h="$host_mem_rate" -v v="$vm_mem_rate" 'BEGIN {printf "%.2fx", h/v}')

    printf "vm%-7d %-20s %-20s\n" "$vm_idx" "$cpu_slowdown" "$mem_slowdown"

    ((vm_idx++))
done
