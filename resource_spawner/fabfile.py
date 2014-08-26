import os
import re
import copy
import tempfile
import time
import datetime
import subprocess
import paramiko
import commands
import json
import pycurl
import cStringIO
import yaml


from fabric.api import env,parallel, roles, run, settings, sudo, execute,hide
from fabric.operations import run, put,sudo
from fabric.state import output
from fabric.exceptions import CommandTimeout
from time import sleep

paramiko.util.log_to_file("/dev/null")

### If upgrade target is not specified take the default value "target" for target snapshot
try: env.upgrade
except Exception:  env.upgrade =  'target'

### Set default values for servers if not set in commandline
try: env.ocservers
except Exception:  env.ocservers =  ''
try: env.cpservers
except Exception:  env.cpservers =  ''
try: env.stservers
except Exception:  env.stservers =  ''
try: env.lbservers
except Exception:  env.lbservers =  ''
try: env.dbservers
except Exception:  env.dbservers =  ''

### Set roles here

env.roledefs = {
  'oc': env.ocservers.split(':'),
  'cp': env.cpservers.split(':'),
  'st': env.stservers.split(':'),
  'lb': env.lbservers.split(':'),
  'db': env.dbservers.split(':'),
  'all': env.lbservers.split(':') + env.dbservers.split(':') + env.ocservers.split(':') + env.cpservers.split(':') + env.stservers.split(':'),
}

## rdYaml: Read yaml from a file and return a dict object
## Arguments:
### file: file path to read
## Return: python dict object

def rdYaml(file_path):
  fs = file(file_path,'r')
  output =  yaml.load(fs)
  return output

## wtYaml: take a python object and write to provided file.
## Arguments:
## data: python dictionary object
## file_path: file path
## append: True or False whether to append existing the yaml file or not

def wtYaml(data,file_path,append=False):
  if append == False:
    fs = file(file_path,'w')
  else:
    fs = file(file_path,'a')

  yaml.dump(data,fs)


## initiateSetup: initiate the new setup from caller machines usually this will be jenkins server
### Arguments: 
#### dir - this is path to the directory which must contain all data to be passwed to the new system
###        This directory will be copied over to remote location and run scripts and fab from it
#### fabfile.py - this file will be served fab runs on the jumphost/lb server on the test cloud
#### userdata.sh - this script does basic setup and installs puppet on the systems
#### ssh private key - this will be transferred to lb server, so that it can be used as jumphost, 
#####                  this key will be used by fab to login to other servers
### This will call fab from lb/jumphost server
## Example: fab -f fabfile  -i /tmp/resource_spawner.mmlmit/id_rsa -u ubuntu -H 10.135.97.125 --set cpservers=10.1.0.253:10.1.0.252,ocservers=10.1.0.11:10.1.0.12,stservers=10.1.0.51:10.1.0.52:10.1.0.53,dbservers=10.1.0.10,lbservers=10.1.0.5,cloudname=harish1112 initiateSetup:dir=/tmp/resource_spawner.mmlmit,verbose=verbose

def initiateSetup(dir,verbose='no'):
  ### Print stdout and error messages only on verbose 
  if verbose.upper() == 'NO':
    output.update({'running': False, 'stdout': False, 'stderr': False})

  log("Copying the files to lb node")
  ## Make a tar of the directory and send to remote
  base_dir=os.path.basename(dir)
  os.system('cd %s; tar zcf  %s.tar.gz %s' % (os.path.dirname(dir),base_dir,base_dir))

  ## Copy files to lb
  execute(putFiles,hosts=env.host,files = {dir + ".tar.gz": '/tmp'})

  ### Untar and copy fab file and ssh private key and puppet code to lb
  run('cd /tmp; tar  -zxf %s.tar.gz; cp -r /tmp/%s/jiocloud_puppet_builder/resource_spawner/fabfile.py ~/; cp -f /tmp/%s/id_rsa ~/.ssh' % (base_dir,base_dir,base_dir))
  sudo ('cp -r /tmp/%s/jiocloud_puppet_builder /var/puppet' % base_dir) 

  log("Setting up the system on %s" % env.host)

  log("Run userdata.sh on lb node")
  sudo("bash /tmp/%s/jiocloud_puppet_builder/resource_spawner/userdata.sh  -r lb" % base_dir)

  log("Run fab from lb1 to setup the cloud: %s" % env.project)

  ## Enable output - it is required to print inner fab messages
  output.update({'running': True, 'stdout': True, 'stderr': True})

  run('fab -f ~/fabfile  -i ~ubuntu/.ssh/id_rsa --set cpservers=%s,ocservers=%s,stservers=%s,dbservers=%s,lbservers=%s setup:/tmp/%s,verbose:%s,verify=%s'  % (env.cpservers,env.ocservers,env.stservers,env.dbservers,env.lbservers, base_dir,verbose,False))
