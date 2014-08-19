#!/bin/bash

cat <<EOF > /etc/sysctl.d/11-disable-ipv6.conf 
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sysctl -p

cat <<'EOF' | tee -a /etc/skel/.bashrc | tee -a ~ubuntu/.bashrc | tee -a ~root/.bashrc
export PS1=`echo "$PS1" | sed 's/@.h/@__project__\/\\\h/g'`
EOF

cat <<ETC_HOSTS > /etc/hosts
127.0.0.1 localhost `hostname`
ETC_HOSTS

mkdir /etc/puppet
[ -e /etc/puppet/local_facter.env ] || echo "#All local facters go here" > /etc/puppet/local_facter.env
if [ ___BASE_SNAPSHOT_VERSION___ -ne 0 ]; then
  sed -i -e '/^ *export FACTER_base_snapshot_version=/{s/.*/export FACTER_base_snapshot_version="v___BASE_SNAPSHOT_VERSION___"/;:a;n;:ba;q}' -e '$ aexport FACTER_base_snapshot_version="v___BASE_SNAPSHOT_VERSION___"' /etc/puppet/local_facter.env
  sed -i -e '/^ *export FACTER_target_snapshot_version=/{s/.*/export FACTER_target_snapshot_version="v___TARGET_SNAPSHOT_VERSION___"/;:a;n;:ba;q}' -e '$ aexport FACTER_target_snapshot_version="v___TARGET_SNAPSHOT_VERSION___"' /etc/puppet/local_facter.env
else
  sed -i -e '/^ *export FACTER_target_snapshot_version=/{s/.*/export FACTER_target_snapshot_version="v___TARGET_SNAPSHOT_VERSION___"/;:a;n;:ba;q}' -e '$ aexport FACTER_target_snapshot_version="v___TARGET_SNAPSHOT_VERSION___"' /etc/puppet/local_facter.env
fi
sed -i -e '/^ *export FACTER_my_project=/{s/.*/export FACTER_my_project="__project__"/;:a;n;:ba;q}' -e '$ aexport FACTER_my_project="__project__"' /etc/puppet/local_facter.env
sed -i -e '/^ *export FACTER_openstack_admin_pass=/{s/.*/export FACTER_openstack_admin_pass="___OPENSTACK_ADMIN_PASSWORD___"/;:a;n;:ba;q}' -e '$ aexport FACTER_openstack_admin_pass="___OPENSTACK_ADMIN_PASSWORD___"' /etc/puppet/local_facter.env

sed -i -e '/^ *export FACTER_openstack_region=/{s/.*/export FACTER_openstack_region="___OPENSTACK_REGION___"/;:a;n;:ba;q}' -e '$ aexport FACTER_openstack_region="___OPENSTACK_REGION___"' /etc/puppet/local_facter.env

 


echo 'APT::Get::AllowUnauthenticated "true";' > /etc/apt/apt.conf.d/80unauthenticatedpkgs
cat <<EOF > /etc/apt/apt.conf.d/90proxy
Acquire::http::proxy "http://10.1.0.5:3128/";
Acquire::https::proxy "http://10.1.0.5:3128/";
EOF

cat <<EOF > /etc/apt/sources.list 
deb [arch=amd64] http://10.135.96.60/mirror1/mirror/archive.ubuntu.com/ubuntu precise main restricted universe
deb [arch=amd64] http://10.135.96.60/mirror1/mirror/archive.ubuntu.com/ubuntu precise-updates main restricted universe
deb [arch=amd64] http://10.135.96.60/mirror1/mirror/apt.puppetlabs.com/ precise main dependencies
EOF
rv_apt_update=1
num_apt_update=1
while [ $num_apt_update -lt 5 ]; do 
  apt-get update; rv_apt_update=$?
  if [ $rv_apt_update -eq 0 ]; then
    num_apt_update=5
  fi
  num_apt_update=$(($num_apt_update+1))
  sleep 3
done
rv_apt_install=1
num_apt_install=1
while [ $num_apt_install -lt 5 ]; do 
  apt-get install -y puppet-common subversion; rv_apt_install=$?
  if [ $rv_apt_install -eq 0 ]; then
    num_apt_install=5
  fi
  num_apt_install=$(($num_apt_install+1))
  sleep 3
done
mkdir -p /root/.subversion
cat <<EOF > /root/.subversion/servers 
[global]
http-proxy-host = 10.1.0.5
http-proxy-port = 3128
EOF

cp -rf /root/.subversion ~ubuntu/
chown -R ubuntu.ubuntu  ~ubuntu

echo p | svn co https://10.135.121.138/svn/puppet_new_1/trunk/ /var/puppet  --username svn --password SubVer510n@1234 
rv_svn_co=1
num_svn_co=1
while [ $num_svn_co -lt 5 ]; do 
  svn co https://10.135.121.138/svn/puppet_new_1/trunk/ /var/puppet  --username svn --password SubVer510n@1234 --no-auth-cache; rv_svn_co=$?
  if [ $rv_svn_co -eq 0 ]; then
    num_svn_co=5
  fi
  num_svn_co=$(($num_svn_co+1))
  sleep 3
done


cat <<EOF > /etc/resolv.conf
search jiocloud.com
nameserver 10.1.0.5
EOF

rm -rf /etc/apt/sources.list* ; touch /etc/apt/sources.list
apt-get clean ;apt-get update
if [ ! -d /var/puppet ]; then
  echo p | svn co https://10.135.121.138/svn/puppet_new_1/trunk/ /var/puppet  --username svn --password SubVer510n@1234
  svn co https://10.135.121.138/svn/puppet_new_1/trunk/ /var/puppet  --username svn --password SubVer510n@1234 --no-auth-cache;
fi
umount /mnt
sed -i '/\/dev\/vdb[\s\t]*\/mnt.*/d' /etc/fstab
echo "`date` Finished userdata execution"
