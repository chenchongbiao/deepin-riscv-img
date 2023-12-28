#!/bin/bash

# 何命令失败（退出状态非0），则脚本会终止执行
set -o errexit
# 尝试使用未设置值的变量，脚本将停止执行
set -o nounset

ROOTFS=`mktemp -d`
TARGET_DEVICE=qemu
TARGET_ARCH=riscv64
COMPONENTS=standard
DISKSIZE="60G"
DISKIMG="deepin-$TARGET_DEVICE-$TARGET_ARCH.qcow2"
readarray -t REPOS < ./profiles/sources.list
PACKAGES=`cat ./profiles/packages.txt | grep -v "^-" | xargs | sed -e 's/ /,/g'`

sudo apt update -y
sudo apt-get install -y qemu-user-static binfmt-support mmdebstrap arch-test usrmerge usr-is-merged qemu-system-misc opensbi u-boot-qemu systemd-container

# 创建根文件系统
sudo mmdebstrap \
    --hook-dir=/usr/share/mmdebstrap/hooks/merged-usr \
    --include=$PACKAGES \
    --architectures=$TARGET_ARCH $COMPONENTS \
    --customize=./profiles/stage2.sh \
    $ROOTFS \
    "${REPOS[@]}"

sudo echo "deepin-$TARGET_ARCH-$TARGET_DEVICE" | sudo tee $ROOTFS/etc/hostname > /dev/null
sudo echo "Asia/Shanghai" | sudo tee $ROOTFS/etc/timezone > /dev/null
sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai $ROOTFS/etc/localtime
sudo tee -a $ROOTFS/etc/default/u-boot <<-'EOF'
# change ro to rw, set root device
U_BOOT_PARAMETERS="rw noquiet root=/dev/vda1"

# fdt is provided by qemu
U_BOOT_FDT_DIR="noexist"
EOF
sudo systemd-nspawn -D $ROOTFS bash -c "u-boot-update || true"

# sudo virt-make-fs --partition=gpt --type=ext4 --size=+10G --format=qcow2 $ROOTFS $DISKIMG
# -l 懒卸载，避免有程序使用 ROOTFS 还没退出
sudo umount -l $ROOTFS
# sudo rm -rf $ROOTFS