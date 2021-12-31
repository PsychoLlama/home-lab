# File Server

Running the file server requires manually initializing a ZFS pool. Personally, I use an encrypted RAIDZ1 pool with some reasonable defaults for shares ([particularly `journald`](https://nixos.wiki/wiki/ZFS#Journald)):

```bash
zpool create \
  -O xattr=sa \
  -O acltype=posixacl \
  -O atime=off \
  -O encryption=aes-256-gcm \
  -O keyformat=passphrase \
  -O compression=on \
  -O mountpoint=none \
  pool0 raidz1 sdb sdc sdd
```

Automatic snapshots are applied to any dataset with the `com.sun:auto-snapshot` filesystem feature.

```bash
zfs set com.sun:auto-snapshot=true pool0
```
