#! /bin/bash
# This script is only needed in master node
pod_network="10.244.0.0/16"
apiserver_network=$(hostname -i)
# configure pod network and for save token for cluster join
kubeadm init --pod-network-cidr=$pod_network --apiserver-advertise-address=$apiserver_network | tee /home/vagrant/kubeadm_init_output
grep -A 2 'kubeadm join' /home/vagrant/kubeadm_init_output > /home/vagrant/token

if [ $? -ne 0 ]
then
	echo "kubeadm init failed"
	echo "fix the errors and retry"
	exit
fi

# environment variable for using kubectl command
export KUBECONFIG=/etc/kubernetes/admin.conf

# download the CNI flannel file if it is not in the current directory
[ -f kube-flannel.yml ] || \
	wget https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# add eth1 interface card to the CNI flannel yaml file
#(This setting is neccssary if the first nic of the host is a nat type)
sed -e "/kube-subnet-mgr/a\        - --iface=eth1" kube-flannel.yml > modified-kube-flannel.yml
kubectl apply -f ./modified-kube-flannel.yml

if [ $? -ne 0 ]
then
	echo "CNI flannel installation failed"
	echo "fix the errors and retry"
	exit
fi

