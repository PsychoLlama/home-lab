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

# Diff system state against expected state.
export def plan []: nothing -> table {
  let state_file = open-state-file
  let actual = get actual
  let managed_state = filter-unmanaged $state_file $actual
  let expected_state = format expected $state_file
  diff $managed_state $expected_state
}

# Apply a diff to the system, bringing it into alignment with the state file.
export def apply []: nothing -> nothing {
  def ask_permission [] {
    if $env.AUTO_CONFIRM? == "true" {
      return true
    }

    print "Apply changes?"
    ([confirm cancel] | input list) == "confirm" 
  }

  let diff = plan

  if ($diff | is-empty) {
    log info "No changes to apply."
    return
  }

  print ($diff | table --theme psql)

  if not (ask_permission) {
    log warning "Aborted."
    return
  }

  for action in (execution plan $diff) {
    log info $"Executing: ($action.cmd) ($action.args | str join ' ')"
    run-external $action.cmd ...$action.args
  }

  log info "Changes applied."
}

# Returns the actual state of all dataset properties and pool attributes on
# the system.
#
# SEE: zprops(7), zpoolprops(7)
export def "get actual" []: nothing -> table {
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
# specified in the state file. The output schema matches the actual state.
export def "format expected" [
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
export def filter-unmanaged [
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

    match $expected {
      null => false
      _ => (not ($entry.prop in $expected.ignored_properties))
    }
  }
}

export def diff [
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

export def "execution plan" [diff]: nothing -> list {
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
