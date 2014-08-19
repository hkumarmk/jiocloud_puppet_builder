#!/bin/bash -v
tar zcf /tmp/spawn_resources_files.tar.gz userdata* id_rsa.pub fabfile.py
cd ../
cat source/spawn_resources.sh /tmp/spawn_resources_files.tar.gz > spawn_resources.bin
rm -f /tmp/spawn_resources_files.tar.gz
chmod +x spawn_resources.bin
