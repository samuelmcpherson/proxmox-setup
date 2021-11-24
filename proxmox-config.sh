#!/bin/bash

USER=$1

USERPASS=$2

USERSHELL=/bin/zsh

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

INTEL_CPU=yes

AMD_CPU=

EFI=
# This variable determines what bootloader configuration is modified when setting up PCI passthrough, EFI installations use systemdboot

BIOS=yes
# This variable determines what bootloader configuration is modified when setting up PCI passthrough, BIOS installations use grub

export DEBIAN_FRONTEND=noninteractive
# Make sure that interactive prompts do not interrupt any system upgrades or package installations

if [[ -n "$COMMUNITYREPO" ]]
then 
    echo "deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list.d/pve-community.list
    # Setup the community repository

    rm /etc/apt/sources.list.d/pve-enterprise.list
    # Removes the default enterprise repository
fi

apt update && apt -y upgrade
# Fully upgrades the system 

apt install -y sudo rsync dosfstools zsh zsh-antigen curl patch wget git irssi lynx elinks htop lm-sensors net-tools screen tmux sysstat iotop ripgrep nmap iftop vim tcpdump smartmontools sanoid
# Install a set of base packages 

if [[ -n "$ZFS" ]]
then
    apt install -y debhelper libcapture-tiny-perl libconfig-inifiles-perl pv lzop mbuffer
    # Install requirements to build and install sanoid for ZFS snapshot management

    rm -r /var/lib/vz/dump
    rm -r /var/lib/vz/images
    rm -r /var/lib/vz/template
    # Remove default image storage directories to replace with dedicated ZFS datasets 


    zfs create -o canmount=off -o xattr=sa -o compression=lz4 -o recordsize=16k rpool/data/VM_image_data
    # Create VM_image_data parent dataset with properties to optimize VM performance on any child datasets

    zfs create -o mountpoint=/var/lib/vz/dump rpool/data/VM_image_data/dump
    zfs create -o mountpoint=/var/lib/vz/images rpool/data/VM_image_data/images
    zfs create -o mountpoint=/var/lib/vz/template rpool/data/VM_image_data/template
    # Create child datasets for image storage
    
    zfs create -o canmount=off rpool/data/users
    # Create separate dataset for user accounts
    
    #cd /tmp && git clone https://github.com/jimsalterjrs/sanoid.git
    # Pull the github repo to install sanoid

    #cd /tmp/sanoid && git checkout $(git tag | grep '^v' | tail -n 1) && ln -s packages/debian . && dpkg-buildpackage -uc -us
    # Checkout the latest stable version of sanoid and build the debian package

    #apt install -y /tmp/sanoid_*_all.deb
    # Install the built sanoid package

    systemctl enable sanoid.timer
    # Enable the sanoid shedule

    zfs create -o mountpoint=/home/$USER rpool/data/users/$USER
    # Create main user home directory dataset

    useradd -M -g users -G sudo,adm,plugdev -s $USERSHELL -d /home/$USER $USER
    # Create main user for non-root configuration

    if [[ -n "$ANSIBLE" ]]
    then
        zfs create -o mountpoint=/home/ansible rpool/data/users/ansible
        # Create home directory for separate ansible user

        useradd -M -s /bin/bash -d /home/ansible ansible
        # Create separate ansible user
    fi

elif [[ -z "$ZFS" ]]
then
    useradd -m -g users -G sudo,adm,plugdev -s $USERSHELL $USER
    # Create main user for non-root configuration

    if [[ -n "$ANSIBLE" ]]
    then
        useradd -m -s /bin/bash ansible
        # Create separate ansible user
    fi
fi

mkdir -p /home/$USER/.ssh

cd /home/$USER && git clone $CONFIGREPO

cp $CONFIGDIR/home/.ssh/config /home/$USER/.ssh/config

cp $CONFIGDIR/home/.vimrc /home/$USER/.vimrc

cp $CONFIGDIR/home/.gitconfig /home/$USER/.gitconfig
# Copy a configured git configuration file to the main user account

