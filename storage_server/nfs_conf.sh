#! /bin/bash
#nfs를 사용하기 위해서는 nfs-utils 패키지기 설치되어 있어야 합니다.
yum -y install nfs-utils
mkdir /var/nfs_storage
# 아래설정중 ip address 와 괄호사이에 빈칸이 있으면 안됩니다.
echo "/var/nfs_storage  192.168.93.0/24(rw,no_root_squash)" > /etc/exports
systemctl restart nfs-server
systemctl enable nfs-server
systemctl stop firewalld > /dev/null
systemctl disable firewalld> /dev/null
