all:

setup:
	sudo ./create_rootfs.sh

run:
	sudo rm -rf results/
	sudo ./run_vms.sh rootfs.raw
	./run_host.sh

process:
	sudo ./extract_results.sh

