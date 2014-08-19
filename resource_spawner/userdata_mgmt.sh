#!/bin/bash 
echo "`date` Starting userdata execution"
proxy_up=0
echo -n "Waiting for proxy service up in lb1..."
while [ $proxy_up -eq 0 ]; do
  sleep 3
  curl -f --proxy http://10.1.0.5:3128 http://10.135.96.60  &> /dev/null; rv=$?
  echo -n .
  if [ $rv -eq 0 ];then
    proxy_up=1
  fi
done
curl --proxy http://10.1.0.5:3128 http://10.135.120.107:8080/userdata/userdata_mgmt_static.sh > /tmp/userdata_mgmt.sh
curl --proxy http://10.1.0.5:3128 http://10.135.120.107:8080/userdata/fabfile.py > /tmp/fabfile.py
sed -i -e "s/__project__/___PROJECT___/g" -e "s/___CP_SERVERS_TOBE_REPLACED___/___CP_SERVERS_TOBE_REPLACED_Static___/" -e "s/___ST_SERVERS_TOBE_REPLACED___/___ST_SERVERS_TOBE_REPLACED_Static___/" -e "s/___ALL_SERVERS_TOBE_REPLACED___/___ALL_SERVERS_TOBE_REPLACED_Static___/" /tmp/fabfile.py
  if [ __Verbose__ -eq 1 ]; then
    sed -i -e "s/__project__/___PROJECT___/g" -e "s/___Forward_DNS_Entries___/___Forward_DNS_Entries_Static___/g" -e "s/___Reverse__DNS__Entries___/___Reverse__DNS__Entries_Static___/g" -e "s/___Verbose_Static___/:verbose/" /tmp/userdata_mgmt.sh
  else
    sed -i -e "s/__project__/___PROJECT___/g" -e "s/___Forward_DNS_Entries___/___Forward_DNS_Entries_Static___/g" -e "s/___Reverse__DNS__Entries___/___Reverse__DNS__Entries_Static___/g" -e "s/___Verbose_Static___//" /tmp/userdata_mgmt.sh
  fi
   sed -i -e 's/__UPGRADE_TO_BASE__/___UPGRADE_TO_BASE_Static___/' /tmp/userdata_mgmt.sh
  sed -i -e "/___FABFILE.PY_CONTENTS___/r /tmp/fabfile.py" -e "/___FABFILE.PY_CONTENTS___/d" /tmp/userdata_mgmt.sh
  sed -i -e "s/__project__/___PROJECT___/g" /tmp/userdata_mgmt.sh
/bin/bash /tmp/userdata_mgmt.sh
rm -f /tmp/userdata.sh /tmp/fabfile.py

