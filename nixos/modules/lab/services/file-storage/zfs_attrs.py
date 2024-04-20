import subprocess
import json
import unittest
from textwrap import dedent
import logging
from os import environ
from functools import reduce
from itertools import groupby

#
# Diffs system ZFS attributes against a desired state, optionally applying
# changes to bring the system into alignment.
#
# DEVELOPMENT
# -----------
# Getting dependencies: `nix-shell`
# Running tests: `$ unit_test`
# Formatting: `$ format`
# Running: `EXPECTED_STATE=./test-file.json python3 -m zfs_attrs`
#

STATE_FILE = environ.get("EXPECTED_STATE")
logger = logging.getLogger(__name__)


def main():
    logging.basicConfig(level=logging.INFO)

    if STATE_FILE is None:
        logger.error("EXPECTED_STATE environment variable is required")
        return

    desired_state = get_expected_properties()
    actual_state = get_dataset_properties()
    print(compare_zfs_properties(desired_state, actual_state))

    # TODO:
    # - Print the diff
    # - Apply changes


# Fetch a list of every ZFS property on the system. This does not include
# inherited properties or defaults.
def get_dataset_properties():
    proc = subprocess.run(
        ["zfs", "get", "-Hpt", "filesystem", "-s", "local", "all"],
        capture_output=True,
        text=True,
    )

    properties = parse_dataset_properties(proc.stdout)

    return properties


# Parse the stdout string representing ZFS properties.
#
# Example:
#
#   {dataset}\t{property}\t{value}\t{scope}
#   {dataset}\t{property}\t{value}\t{scope}
#   ...
#
def parse_dataset_properties(output):
    rows = [line.split("\t") for line in output.splitlines()]

    all_properties = [
        {
            "dataset": entry[0],
            "property": entry[1],
            "value": entry[2],
        }
        for entry in rows
    ]

    properties_by_dataset = groupby(
        all_properties, key=lambda x: x["dataset"]
    )

    return {
        dataset: {entry["property"]: entry["value"] for entry in entries}
        for dataset, entries in properties_by_dataset
    }


# Expected structure:
#
#   type ExpectedProperties = {
#     pools: {
#       [pool_name: string]: ResourceDescription
#     }
#     datasets: {
#       [dataset_name: string]: ResourceDescription
#     }
#   }
#
#   type ResourceDescription = {
#     ignored_properties: string[]
#     properties: { [property_name: string]: string }
#   }
#
def get_expected_properties():
    logger.info("Reading desired state from %s", STATE_FILE)
    with open(STATE_FILE) as f:
        return json.load(f)


def compare_zfs_properties(desired_state, actual_state):
    diffs = []

    # Detect new or changed properties.
    for dataset, properties in desired_state["datasets"].items():
        for property, expected_value in properties["properties"].items():
            actual_value = actual_state.get(dataset, {}).get(property)

            if actual_value != expected_value:
                diffs.append(
                    {
                        "dataset": dataset,
                        "property": property,
                        "expected": expected_value,
                        "actual": actual_value,
                    }
                )

    # Detect removed properties.
    for dataset, properties in actual_state.items():
        for property, _ in properties.items():
            if property not in desired_state["datasets"].get(dataset, {}).get(
                "properties", {}
            ):
                diffs.append(
                    {
                        "dataset": dataset,
                        "property": property,
                        "expected": None,
                        "actual": actual_state[dataset][property],
                    }
                )

    return diffs


if __name__ == "__main__":
    main()


########################################################################
#                                 TESTS                                #
########################################################################

class MockStateFactory:
    "Utilities for creating mock data in tests"

    def expected_state(self, *datasets):
        return {
            "datasets": reduce(
                lambda acc, dataset: acc | dataset, datasets, {}
            ),
        }

    def dataset(self, name, ignored_properties=None, **props):
        return {
            name: {
                "ignored_properties": ignored_properties or [],
                "properties": props,
            }
        }


class TestPropertyParsing(unittest.TestCase):
    def test_parse_zfs_properties(self):
        output = dedent(
            """
            locker	compression	on	local
            locker	relatime	on	local
            locker/nixos/var/log	com.sun:auto-snapshot	true	local
            locker/data	mountpoint	/	local
        """
        ).strip()

        expected = {
            "locker": {"compression": "on", "relatime": "on"},
            "locker/nixos/var/log": {"com.sun:auto-snapshot": "true"},
            "locker/data": {"mountpoint": "/"},
        }

        self.assertEqual(parse_dataset_properties(output), expected)

class TestPropertyDiffing(unittest.TestCase):
    mocks = MockStateFactory()

    def test_changed_property_diff(self):
        desired = self.mocks.expected_state(
            self.mocks.dataset("locker", compression="on")
        )

        actual = {
            "locker": {"compression": "off"},
        }

        self.assertEqual(
            compare_zfs_properties(desired, actual),
            [
                {
                    "dataset": "locker",
                    "property": "compression",
                    "expected": "on",
                    "actual": "off",
                },
            ],
        )

    def test_missing_property_diff(self):
        desired = self.mocks.expected_state(
            self.mocks.dataset("locker", compression="on")
        )

        actual = {
            "locker": {},
        }

        self.assertEqual(
            compare_zfs_properties(desired, actual),
            [
                {
                    "dataset": "locker",
                    "property": "compression",
                    "expected": "on",
                    "actual": None,
                },
            ],
        )

    def test_removed_property_diff(self):
        desired = self.mocks.expected_state(self.mocks.dataset("locker"))

        actual = {
            "locker": {"compression": "on"},
        }

        self.assertEqual(
            compare_zfs_properties(desired, actual),
            [
                {
                    "dataset": "locker",
                    "property": "compression",
                    "expected": None,
                    "actual": "on",
                },
            ],
        )

    def test_all_properties_removed(self):
        # Locker not specified. Assume all properties are to be removed.
        desired = self.mocks.expected_state()

        actual = {
            "locker": {"compression": "on"},
        }

        self.assertEqual(
            compare_zfs_properties(desired, actual),
            [
                {
                    "dataset": "locker",
                    "property": "compression",
                    "expected": None,
                    "actual": "on",
                },
            ],
        )

    def test_all_properties_are_new(self):
        desired = self.mocks.expected_state(
            self.mocks.dataset("locker", relatime="on")
        )

        # "locker" will not be in the parsed output if it has no properties.
        actual = {}

        self.assertEqual(
            compare_zfs_properties(desired, actual),
            [
                {
                    "dataset": "locker",
                    "property": "relatime",
                    "expected": "on",
                    "actual": None,
                },
            ],
        )

    def test_no_properties_changed(self):
        desired = self.mocks.expected_state(
            self.mocks.dataset("locker", compression="on")
        )

        actual = {
            "locker": {"compression": "on"},
        }

        self.assertEqual(compare_zfs_properties(desired, actual), [])

    @unittest.skip("Not implemented")
    def test_ignored_properties(self):
        pass