#  log("Verify the cloud")
#  sudo('fab -f ~ubuntu/%s/fabfile checkAll' % dir)

##Python logger doesnt work with fab
def log(msg):
  print str(datetime.datetime.now()) + ' ' + msg

##This Function to get the token from keystone 
##This Function will return the keystone response in json 
def getToken(username, password, tenantname, keystoneurl):
    postData = '{"auth": {"tenantName": "%s",\
        "passwordCredentials":{"username":"%s", "password": "%s"}\
        }}' % (tenantname, username, password)
    response = cStringIO.StringIO()
    try:
        c = pycurl.Curl()
        c.setopt(pycurl.URL, keystoneurl)
        c.setopt(pycurl.HTTPHEADER, ['Content-Type:application/json'])
        c.setopt(pycurl.POST, 1)
        c.setopt(pycurl.POSTFIELDS, postData)
        c.setopt(c.WRITEFUNCTION, response.write)
        c.perform()
        status_code = c.getinfo(pycurl.HTTP_CODE)
        if status_code == 200:
            return response
        else:
            log(response.getvalue())
            response.close()
            response = cStringIO.StringIO()
            response.write("NULL")
            return response
    except Exception, err:
        print Exception, err
        response.close()
        response = cStringIO.StringIO()
        response.write("NULL")
        return response

##This function will return vm list in json format
def getVmList(token, nova_endpoint):
    response = cStringIO.StringIO()
    xauth = str("X-Auth-Token: %s" % token)
    try:
        c = pycurl.Curl()
        c.setopt(pycurl.URL, nova_endpoint)
        c.setopt(pycurl.HTTPHEADER, [xauth])
        c.setopt(c.WRITEFUNCTION, response.write)
        c.perform()
        status_code = c.getinfo(pycurl.HTTP_CODE)
        if status_code == 200:
            return response
        else:
            log(response.getvalue())
            response.close()
            response = cStringIO.StringIO()
            response.write("NULL")
            return response
    except Exception, err:
        print Exception, err
        response.close()
        response = cStringIO.StringIO()
        response.write("NULL")
        return response


##This Function will create a yaml file which will be having hostname and ipaddress 
def createResourceYaml(username, password, tenant_name, auth_url, project_name, file_path):
    nodes = {}
    DataFound = getToken(username, password, tenant_name, auth_url)
    if DataFound.getvalue() != "NULL":
        datajson = json.loads(DataFound.getvalue())
        token = datajson['access']['token']['id']
        nova_endpoint = str(datajson['access']['serviceCatalog']
                            [0]['endpoints'][0]['publicURL']+"/servers/detail")
        DataNova = getVmList(token, nova_endpoint)
        if DataNova.getvalue() != "NULL":
            data_nova = json.loads(DataNova.getvalue())
            for vm in data_nova['servers']:
                name_vm = vm['name']
                split_name = name_vm.split("_")
                storage_access = "stg_access_%s" % project_name
                try:
                    if split_name[1] == project_name:
                        vm_meta = vm['metadata']['host_type']
                        if nodes.has_key(vm_meta):
                            nodes[vm_meta].update({str(split_name[0]):
                                          str(vm['addresses']
                                          [storage_access][0]['addr'])})
                        else:
                            nodes.update({str(vm_meta):{str(split_name[0]):
                                                   str(vm['addresses']
                                                   [storage_access][0]['addr'])}})
                except:
                    log("Variable Not Initialized")
            wtYaml(nodes, file_path, True)
            return 0
        else:
            log("Nova api call failed")
            return 100
    else:
        log("Keystone Api call failed")
        return 100


## This expect a dictionary of files with source -> destination format 
## will files from source directory to destination

@parallel
def putFiles(files,run_type=run):
#  with hide('warnings'), settings(warn_only = True):
    for key in files:
      print "%s -> %s" % (key,files[key])
      ## Make parent directory
      run_type('mkdir -p %s' % files[key])
      if run_type == sudo:
        put (key,files[key],use_sudo=True)
      else:
        put(key,files[key])

