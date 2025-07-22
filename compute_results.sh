#!/bin/bash
set -euo pipefail
export LC_NUMERIC=C

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
  END {if (mib && time) printf "%.2f", mib/time}
' "$HOST_MEM_FILE")
echo "[Host] MEM MiB/sec:   $host_mem_rate"

echo ""
printf "%-40s %-30s %-30s\n" "VM Disk" "CPU (VM / Host, %)" "MEM (VM / Host, %)"

# parse VM results
vm_disks=()
vm_cpu_eps_list=()
vm_mem_rate_list=()

# extract CPU results
awk '
  /^===== Results from/ {
      sub(/^===== Results from /, "", $0)
      sub(/ =====$/, "", $0)
      disk=$0
      while (getline) {
          if (/events per second/) {
              cpu_eps=$4
              printf "%s %s\n", disk, cpu_eps
              break
          }
      }
  }
' "$VMS_CPU_FILE" > /tmp/vm_cpu_results.txt

# extract MEM results
awk '
  /^===== Results from/ {
      sub(/^===== Results from /, "", $0)
      sub(/ =====$/, "", $0)
      disk=$0
      mib=0; time=0
      while (getline) {
          if (/MiB transferred/) mib=$1
          if (/total time/) {
              time=$3
              rate=(mib/time)
              printf "%s %.2f\n", disk, rate
              break
          }
      }
  }
' "$VMS_MEM_FILE" > /tmp/vm_mem_results.txt

# read into arrays
while read -r disk cpu; do
    vm_disks+=("$disk")
    vm_cpu_eps_list+=("$cpu")
done < /tmp/vm_cpu_results.txt

while read -r disk mem; do
    vm_mem_rate_list+=("$mem")
done < /tmp/vm_mem_results.txt

rm -f /tmp/vm_cpu_results.txt /tmp/vm_mem_results.txt

# sanity check
if [[ ${#vm_cpu_eps_list[@]} -ne ${#vm_mem_rate_list[@]} ]]; then
    echo "Mismatch: ${#vm_cpu_eps_list[@]} CPU results vs ${#vm_mem_rate_list[@]} MEM results"
    exit 1
fi

num_vms=${#vm_cpu_eps_list[@]}

for ((i=0; i<num_vms; i++)); do
    disk="$(basename "${vm_disks[$i]}")"
    vm_cpu_eps="${vm_cpu_eps_list[$i]}"
    vm_mem_rate="${vm_mem_rate_list[$i]}"

    cpu_ratio=$(awk -v h="$host_cpu_eps" -v v="$vm_cpu_eps" 'BEGIN {printf "%.1f", (v/h)*100}')
    mem_ratio=$(awk -v h="$host_mem_rate" -v v="$vm_mem_rate" 'BEGIN {printf "%.1f", (v/h)*100}')

    printf "%-40s %7.2f / %7.2f, %5.1f%% %15.2f / %7.2f, %5.1f%%\n" \
        "$disk" \
        "$vm_cpu_eps" "$host_cpu_eps" "$cpu_ratio" \
        "$vm_mem_rate" "$host_mem_rate" "$mem_ratio"
done
