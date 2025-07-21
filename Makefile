all:

NB_CORES ?= 1

setup:
	sudo ./create_rootfs.sh

run_lkvm:
	sudo ./run_vms.sh rootfs.raw $(NB_CORES) lkvm
	./run_host.sh $(NB_CORES)
	sudo ./extract_results.sh $(NB_CORES) results_$(NB_CORES)_cores
	sudo ./compute_results.sh host_sysbench_cpu_$(NB_CORES)_cores.txt host_sysbench_mem_$(NB_CORES)_cores.txt sysbench_cpu_$(NB_CORES)_cores.txt sysbench_mem_$(NB_CORES)_cores.txt > processed_$(NB_CORES)_lkvm.txt
	sudo rm -rf results_$(NB_CORES)_cores

run_qem:
	sudo ./run_vms.sh rootfs.raw $(NB_CORES) qemu
	./run_host.sh $(NB_CORES)
	sudo ./extract_results.sh $(NB_CORES) results_$(NB_CORES)_cores
	sudo ./compute_results.sh host_sysbench_cpu_$(NB_CORES)_cores.txt host_sysbench_mem_$(NB_CORES)_cores.txt sysbench_cpu_$(NB_CORES)_cores.txt sysbench_mem_$(NB_CORES)_cores.txt > processed_$(NB_CORES)_qem.txt
	sudo rm -rf results_$(NB_CORES)_cores
