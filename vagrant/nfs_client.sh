#! /bin/bash
sudo apt update
sudo apt install -y nfs-common
sudo mkdir -p /var/nfs_storage
sudo mount 192.168.31.100:/var/nfs_storage /var/nfs_storage
sudo echo "192.168.31.100:/var/nfs_storage  /mnt/nfs_storage  nfs  defaults  0  0" >> /etc/fstab
sudo ufw disable
sudo sysctl -w net.ipv4.ip_forward=1
sudo net.bridge.bridge-nf-call-ip6tables = 1 
sudo net.bridge.bridge-nf-call-iptables = 1
sudo swapoff -a
sudo sed -e '/swap/s/^/#/' -i /etc/fstab