#!/bin/bash
#
# virt-inst-cd.sh : script to start a vm with cd iso image on kvm
# version : 1.0
#
# Author : Claude Durocher
# License : GPLv3
#
# requires the following packages on Ubuntu host:
#  wget qemu-kvm libvirt-bin virtinst bridge-utils 
# requires the following packages on CentOS host:
#  wget qemu-kvm libvirt virt-install bridge-utils 
#

# image selection
IMG_URL="http://somesite.com/"
IMG_NAME="somefile.iso"
# kvm defaults pool paths
DEF_POOL=default
DEF_POOL_PATH=/var/lib/libvirt/images
# vm prefs : specify vm preferences for your guest
GUEST=guestname
DOMAIN=localnet
VROOTDISKSIZE=50G
VCPUS=4
VMEM=8192
NETWORK="bridge=br0,model=virtio --network bridge=br1,model=virtio"
FORMAT=qcow2
# guest image format: qcow2 or raw
FORMAT=qcow2
# kvm pool
POOL=$DEF_POOL
POOL_PATH=$DEF_POOL_PATH
# don't edit below unless you know wat you're doing!

# check if the script is run as root user
if [[ $USER != "root" ]]; then
  echo "This script must be run as root!" && exit 1
fi

# download ISO if not already downloaded
if [[ ! -f ${IMG_NAME} ]]; then
  echo "Downloading image ${IMG_NAME}..."
  wget ${IMG_URL}/${IMG_NAME} -O ${IMG_NAME}
fi

# check if POOL exists, otherwise create it
if [[ "$(virsh pool-list|grep ${POOL} -c)" -ne "1" ]]; then
  virsh pool-define-as --name ${POOL} --type dir --target ${POOL_PATH}
  virsh pool-autostart ${POOL}
  virsh pool-build ${POOL}
  virsh pool-start ${POOL}
fi

# copy ISO to libvirt's POOL
if [[ ! -f ${POOL_PATH}/${IMG_NAME} ]]; then
  cp ${IMG_NAME} ${POOL_PATH}
  virsh pool-refresh ${POOL} 
fi

# create GUEST disk
virsh vol-create-as ${POOL} ${GUEST}.root.img ${VROOTDISKSIZE} --format ${FORMAT}

# create and start GUEST
virt-install \
  --name ${GUEST} \
  --ram ${VMEM} \
  --vcpus=${VCPUS} \
  --autostart \
  --memballoon virtio \
  --network ${NETWORK},model=virtio \
  --boot hd \
  --disk vol=${POOL}/${GUEST}.root.img,format=${FORMAT},bus=virtio \
  --graphics vnc,listen=0.0.0.0 --noautoconsole \
  --cdrom ${POOL_PATH}/${IMG_NAME}

# display result
echo
echo "List of running VMs :"
echo
virsh list
echo
echo "VNC display: 590"$(virsh vncdisplay ${GUEST})
echo
echo 'IMPORTANT :Add <driver name="qemu"/> to each virtio network interface !

# stuff to remember
echo
echo "************************"
echo "Useful stuff to remember"
echo "************************"
echo
echo "To login to vm guest:"
echo " sudo virsh console ${GUEST}"
echo "Default user for cloud image is :"
echo " ${IMG_USER}"
echo
echo "To edit guest vm config:"
echo " sudo virsh edit ${GUEST}"
echo
echo "To create a volume:"
echo " virsh vol-create-as ${POOL} ${GUEST}.vol1.img 20G --format ${FORMAT}"
echo "To attach a volume to an existing guest:"
echo " virsh attach-disk ${GUEST} --source ${POOL_PATH}/${GUEST}.vol1.img --target vdc --driver qemu --subdriver ${FORMAT} --persistent"
echo "To prepare the newly attached volume on guest:"
echo " sgdisk -n 1 -g /dev/vdc && && mkfs -t ext4 /dev/vdc1 && sgdisk -c 1:'vol1' -g /dev/vdc && sgdisk -p /dev/vdc"
echo " mkdir /mnt/vol1"
echo " echo '/dev/vdc1 /mnt/vol1 ext4 defaults,relatime 0 0' >> /etc/fstab"
echo
echo "To shutdown a guest vm:"
echo "  sudo virsh shutdown ${GUEST}"
echo
