{ makeTest, ... }:

# Measured in MiB.
let
  disk-size = 2 * 1024;
in
{
  management = makeTest {
    name = "zfs-management";

    nodes.machine =
      { pkgs, lib, ... }:
      {
        virtualisation.emptyDiskImages = lib.replicate 4 disk-size;
        environment.systemPackages = [ pkgs.parted ];
        networking.hostId = "00000000";
        lab.filesystems.zfs = {
          enable = true;
          mounts = {
            "/mnt/pool" = "test-pool";
            "/mnt/pool/dataset" = "test-pool/dataset";
          };

          pools = {
            plain = {
              vdevs = [ { sources = [ "vdb" ]; } ];

              settings = {
                comment = "Test pool";
                autotrim = "on";
              };

              properties.mountpoint = "none";

              datasets = {
                test-1.properties.mountpoint = "none";
                test-2.properties = {
                  mountpoint = "none";
                  compression = "on";
                };
              };
            };

            fancy = {
              datasets.test.properties.mountpoint = "none";
              vdevs = [
                {
                  type = "mirror";
                  sources = [
                    "vdc"
                    "vdd"
                  ];
                }
                {
                  type = "log";
                  sources = [ "vde" ];
                }
              ];
            };
          };
        };
      };

    testScript = ''
      import textwrap

      start_all()

      with subtest("pool creation"):
        machine.succeed("system fs init")

        # ZFS has no export format. The convention is parsing with awk.
        pool_details = machine.succeed(
          """
          zpool status -vp | awk '
            /pool:/ { pool = $2; vdev = "disk"; next }
            $1 ~ "logs" { vdev = $1; next }
            $1 ~ "mirror" { vdev = $1; next }
            $1 == pool { next }
            $1 == "NAME" { next }
            NF != 5 { next }
            $2 == "ONLINE" { print pool","vdev","$1 }
          ' | sort
          """
        )

        # NOTE: Parsing is fragile. Double check the pool interactively before
        # bothering to troubleshoot.

        assert pool_details.strip() == textwrap.dedent("""
          fancy,logs,vde
          fancy,mirror-0,vdc
          fancy,mirror-0,vdd
          plain,disk,vdb
        """).strip(), "ZFS pools were not created correctly"

      with subtest("pool properties"):
        machine.succeed("zpool get comment plain | grep -q 'Test pool'")
        machine.succeed("zpool get autotrim plain | grep -q on")
        machine.succeed("zfs get mountpoint plain | grep -q none")

      with subtest("dataset creation"):
        datasets = machine.succeed(
          """
          zfs list -pt filesystem | awk '
            NR != 1 { print $1 }
          ' | sort
          """
        )

        assert datasets.strip() == textwrap.dedent("""
          fancy
          fancy/test
          plain
          plain/test-1
          plain/test-2
        """).strip(), "ZFS datasets were not created correctly"

      with subtest("dataset properties"):
        machine.succeed("zfs get mountpoint plain/test-1 | grep -q none")
        machine.succeed("zfs get mountpoint plain/test-2 | grep -q none")
        machine.succeed("zfs get compression plain/test-2 | grep -q on")
    '';
  };
}
