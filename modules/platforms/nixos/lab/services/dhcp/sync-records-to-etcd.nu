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
      ip: ($env | get $"DELETED_LEASES4_AT($item.index)_ADDRESS")
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
  let hostname = normalize_hostname $lease.hostname

  # Clients are free to omit the hostname, or to send one that normalizes to
  # nothing. Writing those would clobber the zone apex key.
  if ($hostname | is-empty) {
    log info $"Ignoring lease with empty hostname ip=($lease.ip)"
    return
  }

  let etcd_key = make_etcd_key $hostname
  let record = { host: $lease.ip } | to json --raw

  log info $"Adding record to etcd ip=($lease.ip) key=($etcd_key)"
  etcdctl put $etcd_key $record
}

# Remove a record from etcd.
def remove_lease [lease] {
  let hostname = normalize_hostname $lease.hostname

  if ($hostname | is-empty) {
    log info $"Ignoring expired lease with empty hostname ip=($lease.ip)"
    return
  }

  let etcd_key = make_etcd_key $hostname

  # Records are keyed by hostname alone, so a hostname collision (two devices
  # flashed with the same default name) makes them share a key. Expiring the
  # older lease must not delete the record the newer device just wrote, so
  # only delete when the stored address still matches the expiring lease.
  let current = etcdctl get $etcd_key --print-value-only | str trim
  if ($current | is-empty) {
    log info $"No record to remove key=($etcd_key)"
    return
  }

  let stored_ip = try {
    $current | from json | get host
  } catch {
    log warning $"Ignoring malformed record key=($etcd_key) value=($current)"
    return
  }

  if $stored_ip != $lease.ip {
    log info $"Keeping record owned by another lease key=($etcd_key) stored=($stored_ip) expiring=($lease.ip)"
    return
  }

  log info $"Removing record from etcd key=($etcd_key)"
  etcdctl del $etcd_key
}

# Reduce a DHCP-supplied hostname to a single DNS label.
#
# Clients send whatever they like: trailing dots ("xbox."), FQDNs
# ("laptop.local"), and mixed case all show up in practice. Everything here
# lives under a single `host.<zone>` prefix, so only the first label is
# meaningful -- anything else produces a key that never resolves.
def normalize_hostname [hostname: string] {
  $hostname | str trim | split row "." | first | str lowercase
}

# Find the right etcd key for the DNS record
def make_etcd_key [hostname: string] {
  $"($settings.etcd_prefix)/($hostname)"
}
