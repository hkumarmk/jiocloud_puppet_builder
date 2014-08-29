#!/bin/bash
trap  "_finish" 0 1 2 3 9 15

## Function to cleanup the files and sub processes
function _finish() {
  rv=${1:-$?};
  pkill -9 -P $$
#  destroyResources
#  kill 0
  rm -fr /dev/shm/lines.$$ /dev/shm/number.$$
  exit $rv
}


### Creates resources on overcloud
function createResourcesOnOverCloud() {
  lg Creating Resources on overcloud
  export OS_NO_CACHE='true'
  export OS_USERNAME=admin
  export OS_TENANT_NAME='admin'
  export OS_PASSWORD='Chang3M3'
  export OS_AUTH_URL=https://${project}.jiocloud.com:5000/v2.0
  export OS_AUTH_STRATEGY='keystone'
  export OS_REGION_NAME='TestCloud'
  export CINDER_ENDPOINT_TYPE='publicURL'
  export GLANCE_ENDPOINT_TYPE='publicURL'
  export KEYSTONE_ENDPOINT_TYPE='publicURL'
  export NOVA_ENDPOINT_TYPE='publicURL'
  export NEUTRON_ENDPOINT_TYPE='publicURL'
  lg Creating Tenant - demo
  [ `keystone tenant-get demo 2> /dev/null | grep -c "enabled\s*|\s*True"` -eq 0 ] && keystone tenant-create --name demo;
  lg Creating user demo with _member_ role in tenant demo
  [ `keystone user-get demo 2> /dev/null | grep -c "enabled\s*|\s*True"` -eq 0 ] && keystone user-create --name demo --pass demo;
  [ `keystone user-role-list --user demo --tenant demo 2> /dev/null | grep -c _member_` -eq 0 ] && keystone user-role-add --user demo --role _member_ --tenant demo;
  [ `keystone user-role-list --user admin --tenant demo 2> /dev/null | grep -c admin` -eq 0 ] && keystone user-role-add --user admin --role admin --tenant demo;
  lg Creating Images
  if [ `glance image-show ubuntu-12.04 2> /dev/null | grep -c "status\s*|\s*active"` -eq 0 ]; then
    curl http://10.135.96.60/vm_images/ubuntu-12.04-server-cloudimg-amd64-disk1.img > $tmp/12.04.img
    glance image-create --name ubuntu-12.04 --disk-format qcow2 --container-format bare --is-public True < $tmp/12.04.img
    rm -f $tmp/12.04.img
  fi
  if [ `glance image-show ubuntu-14.04 | grep -c "status\s*|\s*active"` -eq 0 ]; then
    curl http://10.135.96.60/vm_images/trusty-server-cloudimg-amd64-disk1.img> $tmp/14.04.img
    glance image-create --name ubuntu-14.04 --disk-format qcow2 --container-format bare --is-public True < $tmp/14.04.img
    rm -f $tmp/14.04.img
  fi

  export OS_TENANT_NAME='demo'
  lg Creating Network in demo tenant - demo-network
  [ `neutron net-show demo-network | grep -ic "status\s*|\s*ACTIVE"` -eq 0 ] && neutron net-create demo-network ;
  if [ ${create_ipam:-0} -eq 1 ]; then
    lg Creating IPAM demo-ipam
    [ `neutron ipam-list | grep -c demo-ipam` -eq 0 ] && neutron ipam-create demo-ipam
  fi
  lg Creating subnet demo-subnet with cidr 10.1.0.0/24
  [ `neutron subnet-list | grep -c 10.1.0.0/24` -eq 0 ] && neutron subnet-create demo-network 10.1.0.0/24 --name demo-subnet ;
  imagelist=`glance image-list | awk '/qcow2/ {print $2}'`
  netid=`neutron net-show demo-network | awk '/\| *id/ { print $4}'`
  echo "__Returns__: image_list: `echo $imagelist`, netid: $netid"
}


### Forks as sub processes,
## Check the vm console using nova-console and rebuild the vm if it stuck on boot.
## There was some situations where vm boot stuck on cloud-init, this function will fix that situation
function check_boot() {
  lg Checking the state of $1
  num_check=${2:-0}
  vm_state=0
  print_started=0
  if [ $1 == "ct1" ]; then
    check_duration=30
  else
    check_duration=10
  fi
  while [ $vm_state == 0 ]; do
    sleep $check_duration
    vm_state=`nova list --name $1 | grep -c ACTIVE`
  done
  if [ $1 == "ct1" ]; then
    lg $1 is booting normally
    return 0
  fi
}

