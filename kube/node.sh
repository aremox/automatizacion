hostnamectl set-hostname nodo2
nmcli connection modify enp0s3 ipv4.addresses 192.168.1.194/24
nmcli connection modify enp0s3 ipv4.gateway 192.168.1.1
nmcli connection modify enp0s3 ipv4.dns 8.8.8.8
systemctl stop firewalld
systemctl disable firewalld
grubby --update-kernel ALL --args selinux=0
dnf update -y
dnf install nfs-utils nfs4-acl-tools wget -y
dnf install nfs-utils net-tools -y
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

kubeadm config images pull

init 6

kubeadm join 192.168.1.192:6443 --token p4wtiu.grbktbc6aeea3laq \
        --discovery-token-ca-cert-hash sha256:e59964c02678e436f405436df3c77a4dbb065d737b255b7c3f0f5858618c452f

