dnf install nfs-utils net-tools -y
systemctl enable nfs-server
systemctl start nfs-server
mkdir /srv/nfs
cat <<EOF>> /etc/exports 
/srv/nfs        192.168.1.192(rw,sync,no_root_squash,no_all_squash) 192.168.1.193(rw,sync,no_root_squash,no_all_squash) 192.168.1.194(rw,sync,no_root_squash,no_all_squash)
/srv/mysql      192.168.1.192(rw,sync,no_root_squash,no_all_squash) 192.168.1.193(rw,sync,no_root_squash,no_all_squash) 192.168.1.194(rw,sync,no_root_squash,no_all_squash)
/srv/wp         192.168.1.192(rw,sync,no_root_squash,no_all_squash) 192.168.1.193(rw,sync,no_root_squash,no_all_squash) 192.168.1.194(rw,sync,no_root_squash,no_all_squash)
EOF
exportfs -r
exportfs -s
showmount -e 192.168.1.192