function lg() {
  echo "`date`|$*"
}



function usage() {
  printf "\n$*\n"
  printf "Usage: $0 -u <user name> [-v] [-t <tenant>] [-P <overcloud admin password> ] [-R <overcloud region> [-c <number of compute nodes>] [-s <number of storage nodes>] [-p <password>] [ -l ] [ -d ] [-B <Version>] [-T <version>] \n\n-u <user name>\t User name who have admin access to admin project\n-c <number of compute nodes>\tNumber of compute nodes to be spawned, default is 3\n-s <number of storage nodes>\tNumber of storage nodes to be spawned, default 3\n-t <tenant>\tTenant to be used (default is testproj_<pid>)\n-p <password>\tuser password\n-l\tUse datacenter internal floating IP, default is public floating IP\n-d\t Delete project and all components in it,\n-v\tVerbose output\n-B <version>\tBase snapshot version\n-T <version>\tTarget snapshot version\n-R <overcloud Region>\t Overcloud Region name\n-P <overcloud admin/service user password>\tOvercloud admin and service user password" 
  exit 0
}

function rebuildServers() {
  lg Rebuilding All servers
  for node in `nova list | awk '{print $4}'| grep -v "Name\|^ *$"`; do
    nova rebuild $node ubuntu12.04 > /dev/null
    check_boot $node
  done
}

function destroyResources() {
  export OS_TENANT_NAME="$tenant"
  #
  # Disassociate and delete the ip address. We need to do this first
  # so that we can use the subnet to ensure that we delete the floating
  # ip from the correct port
  #
  lb_id=`nova show lb1_$project 2> /dev/null | awk '/\| *id *\|/ {print $4}'`
  if [ `echo $lb_id  | grep -c "[a-z]"` -ne 0 ]; then
    fip=`nova floating-ip-list | grep $lb_id | awk '{print $2}'`
    if [ `echo $fip | grep -c "[0-9]"` -ne 0 ]; then
      fip_id=`neutron floatingip-list |grep $fip | awk '{print $2}'`
      lg "Deleting floating IP $fip"
      neutron floatingip-disassociate $fip_id || _retry 1 neutron floatingip-disassociate $fip_id
      neutron floatingip-delete $fip_id || _retry 1 neutron floatingip-delete $fip_id
    fi
  fi
  nova keypair-delete $project > /dev/null 
  pkill -9 -P $$
  lg "Deleting VMs"
  for nd in `nova list | grep $project | awk '{print $2}'`; do
    lg Deleting VM $nd
    nova delete $nd;
  done
  sleep 5;
  while [ `nova list | grep $project | awk '{print $2}' | wc -l` -ne 0 ]; do
    sleep 3;
  done
  sleep 3
  
  lg "Deleting the Networks"
  neutron net-delete "stg_access_${project}" || _retry 1 neutron net-delete "stg_access_${project}"
  neutron net-delete "stg_cluster_${project}" || _retry 1 neutron net-delete "stg_cluster_${project}"
  neutron net-delete "sdn_${project}" || _retry neutron 1 net-delete "sdn_${project}"


  if [ ${create_ipam:-0} -eq 1 ]; then
    neutron ipam-delete ipam1 || _retry 1 neutron ipam-delete ipam1
  fi
  exit
}

function _retry() {
  echo ; return
  retry_num=${1:-1}
  shift
  command=$*
  max_retry=5
  lg Warn $command failed, retrying
  while [ $retry_num -le $max_retry ]; do
    $command || _retry $retry_num $command
  done
}

function _fail() {
  lg $*, Rolling back.
#  _finish 100
  # TODO do not leave this uncommented!!!
  destroyResources
  exit 100
}

# download Puppet content
function setupPuppet() {
  pushd $tmp/jiocloud_puppet_builder
  if ! gem list librarian-puppet-simple | grep librarian-puppet-simple ; then
    sudo apt-get install -y ruby1.9.1 rubygems
    sudo gem install --no-ri --no-rdoc librarian-puppet-simple
  fi
  librarian-puppet install
  popd
}

### This will create temporary directory
### Copy all files to be moved to the cloud to tempoarry directory
### $tmp will be exported so other functions can push the files to this directory
### Finally fab will transfer this $tmp to cloud systems