## run commands parallel on specified machines
### command - an arbiterary command
### run_type - two values - run, sudo, to determine whether to run as current user or root

@parallel
def runCommand(cmd,run_type):
  if run_type == 'sudo':
    sudo(cmd)
  elif run_type == 'run':
    run(cmd)
  else:
    log("No valid runtype %s" % run_type)


## Setup the entire system 
### Copy userdata file  to /tmp of all systems - roldefs['all']
### Run userdata file to do basic setup and install puppet
### Run puppet on the systems to setup openstack and other applications

def setup(dir,verbose='no',verify=False):
  """Setup the entire cloud system""" 
  timeout = 5
  maxAttempts = 40
  if verbose.upper() == 'NO':
    output.update({'running': False, 'stdout': False, 'stderr': False})
  log("Waiting till all servers are sshable")
  while not verifySshd(env.roledefs['all'],'ubuntu'):
      sleep(5)
      continue
  log("all nodes are sshable now")
  log("Copy data to All except lb servers")
  nodes_to_run_userdata =  env.roledefs['oc'] + env.roledefs['cp'] + env.roledefs['cp'] + env.roledefs['st'] + env.roledefs['db']

  ## Make tar
  log("Making tar")
  os.system('cd %s/..; tar zcf  %s.tar.gz %s' % (dir,dir,os.path.basename(dir)))
  ## Copy the tar
  log("Copy tar files")
  execute(putFiles,hosts=nodes_to_run_userdata,files = {dir + ".tar.gz": '/tmp'})

  log("Running userdata script on all servers")
  ## Untar, copy puppet files, run userdata
  command_to_run='tar -C %s -zxf %s.tar.gz; cp -r %s/jiocloud_puppet_builder  /var/puppet/; bash %s/jiocloud_puppet_builder/resource_spawner/userdata.sh -r non-lb -p http://%s:3128' % (os.path.dirname(dir),dir,dir,dir,env.roledefs['lb'][0])

  execute(runCommand,hosts=nodes_to_run_userdata,cmd=command_to_run,run_type="sudo")

  status = 1
  attempt = 1
  ## Configure contrail vm - this is only applicable for 
  ## vm spawned from contrail golden image
  log("Configuring contrail node")
  execute(configContrail,hosts='10.1.0.245')
  ## Run puppet - first run on all servers
  log("Initial execution of puppet run on storage")
  with hide('warnings'), settings(warn_only = True):
    execute(runPapply,hosts=env.roledefs['all'])
  
  ## Reduce the wait time for cloud-init-nonet on cp nodes as they have vhost0 which would not be coming up by that.
    execute(reduceCloudinitWaitTime,hosts=env.roledefs['cp'])
  
## Run papply on LB and DB nodes
  log("Running papply on LB and db nodes")
  with hide('warnings'), settings(warn_only = True):
    execute(runPapply,hosts=['10.1.0.5','10.1.0.10','10.1.0.53','10.1.0.52','10.1.0.51'] ) 

  ## Sync the time initially to avoid ntp to take longer to sync te clocks.
    log("Executing ntpdate for initial time sync")
    try: 
      execute(runNtpdate,hosts='10.1.0.5')
    except Exception:
      log('Failed time sync on lb, retrying')
      execute(runNtpdate,hosts='10.1.0.5')
    try:
      execute(runNtpdate,hosts=env.roledefs['all'])
    except Exception:
      log('Failed time sync on lb, retrying')
      execute(runNtpdate,hosts=env.roledefs['all'])
  ##
  log("Checking ceph mon status")
  with hide('warnings'), settings(host_string = '10.1.0.53', warn_only = True):
    st_ceph_mon = sudo ("ceph mon stat | grep st1,st2,st3")
    if st_ceph_mon.return_code != 0:
      log("Ceph Mons are not up, fixing")
      while st_ceph_mon.return_code != 0:
        execute(runPapply,hosts=['10.1.0.53','10.1.0.52','10.1.0.51'])
        with  settings(host_string = '10.1.0.53', warn_only = True):
          execute(waitForSSH)
          try:
	    st_ceph_mon = sudo ("ceph mon stat | grep st1,st2,st3")
          except Exception:
            log("Failed checking mon stat, retrying")
	    st_ceph_mon = sudo ("ceph mon stat | grep st1,st2,st3")

  log("ceph mon are up, running papply on db, cp and oc nodes")
  nodes = ['10.1.0.10'] + env.roledefs['cp'] + env.roledefs['oc'] + env.roledefs['st']
  execute(runPapply,hosts=nodes)

  log("Restarting ntp on all servers")
  execute(restartNtp,hosts=env.roledefs['all'])  

  log("Configuring All CP nodes")
  execute(configCP,hosts=env.roledefs['cp'])
  execute(runPapply,hosts=nodes)
  if verify == True:
    execute(checkAll,verbose=verbose)

