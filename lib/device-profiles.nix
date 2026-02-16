# Flake inputs given manually, not by the NixOS module system.
{ nixos-hardware, nixpkgs, ... }:

{
  raspberry-pi-4 = {
    imports = [
      nixos-hardware.nixosModules.raspberry-pi-4
      nixpkgs.nixosModules.notDetected
    ];

    deployment.tags = [ "rpi4" ];

    fileSystems."/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };

    # Enable GPU acceleration.
    hardware.raspberry-pi."4".fkms-3d.enable = true;

    # Enable audio.
    services.pulseaudio.enable = true;

    # Necessary for building boot images and running NixOS tests.
    lab.host.builder.supportedFeatures = [
      "benchmark"
      "big-parallel"
      "kvm"
      "nixos-test"
    ];
  };

  cm3588 =
    { lib, config, ... }:
    {
      hardware.enableRedistributableFirmware = true;

      # HDMI output requires kernel >= 6.13 (RK3588 HDMI TX support via
      # dw-hdmi-qp landed upstream in that release). The upstream DTB also
      # disables the VOP2 display controller for this board. Once the
      # kernel catches up, enable HDMI with:
      #
      #   hardware.deviceTree.overlays = [{
      #     name = "enable-vop2";
      #     dtsText = ''
      #       /dts-v1/;
      #       /plugin/;
      #
      #       / { compatible = "friendlyarm,cm3588-nas"; };
      #       &vop { status = "okay"; };
      #     '';
      #   }];
      #   boot.kernelParams = [ ... "console=tty0" ];
      #
      assertions = [
        {
          assertion = lib.versionOlder config.boot.kernelPackages.kernel.version "6.13";
          message = ''
            Kernel ${config.boot.kernelPackages.kernel.version} supports HDMI
            output on the CM3588 NAS. See the comments in this file to enable it.
          '';
        }
      ];

      boot = {
        # Yoinked from `nixos-hardware`. It's the only meaningful export.
        kernelParams = [ "console=ttyS2,1500000n8" ];

        # Bootstrapped from `github:Mic92/nixos-aarch64-images#cm3588NAS`.
        loader = {
          grub.enable = false;
          generic-extlinux-compatible.enable = true;
        };
      };

      fileSystems."/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
        options = [ "noatime" ];
      };
    };
}
