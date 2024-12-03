#/bin/bash
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
sed -i -e 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd
