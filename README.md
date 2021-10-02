# proxmox-setup
## Purpose:
These scripts have been designed to automate the process of setting up a new Proxmox Virtual Environment, they accomplish the following tasks:

- Configuring the community repository if requested

- Creating an non-root admin user and setting a user shell and password

- Adding an authorized key to the admin user

- Disabling password based ssh login

- Install a set of useful packages

- Setup pci passthrough for VMs

- Setting up an ansible user with passwordless sudo access and adding an authorized public key for this account

- Configure ZFS datasets to allow for easier administration and more granular configuration

- Setup Sanoid to automatically schedule ZFS snapshots

## How to use:
These scripts are designed to be run from a separate device to configure a fresh install of Proxmox.

The configuration can be modified by editing the environment variables st at the top of the `proxmox-config.sh` script.

After making any desired modifications, run the  ```deploy-wrapper.sh``` script with the following arguments:

1. The IP address of the Proxmox system to connect to

2. The root password of the system

3. The name of the user account to create

4. The password to set for the user account

5. The ssh key to authorize to access the new user account (optional)

### proxmox-config.sh

The `proxmox-config.sh` script uses these environment variables to configure it's behavior:

- `USER=$1`

- `USERPASS=$2`

- `USERSHELL=/bin/zsh`

- `ZFS=yes`

Setting this variable will create separate ZFS datasets for user directories, backups, VM image files, and templates saved on the local ZFS storage. It also installs Sanoid to manage ZFS snapshots systemwide.

- `CONFIGREPO="https://github.com/samuelmcpherson/config-files.git"`

This variable is used for bringing in configuration files present in a separate repository, this will be cloned in the configured user's home directory

- `CONFIGDIR="/home/$USER/$(echo $CONFIGREPO | cut -d '/' -f5 | sed -r 's/.{4}$//')"`

Parsed from `$CONFIGREPO`, used for file operations after the repository is cloned

- `COMMUNITYREPO=yes`

Setting this variable will remove the default Proxmox enterprise repository and add the Proxmox community repository

- `ANSIBLE=yes`

Setting this variable will create a separate ansible user account with passwordless sudo privleges and add a pre-existing public key from the configuration files repository to their authorized keys

- `PASSTHROUGH=yes`

Setting this variable will enable the kernel modules and boot options required for PCI passthrough on Intel based systems; to use this option, one of the following two variables will need to be set in order to correctly modify the kernel commandline of the correct bootloader

- `INTEL_CPU=yes`

- `AMD_CPU=`

- `EFI=`

This variable determines what bootloader configuration is modified when setting up PCI passthrough, EFI installations use systemdboot

- `BIOS=yes`

This variable determines what bootloader configuration is modified when setting up PCI passthrough, BIOS installations use grub

- `export DEBIAN_FRONTEND=noninteractive`

Make sure that interactive prompts do not interrupt any system upgrades or package installations

### deploy-wrapper.sh

The ```deploy-wrapper.sh``` script is used to connect to the new Proxmox installation over ssh and run the ```proxmox-config.sh``` script.

It accepts 5 arguments:
1. The IP address of the Proxmox system to connect to

2. The root password of the system

3. The name of the user account to create

4. The password to set for the user account

5. The ssh key to authorize to access the new user account (optional)

