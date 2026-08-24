{
  lab.deviceProfiles.cm3588 =
    { ... }:
    {
      hardware.enableRedistributableFirmware = true;

      # HDMI output requires kernel >= 6.13 (RK3588 HDMI TX support via
      # dw-hdmi-qp landed upstream in that release). The upstream DTB ships
      # the VOP2 display controller disabled for this board, so re-enable it
      # with an overlay. As of NixOS 26.05 the mainline kernel (>= 6.18) is
      # new enough; previously an assertion guarded this until the kernel
      # caught up.
      hardware.deviceTree.overlays = [
        {
          name = "enable-vop2";
          dtsText = ''
            /dts-v1/;
            /plugin/;

            / { compatible = "friendlyarm,cm3588-nas"; };
            &vop { status = "okay"; };
          '';
        }
      ];

      boot = {
        # Yoinked from `nixos-hardware`. It's the only meaningful export.
        # `console=tty0` activates the HDMI framebuffer console.
        kernelParams = [
          "console=ttyS2,1500000n8"
          "console=tty0"
        ];

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
