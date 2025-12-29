{
  config,
  lib,
  ...
}:

let
  cfg = config.lab.services.unifi;
in

{
  options.lab.services.unifi = {
    enable = lib.mkEnableOption "UniFi Network Controller for managing UniFi devices";

    image = lib.mkOption {
      type = lib.types.str;
      default = "jacobalberty/unifi:latest";
      description = "Docker image for the UniFi controller";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "America/New_York";
      description = "Timezone for the controller";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall ports for UniFi controller";
    };
  };

  config = lib.mkIf cfg.enable {
    # Using a container because I don't want to compile MongoDB from source.
    # The packages aren't in hydra.
    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.unifi = {
      image = cfg.image;
      environment = {
        TZ = cfg.timezone;
      };
      # Bind to specific interfaces - not exposed to WAN
      ports = [
        # AP communication (wap interface only)
        "10.0.1.1:8080:8080" # Device inform
        "10.0.1.1:3478:3478/udp" # STUN
        "10.0.1.1:10001:10001/udp" # AP discovery
        # Web UI via Tailscale only (ingress connects through Tailscale)
        # TODO: Hardcoded Tailscale IP is brittle. If the IP changes, update
        # this or implement dynamic IP resolution at service start.
        "100.88.147.49:8443:8443"
      ];
      volumes = [
        "unifi-data:/unifi"
      ];
    };

    # Only open ports needed for AP communication (not web UI - use Tailscale ingress)
    networking.firewall.interfaces = lib.mkIf cfg.openFirewall {
      # Home network (where AP lives)
      wap = {
        allowedTCPPorts = [ 8080 ]; # Device inform
        allowedUDPPorts = [ 3478 10001 ]; # STUN + discovery
      };
    };
  };
}
