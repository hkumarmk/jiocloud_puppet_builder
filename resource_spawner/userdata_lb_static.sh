#!/bin/bash
#echo "`date` Starting userdata execution"
nics=`lshw -quiet -C network | awk '/logical name/ {print $NF}'`
cat <<EOF > /etc/sysctl.d/11-disable-ipv6.conf 
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sysctl -p

for i in $nics; do
  cat <<EOF > /etc/network/interfaces.d/${i}.cfg
auto $i
iface $i inet dhcp
EOF
done

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
sed -i -e '/^ *export FACTER_no_operatingsystem_upgrade=/{s/.*/export FACTERexport FACTER_no_operatingsystem_upgrade=1/;:a;n;:ba;q}' -e '$ aexport FACTER_no_operatingsystem_upgrade=1' /etc/puppet/local_facter.env

/etc/init.d/networking restart

cat <<'EOF' | tee -a /etc/skel/.bashrc | tee -a ~ubuntu/.bashrc | tee -a ~root/.bashrc
export PS1=`echo "$PS1" | sed 's/@.h/@__project__\/\\\h/g'`
EOF

echo 'APT::Get::AllowUnauthenticated "true";' > /etc/apt/apt.conf.d/80unauthenticatedpkgs
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
  apt-get install -y puppet-common subversion squid bind9 haproxy; rv_apt_install=$?
  if [ $rv_apt_install -eq 0 ]; then
    num_apt_install=5
  fi
  num_apt_install=$(($num_apt_install+1))
  sleep 3
done
ntpdate -u 10.135.121.138 10.135.121.107
cat <<EOF > /etc/squid3/squid.conf 
acl manager proto cache_object
acl localhost src 127.0.0.1/32 ::1
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32 ::1
acl localnet src 10.0.0.0/8
acl SSL_ports port 443
acl Safe_ports port 80		# http
acl Safe_ports port 8080
acl Safe_ports port 443		# https
acl CONNECT method CONNECT
http_access allow manager localhost
http_access deny manager
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost
http_access allow localnet
http_access deny all
http_port 3128
coredump_dir /var/spool/squid3
EOF
service squid3 restart

cat <<EOF > /etc/bind/named.conf.default-zones 
zone "." {
	type hint;
	file "/etc/bind/db.root";
};

zone "localhost" {
	type master;
	file "/etc/bind/db.local";
};

zone "127.in-addr.arpa" {
	type master;
	file "/etc/bind/db.127";
};

zone "0.in-addr.arpa" {
	type master;
	file "/etc/bind/db.0";
};

zone "255.in-addr.arpa" {
	type master;
	file "/etc/bind/db.255";
};
zone "jiocloud.com" {
  type master;
  file "/var/lib/bind/jiocloud.com";
  allow-update { key dhcpupdate; };
};
zone "10.in-addr.arpa" {
        type master;
	allow-update { key dhcpupdate; };
        file "/var/lib/bind/10.in-addr.arpa";
};
key dhcpupdate {
  algorithm hmac-md5;
  secret "yCGS8t1sIM+FoG3xzYfQRQ==";
};
EOF

cat <<EOF > /var/lib/bind/jiocloud.com
\$TTL	604800
@	IN	SOA	@ jiocloud.com (
			      2		; Serial
			 604800		; Refresh
			  86400		; Retry
			2419200		; Expire
			 604800 )	; Negative Cache TTL
;
@	IN	NS	@
@	IN	A	127.0.0.1
EOF

cat <<EOF > /var/lib/bind/10.in-addr.arpa
\$TTL   604800
10.in-addr.arpa.       IN      SOA     @ jiocloud.com. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      @
        A       127.0.0.1
EOF

cat <<EOF > /etc/default/bind9
RESOLVCONF=no
OPTIONS="-4 -u bind"
EOF

chown -R bind /var/lib/bind/
service bind9 restart
mkdir -p ~ubuntu/.ssh
chown ubuntu.ubuntu ~ubuntu/.ssh
chmod 700 ~ubuntu/.ssh

