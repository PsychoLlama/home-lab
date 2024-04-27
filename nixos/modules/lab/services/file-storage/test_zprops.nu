use std assert
use zprops.nu

def fill_partial_state [partial_state: record] {
  def fill_missing_resource_fields [] {
    $in
    | default {}
    | transpose name state
    | upsert state {||
      | default [] ignored_properties
      | default {} properties
    }
    | transpose -rd
    | into record # Transpose returns table for empty input
  }

  | $partial_state
  | upsert pools { fill_missing_resource_fields }
  | upsert datasets { fill_missing_resource_fields }
}

#[test]
def test_flatten_empty_expected_state [] {
  let state = fill_partial_state {}
  let expected = zprops format expected $state

  assert equal $expected []
}

#[test]
def test_flatten_expected_state_with_dataset_properties [] {
  let state = fill_partial_state {
    datasets: {
      locker: {
        properties: {
          compression: on
          relatime: on
        }
      }
    }
  }

  let expected = zprops format expected $state

  assert equal $expected [
    [type, name, prop, value, source];
    [dataset, locker, compression, on, local]
    [dataset, locker, relatime, on, local]
  ]
}

#[test]
def test_flatten_expected_state_with_pool_properties [] {
  let state = fill_partial_state {
    pools: {
      locker: {
        properties: { autoexpand: on }
      }
    }
  }

  let expected = zprops format expected $state

  assert equal $expected [
    [type, name, prop, value, source];
    [pool, locker, autoexpand, on, local]
  ]
}

#[test]
def test_unmanaged_pools_and_datasets [] {
  let state = fill_partial_state {
    datasets: {
      locker: {
        properties: {
          compression: on
        }
      }
    }
  }

  let actual = [
    [type,    name,      prop,        value, source];
    [dataset, locker,    compression, on,    local]
    [dataset, unmanaged, compression, on,    local]
    [pool,    unknown,   autoexpand,  on,    local]
  ]

  let filtered = zprops filter-unmanaged $state $actual

  assert equal $filtered [
    [type,    name,   prop,        value, source];
    [dataset, locker, compression, on,    local]
  ]
}

#[test]
def test_unmanaged_properties [] {
  let state = fill_partial_state {
    pools: {
      tank: {
        ignored_properties: [autotrim]
        properties: {
          autoexpand: on
        }
      }
    }
    datasets: {
      locker: {
        ignored_properties: [mountpoint]
        properties: {
          relatime: on
        }
      }
    }
  }

  let actual = [
    [type,    name,      prop,       value, source];
    [dataset, locker,    relatime,   off,   local]
    [dataset, locker,    mountpoint, none,  local]
    [pool,    tank,      autoexpand, off,   local]
    [pool,    tank,      autotrim,   off,   local]
  ]

  let filtered = zprops filter-unmanaged $state $actual

  assert equal $filtered [
    [type,    name,   prop,       value, source];
    [dataset, locker, relatime,   off,   local]
    [pool,    tank,   autoexpand, off,   local]
  ]
}

#[test]
def test_diff_added_properties [] {
  let expected = [
    [type,    name,   prop,        value, source];
    [dataset, locker, compression, on,    local]
    [dataset, locker, relatime,    on,    local]
  ]

  let actual = []

  let diff = zprops diff $actual $expected

  assert equal $diff [
    [type,    change, name,   prop,        actual, expected];
    [dataset, add,    locker, compression, null,   on]
    [dataset, add,    locker, relatime,    null,   on]
  ]
}

#[test]
def test_diff_changed_properties [] {
  let expected = [
    [type,    name,   prop,        value, source];
    [dataset, locker, compression, on,    local]
    [dataset, locker, relatime,    on,    local]
  ]

  let actual = [
    [type,    name,   prop,        value, source];
    [dataset, locker, compression, off,   local]
    [dataset, locker, relatime,    on,    local]
  ]

  let diff = zprops diff $actual $expected

  assert equal $diff [
    [type,    change, name,   prop,        actual, expected];
    [dataset, modify, locker, compression, off,    on]
  ]
}

#[test]
def test_removed_properties [] {
  let expected = [
    [type,    name,   prop,        value, source];
    [dataset, locker, compression, on,    local]
  ]

  let actual = [
    [type,    name,   prop,        value, source];
    [dataset, locker, compression, on,    local]
    [dataset, locker, relatime,    on,    local]
  ]

  let diff = zprops diff $actual $expected

  assert equal $diff [
    [type,    change, name,   prop,     actual, expected];
    [dataset, remove, locker, relatime, on,     null]
  ]
}

#[test]
def test_diff_added_and_removed_properties [] {
  let expected = [
    [type,    name,    prop,        value, source];
    [dataset, locker,  compression, on,    local]
    [pool,    example, autoexpand,  off,   local]
  ]

  let actual = [
    [type,    name,    prop,       value, source];
    [dataset, locker,  relatime,   on,    local]
    [pool,    example, autoexpand, on,    local]
  ]

  let diff = zprops diff $actual $expected

  assert equal $diff [
    [type,    change, name,    prop,        actual, expected];
    [dataset, add,    locker,  compression, null,   on]
    [dataset, remove, locker,  relatime,    on,     null]
    [pool,    modify, example, autoexpand,  on,     off]
  ]
}

#[test]
def test_modified_dataset_execution_plan [] {
  let diff = [
    [type,    change, name,    prop,        actual, expected];
    [dataset, add,    locker,  compression, null,   on]
    [dataset, modify, locker,  relatime,    on,     off]
  ]

  let commands = zprops execution plan $diff

  assert equal $commands [
    { cmd: zfs, args: [set -u compression=on relatime=off locker] }
  ]
}

#[test]
def test_removed_dataset_props_execution_plan [] {
  let diff = [
    [type,    change, name,    prop,     actual, expected];
    [dataset, remove, locker,  relatime, on,     null]
    [dataset, remove, locker,  xattr,    on,     null]
  ]

  let commands = zprops execution plan $diff

  assert equal $commands [
    { cmd: zfs, args: [inherit relatime locker] }
    { cmd: zfs, args: [inherit xattr locker] }
  ]
}

#[test]
def test_modified_pool_execution_plan [] {
  let diff = [
    [type, change, name, prop,       actual, expected];
    [pool, modify, tank, autoexpand, off,    on]
    [pool, add,    tank, autotrim,   null,   on]
  ]

  let commands = zprops execution plan $diff

  assert equal $commands [
    { cmd: zpool, args: [set autoexpand=on tank] }
    { cmd: zpool, args: [set autotrim=on tank] }
  ]
}
