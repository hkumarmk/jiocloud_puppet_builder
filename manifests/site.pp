## Call jiocloud class

if $::role == 'tempest' {
  include tempest
} elsif $::role == 'reliance_spawn_machine' {
  package { 'git': }
  package { 'vim': }
  class { 'openstack_extras::repo::uca':
    release => 'havana',
  }
  class { 'openstack_extras::client':
    ceilometer => false,
  }
} else {
  fail("Undefined role ${::role}")
  #include jiocloud
}
