# File Server Setup

This stack configures a NAS with encrypted ZFS storage and Syncthing.

## Initial Setup

ZFS pools and datasets must be created manually. The configuration in
`default.nix` documents the expected state but doesn't apply it automatically.

### 1. Create the Pool

Encryption must be enabled at creation time:

```sh
zpool create \
  -O encryption=on \
  -O keylocation=prompt \
  -O keyformat=passphrase \
  -O xattr=on \
  -O acltype=posix \
  -O atime=off \
  -O compression=on \
  -O mountpoint=none \
  pool0 raidz1 nvme0n1 nvme1n1 nvme2n1
```

### 2. Create Datasets

```sh
zfs create pool0/syncthing
zfs set com.sun:auto-snapshot=true pool0/syncthing
```

## Daily Operations

After boot, decrypt and mount the pool:

```sh
zfs-attach
```

To unmount before shutdown or maintenance:

```sh
zfs-detach
```

## References

- `zpoolconcepts(7)` - Pool and vdev types
- `zfsprops(7)` - Dataset properties
- `zpoolprops(7)` - Pool properties
