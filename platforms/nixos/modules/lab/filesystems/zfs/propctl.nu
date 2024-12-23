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

# Workaround for weird bug in newer nushell versions. Environment doesn't seem
# to be loading correctly. Copied from the `std` module.
export-env {
    $env.NU_LOG_FORMAT = $env.NU_LOG_FORMAT? | default "%ANSI_START%%DATE%|%LEVEL%|%MSG%%ANSI_STOP%"
    $env.NU_LOG_DATE_FORMAT = $env.NU_LOG_DATE_FORMAT? | default "%Y-%m-%dT%H:%M:%S%.3f"
}

use std log

# Diff system state against expected state.
export def plan []: nothing -> table {
  let state_file = open-state-file
  let actual = read-system-state
  let managed_state = filter-unmanaged-state $state_file $actual
  let expected_state = flatten-state-file $state_file
  generate-diff $managed_state $expected_state
}

# Apply a diff to the system, bringing it into alignment with the state file.
# Expects output from `plan`.
export def apply [--sudo]: table -> nothing {
  let diff = $in

  def ask_permission [] {
    if $env.AUTO_CONFIRM? == "true" {
      return true
    }

    print "Apply changes?"
    ([confirm cancel] | input list) == "confirm" 
  }

  if ($diff | is-empty) {
    log info "No changes to apply."
    return
  }

  print ($diff | table --theme psql)

  if not (ask_permission) {
    log warning "Aborted."
    return
  }

  for plan in (to-execution-plan $diff) {
    let action = match $sudo {
      true => { cmd: sudo, args: [$plan.cmd ...$plan.args] }
      _ => $plan
    }

    log info $"Executing: ($action.cmd) ($action.args | str join ' ')"
    run-external $action.cmd ...$action.args
  }

  log info "Changes applied."
}

# Returns the actual state of all dataset properties and pool attributes on
# the system.
#
# SEE: zprops(7), zpoolprops(7)
export def read-system-state []: nothing -> table {
  let pools = zpool get all -H
  | lines
  | parse "{name}\t{prop}\t{value}\t{source}"
  | each { merge { type: pool } }
  | where source == local
  | where prop !~ 'feature@' # Not supported yet.

  let datasets = zfs get -Ht filesystem all
  | lines
  | parse "{name}\t{prop}\t{value}\t{source}"
  | each { merge { type: dataset } }
  | where source == local

  $pools | append $datasets
}

# Returns the expected state of all dataset properties and pool attributes as
# specified in the state file, but flattened to a table matching the schema of
# `read-system-state`.
export def flatten-state-file [
  state_file: record<pools: record, datasets: record>
]: nothing -> table {
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

  | enumerate_resources "pool" $state_file.pools
  | append (enumerate_resources "dataset" $state_file.datasets)
}

# Remove any pools, datasets, or properties from actual state that aren't
# managed by the state file.
export def filter-unmanaged-state [
  state_file: record
  actual_state: table
] {
  $actual_state | filter {|entry|
    let expected = $state_file
    | get -is (match $entry.type {
        pool => "pools"
        dataset => "datasets"
      })
    | get -is $entry.name

    # If the state file doesn't specify the pool/dataset, then ignore it.
    if $expected == null {
      false
    } else {
      not ($entry.prop in $expected.ignored_properties)
    }
  }
}

# Compare system state against expected state to find added, modified, or
# removed properties. Works for both pools and datasets.
export def generate-diff [
  actual: table,
  expected: table,
]: nothing -> table {
  # Make comparison of expected <-> actual easier by indexing records by
  # composite key.
  def key_by_composite_id []: table -> record {
    let entries = $in

    # Transpose returns an empty table if the input is empty. Make sure we
    # always return a record.
    if ($entries | is-empty) {
      return {}
    }

    $entries
    | each {|entry|
        {
          key: (get_composite_id $entry)
          value: $entry
        }
      }
    | transpose -rd
  }

  def get_composite_id [entry: record]: nothing -> string {
    $"($entry.type):($entry.name):($entry.prop)"
  }

  let keyed_actual = $actual | key_by_composite_id
  let keyed_expected = $expected | key_by_composite_id

  # Find values in "expected" that do not exist in "actual", or values that
  # differ between the two.
  let additions_or_modifications = $expected | each {|entry|
    let actual = $keyed_actual
    | get -si (get_composite_id $entry)
    | get value?

    # Values are identical. No change needed.
    if ($entry.value == $actual) {
      return null
    }

    {
      type: $entry.type
      change: (match $actual {
        null => "add"
        _ => "modify"
      })
      name: $entry.name
      prop: $entry.prop
      actual: $actual
      expected: $entry.value
    }
  }

  # Find values in "actual" that do not exist in "expected".
  let deletions = $actual | each {|entry|
    let expected = $keyed_expected | get -si (get_composite_id $entry)

    if $expected != null {
      return null
    }

    {
      type: $entry.type
      change: "remove"
      name: $entry.name
      prop: $entry.prop
      actual: $entry.value
      expected: null
    }
  }

  $additions_or_modifications
  | append $deletions
  | filter {|change| $change != null }
  | each { merge { sort_key: (get_composite_id $in) } }
  | sort-by sort_key
  | reject sort_key
}

# Generate commands from the state diff to bring the system into alignment.
export def to-execution-plan [diff]: nothing -> list {
  let dataset_prop_changes = $diff
  | where type == dataset and change in [add, modify]
  | group-by name
  | items {|dataset, changes|
      let properties = $changes
      | each { [$in.prop $in.expected] | str join "=" }

      {
        cmd: "zfs"
        args: ["set" "-u" ...$properties $dataset]
      }
    }

  let dataset_prop_removals = $diff
  | where type == dataset and change == remove
  | each {|change|
      {
        cmd: "zfs"
        args: ["inherit" $change.prop $change.name]
      }
    }

  let pool_attr_changes = $diff
  | where type == pool and change in [add, modify]
  | each {|change|
      {
        cmd: "zpool"
        args: ["set" $"($change.prop)=($change.expected)" $change.name]
      }
    }

  | $dataset_prop_changes
  | append $dataset_prop_removals
  | append $pool_attr_changes
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

# Generate a state file snapshot from current system state.
export def export-system-state []: nothing -> record {
  let system_state = read-system-state

  def to_state_format []: table -> record {
    let resource_state = $in

    if ($resource_state | is-empty) {
      return {}
    }

    $resource_state
    | sort-by name
    | group-by name
    | items {|name, entries|
      {
        name: $name
        state: {
          ignored_properties: []
          properties: (
            $entries
            | sort-by prop
            | select prop value
            | transpose -rd
          )
        }
      }
    }
    | transpose -rd
  }

  {
    pools: ($system_state | where type == pool | to_state_format),
    datasets: ($system_state | where type == dataset | to_state_format),
  }
}
