#!/bin/bash

ADDRESS=$1
# IP address or hostname of the device to connect to 

PASSWORD=$2
# Root password of the device to connect to

USERPASS=$3
# Password to set for the main user account created by the configuration script

PUBLIC_KEY=$4
# Optional: This variable is used to specify the public key to add to authorized_keys file for the user account created 

USER=oslander
# The main user account to create on the configured system

# ssh auto-enter-password.sh is a script that uses the expect package to automatically enter a password for ssh authentication
./ssh-auto-enter-password.sh "$PASSWORD" scp -o StrictHostKeyChecking=no ./proxmox-config.sh root@"$ADDRESS":/root/proxmox-config.sh


./ssh-auto-enter-password.sh "$PASSWORD" ssh -o StrictHostKeyChecking=no root@"$ADDRESS" /root/proxmox-config.sh "$USER $USERPASS"
# Runs the configuration script with the username of the main user account to create and the password to set for this account

# Checks is a public key file was provided in the optional fourth argument
if [[ -n "$PUBLIC_KEY" ]]
then
    ./ssh-auto-enter-password.sh "$USERPASS" ssh-copy-id -i "$PUBLIC_KEY" "$USER"@"$ADDRESS"
    # If a key was provided, add that key to the authorized_keys file for the main user account created by the configuration script
elif [[ -z "$PUBLIC_KEY" ]]
then
    ./ssh-auto-enter-password.sh "$USERPASS" ssh-copy-id "$USER"@"$ADDRESS"
    # If a key was not provided, add your current system's default key to the authorized_keys file for the main user account created by the configuration script
fi