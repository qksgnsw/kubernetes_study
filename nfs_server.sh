#! /bin/bash
#nfs를 사용하기 위해서는 nfs-utils 패키지기 설치되어 있어야 합니다.
sudo apt update
sudo apt install -y nfs-kernel-server
sudo systemctl start nfs-server
sudo systemctl enable nfs-server
mkdir /var/nfs_storage
# 아래설정중 ip address 와 괄호사이에 빈칸이 있으면 안됩니다.
echo "/var/nfs_storage 192.168.31.0/24(rw,sync,no_subtree_check,no_root_squash)
" > /etc/exports
sudo exportfs -r
sudo exportfs -v
sudo ufw disable

