k8s for begginer
---
2024/12/02

## 0. 목차
- [k8s for begginer](#k8s-for-begginer)
- [0. 목차](#0-목차)
- [1. `vagrant`로 가상머신 생성하기](#1-vagrant로-가상머신-생성하기)
  - [호스트 상세](#호스트-상세)
  - [가상머신 상세](#가상머신-상세)
  - [생성하기](#생성하기)
- [2. k8s 구축하기 with kubespray](#2-k8s-구축하기-with-kubespray)
  - [설치하기](#설치하기)
  - [kubespray로 삭제하기](#kubespray로-삭제하기)
  - [트러블슈팅](#트러블슈팅)
    - [ansible logging](#ansible-logging)
- [3. k8s 클러스터 아키텍처](#3-k8s-클러스터-아키텍처)
  - [Control-plane(Master)](#control-planemaster)
  - [Node(Worker)](#nodeworker)
- [4. k8s 주요 오브젝트와 컨트롤러](#4-k8s-주요-오브젝트와-컨트롤러)
  - [Namespace](#namespace)
  - [Pod](#pod)
  - [Service](#service)
    - [ClusterIP](#clusterip)
    - [NodePort](#nodeport)
    - [LoadBalancer](#loadbalancer)
  - [ReplicaSet](#replicaset)
  - [Deployment](#deployment)
    - [rollout](#rollout)
      - [history](#history)
      - [undo](#undo)
  - [Volume](#volume)
    - [hostPath](#hostpath)
    - [emptyDir](#emptydir)
    - [nfs](#nfs)
    - [PersistentVolume](#persistentvolume)
      - [PV-lifecycle](#pv-lifecycle)
    - [PersistentVolumeCliam](#persistentvolumecliam)
  - [Config](#config)
    - [Secret](#secret)
    - [ConfigMap](#configmap)
  - [Batch](#batch)
    - [Job](#job)
    - [CronJob](#cronjob)

## 1. `vagrant`로 가상머신 생성하기
`virtualBox` Version 7.0

### 호스트 상세
- OS: Mac
- cpu: 2.2 GHz 6코어 Intel Core i7
- mem: 16GB 2400 MHz DDR4
- storage: 256GB

### 가상머신 상세
|노드명|ip|cpu|mem|os|역할|nfs|
|---|---|---|---|---|---|---|
|nfs-storage-node|192.168.31.100|2|4096|Ubuntu2204|nfs 서버|/var/nfs_storage|
|kubespray-node|192.168.31.200|2|4096|Ubuntu2204|kubespray 실행|/var/nfs_storage|
|control-plane|192.168.31.10|2|8192|Ubuntu2204|k8s의 마스터|/var/nfs_storage|
|worker-node1|192.168.31.20|2|4096|Ubuntu2204|k8s의 worker|/var/nfs_storage|
|worker-node2|192.168.31.30|2|4096|Ubuntu2204|k8s의 worker|/var/nfs_storage|

### 생성하기
```sh
$ vagrant --version
Vagrant 2.4.1
```
```sh
# 이미지 미리 다운 받기
vagrant box add generic/ubuntu2204
# 이미지 확인
vagrant box list
# 가상머신 구축
vagrant up
```

## 2. k8s 구축하기 with [kubespray](https://kubespray.io/#/)
### 설치하기
생성이 완료되면 `kubespray-node`로 접속합니다
```sh
$ ssh vagrant@192.168.31.10 # password: vagrant
```
패키지를 업데이트하고 설치합니다.
```sh
$ sudo apt update
$ sudo apt install git python3 python3-pip -y
```
접속을 위해 키를 생성하고 배포합니다.  
`StrictHostKeyChecking` 옵션을 변경합니다.
```sh
$ ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<<y > /dev/null
$ ssh-copy-id 192.168.31.10
$ ssh-copy-id 192.168.31.20
$ ssh-copy-id 192.168.31.30
$ sudo sed -i '/StrictHostKeyChecking/c StrictHostKeyChecking no' /etc/ssh/ssh_config
# 접속확인
$ ssh -i ~/.ssh/id_rsa vagrant@192.168.31.10 'sudo hostname'
$ ssh -i ~/.ssh/id_rsa vagrant@192.168.31.20 'sudo hostname'
$ ssh -i ~/.ssh/id_rsa vagrant@192.168.31.30 'sudo hostname'
```
kubespray를 설치합니다.  
inventory_builder를 사용하는 버전으로 변경해야합니다.
```sh
git clone https://github.com/kubernetes-incubator/kubespray.git
cd kubespray/
pip install -r requirements.txt
# ansible path 등록
source ~/.profile
# 버전 변경 -> 2.26.0 버전 사용
git checkout f9ebd45
# sample 복제
cp -rfp inventory/sample/ inventory/mycluster/

pip3 install -r contrib/inventory_builder/requirements.txt
# k8s 타겟 노드들 선언
declare -a IPS=(192.168.31.10 192.168.31.20 192.168.31.30)
# 인벤토리 생성
CONFIG_FILE=inventory/mycluster/hosts.yml python3 contrib/inventory_builder/inventory.py ${IPS[@]}
```
```yaml
# 아래와 같이 수정. 
all:
  hosts:
    node1:
      ansible_host: 192.168.31.10
      ip: 192.168.31.10
      access_ip: 192.168.31.10
    node2:
      ansible_host: 192.168.31.20
      ip: 192.168.31.20
      access_ip: 192.168.31.20
    node3:
      ansible_host: 192.168.31.30
      ip: 192.168.31.30
      access_ip: 192.168.31.30
  children:
    kube_control_plane:
      hosts:
        node1:
    kube_node:
      hosts:
        node2:
        node3:
    etcd:
      hosts:
        node1:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}
```
```sh
# 이 부분은 확인해봐야 합니다.
$ sed -i 's/nf_conntrack_ipv4/nf_conntrack/' extra_playbooks/roles/kubernetes/node/tasks/main.yml
$ sed -i 's/nf_conntrack_ipv4/nf_conntrack/' roles/kubernetes/node/tasks/main.yml
```
복제한 폴더에 들어가 원하는 옵션을 변경합니다.
```sh
# helm enable
$ sed -i 's/^helm_enabled: false$/helm_enabled: true/' inventory/mycluster/group_vars/k8s_cluster/addons.yml
# metric server enable
$ sed -i 's/^metrics_server_enabled: false$/metrics_server_enabled: true/' inventory/mycluster/group_vars/k8s_cluster/addons.yml
```
```yaml
# inventory/mycluster/group_vars/k8s_cluster/addons.yml
helm_enabled: true # false에서 변경
metrics_server_enabled: true # false에서 변경
```
```yaml
# inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
# Choose network plugin (cilium, calico, kube-ovn, weave or flannel. Use cni for generic cni plugin)
# Can also be set to 'cloud', which lets the cloud provider setup appropriate routing
kube_network_plugin: calico # 원하는 플러그인으로 변경
```
kubespray를 실행합니다.
```sh
ansible-playbook -i inventory/mycluster/hosts.yml --become --become-user=root cluster.yml
```
위 구성으로 약 15분 내외의 시간이 소요됩니다.  
정상적으로 설치되었다면 아래와 같은 문구가 마지막에 출력됩니다.  
모든 노드의 failed가 0이어야 합니다.
```
PLAY RECAP ******************************************************************************************************************************************
node1                      : ok=698  changed=151  unreachable=0    failed=0    skipped=1119 rescued=0    ignored=6
node2                      : ok=420  changed=86   unreachable=0    failed=0    skipped=645  rescued=0    ignored=1
node3                      : ok=420  changed=86   unreachable=0    failed=0    skipped=645  rescued=0    ignored=1
```
마스터노드에 접속합니다.
```sh
$ ssh vagrant@192.168.31.10
```
root로 변경합니다.
```sh
$ sudo -i
```
k8s 상태를 확인합니다.
```sh
$ kubectl get nodes
```
아래와 같이 출력하면 정상입니다.
```sh
# 노드 상태 확인
$ kubectl get nodes
NAME    STATUS   ROLES           AGE     VERSION
node1   Ready    control-plane   6m      v1.30.4
node2   Ready    <none>          5m15s   v1.30.4
node3   Ready    <none>          5m15s   v1.30.4
# 노드 메트릭 확인(metric-server가 정상적으로 설치되었다면.)
$ kubectl top node
NAME    CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
node1   183m         10%    2491Mi          34%
node2   96m          5%     1606Mi          45%
node3   60m          3%     1573Mi          44%
# kube-system 확인
$ kubectl get pods -n kube-system
NAME                                      READY   STATUS    RESTARTS   AGE
calico-kube-controllers-b5f8f6849-688s5   1/1     Running   0          19m
calico-node-9gtrd                         1/1     Running   0          19m
calico-node-dttlx                         1/1     Running   0          19m
calico-node-tknr9                         1/1     Running   0          19m
coredns-776bb9db5d-hj4wf                  1/1     Running   0          18m
coredns-776bb9db5d-rqpcg                  1/1     Running   0          18m
dns-autoscaler-6ffb84bd6-5qvf4            1/1     Running   0          18m
kube-apiserver-node1                      1/1     Running   1          21m
kube-controller-manager-node1             1/1     Running   2          21m
kube-proxy-66kxp                          1/1     Running   0          20m
kube-proxy-8qrrh                          1/1     Running   0          20m
kube-proxy-hlh92                          1/1     Running   0          20m
kube-scheduler-node1                      1/1     Running   1          21m
metrics-server-795767c75-ptbsj            1/1     Running   0          17m
nginx-proxy-node2                         1/1     Running   0          20m
nginx-proxy-node3                         1/1     Running   0          20m
nodelocaldns-dm2n7                        1/1     Running   0          18m
nodelocaldns-kgdhr                        1/1     Running   0          18m
nodelocaldns-mgrsf                        1/1     Running   0          18m
```

### kubespray로 삭제하기

### 트러블슈팅
#### ansible logging
자세한 로그 보기
```sh
$ ansible [COMMAND] -vvv 
```
파이썬 패키지 확인하기
```sh
$ pip list
```


## 3. [k8s 클러스터 아키텍처](https://kubernetes.io/docs/concepts/architecture/)
![k8s 클러스터 아키텍처](./img/kubernetes-cluster-architecture.svg)

### Control-plane(Master)
클러스터의 전반적인 결정을 수행하고 클러스터 이벤트를 감지한다.  
클러스터 내의 어떤 노드에서든 동작할 수 있지만,  
일반적으로 클러스터와 동일한 노드 상에서 구동시킨다.  
- kube-apiserver
외/내무에서 관리자의 원격 명령을 받을 수 있는 컴포넌트.
- etcd
모든 클러스터 데이터를 저장하는 key-value 저장소.
- kube-scheduler
생성된 Pod를 노드에 할당해주는 컴포넌트. (이를 스케쥴링이라고 한다.)  
가장 최적화된 노드에 Pod 배치.
- controller-manager
컨트롤러 프로세스를 실행하는 컴포넌트.  
    - 노드 컨트롤러: 노드가 다운되었을 때 주의하고 대응하는 역할.  
    - 작업 컨트롤러: 일회성 작업을 나타내는 작업 개체를 관찰한 다음, 해당 작업을 완료할 때까지 실행하기 위해 포드를 생성.  
    - EndpointSlice 컨트롤러: 서비스와 Pod를 연결시켜 엔드포인트 오브젝트를 생성.
    - 서비스 계정 컨트롤러: 새 네임스페이스에 대한 기본 서비스 계정생성.    


### Node(Worker)
모든 노드에서 구동하며, k8s 런타임 환경을 제공.
- kubelet  
클러스터 안의 각 노드에서 구동하는 에이전트.  
Pod안의 Container가 구동하는지 확인.
- kube-proxy(optional)  
클러스터 안에 있는 각 노드에서 구동하는 네트워크 프록시.  
노드 안에서 네트워크 룰을 유지.  
k8s에서의 Service를 구현.  

## 4. k8s 주요 오브젝트와 컨트롤러
아래의 명령어로 오브젝트를 확인 할 수 있다.  
```sh
kubectl api-resources
```
### [Namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
싱글 클러스터에서의 리소스 그룹을 격리하는 메커니즘.  

```yaml
# basic/001.namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name:  testns
```
생성
```sh
kubectl apply -f basic/001.namespace.yaml 
namespace/testns created
```
생성 확인
```sh
$ kubectl get namespace
NAME              STATUS   AGE
default           Active   127m
kube-node-lease   Active   127m
kube-public       Active   127m
kube-system       Active   127m
testns            Active   74s
```
네임스페이스 변경
```sh
$ kubectl config set-context --current --namespace=testns
Context "kubernetes-admin@cluster.local" modified.
```
변경 확인
```sh
$ kubectl config current-context && kubectl config view --minify | grep namespace:
kubernetes-admin@cluster.local
    namespace: testns
```
### [Pod](https://kubernetes.io/docs/concepts/workloads/pods/)
쿠버네티스의 기본단위
```yaml
# basic/002.pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: apache
  labels:
    app: apache
spec:
  containers:
  - name: apache
    image: httpd:2.4
    resources:
      limits:
        memory: "128Mi"
        cpu: "500m"
    ports:
      - containerPort: 80
```
파드 생성
```sh
$ kubectl apply -f basic/002.pod.yaml 
pod/apache created
```
파드 확인
```sh
$ kubectl get pods -o wide
NAME     READY   STATUS    RESTARTS   AGE   IP            NODE    NOMINATED NODE   READINESS GATES
apache   1/1     Running   0          24s   10.233.71.2   node3   <none>           <none>
```
아파치 접속 확인.  
```sh
$ curl 10.233.71.2
<html><body><h1>It works!</h1></body></html>
```
### [Service](https://kubernetes.io/docs/concepts/services-networking/service/)
쿠버네티스에서 서비스는 네트워크 애플리케이션을 노출하는 방법.
#### [ClusterIP](https://kubernetes.io/docs/concepts/services-networking/service/#type-clusterip)
클러스터 사설 IP
#### [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport)
정적 IP를 노출
```yaml
# basic/003.service.yaml
apiVersion: v1
kind: Service
metadata:
  name: apache
spec:
  selector:
    app: apache
  ports:
  - port: 8001
    targetPort: 80
  type : NodePort 
```
서비스 생성
```sh
kubectl apply -f basic/003.service.yaml 
service/apache created
```
파드 확인
```sh
$ kubectl get pods -o wide --show-labels
NAME     READY   STATUS    RESTARTS   AGE     IP            NODE    NOMINATED NODE   READINESS GATES   LABELS
apache   1/1     Running   0          2m48s   10.233.71.4   node3   <none>           <none>            app=apache
# pod ip로 접속
$ curl 10.233.71.4
<html><body><h1>It works!</h1></body></html>
```
서비스 확인(NodePort)
```sh
$ kubectl get service -o wide
NAME     TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE     SELECTOR
apache   NodePort   10.233.46.196   <none>        8001:32455/TCP   2m33s   app=apache
# 클러스터 ip로 접속
curl 10.233.46.196:8001
<html><body><h1>It works!</h1></body></html>
```
외부에서의 접속
```sh
$ curl 192.168.31.10:32455
<html><body><h1>It works!</h1></body></html>
```
#### [LoadBalancer](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer)

외부 로드밸런서를 사용하여 외부로 노출.
### [ReplicaSet](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
원하는 파드의 갯수를 안정적으로 유지.
```yaml
# basic/004.replicaset.yaml
apiVersion: apps/v1
kind: ReplicaSet # 파드를 만듬
metadata:
  name: apahce-replica # 파드의 이름
  # labels:
  #   app: apahce-replica
spec:
  replicas: 5 # 0 으로 변경하여 비활성화
  selector:
    matchLabels:
      app: apahce-replica # template.metadata.labels.[key] 와 맞아야함.
  # 어떤 형태로 만들 것인가.
  template:
    metadata:
      labels:
        app: apahce-replica # selector.matchLabels.[key] 와 맞아야함.
    spec:
      containers:
        - name: ac
          image: httpd:2.4
          ports:
            - containerPort: 80
```
레플리카셋 생성
```sh
$ kubectl apply -f basic/004.replicaset.yaml 
replicaset.apps/apahce-replica created
```
파드 확인
```sh
$ kubectl get pods -o wide --show-labels
NAME                   READY   STATUS    RESTARTS   AGE   IP               NODE    NOMINATED NODE   READINESS GATES   LABELS
apahce-replica-5xkdn   1/1     Running   0          64s   10.233.75.3      node2   <none>           <none>            app=apahce-replica
apahce-replica-f8gpf   1/1     Running   0          64s   10.233.71.6      node3   <none>           <none>            app=apahce-replica
apahce-replica-hs468   1/1     Running   0          64s   10.233.102.131   node1   <none>           <none>            app=apahce-replica
apahce-replica-pdvnh   1/1     Running   0          64s   10.233.75.4      node2   <none>           <none>            app=apahce-replica
apahce-replica-qrp4w   1/1     Running   0          64s   10.233.71.5      node3   <none>           <none>            app=apahce-replica
```

### [Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
애플리케이션 워크로드를 구동하기 위한 파드 집합을 관리한다.
```yaml
# basic/005.deployment.yaml  
apiVersion: apps/v1
kind: Deployment # 레플리카셋을 만듬
metadata:
  name: nginx-deployment
spec:
  replicas: 10
  selector:
    matchLabels:
      app: nginx-deployment # template.metadata.labels.[key] 와 맞아야함.
  # strategy:
  #   type: Recreate # 일괄 업데이트
  strategy:
    type: RollingUpdate # 롤링업데이트
    rollingUpdate:
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: nginx-deployment # selector.matchLabels.[key] 와 맞아야함.
    spec:
      containers:
      - name: nc
        image: nginx:1.18
        resources:
          limits:
            memory: "128Mi"
            cpu: "100m"
        ports:
        - containerPort: 80
```
Deployment 생성
```sh
$ kubectl apply -f basic/005.deployment.yaml 
deployment.apps/nginx-deployment created
```
파드 확인
```sh
$ kubectl get pods -o wide --show-labels
NAME                               READY   STATUS    RESTARTS   AGE   IP               NODE    NOMINATED NODE   READINESS GATES   LABELS
nginx-deployment-c69d65ccd-2k4zc   1/1     Running   0          48s   10.233.71.9      node3   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-7bh9w   1/1     Running   0          48s   10.233.71.10     node3   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-8pz4n   1/1     Running   0          48s   10.233.75.6      node2   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-9cwn5   1/1     Running   0          48s   10.233.102.132   node1   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-gntr4   1/1     Running   0          48s   10.233.71.8      node3   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-hh262   1/1     Running   0          48s   10.233.75.7      node2   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-kxbnx   1/1     Running   0          48s   10.233.102.133   node1   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-lzgx8   1/1     Running   0          48s   10.233.75.5      node2   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-tnrgn   1/1     Running   0          48s   10.233.102.134   node1   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-tt7nf   1/1     Running   0          48s   10.233.71.7      node3   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
```
레플리카셋 확인.  
디플로이먼트는 레플리카셋을 생성한다.
```sh
$ kubectl get replicasets.apps nginx-deployment-c69d65ccd 
NAME                         DESIRED   CURRENT   READY   AGE
nginx-deployment-c69d65ccd   10        10        10      91s
```
#### [rollout](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/)
리소스의 rollout을 관리.  
유효한 리소스  
- deployments
- daemonsets
- statefulsets
##### [history](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_history/)
이전 rollout revision과 설정을 보여줌.
```yaml
# basic/005.deployment.yaml  
image: nginx:1.19 # nginx:1.18 에서 버전 변경
```
```sh
$ kubectl apply -f basic/005.deployment.yaml 
deployment.apps/nginx-deployment configured
```
```sh
$ kubectl get pods -o wide --show-labels
NAME                               READY   STATUS              RESTARTS   AGE    IP               NODE    NOMINATED NODE   READINESS GATES   LABELS
nginx-deployment-844c97897-74rhv   0/1     ContainerCreating   0          5s     <none>           node2   <none>           <none>            app=nginx-deployment,pod-template-hash=844c97897
nginx-deployment-844c97897-gk68k   0/1     ContainerCreating   0          5s     <none>           node3   <none>           <none>            app=nginx-deployment,pod-template-hash=844c97897
nginx-deployment-844c97897-pzp4g   0/1     ContainerCreating   0          5s     <none>           node1   <none>           <none>            app=nginx-deployment,pod-template-hash=844c97897
nginx-deployment-844c97897-wlg6r   0/1     ContainerCreating   0          4s     <none>           node2   <none>           <none>            app=nginx-deployment,pod-template-hash=844c97897
nginx-deployment-c69d65ccd-2k4zc   1/1     Running             0          6m4s   10.233.71.9      node3   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-8pz4n   1/1     Running             0          6m4s   10.233.75.6      node2   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-9cwn5   1/1     Running             0          6m4s   10.233.102.132   node1   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-gntr4   1/1     Running             0          6m4s   10.233.71.8      node3   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-hh262   1/1     Running             0          6m4s   10.233.75.7      node2   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-kxbnx   1/1     Running             0          6m4s   10.233.102.133   node1   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-lzgx8   1/1     Running             0          6m4s   10.233.75.5      node2   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-tnrgn   1/1     Running             0          6m4s   10.233.102.134   node1   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
nginx-deployment-c69d65ccd-tt7nf   1/1     Running             0          6m4s   10.233.71.7      node3   <none>           <none>            app=nginx-deployment,pod-template-hash=c69d65ccd
```
업데이트 확인
```sh
$ kubectl describe pod nginx-deployment-844c97897-74rhv | grep Image:
    Image:          nginx:1.19
```
롤아웃 히스토리 확인
```sh
$ kubectl rollout history deployment nginx-deployment 
deployment.apps/nginx-deployment 
REVISION  CHANGE-CAUSE
1         <none> # nginx:1.18
2         <none> # nginx:1.19
```
##### [undo](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_undo/)
이전 rollout으로의 롤백
```sh
$ kubectl rollout undo deployment nginx-deployment --to-revision=1
deployment.apps/nginx-deployment rolled back
```
rollout 히스토리 확인
```sh
$ kubectl rollout history deployment nginx-deployment 
deployment.apps/nginx-deployment 
REVISION  CHANGE-CAUSE
2         <none>
3         <none>
```
롤백된 파드의 nginx 버전 확인
```sh
$ kubectl describe pod nginx-deployment-c69d65ccd-6x9nk | grep Image:
    Image:          nginx:1.18
```
### [Volume](https://kubernetes.io/docs/concepts/storage/volumes/)

#### [hostPath](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath)
호스트 노드의 파일시스팀을 파드 안으로 마운트.  

```sh
mkdir -p basic/hostpath
echo welcome > basic/hostpath/index.html
```
index.html 파일 확인
```sh
cat basic/hostpath/index.html 
welcome
```
테스트할 노드의 레이블을 확인.  
여기서는 `kubernetes.io/hostname: node1` 을 사용함.
```sh
$ kubectl get nodes --show-labels
NAME    STATUS   ROLES           AGE     VERSION   LABELS
node1   Ready    control-plane   3h31m   v1.30.4   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=node1,kubernetes.io/os=linux,node-role.kubernetes.io/control-plane=,node.kubernetes.io/exclude-from-external-load-balancers=
node2   Ready    <none>          3h30m   v1.30.4   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=node2,kubernetes.io/os=linux
node3   Ready    <none>          3h30m   v1.30.4   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=node3,kubernetes.io/os=linux
```
```yaml
# basic/006.hostpath.yaml
apiVersion: v1
kind: Pod
metadata:
  name: apache
  labels:
    name: apache
spec:
  # 테스트하는 곳이 node1이므로 해당 노드로 고정하는 구문
  nodeSelector:
    kubernetes.io/hostname: node1
  containers:
  - name: apache
    image: httpd:2.4
    resources:
      limits:
        memory: "128Mi"
        cpu: "100m"
    ports:
      - containerPort: 80
    volumeMounts:
    - mountPath: /usr/local/apache2/htdocs
      name: hostpath-volume # 일치해야함
      readOnly: true
  volumes:
  - name: hostpath-volume # 일치해야함
    hostPath:
      path: /root/kubernetes/basic/hostpath # 폴더 경로 본인에게 맞게 확인
      # type: Directory 
      type: DirectoryOrCreate

# volumes.name.hostPath.path를 
# containers.name.volumeMounts.mountPath로 임포트함
```
```sh
kubectl apply -f basic/006.hostpath.yaml 
pod/apache created
```
파드 상태 및 ip 확인
```sh
kubectl get pods -o wide
NAME     READY   STATUS    RESTARTS   AGE   IP               NODE    NOMINATED NODE   READINESS GATES
apache   1/1     Running   0          46s   10.233.102.141   node1   <none>           <none>
```
hostpath에 존재하는 index.html로 서빙되는지 확인.
```sh
$ curl 10.233.102.141
welcome
```

#### [emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir)
포드가 노드에 할당될 때 볼륨이 생성.  
Pod의 모든 컨테이너는 emptyDir 볼륨에서 동일한 파일을 읽고 쓸 수 있음.  
해당 볼륨은 각 컨테이너의 동일하거나 다른 경로에 마운트될 수 있음.  
Pod가 노드에서 제거되면, emptyDir의 데이터는 영구적으로 삭제
```yaml
# basic/007.emptydir.yaml
apiVersion: v1
kind: Pod
metadata:
  name: redis
spec:
  containers:
    - name: redis
      image: redis
      volumeMounts:
        - name: redis-storage
          mountPath: /data/redis
  volumes:
    - name: redis-storage
      emptyDir: {}
```
파드 생성하기
```sh
$ kubectl apply -f basic/007.emptydir.yaml 
pod/redis created

```
해당 파드 접속하기
```sh
$ kubectl exec -it pods/redis -- /bin/bash
root@redis:/data#
```
마운트된 폴더에서 파일 생성
```sh
root@redis:/data# cd redis/
root@redis:/data/redis# echo redis >> myredis.txt
root@redis:/data/redis# ls -al
total 12
drwxrwxrwx 2 redis root  4096 Nov 29 07:08 .
drwxr-xr-x 3 redis redis 4096 Nov 29 07:06 ..
-rw-r--r-- 1 root  root     6 Nov 29 07:08 myredis.txt
```
파일 확인해보기  
***주의할점: 해당 파드가 위치하는 노드에서 검색해야 한다.***
```sh
$ find / -name myredis.txt
/var/lib/kubelet/pods/9fb605d7-a24b-4258-8091-718e197e9041/volumes/kubernetes.io~empty-dir/redis-storage/myredis.txt

$ cat /var/lib/kubelet/pods/9fb605d7-a24b-4258-8091-718e197e9041/volumes/kubernetes.io~empty-dir/redis-storage/myredis.txt
redis
```

#### [nfs](https://kubernetes.io/docs/concepts/storage/volumes/#nfs)
nfs 볼륨은 기존 NFS(네트워크 파일 시스템) 공유를 Pod에 마운트할 수 있도록 함.

nfs 마운트 확인
```sh
$ df -h
...
192.168.31.100:/var/nfs_storage     62G  5.1G   54G   9% /var/nfs_storage
...

$ showmount -e 192.168.31.100
Export list for 192.168.31.100:
/var/nfs_storage 192.168.31.0/24
```
nfs에 index.html 생성
```sh
echo "welcom to nfs_apache" > /var/nfs_storage/index.html
```
위 파일 확인 
```sh
# nfs에 연결된 다른 노드에서도 확인.
$ cat /var/nfs_storage/index.html
welcom to nfs_apache
```
```yaml
# 아래와 같이 nfs 설정을 해놓은 상태임
# 192.168.31.100:/var/nfs_storage     62G  5.2G   54G   9% /mnt/nfs_storage

# basic/008.nfs.yaml
apiVersion: apps/v1
kind: ReplicaSet # 파드를 만듬
metadata:
  name: apahce-pod-replica # 파드의 이름
  # labels:
  #   app: apahce-replica
spec:
  replicas: 10 # 0 으로 변경하여 삭제
  selector:
    matchLabels:
      app: apahce-replica # template.metadata.labels.[key] 와 맞아야함.
  # 어떤 형태로 만들 것인가.
  template:
    metadata:
      labels:
        app: apahce-replica # selector.matchLabels.[key] 와 맞아야함.
    spec:
      containers:
        - name: ac
          image: httpd:2.4
          ports:
            - containerPort: 80
          volumeMounts:
          - mountPath: /usr/local/apache2/htdocs
            name: nfs-volume # 일치해야함
            # 당연히 container 안에서 수정 안됨
            # bash: index.html: Read-only file system
            readOnly: true 
      volumes:
      - name: nfs-volume # 일치해야함
        nfs:
          path: /var/nfs_storage
          server: 192.168.31.100 
    
# nfs 볼륨은 k8s에서 직접 연결하는 것 같지만
# 실제로는 호스트에서 연결이 되어있어야 한다.
```
파드 생성 확인
```sh
$ kubectl get pods -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP               NODE    NOMINATED NODE   READINESS GATES
apahce-pod-replica-22blr   1/1     Running   0          15s   10.233.71.22     node3   <none>           <none>
apahce-pod-replica-288jj   1/1     Running   0          15s   10.233.71.23     node3   <none>           <none>
apahce-pod-replica-6x2bh   1/1     Running   0          15s   10.233.75.14     node2   <none>           <none>
apahce-pod-replica-96pc7   1/1     Running   0          15s   10.233.102.144   node1   <none>           <none>
apahce-pod-replica-crpqj   1/1     Running   0          15s   10.233.75.16     node2   <none>           <none>
apahce-pod-replica-dt7gw   1/1     Running   0          15s   10.233.102.143   node1   <none>           <none>
apahce-pod-replica-f29pf   1/1     Running   0          15s   10.233.71.21     node3   <none>           <none>
apahce-pod-replica-p22g5   1/1     Running   0          15s   10.233.75.15     node2   <none>           <none>
apahce-pod-replica-psln8   1/1     Running   0          15s   10.233.102.142   node1   <none>           <none>
apahce-pod-replica-t8jmw   1/1     Running   0          15s   10.233.71.20     node3   <none>           <none>
```
nfs에 속한 index.html 파일이 제대로 서빙되는지 확인
```sh
# node1
$ curl 10.233.102.144
welcom to nfs_apache
# node2
$ curl 10.233.75.14
welcom to nfs_apache
# node3
$ curl 10.233.71.21
welcom to nfs_apache
```
파일 수정 테스트
```sh
$ echo "welcom to nfs_apache_update" > /var/nfs_storage/index.html
$ cat /var/nfs_storage/index.html
welcom to nfs_apache_update
```
정상적으로 업데이트 되었는지 확인
```sh
$ curl 10.233.102.144
welcom to nfs_apache_update
$ curl 10.233.75.14
welcom to nfs_apache_update
$ curl 10.233.71.21
welcom to nfs_apache_update
```

#### [PersistentVolume](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
영구 스토리지 볼륨을 설정하기 위한 클러스터 리소스.  

```yaml
# 009.pb-nfs.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
  labels:
    volume: nfs-pv-volume # pvc가 호출할 때의 식별자가 됨
spec:
  capacity:
    storage: 5Gi # Size와 관련되어있음.
  # volumeMode: Filesystem
  accessModes:
    - ReadWriteMany # ReadWriteOnce, ReadWriteMany, ReadOnlyMany
  persistentVolumeReclaimPolicy: Retain # Retain, Delete
  # storageClassName: slow
  # mountOptions:
  #   - hard # hard, soft
  #   - nfsvers=4.1
  nfs:
    path: /var/nfs_storage
    server: 192.168.31.100
    readOnly: false
```
##### [PV-lifecycle](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#lifecycle-of-a-volume-and-claim)
- Provisioning
  - 볼륨으로 사용하기 위한 물리적인 공간 확보
  - 디스크 공간을 확보하여 PV를 생성.
  - 동적와 정적이 있음.
- Binding
  - PV 와 PVC를 연결하는 단계
  - PVC는 여러개의 PV에 바인딩 될 수 없음.
- Using
  - PVC는 파드에 설정.
  - 해당 파드는 PVC를 통해 볼륨을 인식.
  - 파드를 유지하는 동안 지속적으로 사용 가능하며 시스템에서 제거 불가.
- [Reclaiming](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#retain)
  - 정책
    - Retain(default): 데이터 보존
    - Delete: 스토리지 볼륨 삭제
    - Recycle(deprecated)
#### [PersistentVolumeCliam](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims)
유저가 PV를 사용하기 위한 요청 객체.

### Config
#### Secret
#### ConfigMap

### Batch
#### Job
#### CronJob