function setupTmpDir() {
  relative_path="`dirname $0`/../"
  puppet_builder_location=`readlink -f $relative_path`
  [ -d $puppet_builder_location/tmp/old ] || mkdir -p $puppet_builder_location/tmp/old
  [ -e $puppet_builder_location/tmp/$project ] && mv $puppet_builder_location/tmp/$project $puppet_builder_location/tmp/old/$project.`date +%Y-%m-%d_%H-%M`
  export tmp="$puppet_builder_location/tmp/$project"
  mkdir $puppet_builder_location/tmp/$project 
  mkdir $tmp/jiocloud_puppet_builder
  cp -r $puppet_builder_location/bin  $puppet_builder_location/hiera  $puppet_builder_location/manifests  $puppet_builder_location/Puppetfile  $puppet_builder_location/resource_spawner $tmp/jiocloud_puppet_builder
}


function setupHiera() {
  pushd ../
  if [ -f $tmp/jiocloud_puppet_builder/resource_spawner/fabric.yaml ]; then
    cp $tmp/jiocloud_puppet_builder/resource_spawner/fabric.yaml{,.save}
  fi
  echo '' > $tmp/jiocloud_puppet_builder/resource_spawner/fabric.yaml
  addHieraData target_version $target_version
  addHieraData project $project
  [ $base_version -ne 0 ] && addHieraData base_version $base_version
  addHieraData 'fabric::floating_ip' $fip
  addHieraData 'fabric::dir_to_copy' $tmp
  [ $verbose -ne 0 ] && addHieraData 'fabric::verbose' yes
  addHieraData 'fabric::auth_user' $user
  addHieraData 'fabric::auth_password' $passwd
  addHieraData 'fabric::auth_tenant' $tenant
  addHieraData 'fabric::auth_url' $url
  addHieraData 'fabric::user_yaml' jiocloud_puppet_builder/hiera/user.yaml
  addHieraData 'fabric::ssh_key' "$tmp/id_rsa"
  popd
}

function addHieraData() {
  echo "$1: $2" >> $tmp/jiocloud_puppet_builder/resource_spawner/fabric.yaml
}

