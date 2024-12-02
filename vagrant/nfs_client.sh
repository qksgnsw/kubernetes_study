#! /bin/bash
sudo apt update
sudo apt install -y nfs-common
sudo mkdir -p /var/nfs_storage
sudo mount 192.168.31.100:/var/nfs_storage /var/nfs_storage
sudo echo "192.168.31.100:/var/nfs_storage  /mnt/nfs_storage  nfs  defaults  0  0" >> /etc/fstab