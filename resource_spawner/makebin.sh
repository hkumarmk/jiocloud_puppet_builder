#!/bin/bash -v
export tmp=`mktemp -d /tmp/selfextract.XXXXXX`
tar zcf $tmp/spawn_resources_files.tar.gz userdata* fabfile.py
cp spawn_resources.sh $tmp
cat $tmp/spawn_resources.sh $tmp/spawn_resources_files.tar.gz > spawn_resources.bin
rm -rf $tmp
chmod +x spawn_resources.bin
