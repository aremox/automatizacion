hostnamectl set-hostname master
nmcli connection modify enp0s3 ipv4.addresses 192.168.1.192/24
nmcli connection modify enp0s3 ipv4.gateway 192.168.1.1
nmcli connection modify enp0s3 ipv4.dns 8.8.8.8
systemctl stop firewalld
systemctl disable firewalld
grubby --update-kernel ALL --args selinux=0
dnf update -y
dnf install nfs-utils nfs4-acl-tools net-tools wget -y
echo 192.168.1.192 master >> /etc/hosts
echo 192.168.1.193 nodo1 >> /etc/hosts
echo 192.168.1.194 nodo2 >> /etc/hosts
modprobe br_netfilter
#firewall-cmd --add-masquerade --permanent
#firewall-cmd --reload
systemctl status firewalld

cat <<EOF>> /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

swapoff  -a
sed -i '/swap/d' /etc/fstab

wget -O /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/CentOS_8_Stream/devel:kubic:libcontainers:stable.repo
wget -O /etc/yum.repos.d/devel:kubic:crio:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.24/CentOS_8_Stream/devel:kubic:libcontainers:stable:cri-o:1.24.repo

cat <<EOF>> /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

dnf install cri-o -y
systemctl enable crio
systemctl start crio

cat <<EOF>> /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

dnf install -y kubelet kubeadm kubectl iproute-tc --disableexcludes=kubernetes

systemctl enable kubelet
systemctl start kubelet
# Añadir datos de proxy
#vi /etc/sysconfig/crio
kubeadm config images pull

kubeadm init --pod-network-cidr 10.71.0.0/16

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

#kubeadm join 192.168.1.192:6443 --token p4wtiu.grbktbc6aeea3laq \
#        --discovery-token-ca-cert-hash sha256:e59964c02678e436f405436df3c77a4dbb065d737b255b7c3f0f5858618c452f

kubectl get nodes
wget https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml
vi tigera-operator.yaml
kubectl create -f tigera-operator.yaml
wget https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml
vi custom-resources.yaml
kubectl create -f custom-resources.yaml
kubectl get pods -o wide -A
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl get nodes -o wide
kubectl apply -f https://raw.githubusercontent.com/haproxytech/kubernetes-ingress/master/deploy/haproxy-ingress.yaml
kubectl get namespaces


useradd -md /home/kubeadmin kubeadmin
passwd kubeadmin
mkdir -p /home/kubeadmin/.kube
cp -i /etc/kubernetes/admin.conf /home/kubeadmin/.kube/config
chown kubeadmin. /home/kubeadmin/.kube/config
cat <<EOF>> /etc/sudoers.d/kubeadmin
ALL            ALL = (ALL) NOPASSWD: ALL
EOF