# Pull git repository with configuration files to copy to new install

if [[ "$USERSHELL" = "/bin/zsh" || "$USERSHELL" = "/usr/bin/zsh" ]]
then
    cp $CONFIGDIR/home/.zshrc /home/$USER/.zshrc
    
    cp /usr/share/zsh-antigen/antigen.zsh /home/$USER/antigen.zsh
fi
# Copy antigen zsh configuration to main user home directory is zsh is used as the shell

sed -i 's/PATH="\/usr\/local\/bin:\/usr\/bin:\/bin:\/usr\/games"/PATH="\/usr\/local\/sbin:\/usr\/local\/bin:\/usr\/sbin:\/usr\/bin:\/sbin:\/bin"/g' $TEMPMOUNT/etc/zsh/zshenv

if [[ -n "$ANSIBLE" ]]
then
    mkdir -p /home/ansible/.ssh

    cp $CONFIGDIR/home/ansible/authorized_keys /home/ansible/.ssh/authorized_keys
    # Copy a pre-configured public key fingerprint from the config files repository to the ~/.ssh/authorized_keys file for the ansible user to allow key based authentication to this user

    chown -R ansible:ansible /home/ansible

    echo 'ansible ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/030_ansible-nopasswd
    # Allow ansible user to use sudo without a password

fi

cp $CONFIGDIR/etc/ssh/ssh_config /etc/ssh/ssh_config
# Copy ssh_config file to the new system, current version is used to avoid issues when connecting the older Cisco switches

cp $CONFIGDIR/etc/ssh/sshd_config /etc/ssh/sshd_config
# Copy sshd_config file to the the new system, current version restricts ssh access to key based only

if [[ -n "$ZFS" ]]
then
    mkdir /etc/sanoid
    cp $CONFIGDIR/etc/sanoid/proxmox/sanoid.conf /etc/sanoid/sanoid.conf
    # Copy sanoid configuration file into place on the new system
fi

chown -R $USER:users /home/$USER

echo "$USER:$USERPASS" | chpasswd
# Set the main user password 

if [[ -n "$PASSTHROUGH" ]]
then 
    echo 'vfio' >> /etc/modules
    echo 'vfio_iommu_type1' >> /etc/modules
    echo 'vfio_pci' >> /etc/modules
    echo 'vfio_virqfd' >> /etc/modules
    # Adds kernel modules required for pci passthrough

    if [[ -n "$EFI" ]]
    then
        if [ -n "$INTEL_CPU" ] && [ -z "$AMD_CPU" ]
        then
            sed -i 's/root=.*/& intel_iommu=on iommu=pt/g' /etc/kernel/cmdline
        elif [ -z "$INTEL_CPU" ] && [ -n "$AMD_CPU" ]
        then    
            sed -i 's/root=.*/& amd_iommu=on iommu=pt/g' /etc/kernel/cmdline
        else
            echo "Unable to set kernel parameters to enable PCI passthrough, you need to specify if you are using an intel or amd cpu"
        fi
        
        proxmox-boot-tool refresh
    
    elif [[ -n "$BIOS" ]]
    then
        if [ -n "$INTEL_CPU" ] && [ -z "$AMD_CPU" ]
        then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet/& intel_iommu=on iommu=pt/g' /etc/default/grub
        elif [ -z "$INTEL_CPU" ] && [ -n "$AMD_CPU" ]
        then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet/& intel_iommu=on iommu=pt/g' /etc/default/grub
        else
            echo "Unable to set kernel parameters to enable PCI passthrough, you need to specify if you are using an intel or amd cpu"
        fi
        
        proxmox-boot-tool refresh
    
    else
        echo "Unable to set kernel parameters to enable PCI passthrough, you need to specify if you are booting in EFI or BIOS mode"
    fi
    # Edits the kernel commandline to enable pci passthrough, edits systemdboot configuration for efi boot or grub configuration for bios boot. Requires amd or intel cpu type to be specified.

fi
