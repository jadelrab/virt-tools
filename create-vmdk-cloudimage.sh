#!/bin/bash
#
# create-vmdk-cloudimage.sh
# version : 1.0
#
# Author : Claude Durocher
# License : GPLv3
#
# requires the following packages :
#  wget qemu-utils genisoimage
#

# image selection : xenial, centos7, stretch, ...
IMG="xenial"
# architecture : amd64 or i386
ARCH="amd64"
# vm prefs : specify vm preferences for your guest
GUEST_NAME=xenialtest
DOMAIN=cell.local
# guest image format: raw, qcow2 or vmdk for vmware
FORMAT=vmdk
# convert image format : yes or no
CONVERT=yes

# cloud-init config files : specify cloud-init data for your guest
# xenial, use ens3 instead of eth0
cat <<EOF > meta-data
instance-id: iid-${GUEST_NAME};
network-interfaces: |
  auto ens3
  iface ens3 inet static
  address 192.168.122.122
  network 192.168.122.0
  netmask 255.255.255.0
  broadcast 192.168.122.255
  gateway 192.168.122.1
  dns-search ${DOMAIN}
  dns-nameservers 192.168.122.1
hostname: ${GUEST_NAME}
local-hostname: ${GUEST_NAME}
EOF

cat <<EOF > user-data
#cloud-config
password: password
chpasswd: { expire: False }
ssh_pwauth: True
# upgrade packages on startup
package_upgrade: false
#run 'apt-get upgrade' or yum equivalent on first boot
apt_upgrade: false
#manage_etc_hosts: localhost
manage_etc_hosts: true
fqdn: ${GUEST_NAME}.${DOMAIN}
#datasource_list:
#  - ConfigDrive
# install additional packages
packages:
  - mc
  - htop
#  - language-pack-fr
# run commands
runcmd:
# install htop on centos/fedora
#  - [ sh, -c, "curl http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-2.noarch.rpm -o /tmp/epel-release.rpm" ]
#  - [ sh, -c, "yum install -y /tmp/epel-release.rpm" ]
#  - [ sh, -c, "yum install -y htop" ]
#ssh_authorized_keys:
#  - ssh-rsa AAAAB3NzaC1yc2QwAAADAQABAAa3BAQC0g+ZTxC7weoIJLUafOgrm+h...
EOF

# don't edit below unless you know wat you're doing!

# download cloud image if not already downloaded
#  ref. https://openstack.redhat.com/Image_resources
case $IMG in
  precise)  IMG_USER="ubuntu"
            IMG_URL="http://cloud-images.ubuntu.com/releases/12.04/release"
            IMG_NAME="ubuntu-12.04-server-cloudimg-${ARCH}-disk1.img"
            ;;
  trusty)   IMG_USER="ubuntu"
            IMG_URL="http://cloud-images.ubuntu.com/releases/14.04/release"
            IMG_NAME="ubuntu-14.04-server-cloudimg-${ARCH}-disk1.img"
            ;;
  xenial)   IMG_USER="ubuntu"
            IMG_URL="http://cloud-images.ubuntu.com/releases/16.04/release/"
            IMG_NAME="ubuntu-16.04-server-cloudimg-${ARCH}-disk1.img"
            ;;
  centos6)  IMG_USER="centos"
            IMG_URL="https://cloud.centos.org/centos/6/images"
            if [[ $ARCH = "amd64" ]]; then
              IMG_NAME="CentOS-6-x86_64-GenericCloud.qcow2"
            else
              echo "Cloud image not available!"; exit 1
            fi
            ;;
  centos7)  IMG_USER="centos"
            IMG_URL="https://cloud.centos.org/centos/7/images"
            if [[ $ARCH = "amd64" ]]; then
              IMG_NAME="CentOS-7-x86_64-GenericCloud.qcow2"
            else
              echo "Cloud image not available!"; exit 1
            fi
            ;;
  fedora26) IMG_USER="fedora"
            if [[ $ARCH = "amd64" ]]; then
              IMG_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/26/CloudImages/x86_64/images/"
              IMG_NAME="Fedora-Cloud-Base-26-1.5.x86_64.qcow2"
            else
              echo "Cloud image not available!"; exit 1
            fi
            ;;
  jessie)   IMG_USER="debian"
            if [[ $ARCH = "amd64" ]]; then
              IMG_URL="https://cdimage.debian.org/cdimage/openstack/current-8"
              IMG_NAME="debian-8-openstack-amd64.qcow2"
            else
              echo "Cloud image not available!"; exit 1
            fi
            ;;
  stretch)  IMG_USER="debian"
            if [[ $ARCH = "amd64" ]]; then
              IMG_URL="https://cdimage.debian.org/cdimage/openstack/current-9"
              IMG_NAME="debian-9-openstack-amd64.qcow2"
            else
              echo "Cloud image not available!"; exit 1
            fi
            ;;
  *)        echo "Cloud image not available!"; exit 1
            ;;
esac

# get cloud image if not already present and create a guest root disk
if [[ ! -f ${IMG_NAME} ]]; then
  echo "Downloading ${IMG_NAME}..."
  wget ${IMG_URL}/${IMG_NAME} -O ${IMG_NAME}
fi
cp ${IMG_NAME} ${GUEST_NAME}.root.img
echo "${GUEST_NAME}.root.img created."

# convert image format if requested
if [[ "${CONVERT}" == "yes" ]]; then
  echo "Converting ${GUEST_NAME}.root.img to format ${FORMAT}..."
  # ref. https://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=2144687
  # ref. https://lists.ubuntu.com/archives/ubuntu-server-bugs/2016-April/145755.html
  # ref. http://cot.readthedocs.io/en/latest/COT.disks.vmdk.html
  qemu-img convert -O ${FORMAT} ${GUEST_NAME}.root.img ${GUEST_NAME}.root.img.${FORMAT}
  #printf '\x03' | dd conv=notrunc of=${GUEST_NAME}.root.img.${FORMAT} bs=1 seek=$((0x4))
  rm ${GUEST_NAME}.root.img
  echo "Convert done."
fi

# write the two cloud-init files into an ISO
genisoimage -input-charset utf8 -output ${GUEST_NAME}.configuration.iso -volid cidata -joliet -rock user-data meta-data
# keep a backup of the files for future reference
mv user-data ${GUEST_NAME}.user-data
mv meta-data ${GUEST_NAME}.meta-data
echo "${GUEST_NAME}.configuration.iso created."

echo "To create guest ${GUEST_NAME}, boot ${GUEST_NAME}.root.img.${FORMAT} with ${GUEST_NAME}.configuration.iso attached as CD-ROM."

