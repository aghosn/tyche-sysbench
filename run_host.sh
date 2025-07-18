#!/bin/bash

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <nb cores>"
    exit 1
fi

NB_CORES="$1"

echo "[+] Measuring sysbench on the host w/ ${NB_CORES} cores."
echo "[+] Starting sysbench cpu..."
sysbench cpu --threads=$NB_CORES --time=120 run > host_sysbench_cpu_${NB_CORES}_cores.txt
echo "[✓] Done with sysbench cpu on the host."
echo "[+] Starting sysbench mem..."
sysbench memory --time=120 --threads=$NB_CORES --memory-access-mode=rnd --memory-oper=write run > host_sysbench_mem_${NB_CORES}_cores.txt
echo "[✓] Done with sysbench mem on the host."