function createResources() {
  lg "Generate key and export it to openstack"
  ### Generate key and export it.
  ssh-keygen -f $tmp/id_rsa -t rsa -N ''
  nova keypair-add --pub-key $tmp/id_rsa.pub $project > /dev/null ||  _fail "Kepair addition failed for $project"

  if [ ${create_flavors:-0} -eq 1 ]; then
    # TODO There is an issue with flavor creation
    # the commands to list/show flavors do not work on Havana,
    # therefor, we are ignoring failures when we try to create
    # flavors. This is obviously problematic for cases where
    # there are unexpected failures, but this should rarely happen
    # (b/c the flavors only need to be created once on each tenant)
    for flavor in m1.controller m1.compute m1.contrail m1.storage; do
      lg Adding flavor $flavor
      if [ $flavor == 'm1.controller' ]; then
        mem=4096; disk=20; swap=2048; vcpu=4
      elif [ $flavor == 'm1.compute' ]; then
        mem=8192;  disk=20; swap=4096; vcpu=8; ephemeral="--ephemeral 500"
      elif [ $flavor == 'm1.contrail' ]; then
        mem=8192;  disk=20; swap=4096; vcpu=4
      elif [ $flavor == 'm1.storage' ]; then
        mem=2048; disk=20; swap=1048; vcpu=4; ephemeral="--ephemeral 50"
      fi
      lg  Creating flavor $flavor
      nova flavor-create $flavor $flavor $mem $disk $vcpu --swap $swap --is-public=false $ephemeral > /dev/null || true
    done
  fi

  # I am pretty sure this is no longer needed
  #glance member-create 3f855d6f-c054-4d51-add0-41a96122b13a $tid

  proj_synced=0;
  num_try=1;
  failed_sync=0;

  lg "Creating Networks"

  sdn_net="sdn_${project}"
  stg_access_net="stg_access_${project}"
  stg_cluster_net="stg_cluster_${project}"

  neutron net-create $sdn_net > /dev/null ||  _fail Network creation $sdn_net  failed
  neutron net-create $stg_access_net > /dev/null ||  _fail Network creation $stg_access_net failed
  neutron net-create $stg_cluster_net > /dev/null ||  _fail Network creation $stg_cluster_net failed
  if [ ${create_ipam:-0} -eq 1 ]; then
    lg "Creating IPAM ipam1"
    # TODO check if it exists, and just warn
    neutron ipam-create ipam1 > /dev/null ||  _fail IPAM create failed
  fi
  lg Creating Subnets
  # TODO maybe we want to make the subnets configurable eventually...
  neutron subnet-create $sdn_net 10.0.0.0/24 > /dev/null ||  _fail subnet create sdn failed
  neutron subnet-create $stg_access_net 10.1.0.0/24 > /dev/null ||  _fail subnet create stg_access failed
  neutron subnet-create $stg_cluster_net 10.2.0.0/24 > /dev/null ||  _fail subnet create stg_cluster failed
  stg_cluster_nw_id=`neutron net-list | grep $stg_cluster_net | awk '{print $2}'`
  stg_access_nw_id=`neutron net-list | grep $stg_access_net | awk '{print $2}'`
  sdn_nw_id=`neutron net-list | grep $sdn_net | awk '{print $2}'`
  lg Booting VMs
  ct1_name="ct1_$project"
  db1_name="db1_${project}"
  st1_name="st1_${project}"
  st2_name="st2_${project}"
  st3_name="st3_${project}"
  oc1_name="oc1_${project}"
  oc2_name="oc2_${project}"
  lb1_name="lb1_${project}"
  if [ $contrail_fresh_vm -eq 0 ]; then
    lg Booting contrail VM
    # TODO move the specification of networks and ip addresses to an external
    # config file
    nova boot --flavor m1.medium --image 3f855d6f-c054-4d51-add0-41a96122b13a --meta host_type=ct $ct1_name --nic net-id=${stg_access_nw_id},v4-fixed-ip=10.1.0.245 > /dev/null ||  _fail nova boot $ct1_name failed.
  else
    nova boot --flavor m1.contrail --image ubuntu12.04 --key-name $project  --meta host_type=ct $ct1_name --nic net-id=${stg_access_nw_id},v4-fixed-ip=10.1.0.245 > /dev/null ||  _fail nova boot $ct1_name failed.
    check_boot $ct1_name &
  fi

  nova boot --flavor m1.controller --image ubuntu12.04 --key-name $project  --meta host_type=db $db1_name --nic net-id=${stg_access_nw_id},v4-fixed-ip=10.1.0.10 > /dev/null ||  _fail nova boot $db1_name failed
  check_boot $db1_name &
  nova boot --flavor m1.storage --image ubuntu12.04 --key-name $project  --meta host_type=st $st1_name --nic net-id=${stg_access_nw_id},v4-fixed-ip=10.1.0.51 --nic net-id=${stg_cluster_nw_id},v4-fixed-ip=10.2.0.51 > /dev/null ||  _fail nova boot $st1_name failed

  check_boot $st1_name &
  nova boot --flavor m1.storage --image ubuntu12.04 --key-name $project  --meta host_type=st $st2_name --nic net-id=${stg_access_nw_id},v4-fixed-ip=10.1.0.52 --nic net-id=${stg_cluster_nw_id},v4-fixed-ip=10.2.0.52 > /dev/null ||  _fail nova boot $st2_name failed

  check_boot $st2_name &
  nova boot --flavor m1.storage --image ubuntu12.04 --key-name $project  --meta host_type=st $st3_name --nic net-id=${stg_access_nw_id},v4-fixed-ip=10.1.0.53 --nic net-id=${stg_cluster_nw_id},v4-fixed-ip=10.2.0.53 > /dev/null ||  _fail nova boot $st3_name
  check_boot $st3_name
  nova boot --flavor m1.controller --image ubuntu12.04 --key-name $project  --meta host_type=oc $oc1_name --nic net-id=${stg_access_nw_id},v4-fixed-ip=10.1.0.11 > /dev/null ||  _fail nova boot $oc1_name failed
  check_boot $oc1_name &
  nova boot --flavor m1.controller --image ubuntu12.04 --key-name $project  --meta host_type=oc $oc2_name --nic net-id=${stg_access_nw_id},v4-fixed-ip=10.1.0.12 > /dev/null ||  _fail nova boot $oc2_name failed
  check_boot $oc2_name &


  for num in `seq $num_cp`; do
    nova boot --flavor m1.compute --image ubuntu12.04 --key-name $project  --meta host_type=cp "cp${num}_${project}" --nic net-id=${stg_access_nw_id} --nic net-id=${sdn_nw_id}> /dev/null ||  _fail nova boot "cp${num}_${project}" failed
    check_boot "cp${num}_${project}" &
  done

  for num in `seq $num_st`; do
    if [ $num -gt 3 ]; then
      nova boot --flavor m1.storage --image ubuntu12.04 --key-name $project --meta host_type=st "st${num}_${project}"  --nic net-id=${stg_access_nw_id} --nic net-id=${stg_cluster_nw_id} > /dev/null ||  _fail nova boot "st${num}_${project}" failed
      che "st${num}_${project}" &
    fi
  done


  if [ $num_st -gt 3 ]; then
    total_vms=$((7+$num_cp+$num_st-3))
  else
    total_vms=$((7+$num_cp))
  fi
  vms_up=0;
  num_try=1;
  failed=0;
  lg Waiting all cloud systems in active state
  while [ $vms_up -lt $total_vms ]; do
    sleep 10
    nova_list=`nova list | grep $project`
    vms_up=`echo "$nova_list" | grep -c ACTIVE`
    vms_error=`echo "$nova_list" | grep -c ERROR`
    if [ $vms_error -gt 0 ]; then
	_fail One or more VMs failed to spawn
    fi
    num_try=$(($num_try+1))
    if [ $num_try -gt 300 ]; then
      failed=1
      vms_up=$total_vms
    fi
  done
  if [ $failed -eq 0 ]; then

    nova boot --flavor m1.small --image ubuntu12.04 --key-name $project --meta host_type=lb $lb1_name --nic net-id=${stg_access_nw_id},v4-fixed-ip=10.1.0.5 > /dev/null ||  _fail nova boot $lb1_name failed
    check_boot $lb1_name &

  fi

  lb_vm_state=0
  failed_lb_vm_up=0
  num_try=0
  lg waiting for management VM to be up
  while [ $lb_vm_state == 0 ]; do
    sleep 5
    lb_vm_state=`nova list | grep $lb1_name | grep -c ACTIVE`
    if [ $num_try -gt 40 ]; then
      failed_lb_vm_up=1
      lb_vm_state=1
    fi
  done
#  check_boot lb_vm1 &
  if [ $failed_lb_vm_up -eq 1 ]; then
    lg "ERR...Something went bad.... management vm is not coming up. rolling back"
    _finish 100
  fi

  lg Creating Floating IP

  fip=`neutron floatingip-create $floatingpool | grep floating_ip_address | awk -F'|' '{print $3}'`; rv=$?
  if [ $rv -ne 0 ]; then
    fip=`neutron floatingip-create $floatingpool | grep floating_ip_address | awk -F'|' '{print $3}'` || _fail floatingip-create failed
  fi
  fip_id=`neutron floatingip-list  | grep $fip | awk -F'|' '{print $2}'`
  lb_addr=`nova show ${lb1_name} | grep ${stg_access_net} | awk -F'|' '{print $3}'`
  subnet_id=`neutron net-show ${stg_access_net} | grep subnets | awk -F' ' '{print $4}'`
  lb1_port_id=`neutron port-list | grep ${subnet_id} | grep "$(echo $lb_addr | awk '{print $1}')\"" | awk '{print $2}'`
  lg Associating floating IP $fip to lb1
  neutron floatingip-associate $fip_id $lb1_port_id > /dev/null ||  _fail floatingip associate $fip failed

# check default security group exists or not
  secgroup="default"
  lg finding security group default
#  "id","security_group","direction","protocol","remote_ip_prefix","remote_group"
  neutron security-group-list --format csv | egrep "\"${secgroup}\"" 2>&1 > /dev/null || _fail security group rule does not exists and hence failing
	 
  lg "security group $secgroup exists, hence adding (if necessary) group rules to $secgroup"

  secrules=`neutron  security-group-rule-list -c security_group -c direction -c protocol -f csv | grep default | sed 's/\"//g'` || \
	  _fail something went wrong while trying to check for security group rules

  echo "$secrules" | grep ingress | grep tcp > /dev/null || \
	neutron security-group-rule-create --direction ingress --protocol tcp default > /dev/null ||  \
	_fail "security group rule creation failed in ingress tcp"

  echo "$secrules" | grep ingress | grep udp >/dev/null || \
	neutron security-group-rule-create --direction ingress --protocol udp default > /dev/null ||  \
	_fail "security group rule creation failed in ingress udp"

  echo "$secrules" | grep ingress | grep icmp > /dev/null || \
	neutron security-group-rule-create --direction ingress --protocol icmp default > /dev/null || \
       	_fail "security group rule creation failed in ingress icmp"

  echo "$secrules" | grep egress | grep tcp > /dev/null || \
	neutron security-group-rule-create --direction egress --protocol tcp default > /dev/null || \
       	_fail "security group rule creation failed in egress tcp"
  
  echo "$secrules" | grep egress | grep udp > /dev/null || \
          neutron security-group-rule-create --direction egress --protocol udp default > /dev/null || \
          _fail "security group rule creation failed in egress udp"

  echo "$secrules" | grep egress | grep icmp > /dev/null || \
          neutron security-group-rule-create --direction egress --protocol icmp default > /dev/null || \
          _fail "security group rule creation failed in egress icmp"


}

