{ config, lib, ... }:

let
  cfg = config.lab.stacks.home-automation;
in
{
  options.lab.stacks.home-automation = {
    enable = lib.mkEnableOption "Home automation stack with Home Assistant";
  };

  config = lib.mkIf cfg.enable {
    lab.services.vpn.client.tags = [ "home-automation" ];

    # mDNS client for device discovery (works with router's Avahi reflector)
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    services.home-assistant = {
      enable = true;

      extraComponents = [
        # Discovery protocols
        "zeroconf"
        "ssdp"
        "upnp"

        # User's devices
        "hue"
        "cast" # Also covers Google Home speakers
        # "xbox" - disabled due to insecure ecdsa dependency (CVE-2024-23342)
        "fitbit"
        "withings"
        "spotify"

        # Services
        "ntfy"
        "prometheus"

        # OAuth support
        "application_credentials"

        # Useful defaults
        "met"
      ];

      config = {
        # Disable hardware integrations (no USB/Bluetooth on this host)
        usb = { };
        bluetooth = { };

        homeassistant = {
          name = "Home";
          unit_system = "us_customary";
          time_zone = "America/New_York";
          external_url = "https://home.selfhosted.city";
          internal_url = "http://localhost:8123";
        };

        # Trust reverse proxy (Tailscale CGNAT range)
        http = {
          use_x_forwarded_for = true;
          trusted_proxies = [ "100.64.0.0/10" ];
        };

        # Enable UI-based configuration
        config = { };
        frontend = { };
        api = { };
        mobile_app = { };
        lovelace.mode = "storage";

        # Discovery
        zeroconf = { };
        ssdp = { };

        # Automation framework (UI-managed via storage)
        # NOTE: These files must exist in /var/lib/hass/ on first deploy:
        #   touch automations.yaml scripts.yaml scenes.yaml
        automation = "!include automations.yaml";
        script = "!include scripts.yaml";
        scene = "!include scenes.yaml";

        # Expose metrics to Prometheus
        prometheus = { };
      };
    };
  };
}
