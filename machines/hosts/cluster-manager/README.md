# Cluster Manager

This machine is responsible for managing the cluster with NixOps, including itself. The `home-lab` repository is edited and deployed from here.

To make changes, mount the directory on a remote dev machine using `sshfs` and call `nixops` remotely.
