# ZFS pools and datasets have properties, such as encryption or compression.
# These properties should be initialized on creation and may change over time.
# They are configured by command line.
#
# The goal of this module is to implement Configuration as Code for all ZFS
# properties. You define the expected state and this module compares it
# against the system, computes a diff, derives an execution plan, and
# optionally brings the system into alignment.
#
# It should be run whenever new datasets/pools are created or when properties
# update.
#
# NOTE: This program ignores pools and datasets not specified in the expected
# state file.

use std log

# Check dataset and pool properties for drift and apply the expected state.
export def main []: nothing -> nothing {
  log error "Not implemented"
}

# Returns the actual state of all dataset properties and pool attributes on
# the system.
#
# SEE: zprops(7), zpoolprops(7)
export def 'get actual' []: nothing -> table {
  let pools = zpool get all -H
  | lines
  | parse "{name}\t{prop}\t{value}\t{source}"
  | each { merge { type: pool } }

  let datasets = zfs get -Ht filesystem all
  | lines
  | parse "{name}\t{prop}\t{value}\t{source}"
  | each { merge { type: dataset } }

  $pools | append $datasets
}

# Returns the expected state of all dataset properties and pool attributes as
# specified in the state file. The output schema matches the actual state.
export def 'get expected' []: nothing -> table {
  let expected = open-state-file

  def enumerate_resources [resource_type: string, expected: record] {
    $expected
    | transpose name settings
    | each { merge { type: $resource_type } }
    | each { enumerate_properties }
    | flatten
  }

  def enumerate_properties []: record -> record {
    let resource = $in

    $resource.settings.properties
    | transpose name value
    | each {|prop|
      {
        type: $resource.type
        name: $resource.name
        prop: $prop.name
        value: $prop.value
        source: "local"
      }
    }
  }

  | enumerate_resources "pool" $expected.pools
  | append (enumerate_resources "dataset" $expected.datasets)
}

# Return the path to the JSON file specifying the expected system state.
export def open-state-file []: nothing -> record {
  let config_file = if $env.EXPECTED_STATE? == null {
    error make {
      msg: "EXPECTED_STATE environment variable is required"
    }
  } else {
    $env.EXPECTED_STATE
  }

  open $config_file
}

## TODO:
# - Add this script to `lab.system`
# - Write tests for converting the expected data to a flat table
# - Derive a system diff
# - Derive an execution plan
