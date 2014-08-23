#!/bin/bash -x
#echo "`date` Starting userdata execution"
while getopts "r:u:p:" OPTION; do
  case "${OPTION}" in
    r)
      role=${OPTARG}
      ;;
    u)
     apt_repo_base_url=${OPTARG}
     ;;
    p)
     proxy_server=${OPTARG}
     ;;
  esac
done
if [ `echo $role | grep -c "[a-zA-Z0-9]"` -eq 0 ]; then
  printf "Role is mandatory.\nUsage: $0 -r <role> -u <apt repo base url> -p <proxy server url>"
  exit 1
fi
apt_repo_base_url=${apt_repo_base_url:-"http://10.135.96.60/mirror1/mirror"}  # http://10.135.96.60/mirror1/mirror

## Enable all nics and restart network to up all of them
nics=`lshw -quiet -C network | awk '/logical name/ {print $NF}'`

for i in $nics; do
  cat <<EOF > /etc/network/interfaces.d/${i}.cfg
auto $i
iface $i inet dhcp
EOF
done

/etc/init.d/networking restart

## Add hostname to hosts so ssh will be faster
cat <<ETC_HOSTS > /etc/hosts
127.0.0.1 localhost `hostname`
ETC_HOSTS

### Setup proxy for apt on non-lb nodes

if [ $role != 'lb' ]; then
  cat <<EOF > /etc/apt/apt.conf.d/90proxy
Acquire::http::proxy "$proxy_server";
Acquire::https::proxy "$proxy_server";
EOF
fi

### Unmount ephemeral disk if mounted
umount /mnt
sed -i '/\/dev\/vdb[\s\t]*\/mnt.*/d' /etc/fstab


## Setup bash prompt so the project name is added in the bash prompt
cat <<'EOF' | tee -a /etc/skel/.bashrc | tee -a ~ubuntu/.bashrc | tee -a ~root/.bashrc
export PS1=`echo "$PS1" | sed 's/@.h/@__project__\/\\\h/g'`
EOF

### Configure apt 
echo 'APT::Get::AllowUnauthenticated "true";' > /etc/apt/apt.conf.d/80unauthenticatedpkgs
cat <<EOF > /etc/apt/sources.list 
deb [arch=amd64] $apt_repo_base_url/archive.ubuntu.com/ubuntu precise main restricted universe
deb [arch=amd64] $apt_repo_base_url/archive.ubuntu.com/ubuntu precise-updates main restricted universe
deb [arch=amd64] $apt_repo_base_url/apt.puppetlabs.com/ precise main dependencies
deb [arch=amd64] $apt_repo_base_url/ppa.launchpad.net/chris-lea/fabric/ubuntu/ precise main 
deb [arch=amd64] $apt_repo_base_url/ubuntu-cloud.archive.canonical.com/ubuntu/ precise-updates/havana main
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

if [ $role != 'lb' ]; then
  apt-get install -y puppet-common; rv_apt_install=$?
else
  apt-get install -y puppet-common fabric squid haproxy; rv_apt_install=$?
  cat <<EOF > /etc/squid3/squid.conf 
acl manager proto cache_object
acl localhost src 127.0.0.1/32 ::1
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32 ::1
acl localnet src 0.0.0.0/1
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
fi
