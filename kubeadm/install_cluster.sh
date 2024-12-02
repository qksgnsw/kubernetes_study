### bash script for install kubernetes cluster(kubernetes 1.29)

#Set the time zone to local time and set the exact time
timedatectl set-timezone Asia/Seoul

yum install -y yum-utils
modprobe overlay
modprobe br_netfilter
yum install -y iproute-tc

cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
# apply the 99-kubernetes-cri.conf file immediately
sysctl --system

# disable firewall
systemctl disable firewalld
systemctl stop firewalld

yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

yum install -y containerd.io

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

# disable selinux
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF


yum install -y kubelet kubeadm kubectl \
--disableexcludes=kubernetes

systemctl enable --now kubelet

# disable swap space
swapoff -a
sed -e '/swap/s/^/#/' -i /etc/fstab

# add cluster nodes in the hosts file
tee /etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
:1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOF

echo "192.168.91.10   control-plane" >> /etc/hosts
echo "192.168.91.20   worker-node1" >> /etc/hosts
echo "192.168.91.30   worker-node2" >> /etc/hosts