### Starts here
contrail_fresh_vm=0
delete=0
local=0
num_cp=0
num_st=3
logfile=/tmp/spawn_resource_$$.log
fail=0
verbose=0
nova_rebooted=0
base_version=0
target_version=0
while getopts "giBIf:bvdc:s:r:k:t:u:p:T:P:t:z:F:" OPTION; do
  case "${OPTION}" in
    u)
      user=${OPTARG}
      ;;
    p)
      passwd=${OPTARG}
      ;;
    g)
      contrail_fresh_vm=1
      ;;
    r)
      region=${OPTARG:-"P1_mum"}
      ;;
    c)
      num_cp=${OPTARG:-3}
      ;;
    s)
      num_st=${OPTARG:-3}
      ;;
    t)
      tenant=${OPTARG}
      ;;
    B)
      base_version=${OPTARG}
      ;;
    T)
      target_version=${OPTARG}
      ;;
    k)
      url=${OPTARG:-'https://identity-beta.jiocloud.com/v2.0/'}
      ;;
    d)
      delete=1
      ;;
    v)
      verbose=1
      ;;
    P)
      overcloud_admin_password=${OPTARG}
      ;;
    R)
      overcloud_region=${OPTARG}
      ;;
    I)
      create_ipam=1
      ;;
    z)
      id=${OPTARG}
      ;;
    f)
      create_flavors=1
      ;;
    F)
      floatingpool=${OPTARG}
      ;;
    *)
      usage Invalid parameter
      ;;
  esac
