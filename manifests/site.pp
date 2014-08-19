## Call jiocloud class

if $::role == 'tempest' {
  include tempest
} else {
  include jiocloud
}
