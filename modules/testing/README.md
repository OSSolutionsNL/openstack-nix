# SSH Access

## Storage VM

```bash
ssh root@localhost -p 2022 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
```

## Controller VM

```bash
ssh root@localhost -p 1122 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
```

# Cinder & tgtd

## Create volume

* login in to `controllerVM` or `storageVM`

```bash
openstack volume create --size 4 TEST_VOL
```

* Cinder will create a LVM logical volume in the volume group `cinder-volumes`.
* At this time this volume will not be exposed as an iSCSI volume. This only happens when the volume is assigned to a VM.

## Assign volume to a VM

* create a new VM with: `openstack server create`
  * or look into system unit: `openstack-create-vm` on VM `controllerVM`

* attach volume to vm

```bash
openstack server list
openstack volume list
openstack server add volume <INSTANCE_NAME_OR_ID> <VOLUME_NAME_OR_ID>
```

* Verify tgtd status on `storageVM`: `tgt-admin --dump`
* Cinder should generated a tgtd configuration file within: `/var/lib/cinder/volumes`
* In the VM `computeVM` should appear a new block device `sda`. (`dmesg`)

```bash
[root@storageVM:/var/lib/cinder/volumes]# l
total 12K
drwxr-xr-x 2 cinder cinder 4.0K Feb 24 08:16 .
drwxr-xr-x 6 cinder cinder 4.0K Feb 24 08:09 ..
-rw------- 1 cinder cinder  268 Feb 24 08:16 volume-64159e0c-18bb-449f-b1e0-86f198b170e4
```
