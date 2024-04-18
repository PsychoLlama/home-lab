import subprocess
import json
import unittest
from textwrap import dedent
import logging
from os import environ

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
    compare_zfs_properties(desired_state, actual_state)


# Fetch a list of every ZFS property on the system. This does not include
# inherited properties or defaults.
def get_dataset_properties():
    proc = subprocess.run(
        ["zfs", "get", "-Hpt", "filesystem", "-s", "local", "all"],
        capture_output=True,
        text=True,
    )

    properties = parse_dataset_properties(proc.stdout)
    logger.info(
        "Found %d properties across %d datasets",
        len(properties),
        len({entry["dataset"] for entry in properties}),
    )

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

    return [
        {
            "dataset": entry[0],
            "property": entry[1],
            "value": entry[2],
        }
        for entry in rows
    ]


# Expected structure:
#
#   type ExpectedProperties = {
#     pools: PropAssignments;
#     datasets: PropAssignments;
#   }
#
#   type PropAssignments = {
#     ignored_properties: string[];
#     properties: { [resource_name: string]: Map<string, string> }
#   }
#
def get_expected_properties():
    logger.info("Reading desired state from %s", STATE_FILE)
    with open(STATE_FILE) as f:
        return json.load(f)


def compare_zfs_properties(desired_state, actual):
    # TODO: Derive a diff.
    print(
        json.dumps(
            {"desired_state": desired_state, "actual": actual}, indent=2
        )
    )


if __name__ == "__main__":
    main()


class TestZfsProperties(unittest.TestCase):
    def test_parse_zfs_properties(self):
        output = dedent(
            """
            locker	compression	on	local
            locker/nixos/var/log	com.sun:auto-snapshot	true	local
            locker/data	mountpoint	/	local
        """
        ).strip()

        expected = [
            {"dataset": "locker", "property": "compression", "value": "on"},
            {
                "dataset": "locker/nixos/var/log",
                "property": "com.sun:auto-snapshot",
                "value": "true",
            },
            {
                "dataset": "locker/data",
                "property": "mountpoint",
                "value": "/",
            },
        ]

        self.assertEqual(parse_dataset_properties(output), expected)

    def test_new_property_diff(self):
        pass
