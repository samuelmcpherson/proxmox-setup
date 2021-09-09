#!/bin/bash

USER=$1

USERPASS=$2

ZFS=yes
# Setting this variable will create separate ZFS datasets for user directories, backups, VM image files, and templates saved on the local ZFS storage. It also installs Sanoid to manage ZFS snapshots systemwide. 

CONFIGREPO="https://github.com/samuelmcpherson/config-files.git"
# This variable is used for bringing in configuration files present in a separate repository, this will be cloned in the configured user's home directory

CONFIGDIR="/home/$USER/$(echo $CONFIGREPO | cut -d '/' -f5 | sed -r 's/.{4}$//')"
# Parsed from $CONFIGREPO, used for file operations after the repository is cloned

COMMUNITYREPO=yes
# Setting this variable will remove the default Proxmox enterprise repository and add the Proxmox community repository 

ANSIBLE=yes
# Setting this variable will create a separate ansible user account with passwordless sudo privleges and add a pre-existing public key from the configuration files repository to their authorized keys

PASSTHROUGH=yes
# Setting this variable will enable the kernel modules and boot options required for PCI passthrough on Intel based systems; to use this option, one of the following two variables will need to be set in order to correctly modify the kernel commandline of the correct bootloader

EFI=
# This variable determines what bootloader configuration is modified when setting up PCI passthrough, EFI installations use systemdboot

BIOS=yes
# This variable determines what bootloader configuration is modified when setting up PCI passthrough, BIOS installations use grub
 
if [[ -n "$COMMUNITYREPO" ]]
then 
    echo "deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list.d/pve-community.list
    # Setup the community repository

    rm /etc/apt/sources.list.d/pve-enterprise.list
    # Removes the default enterprise repository
fi

apt update && DEBIAN_FRONTEND=noninteractive apt -y upgrade
# Fully upgrades the new system and makes sure that interactive prompts do not interrupt this process

DEBIAN_FRONTEND=noninteractive apt install -y sudo rsync dosfstools zsh curl patch wget git irssi lynx elinks htop lm-sensors net-tools screen tmux sysstat iotop ripgrep nmap iftop vim neovim tcpdump smartmontools

if [[ -n "$ZFS" ]]
then
    DEBIAN_FRONTEND=noninteractive apt install -y debhelper libcapture-tiny-perl libconfig-inifiles-perl pv lzop mbuffer

    rm -r /var/lib/vz/dump
    rm -r /var/lib/vz/images
    rm -r /var/lib/vz/template

    zfs create -o canmount=off -o xattr=sa -o compression=lz4 -o recordsize=16k rpool/data/VM_image_data
    zfs create -o mountpoint=/var/lib/vz/dump rpool/data/VM_image_data/dump
    zfs create -o mountpoint=/var/lib/vz/images rpool/data/VM_image_data/images
    zfs create -o mountpoint=/var/lib/vz/template rpool/data/VM_image_data/template
    zfs create -o canmount=off rpool/data/users
    
    cd /root && git clone https://github.com/jimsalterjrs/sanoid.git

    cd /root/sanoid && git checkout $(git tag | grep '^v' | tail -n 1) && ln -s packages/debian . && dpkg-buildpackage -uc -us

    apt install -y /root/sanoid_*_all.deb

    zfs create -o mountpoint=/home/$USER rpool/data/users/$USER
    
    useradd -M -g users -G sudo,adm,plugdev -s /usr/bin/zsh -d /home/$USER $USER

    if [[ -n "$ANSIBLE" ]]
    then
        zfs create -o mountpoint=/home/ansible rpool/data/users/ansible
    
        useradd -M -s /bin/bash -d /home/ansible ansible
    fi

elif [[ -z "$ZFS" ]]
then
    useradd -m -g users -G sudo,adm,plugdev -s /usr/bin/zsh $USER

    if [[ -n "$ANSIBLE" ]]
    then
        useradd -m -s /bin/bash ansible
    fi
fi

mkdir -p /home/$USER/.ssh

cd /home/$USER && git clone $CONFIGREPO

cp $CONFIGDIR/home/.zshrc /home/$USER/.zshrc

cp $CONFIGDIR/home/.zshrc.local /home/$USER/.zshrc.local

cp $CONFIGDIR/home/grml-zsh-refcard.pdf /home/$USER/grml-zsh-refcard.pdf

if [[ -n "$ANSIBLE" ]]
then
    mkdir -p /home/ansible/.ssh

    cp $CONFIGDIR/home/ansible/authorized_keys /home/ansible/.ssh/authorized_keys

    chown -R ansible:ansible /home/ansible

    echo 'ansible ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/030_ansible-nopasswd

fi

cp $CONFIGDIR/etc/ssh/ssh_config /etc/ssh/ssh_config

cp $CONFIGDIR/etc/ssh/sshd_config /etc/ssh/sshd_config

if [[ -n "$ZFS" ]]
then
    mkdir /etc/sanoid
    cp $CONFIGDIR/etc/sanoid/proxmox/sanoid.conf /etc/sanoid/sanoid.conf
fi

cp $CONFIGDIR/home/.gitconfig /home/$USER/.gitconfig

chown -R $USER:users /home/$USER

echo "$USER:$USERPASS" | chpasswd

if [[ -n "$PASSTHROUGH" ]]
then 
    echo 'vfio' >> /etc/modules
    echo 'vfio_iommu_type1' >> /etc/modules
    echo 'vfio_pci' >> /etc/modules
    echo 'vfio_virqfd' >> /etc/modules
    
    if [[ -n "$EFI" ]]
    then
        sed -i 's/root=.*/& intel_iommu=on iommu=pt/g' /etc/kernel/cmdline
        
        proxmox-boot-tool refresh
    elif [[ -n "$BIOS" ]]
    then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet/& intel_iommu=on iommu=pt/g' /etc/default/grub
        
        proxmox-boot-tool refresh
    else
        echo "Unable to set kernel parameters to enable PCI passthrough, you need to specify if you are booting in EFI or BIOS mode"
    fi

fi
