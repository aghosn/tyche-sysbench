#!/bin/bash
set -euo pipefail

# CONFIGURATION
ROOTFS_DIR=/tmp/rootfs
IMAGE=rootfs.raw
SIZE_GB=1
DISTRO=jammy          # Ubuntu 22.04
ARCH=amd64

# CHECK prerequisites
command -v debootstrap >/dev/null || { echo "debootstrap not found"; exit 1; }
command -v losetup >/dev/null || { echo "losetup not found"; exit 1; }
command -v mkfs.ext4 >/dev/null || { echo "mkfs.ext4 not found"; exit 1; }

sudo true # ensure we have sudo

echo "[+] Create empty RAW disk image..."
dd if=/dev/zero of=$IMAGE bs=1G count=$SIZE_GB

echo "[+] Setup loop device..."
LOOPDEV=$(sudo losetup --show -fP $IMAGE)
echo "[+] Loop device: $LOOPDEV"

echo "[+] Format loop device with ext4..."
sudo mkfs.ext4 ${LOOPDEV}

echo "[+] Mount image to $ROOTFS_DIR..."
sudo mkdir -p $ROOTFS_DIR
sudo mount ${LOOPDEV} $ROOTFS_DIR

echo "[+] Bootstrap minimal Ubuntu rootfs..."
sudo debootstrap --arch=$ARCH $DISTRO $ROOTFS_DIR

#echo "[+] Mount /proc, /sys, /dev into chroot..."
#sudo mount -t proc proc $ROOTFS_DIR/proc
#sudo mount --rbind /sys $ROOTFS_DIR/sys
#sudo mount --rbind /dev $ROOTFS_DIR/dev

echo "[+] Set hostname & root password..."
echo "sysbench-vm" | sudo tee $ROOTFS_DIR/etc/hostname
echo "root:root" | sudo chroot $ROOTFS_DIR chpasswd

cat <<EOF | sudo tee $ROOTFS_DIR/etc/hosts
127.0.0.1 localhost
127.0.1.1 sysbench-vm
EOF

echo "[+] Enable universe in sources.list…"
sudo sed -i 's/\(main\)\(.*\)/\1 universe/' $ROOTFS_DIR/etc/apt/sources.list

echo "[+] Install base packages in chroot..."
sudo chroot $ROOTFS_DIR bash -c "
apt-get update &&
apt-get install -y systemd-sysv sysbench openssh-server sudo
"

echo "[+] Enable SSH at boot..."
sudo chroot $ROOTFS_DIR systemctl enable ssh

echo "[+] Create sysbench run script..."
sudo tee $ROOTFS_DIR/root/run-sysbench.sh > /dev/null <<'EOF'
#!/bin/bash
sudo ip link set enp0s3 up
sudo dhclient enp0s3
mkdir -p /root/sysbench-results
sysbench cpu --threads=$(nproc) --time=120 run > /root/sysbench-results/result_cpu.txt
sysbench memory --time=120 --threads=$(nproc) --memory-access-mode=rnd --memory-oper=write run > /root/sysbench-results/result_mem.txt
EOF
sudo chmod +x $ROOTFS_DIR/root/run-sysbench.sh

echo "[+] Create systemd service to run sysbench at boot..."
sudo tee $ROOTFS_DIR/etc/systemd/system/sysbench.service > /dev/null <<'EOF'
[Unit]
Description=Run sysbench once at boot
After=network-online.target

[Service]
Type=oneshot
ExecStart=/root/run-sysbench.sh
ExecStartPost=/sbin/reboot

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Enable sysbench service..."
sudo chroot $ROOTFS_DIR systemctl enable sysbench.service

echo "[+] Clean up apt caches..."
sudo chroot $ROOTFS_DIR apt-get clean

#echo "[+] Unmount /proc, /sys, /dev..."
#sudo umount -l $ROOTFS_DIR/proc || true
#sudo umount -l $ROOTFS_DIR/sys || true
#sudo umount -l $ROOTFS_DIR/dev || true

echo "[+] Unmount rootfs..."
sudo umount -l $ROOTFS_DIR

echo "[+] Detach loop device..."
sudo losetup -d $LOOPDEV

echo "[✓] DONE: Raw image ready at $IMAGE"