cat <<EOF > ~ubuntu/.ssh/id_rsa
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEA0wSfz9gd2gYgolptano6j9qEeOel2NYueIda8F3BntFixcSb
5mm5qw+Js0raW9G/LA7AEmm9Z/BniJAfNhztTj11KUqcu6/zVTDIh/k6/YZTYdM/
LxF3rEFWgLZEWE/sVL+SK8+DfEAx9lWXo9/xREzURzMDE8pNyH6aSB2GJ7s+y3fN
2nyp3VazKVVQ0Ij6HLP9waqOMeT8XafTc94clVUSBs5pTpuphAeGJTHekLDmeeTn
ulDOV3iUsGZy9spyUtlkCwaYbj+P5iEEx6T0KH1zoAq7fUfR3kZPa7mupZ5cffCC
hp7awCEEO+/0xfc2ctUGoV1U4zdjTRXQbHySqwIDAQABAoIBAFQBYUWy+Z9UFSXM
7gYXhrzB9z7SqVl7WqCs8e0CxhPds36b2JyPtlR9KQpxYCBxjbOSY7Bw2/BG6lCZ
X3OBbI9bNAsuItstHqfpdct70pofIY6uNFcekw/GKxOue+LUXncWlLBQOj36qGky
hd29RyUzmMaHblAwl2qby/utlTy3OwommbHbeLP5fx3yUJvL2oZ2JJeBNdyUB6Vc
Irr1NhLzmXgPCtQ0BUcpcKJz84Uy/PAmxJGvETTXPbopyXjckGNyYCydiGBoNrp2
XyvXEgqRrGaEqSUiYv9VCpwIrQBD+REFBKk4FGW/ByU54F7er4F/1ojMAXgPbwOe
wUdiPyECgYEA8NMuUQ7TrILzoSPrPO7PCC9TBKo5Yl+elFt00+vqFltm7sqwf5qI
90BQcOnvIjIwnVW5BhDjqmi/t6xmNARVQB+18uKAfU9hB6k2x+xHbpmGj03OArHw
nPgTzNzRhUTJzlUhLKYOKaPk4ZBcC5brqEfTOmnABQxry5vr4oTcYnMCgYEA4FCe
srMAHcwv0ggRuSg7cXGA0COSZsZsR3UuOoLe/xneAJTfdZztdFGBChX8/bUAGRHs
csydzNIgAOUT5Lo7zVmYQAJWcr538cVuVT93hnHxWSmz01QWgPdPM48/XLnbRf2n
soWFPCaVJJJAlvhNaTusr7xtTttv+bSZrmsnKOkCgYARX6rfvioXL/tTjLvT0Yau
GHvswjsRlcRi/5YWE9b3dfCfGZBSJFvtOn6TJs1Rsj0/nIeUoHNMP/JU1eMprYZY
8fC2bRDH+YoOe26wTaN5nynN/Nb36s5pBJypEuUqsCO+9vVFu1UaO/CvNTLuwxyN
L2FVvXtU4eiE7+K8nMkpcQKBgCBWfwp0E8g374zv7N4slqU8H73h4vE+Gc4Tbp6w
z0UnjYG39J8YCIOEXH3/vYE13tW+Z8AFD5q/kC2Q2NVYo9Zu3CweKihQnSoVtFpF
1A1lz81y3aHRtYzSGnDsbc4IXTwx3UM3TIXnagjjrLwW/9Hz8GlFWNzNdc8h4iXq
/LJBAoGAGGv9GERNQI3SGVmJb71WM6Io9rAb6da6pWYe+53iRwRYC44MDcsNwpjD
tzfkw2XZk6CRLtXRFsdTMCewYfNTvNO8B4MgQ3YE9e8iKId8JD0QG2vKQIcKGalw
GrtzQbNf6m29XQReRkq9O3qLrU9763yEgP2wT5kd76wFD3ktwF0=
-----END RSA PRIVATE KEY-----
EOF
chown ubuntu.ubuntu ~ubuntu/.ssh/id_rsa
chmod 600 ~ubuntu/.ssh/id_rsa
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

cat <<EOF > /etc/haproxy/haproxy.cfg
global
        log 127.0.0.1   local0 notice
        maxconn 4096
        user haproxy
        group haproxy
        daemon
        quiet
	stats socket /var/run/haproxy mode 777

defaults
        log     global
        mode    http  #HTTP Log format
        option redispatch #try another webhead if retry fails
        option  tcplog
        option  dontlognull
        retries 3
        maxconn 2000
        contimeout      300s
        clitimeout      300s
        srvtimeout      300s
        errorfile       400     /etc/haproxy/errors/400.http
        errorfile       403     /etc/haproxy/errors/403.http
        errorfile       408     /etc/haproxy/errors/408.http
        errorfile       500     /etc/haproxy/errors/500.http
        errorfile       502     /etc/haproxy/errors/502.http
        errorfile       503     /etc/haproxy/errors/503.http
        errorfile       504     /etc/haproxy/errors/504.http

listen  LB-Stats 0.0.0.0:8084
        mode http
	option httplog
        stats enable
        stats uri /lb-stats
EOF
for i in Horizon:80 Horizon-https:443 vncproxy:6080 Keystone:5000 Keystone-admin:35357 Glance:9292 Glance-registry:9191 Cinder:8776 Nova:8774 Metadata:8775 Nova-ec2:8773 ; do 
cat <<EOF >> /etc/haproxy/haproxy.cfg
listen ${i%:*}
  bind 0.0.0.0:${i#*:}
  mode tcp
  option tcpka
  option abortonclose
  server  oc1 10.1.0.11:${i#*:} check inter 3000 rise 2 fall 3
  server  oc2 10.1.0.12:${i#*:} check inter 3000 rise 2 fall 3
EOF
  if [ `echo ${i%:*} | grep -c Horizon` -ne 0 ]; then
    echo "  balance source"
  else 
    echo "  balance roundrobin"
  fi
  if [ `echo ${i%:*} | grep -c Metadata` -eq 0 ]; then
    echo "  option ssl-hello-chk"
  fi
done
cat <<EOF >> /etc/haproxy/haproxy.cfg
listen  Object-Storage
        bind 0.0.0.0:8143
	mode tcp
        balance roundrobin
        option tcpka
        option ssl-hello-chk
        option abortonclose
        server  st1 10.1.0.51:443 check inter 3000 rise 2 fall 3
        server  st2 10.1.0.52:443 check inter 3000 rise 2 fall 3
        server  st3 10.1.0.53:443 check inter 3000 rise 2 fall 3

listen	Neutron
	bind 0.0.0.0:9695
        balance roundrobin
	mode tcp
        option tcpka
        option ssl-hello-chk
        option abortonclose
        server  ct1 10.1.0.245:9695 check inter 3000 rise 2 fall 3

EOF

cat << 'DEFAULT_HAPROXY' > /etc/default/haproxy
ENABLED=1
DEFAULT_HAPROXY

service haproxy restart
nohup /var/puppet/bin/papply >> /var/log/papply.log 2>&1 &
echo "`date` Finished userdata execution"
