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

You also need to generate a host key for the initrd SSH process, used to decrypt pools on boot.

```bash
mkdir -p /etc/secrets/initrd
ssh-keygen -t ed25519 -N "" -f /etc/secrets/initrd/id_ed25519
```

Once that's done, declare the pools in `lab.file-server.pools` and register the datasets with the `/etc/fstab` config. Be sure to decrypt before doing a deploy or systemd will fail and drop you in recovery mode.

On boot up, ssh to port `2222` and enter the decryption keys.