### Verify the services are up and running.
def checkAll(verbose='no'):
  """check all components and return on success, optional argument, 'verbose' for verbose output""" 

  if verbose.upper() == 'NO':
    output.update({'running': False, 'stdout': False, 'stderr': False})

#  rv = {'checkCephOsd': 1, 'checkCephStatus': 1, 'checkNova': 1, 'checkCinder': 1, 'getOSControllerProcs': 1 }
  rv = {'checkCephOsd': 1, 'checkCephStatus': 1, 'checkNova': 1, 'checkCinder': 1, }
  status = 1
  timeout = 5
  initial_prun = 1
  maxAttempts = 40
  attempt = 1
  log("Start checking the cluster")
  log("Checking the services")
  success = 0
  while ( attempt < maxAttempts ):
    attempt += 1
    time.sleep(timeout)
    if status != 0:
      log("System is not up... checking....")
      status = 0 
      for key,val in rv.items():
        if val != 0:
          log( "Executing %s" % key)
          rv[key] = execute(key).values()[0]
          if rv[key] != 0:
            status = 1
    else:
      attempt = maxAttempts        
      success = 1

  if success == 1:
    log("The openstack cloud is up and running")
    return 0
  else:
    log("Something failed, exiting")
    return 100


@parallel
def reduceCloudinitWaitTime():
    sudo('sed -i "s/long=[0-9]*/long=10/g" /etc/init/cloud-init-nonet.conf')

def waitForSSH():
  while not verifySshd([env.host],'ubuntu'):
    sleep(5)
    continue

##Check nova status
def checkNova():
  """Check Nova services are enabled"""
  nodes=env.roledefs['oc'] + env.roledefs['cp']
  dict_hosts=getHostname(nodes)
  failed_hosts=[]
  for key,val in dict_hosts.items():
    with hide('warnings'), settings(host_string = '10.1.0.11', warn_only = True):
      novamanage_status = sudo('nova-manage service list 2> /dev/null | grep "%s.*enabled.*:-)"' % val)
      if novamanage_status.return_code != 0:
	log("Nova is not up for %s" % val)
        failed_hosts.append(key)
  if len(failed_hosts) != 0:
    execute(runPapply,hosts = failed_hosts)
  else:
    log("Nova is running on all nodes")
  return len(failed_hosts)

## Check cinder
def checkCinder():
  """Check Cinder services are enabled"""
  nodes=env.roledefs['oc'] 
  dict_hosts=getHostname(nodes)
  failed_hosts=[]
  for key,val in dict_hosts.items():
    with hide('warnings'), settings(host_string = '10.1.0.11', warn_only = True):
      novamanage_status = sudo('cinder-manage service list 2> /dev/null | grep "%s.*enabled.*:-)"' % val)
      if novamanage_status.return_code != 0:
        log("Cinder services are not up for %s" % val)
        failed_hosts.append(key)
  if len(failed_hosts) != 0:
    execute(runPapply,hosts = failed_hosts)
  else:
    log("Cinder services are up and running on all nodes")
  return len(failed_hosts)


def configContrail():
  """Configure contrail"""
  with hide('warnings'), settings( warn_only = True):
    sudo("sed -i s/pp11.jiocloud.com/__project__.jiocloud.com/g /etc/contrail/svc_monitor.conf /etc/contrail/config.global.js /etc/contrail/openstackrc /etc/contrail/api_server.conf /etc/neutron/neutron.conf")
    execute(rebootNode,hosts=env.host)

@parallel
def checkInitialPapplyRun():
  """Check initial puppet apply has been completed"""
  maxAttempts=30
  attempt = 1
  with hide('warnings'), settings(warn_only = True):
    while ( attempt < maxAttempts ):
      attempt += 1
      time.sleep(5)
      initial_papply_run = run('ps -efw | grep /var/puppet/bin/papply || test -e /var/log/papply.log')
      if initial_papply_run.return_code == 0:
        log(env.host + " Initial Puppet run completed")
        return 0
  return initial_papply_run.return_code

