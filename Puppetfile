git_protocol=ENV['git_protocol'] || 'git'
base_url = "#{git_protocol}://github.com"

mod 'jiocloud/account',
  :git => "#{base_url}/jiocloud/puppet-account",
  :ref => '368cb87bb978642da4bccdd15a666088af8866f9'

mod 'puppetlabs/apache',
  :git => "#{base_url}/puppetlabs/puppetlabs-apache",
  :ref => '1.1.1'

mod 'puppetlabs/apt',
  :git => "#{base_url}/puppetlabs/puppetlabs-apt",
  :ref => '1.4.2'

mod 'puppetlabs/apt_mirror',
  :git => "#{base_url}/jiocloud/puppet-apt_mirror"

mod 'stackforge/ceph',
  :git => "#{base_url}/jiocloud/puppet-ceph",
  :ref => 'svn_git_port'

mod 'stackforge/cinder',
  :git => "#{base_url}/jiocloud/puppet-cinder",
  :ref => 'svn_git_port'

mod 'puppetlabs/concat',
  :git => "#{base_url}/jiocloud/puppetlabs-concat",
  # this is a really strange ref to match...
  :ref => '162048133d1579a4c6d0268d8e0d29fecdbb73d9'

mod 'jiocloud/contrail',
  :git => "#{base_url}/jiocloud/puppet-contrail",
  # we may want to pin this to a revision
  :ref => 'origin/master'

mod 'jiocloud/cron',
  :git => "#{base_url}/jiocloud/puppet-cron",
  # pinning to master for now
  :ref => 'origin/master'

mod 'stackforge/glance',
  :git => "#{base_url}/jiocloud/puppet-glance",
  :ref => 'svn_git_port'

mod 'stackforge/horizon',
  :git => "#{base_url}/jiocloud/puppet-horizon",
  :ref => 'svn_git_port'

mod 'puppetlabs/inifile',
  :git => "#{base_url}/puppetlabs/puppetlabs-inifile",
   :ref => 'ab21bd3'

# TODO jiocloud/jiocloud
# TODO jiocloud/jiocloud_registration

mod 'stackforge/keystone',
  :git => "#{base_url}/jiocloud/puppet-keystone",
  :ref => 'svn_git_port'

mod 'jiocloud/kvm',
  :git => "#{base_url}/jiocloud/puppet-kvm",
  # pinning to master for now
  :ref => 'origin/master'

mod 'rodjek/logrotate',
  :git => "#{base_url}/rodjek/puppet-logrotate",
  :ref => 'd569bcee1b43fa1af816c21afb5664d8e5235553'

#
# please not that this repo is jiocloud-lvm. This is intended to capture
# fact that I have no idea how to reconcile it against its upstream from
# genieattachment
#
mod 'jiocloud/lvm',
  :git => "#{base_url}/jiocloud/jiocloud-lvm"

# TODO fix
mod 'saz/memcached',
  :git => "#{base_url}/saz/puppet-memcached",
  :ref => 'fee24ce'

mod 'puppetlabs/mysql',
  :git => "#{base_url}/puppetlabs/puppetlabs-mysql",
  :ref => '2.2.3'

#
# please not that this repo is jiocloud-network. This is intended to capture
# fact that I have no idea how to reconcile it against its upstream from
# genieattachment
#
mod 'jiocloud/network',
  :git => "#{base_url}/jiocloud/jiocloud-network"

mod 'stackforge/neutron',
  :git => "#{base_url}/jiocloud/puppet-neutron",
  :ref => 'svn_git_port'

mod 'stackforge/nova',
  :git => "#{base_url}/jiocloud/puppet-nova",
  :ref => 'svn_git_port'

mod 'jiocloud/nscd',
  :git => "#{base_url}/jiocloud/puppet-nscd"

mod 'puppetlabs/ntp',
  :git => "#{base_url}/puppetlabs/puppetlabs-ntp",
  :ref => '3.0.1'

mod 'jiocloud/openstack',
  :git => "#{base_url}/jiocloud/puppet-openstack"

mod 'puppetlabs/rabbitmq',
  :git => "#{base_url}/puppetlabs/puppetlabs-rabbitmq",
  :ref => '4.0.0'

mod 'jiocloud/resolver',
  :git => "#{base_url}/jiocloud/puppet-resolver"

mod 'jiocloud/sethostname',
  :git => "#{base_url}/jiocloud/puppet-sethostname"

mod 'saz/ssh',
  :git => "#{base_url}/saz/puppet-ssh.git",
  # this had actually been forked from this repo
  :ref => 'v1.4.0'

mod 'nanliu/staging',
  :git => "#{base_url}/nanliu/puppet-staging",
  :ref => '0.4.1'

mod 'puppetlabs/stdlib',
  :git => "#{base_url}/puppetlabs/puppetlabs-stdlib",
  :ref => '4.1.0'

mod 'saz/sudo',
  :git => "#{base_url}/saz/puppet-sudo",
  :ref => '62b93da'

mod 'duritong/sysctl',
  :git => "#{base_url}/duritong/puppet-sysctl",
  :ref => '4a46338'

mod 'saz/timezone',
  :git => "#{base_url}/saz/puppet-timezone",
  :ref => 'v2.0.0'

mod 'jiocloud/zeromq',
  :git => "#{base_url}/jiocloud/puppet-zeromq"
  # pin to master for now

# this doees not reconcile perfectly
mod 'viirya/zookeeper',
  :git => "#{base_url}/viirya/puppet-zookeeper",
  :ref => '5ce7acebbee871f3cd4e8c6ed2916440eb6a03e6'
