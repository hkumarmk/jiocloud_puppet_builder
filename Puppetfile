git_protocol=ENV['git_protocol'] || 'git'
base_url = "#{git_protocol}://github.com"

# jiocloud specific modules. Created by and
# maintained by the team

mod 'jiocloud/account',
  :git => "#{base_url}/jiocloud/puppet-account",
  :ref => 'origin/master'

mod 'jiocloud/aptmirror',
  :git => "#{base_url}/jiocloud/puppet-aptmirror",
  :ref => 'origin/master'

mod 'jiocloud/contrail',
  :git => "#{base_url}/jiocloud/puppet-contrail",
  :ref => 'origin/master'

mod 'jiocloud/cron',
  :git => "#{base_url}/jiocloud/puppet-cron",
  :ref => 'origin/master'

mod 'jiocloud/kvm',
  :git => "#{base_url}/jiocloud/puppet-kvm",
  :ref => 'origin/master'

mod 'jiocloud/resolver',
  :git => "#{base_url}/jiocloud/puppet-resolver",
  :ref => 'origin/master'

mod 'jiocloud/sethostname',
  :git => "#{base_url}/jiocloud/puppet-sethostname",
  :ref => 'origin/master'

mod 'jiocloud/nscd',
  :git => "#{base_url}/jiocloud/puppet-nscd",
  :ref => 'origin/master'

#mod 'jiocloud/zeromq',
#  :git => "#{base_url}/jiocloud/puppet-zeromq",
#  :ref => 'origin/master'

#
# TODO : add composition modules
#
#mod 'stackforge/puppet-jiocloud',
#  :git => "#{base_url}/jiocloud/puppet-puppet-jiocloud",
#  :ref => 'svn_git_port'
#mod 'stackforge/jiocloud_registration',
#  :git => "#{base_url}/jiocloud/puppet-jiocloud_registration",
#  :ref => 'svn_git_port'

#
# modules used from Puppetlabs
#

mod 'puppetlabs/apt',
  :git => "#{base_url}/puppetlabs/puppetlabs-apt",
  :ref => '1.4.2'

mod 'puppetlabs/apache',
  :git => "#{base_url}/puppetlabs/puppetlabs-apache",
  :ref => '1.1.1'

mod 'puppetlabs/concat',
  :git => "#{base_url}/puppetlabs/puppetlabs-concat",
  :ref => '162048133d1579a4c6d0268d8e0d29fecdbb73d9'

mod 'puppetlabs/inifile',
  :git => "#{base_url}/puppetlabs/puppetlabs-inifile",
  :ref => 'ab21bd3'

mod 'puppetlabs/mysql',
  :git => "#{base_url}/puppetlabs/puppetlabs-mysql",
  :ref => '2.2.3'

mod 'puppetlabs/ntp',
  :git => "#{base_url}/puppetlabs/puppetlabs-ntp",
  :ref => '3.0.1'

mod 'puppetlabs/stdlib',
  :git => "#{base_url}/puppetlabs/puppetlabs-stdlib",
  :ref => '4.1.0'

mod 'puppetlabs/rabbitmq',
  :git => "#{base_url}/puppetlabs/puppetlabs-rabbitmq",
  :ref => '4.0.0'


### modules currently forked from an upstream other than stackforge

mod 'stackforge/ceph',
  :git => "#{base_url}/jiocloud/puppet-ceph",
  :ref => 'svn_git_port'

### modules currently forked from stackforge

mod 'stackforge/cinder',
  :git => "#{base_url}/jiocloud/puppet-cinder",
  :ref => 'svn_git_port'

mod 'stackforge/glance',
  :git => "#{base_url}/jiocloud/puppet-glance",
  :ref => 'svn_git_port'

mod 'stackforge/horizon',
  :git => "#{base_url}/jiocloud/puppet-horizon",
  :ref => 'svn_git_port'

mod 'stackforge/keystone',
  :git => "#{base_url}/jiocloud/puppet-keystone",
  :ref => 'svn_git_port'

mod 'stackforge/neutron',
  :git => "#{base_url}/jiocloud/puppet-neutron",
  :ref => 'svn_git_port'

mod 'stackforge/nova',
  :git => "#{base_url}/jiocloud/puppet-nova",
  :ref => 'svn_git_port'

### modules that are pulled from a third party

mod 'saz/memcached',
  :git => "#{base_url}/saz/puppet-memcached",
  :ref => 'fee24ce'

mod 'rodjek/logrotate',
  :git => "#{base_url}/rodjek/puppet-logrotate",
  :ref => 'd569bcee1b43fa1af816c21afb5664d8e5235553'

mod 'saz/sudo',
  :git => "#{base_url}/saz/puppet-sudo",
  :ref => '62b93da'

mod 'duritong/sysctl',
  :git => "#{base_url}/duritong/puppet-sysctl",
  :ref => '4a46338'

mod 'saz/ssh',
  :git => "#{base_url}/saz/puppet-ssh.git",
  :ref => 'v1.4.0'

mod 'nanliu/staging',
  :git => "#{base_url}/nanliu/puppet-staging",
  :ref => '0.4.1'

mod 'saz/timezone',
  :git => "#{base_url}/saz/puppet-timezone",
  :ref => 'v2.0.0'

#### modules that still need to be fixed

#
# please note that this repo is jiocloud-lvm. This is intended to capture
# fact that I have no idea how to reconcile it against its upstream from
# genieattachment
#
mod 'jiocloud/lvm',
  :git => "#{base_url}/jiocloud/jiocloud-lvm"

#
# please not that this repo is jiocloud-network. This is intended to capture
# fact that I have no idea how to reconcile it against its upstream from
# genieattachment
#
mod 'jiocloud/network',
  :git => "#{base_url}/jiocloud/jiocloud-network",
  :ref => 'origin/master'

mod 'jiocloud/openstack',
  :git => "#{base_url}/jiocloud/puppet-openstack"

# this doees not reconcile perfectly
mod 'viirya/zookeeper',
  :git => "#{base_url}/viirya/puppet-zookeeper",
  :ref => '5ce7acebbee871f3cd4e8c6ed2916440eb6a03e6'

# other third party modules
