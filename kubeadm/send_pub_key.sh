#! /bin/bash
# transfer ssh public key and token to worker nodes
user=vagrant
password=vagrant
######

# array variable declaration
host_ip=$(hostname -i)
declare -a worker_nodes  
worker_nodes=($(grep -v ${host_ip} /etc/hosts | awk '!/localhost/{print $1}'))
ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<<y > /dev/null
sudo sed -i '/StrictHostKeyChecking/c StrictHostKeyChecking no' /etc/ssh/ssh_config

# if not installed package sshpass and then install package sshpass
#rpm -qi sshpass > /dev/null 2>&1 || sudo yum -y install sshpass
echo "install sshpass"
rpm -qi sshpass > /dev/null 2>&1 || \
sudo yum install -y sshpass

for i in ${worker_nodes[*]}
do
    sshpass -p $password ssh-copy-id ${user}@${i} > /dev/null
	scp /home/vagrant/token ${user}@${i}:/home/vagrant/
	ssh ${user}@${i} 'chmod u+x /home/vagrant/token'
	ssh ${user}@${i} 'sudo /home/vagrant/token > /dev/null 2>&1' && join="success"
	if [ "$join" == "success" ]
	then	
		echo "$i cluser join successful"
	else
		echo "$i cluster join failed"
	fi
done		