@parallel
def restartNtp():
  """Restarts ntp server"""
  sudo("service ntp restart")

@parallel
def runNtpdate():
  """Runs ntpdate which is required for initial time sync"""
  with hide('warnings'), settings(warn_only = True):
    if env.host_string == '10.1.0.5':
       sudo("ntpdate -u 10.135.121.138 10.135.121.107")
    else:
      sudo("ntpdate -u 10.1.0.5")
  
def rebootNode():
  with hide('warnings'), settings(warn_only = True):
    try:
      sudo("reboot --force", timeout=5)
    except CommandTimeout:
      pass
    log('Reboot issued; Waiting for the node (%s) to go down...' % env.host)
    wait_until_host_down(wait=300, host=env.host)
    log ('Node (%s) is down... Waiting for node to come back' %   env.host)
    while not verifySshd([env.host],'ubuntu'):
      sleep(5)
      continue
    log("All nodes are sshable now")

@parallel
def runPapply(num_exec=1):
  """Run puppet apply"""
  with hide('warnings'), settings(warn_only = True):
    attempt=1 
    while ( attempt <= num_exec ):
      log(env.host + ' Running Puppet (num_exec: %s)' % attempt)
      if env.upgrade == 'base':
        try:
          papply_out = sudo('/var/puppet/bin/papply -b')
        except Exception:
          log("Failed runPapply, retrying")
          papply_out = sudo('/var/puppet/bin/papply -b')
      else:
        try:
          papply_out = sudo('/var/puppet/bin/papply')
        except Exception:
          log("Failed runPapply, retrying")
          papply_out = sudo('/var/puppet/bin/papply')

      if re.search('dpkg was interrupted, you must manually run \'sudo dpkg --configure -a\' to correct the problem',papply_out):
        sudo('dpkg --configure -a')
      execute(rebootIfNeeded,hosts=env.host)
      attempt += 1
      while not verifySshd([env.host],'ubuntu'):
        sleep(5)
        continue
  log("Done puppet apply on %s" % env.host)


@parallel(pool_size=5)
def configCP():
  """Configure CP server"""
  with hide('warnings'), settings(warn_only = True):
    log("Rebooting Node forcefully")
    execute(rebootNode,hosts=env.host)
    execute(runPapply,hosts=env.host)

### Rebooting from puppet is causing fab to hang, so disabled autoreboot in puppet and handling the reboot in fab
def rebootIfNeeded():
  """Reboot the node if required"""
  if env.host != '10.1.0.5':
   with hide('warnings'), settings(warn_only = True):
    rv_needreboot = sudo ('grep System.restart.required /var/run/reboot-required')
    if rv_needreboot.return_code == 0:
      execute(rebootNode,hosts=env.host)

def restartCephMon():
  """Restart ceph mon"""
  with hide('warnings'), settings(warn_only = True):
    log(env.host + " Restarting ceph mon")
    sudo("/etc/init.d/ceph restart mon")

def checkSvnUpdated():
  """check svn checkout is done"""
  for node in env.roledefs['all']:
    with hide('warnings'), settings(host_string = node, warn_only = True):
#      with hide('running', 'stdout', 'stderr'):
        st_svnup = sudo('svn up --username svn --password SubVer510n@1234 --trust-server-cert --non-interactive /var/puppet/')
        if st_svnup.return_code == 0:
          log(node + " svn update is working")
        else:
          sudo('svn cleanup; echo p | svn -q up --username svn --password SubVer510n@1234 /var/puppet &> /dev/null') 
          log (node + "svn update Failed")
          return 1
  return 0
  

def checkAptUpdated():
  """check apt get update status"""
  for node in env.roledefs['all']:
    with hide('warnings'), settings(host_string = node, warn_only = True):
#      with hide('running', 'stdout', 'stderr'):
        st_aptup = sudo('apt-get  update')
        if st_aptup.return_code == 0:
          log( node + " apt-get update done")
        else:
          log(node + " apt-get update failed") 
          return 1
          execute(runPapply,hosts=node)
  return 0

def cephMonStatus():
  hostlist=[env.roledefs['st'][0]]
  for node in hostlist:
    with hide('warnings'), settings(host_string = node, warn_only = True):
      st_ceph_mon = sudo ("ceph mon stat | grep st1,st2,st3")
      if st_ceph_mon.return_code == 0:
        log("Ceph Mons are running")
        return 0
      else:
        return 1

