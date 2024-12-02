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
  - [TODO: 삭제하기](#todo-삭제하기)
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
    - [TODO: LoadBalancer](#todo-loadbalancer)
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
      - [PV + PVC + POD](#pv--pvc--pod)
  - [Batch](#batch)
    - [Job](#job)
    - [CronJob](#cronjob)
  - [Config](#config)
    - [ConfigMap](#configmap)
    - [Secret](#secret)
- [5. wordpress + mysql](#5-wordpress--mysql)
- [6. Metallb](#6-metallb)
  - [Why?](#why)
  - [설치](#설치)
  - [L2 모드로 구성하기](#l2-모드로-구성하기)
  - [테스트](#테스트)
- [7. TODO: Role](#7-todo-role)
- [8. Helm](#8-helm)
  - [설치](#설치-1)
  - [사용법](#사용법)
    - [기본 명령어](#기본-명령어)
    - [기본 사용 예제](#기본-사용-예제)
- [9. Monitoring with Prometheus](#9-monitoring-with-prometheus)

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

### TODO: 삭제하기

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
#### TODO: [LoadBalancer](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer)

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
# basic/009.pv-nfs.yaml
# 해당 예제는 nfs를 사용.
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
pv 생성
```sh
kubectl apply -f basic/009.pv-nfs.yaml 
persistentvolume/nfs-pv created
```
pv 확인
- `RWO` - ReadWriteOnce
- `ROX` - ReadOnlyMany
- `RWX` - ReadWriteMany
```sh
$ kubectl get persistentvolume
NAME     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
nfs-pv   5Gi        RWX            Retain           Available                          <unset>                          34s
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
```yaml
# basic/010.pv-nfs.yaml 
# basic/009.pv-nfs.yaml 을 실행하여 pv를 생성한 상태.
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  selector:
    matchLabels:
      volume: nfs-pv-volume # pv의 metadata의 labels
  resources:
    requests:
      storage: 1Gi
  # volumeMode: Filesystem
  accessModes:
    - ReadWriteMany # ReadWriteOnce, ReadWriteMany, ReadOnlyMany
```
pvc 생성
```sh
kubectl apply -f basic/010.pvc-nfs.yaml 
persistentvolumeclaim/nfs-pvc created
```
pvc 생성 확인
```sh
$ kubectl get persistentvolumeclaims 
NAME      STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
nfs-pvc   Bound    nfs-pv   5Gi        RWX                           <unset>                 12s
```
pv의 status가 Available에서 Bound로 변경된 것을 확인.
```sh
$ kubectl get persistentvolume
NAME     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
nfs-pv   5Gi        RWX            Retain           Bound    default/nfs-pvc                  <unset>                          5m18s
```

##### PV + PVC + POD
```yaml
# basic/011.apache-pvc-replicas.yaml
# 009.pv-nfs.yaml을 실행하여 성공한 상태
# 010.pvc-nfs.yaml을 실행하여 성공한 상태 
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
        # 011.apache-nfs-replicas.yaml와 비교해보면 알 수 있음.
        # 012.pv-nfs.yam 참조
        persistentVolumeClaim: 
          claimName: nfs-pvc
```
생성
```sh
$ kubectl apply -f basic/011.apache-pvc-replicas.yaml 
replicaset.apps/apahce-pod-replica created
```
생성 중
```sh
$ kubectl get pods -o wide
NAME                       READY   STATUS              RESTARTS   AGE   IP            NODE    NOMINATED NODE   READINESS GATES
apahce-pod-replica-24xjg   0/1     ContainerCreating   0          32s   <none>        node3   <none>           <none>
apahce-pod-replica-8zmtt   1/1     Running             0          32s   10.233.71.2   node3   <none>           <none>
apahce-pod-replica-8zvrc   1/1     Running             0          32s   10.233.71.4   node3   <none>           <none>
apahce-pod-replica-9j965   0/1     ContainerCreating   0          32s   <none>        node2   <none>           <none>
apahce-pod-replica-glt7n   1/1     Running             0          32s   10.233.75.4   node2   <none>           <none>
apahce-pod-replica-kd784   1/1     Running             0          32s   10.233.75.6   node2   <none>           <none>
apahce-pod-replica-mx9hv   1/1     Running             0          32s   10.233.75.3   node2   <none>           <none>
apahce-pod-replica-qt62x   1/1     Running             0          32s   10.233.71.3   node3   <none>           <none>
apahce-pod-replica-s9ccz   0/1     ContainerCreating   0          32s   <none>        node3   <none>           <none>
apahce-pod-replica-snjcn   1/1     Running             0          32s   10.233.75.5   node2   <none>           <none>
```
모든 파드 생성 완료 후 테스트
```sh
$ curl 10.233.71.5
welcom to nfs_apache
$ curl 10.233.71.2
welcom to nfs_apache
```
파일 수정 테스트
```sh
$ echo "welcom to nfs_apache_update_1" > /var/nfs_storage/index.html
$ cat /var/nfs_storage/index.html
welcom to nfs_apache_update_1
$ curl 10.233.71.5
$ curl 10.233.71.2
welcom to nfs_apache_update_1
welcom to nfs_apache_update_1
```
### Batch
#### [Job](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
작업은 완료된 다음 중단되는 일회성 작업
```yaml
# basic/012.job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  template:
    spec:
      containers:
      - name: pi
        image: perl:5.34.0
        command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never
  backoffLimit: 4
```
생성
```sh
$ kubectl apply -f basic/012.job.yaml 
job.batch/pi created
```
확인
```sh
$ kubectl get jobs.batch pi 
NAME   STATUS     COMPLETIONS   DURATION   AGE
pi     Complete   1/1           84s        2m8s
```
로그 확인
```sh
$ kubectl logs jobs/pi
3.1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679821480865132823066470938446095505822317253594081284811174502841027019385211055596446229489549303819644288109756659334461284756482337867831652712019091456485669234603486104543266482133936072602491412737245870066063155881748815209209628292540917153643678925903600113305305488204665213841469519415116094330572703657595919530921861173819326117931051185480744623799627495673518857527248912279381830119491298336733624406566430860213949463952247371907021798609437027705392171762931767523846748184676694051320005681271452635608277857713427577896091736371787214684409012249534301465495853710507922796892589235420199561121290219608640344181598136297747713099605187072113499999983729780499510597317328160963185950244594553469083026425223082533446850352619311881710100031378387528865875332083814206171776691473035982534904287554687311595628638823537875937519577818577805321712268066130019278766111959092164201989380952572010654858632788659361533818279682303019520353018529689957736225994138912497217752834791315155748572424541506959508295331168617278558890750983817546374649393192550604009277016711390098488240128583616035637076601047101819429555961989467678374494482553797747268471040475346462080466842590694912933136770289891521047521620569660240580381501935112533824300355876402474964732639141992726042699227967823547816360093417216412199245863150302861829745557067498385054945885869269956909272107975093029553211653449872027559602364806654991198818347977535663698074265425278625518184175746728909777727938000816470600161452491921732172147723501414419735685481613611573525521334757418494684385233239073941433345477624168625189835694855620992192221842725502542568876717904946016534668049886272327917860857843838279679766814541009538837863609506800642251252051173929848960841284886269456042419652850222106611863067442786220391949450471237137869609563643719172874677646575739624138908658326459958133904780275901
```
#### [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
CronJob은 반복되는 일정에 따라 `Job`을 생성
```yaml
# basic/013.cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "* * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox:1.28
            imagePullPolicy: IfNotPresent
            command:
            - /bin/sh
            - -c
            - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure
```
생성
```sh
$ kubectl apply -f basic/013.cronjob.yaml 
cronjob.batch/hello created
```
확인
```sh
$ kubectl get cronjobs.batch hello 
NAME    SCHEDULE    TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
hello   * * * * *   <none>     False     0        <none>          28s
```
로그 확인
```sh
$ kubectl logs jobs/hello-28885066
Mon Dec  2 01:46:09 UTC 2024
Hello from the Kubernetes cluster
```

### [Config](https://kubernetes.io/docs/concepts/configuration/)
#### [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/)
환경에 따라 다르거나 자주 변경되는 설정 옵션을 오브젝트로 분리해서 관리
```yaml
# basic/014/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myconfigmap
data:
  testkey: testvalue
```
생성
```sh
$ kubectl apply -f basic/014.configmap.yaml 
configmap/myconfigmap created
```
확인
```sh
$ kubectl describe configmaps myconfigmap 
Name:         myconfigmap
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
testkey:
----
testvalue

BinaryData
====

Events:  <none>
```
#### [Secret](https://kubernetes.io/docs/concepts/configuration/secret/)
configmap 오브젝트와 비슷하지만 보안에 민감한 설정을 관리하기 위함
```yaml
# basic/015.secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  password: cGFzc3dvcmQ= # echo -n password | base64
```
생성
```sh
$ kubectl apply -f basic/015.secret.yaml 
secret/mysecret created
```
확인
```sh
$ kubectl describe secrets mysecret 
Name:         mysecret
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
password:  8 bytes
```


## 5. wordpress + mysql

스토리지로 사용할 폴더 생성
```sh
$ mkdir /var/nfs_storage/db_storage
$ mkdir /var/nfs_storage/wp_storage
```
생성 확인
```sh
$ ls -al /var/nfs_storage/
total 20
drwxr-xr-x  4 root root 4096 Dec  2 02:13 .
drwxr-xr-x 14 root root 4096 Dec  2 00:18 ..
drwxr-xr-x  2 root root 4096 Dec  2 02:11 db_storage
-rw-r--r--  1 root root   30 Dec  2 01:31 index.html
drwxr-xr-x  2 root root 4096 Dec  2 02:13 wp_storage
```
폴더 진입
```sh
cd example
```
생성
```sh
$ kubectl apply -f .
configmap/mysqlconfig created
persistentvolume/mysql-pv created
persistentvolumeclaim/mysql-volumeclaim created
service/mysql created
deployment.apps/mysql created
secret/mysqlsecret created
persistentvolume/wp-pv created
persistentvolumeclaim/wp-pvc created
service/wordpress created
deployment.apps/wordpress created
```
확인
```sh
$ kubectl get all -o wide
NAME                             READY   STATUS    RESTARTS   AGE   IP             NODE    NOMINATED NODE   READINESS GATES
pod/mysql-745d4579b9-789lb       1/1     Running   0          29s   10.233.71.29   node3   <none>           <none>
pod/wordpress-66f4cf6f68-xv9mw   1/1     Running   0          29s   10.233.75.10   node2   <none>           <none>

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE   SELECTOR
service/kubernetes   ClusterIP   10.233.0.1      <none>        443/TCP        86m   <none>
service/mysql        ClusterIP   10.233.32.231   <none>        3306/TCP       29s   app=mysql
service/wordpress    NodePort    10.233.1.96     <none>        80:32537/TCP   29s   app=wordpress

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES      SELECTOR
deployment.apps/mysql       1/1     1            1           29s   mysql        mysql       app=mysql
deployment.apps/wordpress   1/1     1            1           29s   wordpress    wordpress   app=wordpress

NAME                                   DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES      SELECTOR
replicaset.apps/mysql-745d4579b9       1         1         1       29s   mysql        mysql       app=mysql,pod-template-hash=745d4579b9
replicaset.apps/wordpress-66f4cf6f68   1         1         1       29s   wordpress    wordpress   app=wordpress,pod-template-hash=66f4cf6f68
```

NodePort로 외부 접속
![접속 확인](./img/example.png)


## 6. [Metallb](https://metallb.universe.tf)
### Why?
k8s은 bare-metal-cluster를 위한 nerwork load balancer를 지원하지 않는다.  
IaaS 플랫폼이 아닐 경우 `Loadbalancer`는 'pending' 상태를 유지한다.  
"NodePort"와 "externalIPs" 서비스를 사용할 수 있지만,  
이 두 가지 옵션 모두 프로덕션 사용에 대한 상당한 단점이 있다.

### 설치
```sh
$ kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
namespace/metallb-system created
customresourcedefinition.apiextensions.k8s.io/bfdprofiles.metallb.io created
customresourcedefinition.apiextensions.k8s.io/bgpadvertisements.metallb.io created
customresourcedefinition.apiextensions.k8s.io/bgppeers.metallb.io created
customresourcedefinition.apiextensions.k8s.io/communities.metallb.io created
customresourcedefinition.apiextensions.k8s.io/ipaddresspools.metallb.io created
customresourcedefinition.apiextensions.k8s.io/l2advertisements.metallb.io created
customresourcedefinition.apiextensions.k8s.io/servicel2statuses.metallb.io created
serviceaccount/controller created
serviceaccount/speaker created
role.rbac.authorization.k8s.io/controller created
role.rbac.authorization.k8s.io/pod-lister created
clusterrole.rbac.authorization.k8s.io/metallb-system:controller created
clusterrole.rbac.authorization.k8s.io/metallb-system:speaker created
rolebinding.rbac.authorization.k8s.io/controller created
rolebinding.rbac.authorization.k8s.io/pod-lister created
clusterrolebinding.rbac.authorization.k8s.io/metallb-system:controller created
clusterrolebinding.rbac.authorization.k8s.io/metallb-system:speaker created
configmap/metallb-excludel2 created
secret/metallb-webhook-cert created
service/metallb-webhook-service created
deployment.apps/controller created
daemonset.apps/speaker created
validatingwebhookconfiguration.admissionregistration.k8s.io/metallb-webhook-configuration created
```
설치 확인
```sh
$ kubectl api-resources  | grep metal
bfdprofiles                                      metallb.io/v1beta1                true         BFDProfile
bgpadvertisements                                metallb.io/v1beta1                true         BGPAdvertisement
bgppeers                                         metallb.io/v1beta2                true         BGPPeer
communities                                      metallb.io/v1beta1                true         Community
ipaddresspools                                   metallb.io/v1beta1                true         IPAddressPool
l2advertisements                                 metallb.io/v1beta1                true         L2Advertisement
servicel2statuses                                metallb.io/v1beta1                true         ServiceL2Status
```
### [L2 모드로 구성하기](https://metallb.universe.tf/configuration/#layer-2-configuration)
```yaml
# metallb/001.setup.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.31.101-192.168.31.110 # 범위
  # - 192.168.31.0/24 # 대역
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
```
생성
```sh
$ kubectl apply -f metallb/001.setup.yaml 
ipaddresspool.metallb.io/first-pool created
l2advertisement.metallb.io/example created
```
확인
```sh
$ kubectl get ipaddresspools.metallb.io -n metallb-system
NAME         AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
first-pool   true          false             ["192.168.31.101-192.168.31.110"]
```
### 테스트
```yaml
# metallb/002.testPodService.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
spec:
  replicas: 10
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx-test
        # image: nginx:latest
        image: twoseven1408/test-nginx:latest # 라운드로빈 테스트용
        resources:
          limits:
            memory: "128Mi"
            cpu: "100m"
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  selector:
    app: nginx-test
  ports:
  - port: 80
  # - port: 9000
    targetPort: 80
  type: LoadBalancer # 기본적으로 라운드로빈임
```
생성
```sh
kubectl apply -f metallb/002.testPodService.yaml 
deployment.apps/nginx-test created
service/nginx-svc created
```
확인: Service에서 LoadBalancer 에 EXTERNAL-IP가 pending이 아니라 할당된 것을 볼 수 있다.
```sh
$ kubectl get all -o wide
NAME                              READY   STATUS    RESTARTS   AGE   IP             NODE    NOMINATED NODE   READINESS GATES
pod/nginx-test-66ff5df8cb-6zvf5   1/1     Running   0          61s   10.233.71.34   node3   <none>           <none>
pod/nginx-test-66ff5df8cb-8qzr7   1/1     Running   0          61s   10.233.75.15   node2   <none>           <none>
pod/nginx-test-66ff5df8cb-bgzxh   1/1     Running   0          61s   10.233.71.32   node3   <none>           <none>
pod/nginx-test-66ff5df8cb-dpj2s   1/1     Running   0          61s   10.233.75.12   node2   <none>           <none>
pod/nginx-test-66ff5df8cb-f4zpl   1/1     Running   0          61s   10.233.75.14   node2   <none>           <none>
pod/nginx-test-66ff5df8cb-g9t6v   1/1     Running   0          61s   10.233.71.35   node3   <none>           <none>
pod/nginx-test-66ff5df8cb-hxlsk   1/1     Running   0          61s   10.233.71.33   node3   <none>           <none>
pod/nginx-test-66ff5df8cb-lnc86   1/1     Running   0          61s   10.233.75.13   node2   <none>           <none>
pod/nginx-test-66ff5df8cb-psh7w   1/1     Running   0          62s   10.233.75.11   node2   <none>           <none>
pod/nginx-test-66ff5df8cb-q2lcw   1/1     Running   0          61s   10.233.71.31   node3   <none>           <none>

NAME                 TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)        AGE    SELECTOR
service/kubernetes   ClusterIP      10.233.0.1     <none>           443/TCP        112m   <none>
service/nginx-svc    LoadBalancer   10.233.31.99   192.168.31.101   80:31646/TCP   62s    app=nginx-test

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                           SELECTOR
deployment.apps/nginx-test   10/10   10           10          62s   nginx-test   twoseven1408/test-nginx:latest   app=nginx-test

NAME                                    DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES                           SELECTOR
replicaset.apps/nginx-test-66ff5df8cb   10        10        10      62s   nginx-test   twoseven1408/test-nginx:latest   app=nginx-test,pod-template-hash=66ff5df8cb
```

endpoints 확인
```sh
$ kubectl get endpoints
NAME         ENDPOINTS                                                     AGE
kubernetes   192.168.31.10:6443                                            115m
nginx-svc    10.233.71.31:80,10.233.71.32:80,10.233.71.33:80 + 7 more...   4m33s
```

LoadBalancer 및 라운드로빈 확인
```sh
$ curl 192.168.31.101

ip address      hostname
-------------------------------------------------
10.233.75.14    nginx-test-66ff5df8cb-f4zpl

-------------------------------------------------
$ curl 192.168.31.101

ip address      hostname
-------------------------------------------------
10.233.75.15    nginx-test-66ff5df8cb-8qzr7

-------------------------------------------------
$ curl 192.168.31.101

ip address      hostname
-------------------------------------------------
10.233.75.13    nginx-test-66ff5df8cb-lnc86

-------------------------------------------------

...
```

ClusterIP 로 접속
```sh
$ curl 10.233.31.99

ip address      hostname
-------------------------------------------------
10.233.75.14    nginx-test-66ff5df8cb-f4zpl

-------------------------------------------------

...
```

NodePort 방식으로 접속
```sh
$ curl 192.168.31.10:31646

ip address      hostname
-------------------------------------------------
10.233.75.14    nginx-test-66ff5df8cb-f4zpl

-------------------------------------------------

...
```


## 7. TODO: [Role](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)



## 8. [Helm](https://helm.sh/ko/docs/)
k8s 패키지 매니저
### [설치](https://helm.sh/ko/docs/intro/install/)
```sh
$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
$ chmod 700 get_helm.sh
$ ./get_helm.sh

Helm v3.16.3 is available. Changing from version v3.15.4.
Downloading https://get.helm.sh/helm-v3.16.3-linux-amd64.tar.gz
Verifying checksum... Done.
Preparing to install helm into /usr/local/bin
helm installed into /usr/local/bin/helm

$ helm version

version.BuildInfo{Version:"v3.16.3", GitCommit:"cfd07493f46efc9debd9cc1b02a0961186df7fdf", GitTreeState:"clean", GoVersion:"go1.22.7
```
### [사용법](https://helm.sh/ko/docs/intro/using_helm/)
#### 기본 명령어
- `helm search`
  - `helm search hub`: 헬름 허브 검색
  - `helm search repo`: 로컬 헬름 클라이언트에 추가된 저장소를 검색
- `helm install`: 설치
- `helm status [패지키명]`: 상태 추적 및 구성 정보 확인
- `helm show values [패키지명]`: 구성 가능한 옵션 확인
- `helm upgrad`e: TODO:
- `helm rollback [RELEASE] [REVISION]`: TODO:
- `helm uninstall [패키지명]`: 삭제
- `helm list`: 현재 배포된 모든 릴리스 확인
- `helm repo`
  - `helm repo list`: 어떤 저장소들이 설정되어 있는지 확인
  - `helm repo add`: 저장소 추가
  - `helm repo update`: 저장소 업데이트
  - `helm repo remove`: 저장소 삭제

[cloud native package](https://artifacthub.io)

#### 기본 사용 예제
```sh
mkdir helm && cd helm
helm repo add bitnami https://charts.bitnami.com/bitnami 
helm pull bitnami/nginx
tar -xf nginx-18.2.6.tgz
cp nginx/values.yaml nginx/my-values.yaml
cd nginx/
helm install nginx -f my-values.yaml .

NAME: nginx
LAST DEPLOYED: Mon Dec  2 03:44:27 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
CHART NAME: nginx
CHART VERSION: 18.2.6
APP VERSION: 1.27.3
```
확인
```sh
$ kubectl get all -o wide
NAME                         READY   STATUS     RESTARTS   AGE   IP       NODE    NOMINATED NODE   READINESS GATES
pod/nginx-557bfc8757-g8tr8   0/1     Init:0/1   0          9s    <none>   node2   <none>           <none>

NAME                 TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)                      AGE    SELECTOR
service/kubernetes   ClusterIP      10.233.0.1     <none>           443/TCP                      166m   <none>
service/nginx        LoadBalancer   10.233.1.148   192.168.31.101   80:30388/TCP,443:31460/TCP   9s     app.kubernetes.io/instance=nginx,app.kubernetes.io/name=nginx

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                                        SELECTOR
deployment.apps/nginx   0/1     1            0           9s    nginx        docker.io/bitnami/nginx:1.27.3-debian-12-r0   app.kubernetes.io/instance=nginx,app.kubernetes.io/name=nginx

NAME                               DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES                                        SELECTOR
replicaset.apps/nginx-557bfc8757   1         1         0       9s    nginx        docker.io/bitnami/nginx:1.27.3-debian-12-r0   app.kubernetes.io/instance=nginx,app.kubernetes.io/name=nginx,pod-template-hash=557bfc8757
```
접속 확인
```sh
$ curl 192.168.31.101
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
상태 확인
```sh
$ helm status nginx 

NAME: nginx
LAST DEPLOYED: Mon Dec  2 03:44:27 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
CHART NAME: nginx
CHART VERSION: 18.2.6
APP VERSION: 1.27.3

** Please be patient while the chart is being deployed **
NGINX can be accessed through the following DNS name from within your cluster:

    nginx.default.svc.cluster.local (port 80)

To access NGINX from outside the cluster, follow the steps below:

1. Get the NGINX URL by running these commands:

  NOTE: It may take a few minutes for the LoadBalancer IP to be available.
        Watch the status with: 'kubectl get svc --namespace default -w nginx'

    export SERVICE_PORT=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].port}" services nginx)
    export SERVICE_IP=$(kubectl get svc --namespace default nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "http://${SERVICE_IP}:${SERVICE_PORT}"

WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
  - cloneStaticSiteFromGit.gitSync.resources
  - resources
+info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
```

## 9. Monitoring with [Prometheus](https://artifacthub.io/packages/helm/prometheus-community/prometheus)
저장소 추가 및 다운로드
```sh
cd helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 
helm repo update 
helm pull prometheus-community/kube-prometheus-stack 
tar xvfz kube-prometheus-stack-66.3.0.tgz 
mv kube-prometheus-stack kube-prometheus-stack-custom 
cd kube-prometheus-stack-custom/ 
cp values.yaml my-values.yaml 
```
설치
```sh
helm install prometheus -f my-values.yaml .

# 약간의 시간이 흐른 뒤에
NAME: prometheus
LAST DEPLOYED: Mon Dec  2 04:05:33 2024
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
kube-prometheus-stack has been installed. Check its status by running:
  kubectl --namespace default get pods -l "release=prometheus"

Visit https://github.com/prometheus-operator/kube-prometheus for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.
```
현재 상태 확인
```sh
$ kubectl get all -o wide
NAME                                                         READY   STATUS              RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
pod/alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running             0          51s   10.233.71.38    node3   <none>           <none>
pod/prometheus-grafana-55d59494bf-fg8kp                      0/3     ContainerCreating   0          68s   <none>          node2   <none>           <none>
pod/prometheus-kube-prometheus-operator-76c785c96d-v4lkh     1/1     Running             0          68s   10.233.71.36    node3   <none>           <none>
pod/prometheus-kube-state-metrics-d85c885bd-h8pt7            1/1     Running             0          68s   10.233.75.18    node2   <none>           <none>
pod/prometheus-prometheus-kube-prometheus-prometheus-0       0/2     PodInitializing     0          49s   10.233.75.20    node2   <none>           <none>
pod/prometheus-prometheus-node-exporter-fqxlf                1/1     Running             0          68s   192.168.31.10   node1   <none>           <none>
pod/prometheus-prometheus-node-exporter-q8pgt                1/1     Running             0          68s   192.168.31.30   node3   <none>           <none>
pod/prometheus-prometheus-node-exporter-zxnq5                1/1     Running             0          68s   192.168.31.20   node2   <none>           <none>

NAME                                              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE    SELECTOR
service/alertmanager-operated                     ClusterIP   None            <none>        9093/TCP,9094/TCP,9094/UDP   52s    app.kubernetes.io/name=alertmanager
service/kubernetes                                ClusterIP   10.233.0.1      <none>        443/TCP                      3h9m   <none>
service/prometheus-grafana                        ClusterIP   10.233.26.214   <none>        80/TCP                       69s    app.kubernetes.io/instance=prometheus,app.kubernetes.io/name=grafana
service/prometheus-kube-prometheus-alertmanager   ClusterIP   10.233.46.120   <none>        9093/TCP,8080/TCP            69s    alertmanager=prometheus-kube-prometheus-alertmanager,app.kubernetes.io/name=alertmanager
service/prometheus-kube-prometheus-operator       ClusterIP   10.233.48.6     <none>        443/TCP                      69s    app=kube-prometheus-stack-operator,release=prometheus
service/prometheus-kube-prometheus-prometheus     ClusterIP   10.233.43.76    <none>        9090/TCP,8080/TCP            69s    app.kubernetes.io/name=prometheus,operator.prometheus.io/name=prometheus-kube-prometheus-prometheus
service/prometheus-kube-state-metrics             ClusterIP   10.233.56.75    <none>        8080/TCP                     69s    app.kubernetes.io/instance=prometheus,app.kubernetes.io/name=kube-state-metrics
service/prometheus-operated                       ClusterIP   None            <none>        9090/TCP                     50s    app.kubernetes.io/name=prometheus
service/prometheus-prometheus-node-exporter       ClusterIP   10.233.59.185   <none>        9100/TCP                     69s    app.kubernetes.io/instance=prometheus,app.kubernetes.io/name=prometheus-node-exporter

NAME                                                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE   CONTAINERS      IMAGES                                    SELECTOR
daemonset.apps/prometheus-prometheus-node-exporter   3         3         3       3            3           kubernetes.io/os=linux   68s   node-exporter   quay.io/prometheus/node-exporter:v1.8.2   app.kubernetes.io/instance=prometheus,app.kubernetes.io/name=prometheus-node-exporter

NAME                                                  READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS                                            IMAGES                                                                                                     SELECTOR
deployment.apps/prometheus-grafana                    0/1     1            0           68s   grafana-sc-dashboard,grafana-sc-datasources,grafana   quay.io/kiwigrid/k8s-sidecar:1.28.0,quay.io/kiwigrid/k8s-sidecar:1.28.0,docker.io/grafana/grafana:11.3.1   app.kubernetes.io/instance=prometheus,app.kubernetes.io/name=grafana
deployment.apps/prometheus-kube-prometheus-operator   1/1     1            1           68s   kube-prometheus-stack                                 quay.io/prometheus-operator/prometheus-operator:v0.78.2                                                    app=kube-prometheus-stack-operator,release=prometheus
deployment.apps/prometheus-kube-state-metrics         1/1     1            1           68s   kube-state-metrics                                    registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.14.0                                              app.kubernetes.io/instance=prometheus,app.kubernetes.io/name=kube-state-metrics

NAME                                                             DESIRED   CURRENT   READY   AGE   CONTAINERS                                            IMAGES                                                                                                     SELECTOR
replicaset.apps/prometheus-grafana-55d59494bf                    1         1         0       68s   grafana-sc-dashboard,grafana-sc-datasources,grafana   quay.io/kiwigrid/k8s-sidecar:1.28.0,quay.io/kiwigrid/k8s-sidecar:1.28.0,docker.io/grafana/grafana:11.3.1   app.kubernetes.io/instance=prometheus,app.kubernetes.io/name=grafana,pod-template-hash=55d59494bf
replicaset.apps/prometheus-kube-prometheus-operator-76c785c96d   1         1         1       68s   kube-prometheus-stack                                 quay.io/prometheus-operator/prometheus-operator:v0.78.2                                                    app=kube-prometheus-stack-operator,pod-template-hash=76c785c96d,release=prometheus
replicaset.apps/prometheus-kube-state-metrics-d85c885bd          1         1         1       68s   kube-state-metrics                                    registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.14.0                                              app.kubernetes.io/instance=prometheus,app.kubernetes.io/name=kube-state-metrics,pod-template-hash=d85c885bd

NAME                                                                    READY   AGE   CONTAINERS                     IMAGES
statefulset.apps/alertmanager-prometheus-kube-prometheus-alertmanager   1/1     51s   alertmanager,config-reloader   quay.io/prometheus/alertmanager:v0.27.0,quay.io/prometheus-operator/prometheus-config-reloader:v0.78.2
statefulset.apps/prometheus-prometheus-kube-prometheus-prometheus       0/1     49s   prometheus,config-reloader     quay.io/prometheus/prometheus:v2.55.1,quay.io/prometheus-operator/prometheus-config-reloader:v0.78.2
```
grafana에 접근하기 위해 service type 변경
```sh
kubectl edit service/prometheus-grafana
```
```yaml
type: ClusterIP # 에서
type: LoadBalancer # 으로 변경하고 저장



#:wq
```
```sh
service/prometheus-grafana edited
```
접속 확인
![그라파나 인덱스](./img/grafana-index.png)

초기 로그인 접속 정보 확인
```sh
$ kubectl get secrets prometheus-grafana -o yaml 
```
```yaml
apiVersion: v1
data:
  admin-password: cHJvbS1vcGVyYXRvcg== # echo cHJvbS1vcGVyYXRvcg== | base64 -d ===> prom-operator
  admin-user: YWRtaW4= # echo YWRtaW4= | base64 -d ====> admin
  ldap-toml: ""
kind: Secret
metadata:
  annotations:
    meta.helm.sh/release-name: prometheus
    meta.helm.sh/release-namespace: default
  creationTimestamp: "2024-12-02T04:22:34Z"
  labels:
    app.kubernetes.io/instance: prom
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: grafana
    app.kubernetes.io/version: 11.3.1
    helm.sh/chart: grafana-8.6.3
  name: prometheus-grafana
  namespace: default
  resourceVersion: "26648"
  uid: d09ea14d-e8de-47ed-a39b-b6d815aee29d
type: Opaque
```
대시보드 확인
![클러스터](./img/grafana-cluster.png)
![네트워크](./img/grafana-network.png)