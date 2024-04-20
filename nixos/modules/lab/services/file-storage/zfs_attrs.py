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
    diff = compare_zfs_properties(desired_state, actual_state)

    print(render_to_string(diff))

    # TODO:
    # - Print the diff
    # - Apply changes


def get_dataset_properties():
    """
    Fetch a list of every ZFS property on the system. This does not include
    inherited properties or defaults.
    """
    proc = subprocess.run(
        ["zfs", "get", "-Hpt", "filesystem", "-s", "local", "all"],
        capture_output=True,
        text=True,
    )

    return parse_dataset_properties(proc.stdout)


def parse_dataset_properties(output):
    """
    Parse the stdout string representing ZFS properties.

    Example:

      {dataset}\t{property}\t{value}\t{scope}
      {dataset}\t{property}\t{value}\t{scope}
      ...

    """
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


def get_expected_properties():
    """
    Expected structure:

    type ExpectedProperties = {
        pools: {
        [pool_name: string]: ResourceDescription
        }
        datasets: {
        [dataset_name: string]: ResourceDescription
        }
    }

    type ResourceDescription = {
        ignored_properties: string[]
        properties: { [property_name: string]: string }
    }
    """
    logger.info("Reading desired state from %s", STATE_FILE)
    with open(STATE_FILE) as f:
        return json.load(f)


def compare_zfs_properties(desired_state, actual_state):
    diffs = []

    # Detect new or changed properties.
    for dataset_name, dataset in desired_state["datasets"].items():
        ignored = set(dataset["ignored_properties"])

        # Check for added or changed properties.
        for property, expected_value in dataset["properties"].items():
            if property in ignored:
                continue

            actual_value = actual_state.get(dataset_name, {}).get(property)

            if actual_value != expected_value:
                diffs.append(
                    {
                        "dataset": dataset_name,
                        "property": property,
                        "expected": expected_value,
                        "actual": actual_value,
                    }
                )

        # Check for removed properties.
        for property, actual_value in actual_state.get(
            dataset_name, {}
        ).items():
            if property in ignored:
                continue

            if property not in dataset["properties"]:
                diffs.append(
                    {
                        "dataset": dataset_name,
                        "property": property,
                        "expected": None,
                        "actual": actual_value,
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

    def test_unmanaged_dataset_is_ignored(self):
        # Locker not specified. Assume its properties are unmanaged.
        desired = self.mocks.expected_state()

        actual = {
            "locker": {"compression": "on"},
        }

        self.assertEqual(
            compare_zfs_properties(desired, actual),
            [],
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

    def test_ignored_properties(self):
        desired = self.mocks.expected_state(
            self.mocks.dataset(
                "locker",
                ignored_properties=["relatime"],
                compression="on",
                relatime="on",
            ),
            self.mocks.dataset(
                "locker/var/log",
                ignored_properties=["mountpoint"],
            ),
        )

        actual = {
            "locker": {"compression": "on", "relatime": "off"},
            "locker/var/log": {"mountpoint": "/var/log"},
        }

        self.assertEqual(compare_zfs_properties(desired, actual), [])
