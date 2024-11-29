#! /bin/bash
sudo echo -n "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
" > /etc/hosts
sudo echo "192.168.31.10   control-plane" >> /etc/hosts
sudo echo "192.168.31.20   worker-node1" >> /etc/hosts
sudo echo "192.168.31.30   worker-node1" >> /etc/hosts
