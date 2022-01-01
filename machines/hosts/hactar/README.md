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

## Syncthing

The service is optional and runs in a NixOS container. It depends on having the right file ownership, which is assigned to group/user IDs `8384`:

```bash
zfs create -o com.sun:auto-snapshot=true pool0/syncthing
mount -t zfs -o zfsutil pool0/syncthing /mnt/pool0/syncthing

# Give Syncthing permission to manage the dataset.
chown 8384:8384 /mnt/pool0/syncthing
```

Then mount it using the `dataDir` option:

```nix
lab.file-server.services.syncthing.dataDir = "/mnt/pool0/syncthing";
```
