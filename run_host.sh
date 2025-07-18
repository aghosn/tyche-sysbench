#!/bin/bash

echo "[+] Measuring sysbench on the host."
echo "[+] Starting sysbench cpu..."
sysbench cpu --threads=1 --time=120 run > host_sysbench_cpu_$(date +%Y%m%d_%H%M%S).txt
echo "[+] Done with sysbench cpu on the host."
echo "[+] Starting sysbench mem..."
sysbench memory --time=120 --threads=1 --memory-access-mode=rnd --memory-oper=write run > host_sysbench_mem_$(date +%Y%m%d_%H%M%S).txt
echo "[+] Done with sysbench mem on the host."
