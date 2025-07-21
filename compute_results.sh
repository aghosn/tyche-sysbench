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

echo "=== Sysbench VM Performance vs Host ==="
echo ""

# host CPU events/sec
host_cpu_eps=$(awk '/events per second/ {print $4; exit}' "$HOST_CPU_FILE")
echo "[Host] CPU events/sec: $host_cpu_eps"

# host MEM throughput (MiB/sec)
host_mem_rate=$(awk '
  /MiB transferred/ {mib=$1}
  /total time/ {time=$3}
  END {if (mib && time) printf "%.2f", mib/time}' "$HOST_MEM_FILE")
echo "[Host] MEM MiB/sec:   $host_mem_rate"

echo ""
printf "%-10s %-30s %-30s\n" "VM" "CPU (VM / Host, %)" "MEM (VM / Host, %)"

# read all VM CPU results
mapfile -t vm_cpu_eps_list < <(awk '/events per second/ {print $4}' "$VMS_CPU_FILE")

# read all VM MEM results
mapfile -t vm_mem_rate_list < <(
  awk '
    /MiB transferred/ {mib=$1}
    /total time/ {
      time=$3
      if (mib && time) {
        printf "%.2f\n", mib/time
        mib=0; time=0
      }
    }' "$VMS_MEM_FILE"
)

num_vms=${#vm_cpu_eps_list[@]}

for ((i=0; i<num_vms; i++)); do
    vm_cpu_eps="${vm_cpu_eps_list[$i]}"
    vm_mem_rate="${vm_mem_rate_list[$i]}"

    cpu_ratio=$(awk -v h="$host_cpu_eps" -v v="$vm_cpu_eps" 'BEGIN {printf "%.1f%%", (v/h)*100}')
    mem_ratio=$(awk -v h="$host_mem_rate" -v v="$vm_mem_rate" 'BEGIN {printf "%.1f%%", (v/h)*100}')

    printf "vm%-7d %-30s %-30s\n" \
        "$i" \
        "$(printf "%.2f / %.2f, %s" "$vm_cpu_eps" "$host_cpu_eps" "$cpu_ratio")" \
        "$(printf "%.2f / %.2f, %s" "$vm_mem_rate" "$host_mem_rate" "$mem_ratio")"
done