done

[ -z $user ] && usage User name must be provided
[ $target_version -eq 0 ] && usage Target version must be provided
if [ -z $tenant ]; then
  usage "Tenant must be provided"
fi
if [ -z $id ]; then
  usage "project is required (and is set with -z b/c we ran out of reasonable letters)"
fi

if [ -z $passwd ]; then
  echo -n "Enter password: "
  stty -echo
  read passwd;
  stty echo
fi
project=$id
overcloud_admin_password=${overcloud_admin_password:-"Chang3M3"}
overcloud_region=${overcloud_region:-"RegionOne"}
url=${url:-'https://identity-beta.jiocloud.com/v2.0/'}
region=${region:-"P1_mum"}
num_cp=${num_cp:-3}
num_st=${num_st:-3}
num_st=3
floatingpool=${floatingpool:-'local-public-two'}
export OS_NO_CACHE='true'
export OS_USERNAME=$user
export OS_TENANT_NAME=${tenant}
export OS_PASSWORD=$passwd
export OS_AUTH_URL=${url}
export OS_AUTH_STRATEGY='keystone'
export OS_REGION_NAME=${region}
export CINDER_ENDPOINT_TYPE='publicURL'
export GLANCE_ENDPOINT_TYPE='publicURL'
export KEYSTONE_ENDPOINT_TYPE='publicURL'
export NOVA_ENDPOINT_TYPE='publicURL'
export NEUTRON_ENDPOINT_TYPE='publicURL'


echo;
if [ $delete -eq 1 ]; then
  destroyResources
fi
if [ `echo $project | grep -c _` -ne 0 ]; then
  usage "Invalid tenant name \"_\" is not allowed"
fi

### git_protocol - this can be a configuration/argument
export git_protocol=${git_protocol:-"https"}


## setupTmpDir: Setup $tmp - temp directory and copy fabfile and userdata to that directory
setupTmpDir

pwd=`pwd`
setupPuppet
createResources
setupHiera
exit 0
