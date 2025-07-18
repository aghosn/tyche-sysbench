all:

NB_CORES ?= 1

setup:
	sudo ./create_rootfs.sh

run:
	sudo ./run_vms.sh rootfs.raw $(NB_CORES)
	./run_host.sh $(NB_CORES)
	sudo ./extract_results.sh $(NB_CORES) results_$(NB_CORES)_cores

