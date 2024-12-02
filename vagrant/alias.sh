sudo echo "alias ka='kubectl apply -f' " >> /root/.bashrc
sudo echo "alias kd='kubectl delete -f' " >> /root/.bashrc
sudo echo "alias chns='kubectl config set-context --current --namespace'" >> /root/.bashrc
sudo echo "alias kgp='kubectl get pods -o wide' " >> /root/.bashrc
sudo echo "alias kgs='kubectl get services -o wide' " >> /root/.bashrc
sudo echo "alias kga='kubectl get all -o wide'" >> /root/.bashrc
sudo echo "source <(helm completion bash) " >> /root/.bashrc
sudo echo "source <(kubectl completion bash)" >> /root/.bashrc