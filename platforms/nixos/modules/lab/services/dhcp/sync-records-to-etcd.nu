use std/log

# Passed in from nix.
let settings = open $env.SETTINGS

# Synchronize DHCP leases to etcd when they change.
def main [event: string] {
  log info $"DHCP event ($event) hostname=($env.LEASE4_HOSTNAME? | default '?')"

  # This is the only event handled currently.
  if $event != "leases4_committed" {
    return
  }

  let count_removed = $env.DELETED_LEASES4_SIZE | into int
  let count_added = $env.LEASES4_SIZE | into int
  log info $"Leases changed added=($count_added) removed=($count_removed)"

  let removed = seq 1 $count_removed | enumerate | each {|item|
    {
      hostname: ($env | get $"DELETED_LEASES4_AT($item.index)_HOSTNAME")
    }
  }

  let added = seq 1 $count_added | enumerate | each {|item|
    {
      hostname: ($env | get $"LEASES4_AT($item.index)_HOSTNAME")
      ip: ($env | get $"LEASES4_AT($item.index)_ADDRESS")
    }
  }

  $removed | each { remove_lease $in }
  $added | each { add_lease $in }

  log info $"Leases synchronized"
}

# Add a record to etcd.
def add_lease [lease] {
  if ($lease.hostname | is-empty) {
    log info $"Ignoring lease with empty hostname ip=($lease.ip)"
  }

  let etcd_key = make_etcd_key $lease.hostname
  let record = { host: $lease.ip } | to json --raw

  log info $"Adding record to etcd ip=($lease.ip) key=($etcd_key)"
  etcdctl put $etcd_key $record
}

# Remove a record from etcd.
def remove_lease [lease] {
  let etcd_key = make_etcd_key $lease.hostname

  log info $"Removing record from etcd key=($etcd_key)"
  etcdctl del $etcd_key
}

# Find the right etcd key for the DNS record
def make_etcd_key [hostname: string] {
  $"($settings.etcd_prefix)/($hostname)"
}
