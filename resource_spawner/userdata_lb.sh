#!/bin/bash
echo "`date` Starting userdata execution"
curl http://10.135.120.107:8080/userdata/userdata_lb_static.sh > /tmp/userdata_lb.sh 2> /dev/null
sed -i -e 's/__project__/___PROJECT___/g' -e 's/___BASE_SNAPSHOT_VERSION___/___BASE_SNAPSHOT_VERSION_STATIC___/g' -e 's/___TARGET_SNAPSHOT_VERSION___/___TARGET_SNAPSHOT_VERSION_STATIC___/g' /tmp/userdata_lb.sh
/bin/bash /tmp/userdata_lb.sh
rm -f /tmp/userdata_lb.sh

