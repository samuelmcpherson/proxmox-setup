#!/bin/bash

ADDRESS=$1

PASSWORD=$2

USERPASS=$3

USER=oslander

./ssh-auto-enter-password.sh "$PASSWORD" scp -o StrictHostKeyChecking=no ./proxmox-config.sh root@"$ADDRESS":/root/proxmox-config.sh

./ssh-auto-enter-password.sh "$PASSWORD" ssh -o StrictHostKeyChecking=no root@"$ADDRESS" /root/proxmox-config.sh "$USERPASS"

./ssh-auto-enter-password.sh "$USERPASS" ssh-copy-id "$USER"@"$ADDRESS"