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
