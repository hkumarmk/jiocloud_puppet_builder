#!/bin/bash
echo "`date` Starting userdata execution"
nics=`lshw -quiet -C network | awk '/logical name/ {print $NF}'`
proxy_up=0
for i in $nics; do
  cat <<EOF > /etc/network/interfaces.d/${i}.cfg
auto $i
iface $i inet dhcp
EOF
done
/etc/init.d/networking restart
echo -n "Waiting for proxy service up in lb1..."
while [ $proxy_up -eq 0 ]; do
  sleep 3
  curl -f --proxy http://10.1.0.5:3128 http://10.135.96.60  &> /dev/null; rv=$?
  echo -n .
  if [ $rv -eq 0 ];then
    proxy_up=1
  fi
done
curl --proxy http://10.1.0.5:3128 http://10.135.120.107:8080/userdata/userdata_static.sh > /tmp/userdata.sh 2> /dev/null
sed -i -e 's/__project__/___PROJECT___/g' -e 's/___BASE_SNAPSHOT_VERSION___/___BASE_SNAPSHOT_VERSION_STATIC___/g' -e 's/___TARGET_SNAPSHOT_VERSION___/___TARGET_SNAPSHOT_VERSION_STATIC___/g' -e 's/___OPENSTACK_REGION___/___OPENSTACK_REGION_STATIC___/g' -e 's/___OPENSTACK_ADMIN_PASSWORD___/___OPENSTACK_ADMIN_PASSWORD_STATIC___/g' /tmp/userdata.sh

/bin/bash /tmp/userdata.sh
rm -f /tmp/userdata.sh

