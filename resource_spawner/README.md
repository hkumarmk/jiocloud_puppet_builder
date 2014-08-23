# prerequisites

This script makes quite a few assumptions about the current state
of your openstack infra.

1. It expects the following flavors to exist:

  m1.controller m1.compute m1.contrail m1.storage

2. Your tenant must have permission to use these flavors

  for the purposes of our internal testing, we assume your
  user belongs to the tenant CI\_CD

3. Your tenant must also have access to the image in glance that
   is currently being used for contrail


