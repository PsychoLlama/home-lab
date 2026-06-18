# Flake inputs given manually, not by the NixOS module system.
{ nixpkgs, ... }:

{
  raspberry-pi-4 =
    { pkgs, ... }:
    {
      # We don't import `nixos-hardware.nixosModules.raspberry-pi-4` anymore. It
      # defaults to the Raspberry Pi Foundation's downstream kernel fork
      # (`linux-rpi`), which nixpkgs only ships as source—the 26.05 upgrade would
      # have meant compiling it locally. Mainline supports everything these
      # headless boards use (genet ethernet, pcie/xhci USB, SD, GPIO) and comes
      # prebuilt from the binary cache. The handful of settings we actually
      # depended on are inlined below; the rest of that module was an opt-in menu
      # of HAT/peripheral overlays and a config.txt generator nothing reads.
      imports = [ nixpkgs.nixosModules.notDetected ];

      deployment.tags = [ "rpi4" ];

      fileSystems."/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
        options = [ "noatime" ];
      };

      boot = {
        # Mainline from the binary cache, not the vendor fork from source. The
        # nixpkgs default LTS—nothing here pins a specific version. (The genet
        # NIC failing to transmit on these boards was a PHY-driver problem, not
        # a kernel-version regression; see the `broadcom` initrd module below.)
        kernelPackages = pkgs.linuxPackages;

        # These boards are headless and wired exclusively over ethernet, so the
        # onboard radios are dead weight—wasted boot time, memory, and attack
        # surface. Disable both:
        #   - brcmfmac: the BCM4345 wifi driver. Its firmware blob loads ~21s
        #     into boot for an interface that never carries traffic (wlan0 sits
        #     DOWN/NO-CARRIER).
        #   - cfg80211: the 802.11 core. It must be named explicitly—udev
        #     coldplugs the wifi node from the firmware DTB and runs `modprobe
        #     brcmfmac`, which pre-loads its dependencies (cfg80211) *before*
        #     hitting the blacklisted target and bailing. Blacklisting brcmfmac
        #     alone leaves cfg80211 loaded at usecount 0.
        #   - btsdio: the SDIO-attached bluetooth controller. It already binds
        #     to nothing here (no hci0 registers), so this stops the module and
        #     the bluetooth stack from loading at all.
        blacklistedKernelModules = [
          "brcmfmac"
          "cfg80211"
          "btsdio"
        ];

        initrd = {
          availableKernelModules = [
            "pcie-brcmstb" # PCIe bus (required for USB3/xHCI)
            "reset-raspberrypi" # loads VL805 USB controller firmware
            "genet" # gigabit ethernet
            "usb-storage"
            "usbhid"
          ];

          # Force-load the Broadcom PHY driver before genet probes the MDIO bus
          # in stage 2. The Pi 4's Broadcom PHY (BCM54210E/54213PE depending on
          # board revision) runs RGMII with the MAC applying only the RX delay,
          # so the PHY itself must add the TX delay.
          # If genet binds the *generic* PHY driver—which it does whenever
          # `broadcom` isn't already loaded—that TX delay is never programmed,
          # and every transmitted frame is mistimed and silently dropped at the
          # switch (link up, RX fine, TX vanishes; the NIC then falls to
          # 169.254). Registering broadcom first makes genet bind the real
          # driver. This is the behaviour the linux-rpi fork gave us for free.
          kernelModules = [ "broadcom" ];

          # Avoids pulling tpm2 userspace into the initrd (yoinked from
          # nixos-hardware, where it's commented "Allow building kernel").
          systemd.tpm2.enable = false;
        };

        loader = {
          grub.enable = false;
          generic-extlinux-compatible.enable = true;
        };
      };

      # Do NOT hand the kernel a device tree from the Nix store. On the Pi 4 the
      # GPU firmware patches the DTB at boot (MAC address, genet/PHY runtime
      # setup, clocks, memory) before passing it to u-boot, and u-boot forwards
      # that patched tree to the kernel. Emitting an `FDT`/`FDTDIR` line in
      # extlinux overrides it with the kernel's pristine, unpatched DTB—on which
      # the genet NIC links up but can never transmit a frame (verified: the
      # router sees zero packets, DHCP never completes, the NIC falls to
      # 169.254). Disabling the extlinux device tree leaves the firmware-patched
      # tree in place, which is exactly how the working linux-rpi generation
      # booted. The downstream firmware DTB binds fine to the mainline drivers.
      hardware.deviceTree.enable = false;

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