def checkCephStatus():
  """run ceph status on specific node"""
  hostlist=[env.roledefs['st'][0]]
  for node in hostlist:
    with hide('warnings'), settings(host_string = node, warn_only = True):
      st_ceph = sudo ("ceph -s | grep 'health *HEALTH_OK\|health *HEALTH_WARN clock skew detected'")
      if st_ceph.return_code == 0:
         log("ceph is healthy")
         return 0
      else:
         log("Ceph failed ") 
         execute(runPapply,hosts=env.roledefs['st'])
         execute(restartCephMon,hosts=env.roledefs['st'])
         return 1
  return 0
  
def checkCephOsd():
  """check minimum one OSD is in and up"""
  with hide('warnings'), settings(host_string = env.roledefs['st'][0], warn_only = True):
    osdUp = sudo ('ceph osd  dump  | grep "up *in"')
    osdUpList = osdUp.split('\n')
    minOsdUpPerNode = 0
    for node in env.roledefs['st']:
      osdUpInNode = 0
      for osd in osdUpList:
        if re.search(node,osd):
	  osdUpInNode = 1
      if osdUpInNode == 0:
        log("Node %s, yet to have minimum OSDs up" % node)
        minOsdUpPerNode = 1
        execute(runPapply,hosts=node)
    return minOsdUpPerNode

def wait_until_host_down(wait=120, host=None):
  if not host:
    host = env.host
  timeout = 5
  attempts = int(round(wait / float(timeout)))
  i = 0
  while i < attempts:
    res = subprocess.call(['ping', '-c', '1', host],
        stdout=subprocess.PIPE,
	stderr=subprocess.PIPE)
    if res is not 0:
      return
    time.sleep(timeout)
    i += 1
  print 'Timeout while waiting for host to shut down.'
  sys.exit(1)


def verifySshd(hostlist=[env.host], user='ubuntu',pkey_file='/home/ubuntu/.ssh/id_rsa'):
  rv_ssh = True
  for node in hostlist:
    log("Trying %s" % node)
    try:
      private_key = paramiko.RSAKey.from_private_key_file(pkey_file)
      client = paramiko.SSHClient()
      client.set_missing_host_key_policy(
        paramiko.AutoAddPolicy())
      client.connect(node,username=user,password='',pkey=private_key)
      client.close()
    except Exception:
      log("Waiting for %s to be sshable" % node)
      rv_ssh = False
  return rv_ssh


#@parallel
def getOSControllerProcs():
  procs_down = []
  with hide('warnings'), settings(host_string = env.roledefs['oc'], warn_only = True):
    procs = run('ps -efw | grep -v grep | grep  "nova-api\|nova-conductor\|glance-api\|glance-registry\|cinder-volume\|cinder-scheduler\|nova-scheduler\|nova-consoleauth\|nova-novncproxy\|cinder-api\|nova-cert\|keystone-all"')
    if not re.match('(.|\n)*nova-api.*',procs):
     procs_down.append('nova-api')
  if not re.match('(.|\n)*nova-conductor.*',procs):
    procs_down.append('nova-conductor')
  if not re.match('(.|\n)*glance-api.*',procs):
    procs_down.append('glance-api')
  if not re.match('(.|\n)*glance-registry.*',procs):
    procs_down.append('glance-registry')
  if not re.match('(.|\n)*cinder-volume.*',procs):
    procs_down.append('cinder-volume')
  if not re.match('(.|\n)*cinder-scheduler.*',procs):
    procs_down.append('cinder-scheduler')
  if not re.match('(.|\n)*nova-scheduler.*',procs):
    procs_down.append('nova-scheduler')
  if not re.match('(.|\n)*nova-consoleauth.*',procs):
    procs_down.append('nova-consoleauth')
  if not re.match('(.|\n)*nova-novncproxy.*',procs):
    procs_down.append('nova-novncproxy')
  if not re.match('(.|\n)*cinder-api.*',procs):
    procs_down.append('cinder-api')
  if not re.match('(.|\n)*nova-cert.*',procs):
    procs_down.append('nova-cert')
  if not re.match('(.|\n)*keystone-all.*',procs):
    procs_down.append('keystone-all')

  if len(procs_down) != 0:
    log("Procs down: %s" % ",".join(procs_down))
    return 1
  else:
    return 0

## Fabric finished

