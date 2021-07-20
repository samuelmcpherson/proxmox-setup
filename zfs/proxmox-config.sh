#!/bin/bash

MOUNTPOINT=/mnt/man-mnt

WORKDIR=/root

REPO=proxmox-setup

USER=ccadmin

COMMUNITYREPO=

PASSTHROUGH=yes

CONFIGFILE1=$WORKDIR/$REPO/configfiles/iscsid.conf

CONFIGDESTINATION1=/etc/iscsi/iscsid.conf

CONFIGFILE2=$WORKDIR/$REPO/configfiles/multipath.conf

CONFIGDESTINATION2=/etc/multipath.conf

CONFIGFILE3=

CONFIGDESTINATION3=
# set networking to dhcp in /etc/network/interfaces

cp -r $MOUNTPOINT/$REPO $WORKDIR

cp -r $MOUNTPOINT/.ssh $WORKDIR

cp -r $MOUNTPOINT/.gitconfig $WORKDIR

if [ -n "$COMMUNITYREPO" ]
then 

    cp $WORKDIR/$REPO/configfiles/proxmox/pve-community.list /etc/apt/sources.list.d

    rm /etc/apt/sources.list.d/pve-enterprise.list

fi

apt update && apt -y upgrade

apt install -y sudo rsync dosfstools zsh curl patch wget git irssi lynx elinks htop lm-sensors net-tools screen tmux sysstat iotop glances ripgrep nmap iftop vim neovim tcpdump smartmontools open-iscsi lsscsi multipath-tools

rm -r /var/lib/vz/dump

rm -r /var/lib/vz/images

rm -r /var/lib/vz/template

apt install -y debhelper libcapture-tiny-perl libconfig-inifiles-perl pv lzop mbuffer

zfs create -o canmount=off rpool/data/users

zfs create -o mountpoint=/home/$USER rpool/data/users/$USER

zfs create -o mountpoint=/home/ansible rpool/data/users/ansible

zfs create -o canmount=off -o xattr=sa -o compression=lz4 -o recordsize=8k rpool/data/VM_image_data

zfs create -o mountpoint=/var/lib/vz/dump rpool/data/VM_image_data/dump

zfs create -o mountpoint=/var/lib/vz/images rpool/data/VM_image_data/images

zfs create -o mountpoint=/var/lib/vz/template rpool/data/VM_image_data/template

cd $WORKDIR && git clone https://github.com/jimsalterjrs/sanoid.git

cd $WORKDIR/sanoid && git checkout $(git tag | grep '^v' | tail -n 1) && ln -s packages/debian . && dpkg-buildpackage -uc -us

apt install -y $WORKDIR/sanoid_*_all.deb

cp $WORKDIR/$REPO/configfiles/sanoid.conf /etc/sanoid

cp $WORKDIR/$REPO/configfiles/ssh_config /etc/ssh

cp $WORKDIR/$REPO/configfiles/sshd_config /etc/ssh

useradd -M -g users -G sudo,adm,plugdev -s /usr/bin/zsh -d /home/$USER $USER

cp $WORKDIR/$REPO/files/dotfiles/.zshrc /home/$USER

cp $WORKDIR/$REPO/files/dotfiles/.zshrc.local /home/$USER

cp $WORKDIR/$REPO/files/dotfiles/grml-zsh-refcard.pdf /home/$USER

cp -a /etc/skel/. /home/$USER

usermod -s /usr/bin/zsh root

cp $WORKDIR/$REPO/files/dotfiles/.zshrc $WORKDIR

cp $WORKDIR/$REPO/files/dotfiles/.zshrc.local $WORKDIR

cp $WORKDIR/$REPO/files/dotfiles/grml-zsh-refcard.pdf $WORKDIR

cp -r $WORKDIR/$REPO/ /home/$USER

cp -r $WORKDIR/$REPO/ /home/$USER

cp -r $WORKDIR/.ssh /home/$USER

cp $WORKDIR/.gitconfig /home/$USER

chown -R $USER:users /home/$USER

useradd -M -s /bin/bash -d /home/ansible ansible

mkdir -p /home/ansible/.ssh

cp $WORKDIR/$REPO/files/ansible/authorized_keys /home/ansible/.ssh

chown -R ansible:ansible /home/ansible

echo 'ansible ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/030_ansible-nopasswd

if [ -n "$PASSTHROUGH" ]
then 

    echo 'vfio' >> /etc/modules
    echo 'vfio_iommu_type1' >> /etc/modules
    echo 'vfio_pci' >> /etc/modules
    echo 'vfio_virqfd' >> /etc/modules

    sed -i 's/root=.*/& intel_iommu=on iommu=pt/g' /etc/kernel/cmdline

    pve-efiboot-tool refresh

    echo 'test with'

    echo

    echo 'dmesg | grep -e DMAR -e IOMMU'

    dmesg | grep -e DMAR -e IOMMU

    echo 

    echo 'dmesg | grep remapping'

    dmesg | grep remapping

    echo

    echo 'find /sys/kernel/iommu_groups/ -type l'

    find /sys/kernel/iommu_groups/ -type l

fi