#!/bin/bash 
cat <<ETC_HOSTS > /etc/hosts
127.0.0.1 localhost `hostname`
ETC_HOSTS


echo 'APT::Get::AllowUnauthenticated "true";' > /etc/apt/apt.conf.d/80unauthenticatedpkgs
cat <<EOF > /etc/apt/apt.conf.d/90proxy
Acquire::http::proxy "http://10.1.0.5:3128/";
Acquire::https::proxy "http://10.1.0.5:3128/";
EOF

cat <<'EOF' > /etc/profile.d/prompt.sh
export PS1=`echo "$PS1" | sed 's/@.h/@${project}\/\\\h/g'`
EOF

cat <<EOF > /etc/apt/sources.list
deb [arch=amd64] http://10.135.96.60/mirror1/mirror/archive.ubuntu.com/ubuntu precise main restricted universe
deb [arch=amd64] http://10.135.96.60/mirror1/mirror/archive.ubuntu.com/ubuntu precise-updates main restricted universe
deb [arch=amd64] http://10.135.96.60/mirror1/mirror/ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/havana main
deb [arch=amd64] http://10.135.96.60/mirror1/mirror/archive.ubuntu.com/ubuntu precise-updates main restricted universe
deb [arch=amd64] http://10.135.96.60/mirror1/mirror/apt.puppetlabs.com/ precise main dependencies
deb [arch=amd64] http://10.135.96.60/mirror1/mirror/ppa.launchpad.net/chris-lea/fabric/ubuntu precise main
EOF
apt-get update
apt-get install -y dnsutils fabric python-paramiko

mkdir -p ~ubuntu/.ssh
chown ubuntu.ubuntu ~ubuntu/.ssh
chmod 700 ~ubuntu/.ssh

cat <<'SSHKEY' > ~ubuntu/.ssh/id_rsa
__SSH_PRIVATE_KEY__
SSHKEY

chown ubuntu.ubuntu ~ubuntu/.ssh/id_rsa
chmod 600 ~ubuntu/.ssh/id_rsa

cat <<FABRICRC > ~ubuntu/.fabricrc

fabfile = ~ubuntu/fabfile.py
skip_bad_hosts = true
warn_only = true
FABRICRC


nsupdate <<'NSUPDATE'
server 10.1.0.5
key dhcpupdate yCGS8t1sIM+FoG3xzYfQRQ==
zone jiocloud.com.
___Forward_DNS_Entries___
update add __project__.jiocloud.com. 86400 IN A 10.1.0.5
send
zone 10.in-addr.arpa
___Reverse__DNS__Entries___
send
quit
NSUPDATE
cat <<'FABFILE' > ~ubuntu/fabfile.py
___FABFILE.PY_CONTENTS___
FABFILE
if [ __UPGRADE_TO_BASE__ -eq 1 ];then
  su - ubuntu -c "fab --set upgrade=base checkAll" 
  rv=$?
  echo "`date` Upgraded to base version"
else
  rv=0
fi

if [ $rv -eq 0 ]; then
  su - ubuntu -c "fab checkAll"
  rv=$?
fi

if [ $rv -eq 0 ]; then
  echo "`date` Finished userdata execution"
  echo "__SHUTDOWN__"
else 
  echo "`date` fab execution failed"
  echo "__FAILED_FAB__"
fi

if [ $rv -eq 0 ]; then
  echo "`date` Finished userdata execution"
  echo "__SHUTDOWN__"
else 
  echo "`date` fab execution failed"
  echo "__FAILED_FAB__"
fi

#shutdown -h +3 


