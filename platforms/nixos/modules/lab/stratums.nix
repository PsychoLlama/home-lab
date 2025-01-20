{ config, lib, ... }:

# The lab is divided into "Stratums", which are sets of services that can only
# depend on themselves or a lower stratum. This helps prevent circular
# dependencies. Circular dependencies cause substantial problems when
# rebuilding the lab from scratch.
#
# The lower stratums should contain as few services as possible.

let
  inherit (lib) types mkOption;
  inherit (cfg) platform framework;
  cfg = config.lab.stratums;

  require =
    name: stratum:
    mkOption {
      type = types.anything;
      description = "Convenience option for asserting a stratum dependency";
      internal = true;
      readOnly = true;
      default = {
        assertion = stratum.initialized;
        message = "This service requires the ${name} stratum.";
      };
    };
in

{
  options.lab.stratums = {
    platform = {
      initialized = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether all critical services have been initialized. This stratum
          includes the lowest-level services, such as networking and
          discovery.
        '';
      };
    };

    framework = {
      assertion = require "platform" platform.initialized;
      initialized = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether all multi-tenant supports have been initialized. This
          stratum includes services like container orchestration, service
          discovery, and key management.
        '';
      };
    };

    application = {
      assertion = require "framework" (framework.initialized && platform.initialized);
      initialized = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether all tenant-level services have been initialized. This level
          includes everything that is not crucial to platform or framework
          stratums, such as applications, servers, and databases.

          There are no higher stratums. Nothing should depend on this level.
        '';
      };
    };
  };

  config.assertions = [
    {
      assertion = cfg.framework.initialized -> cfg.platform.initialized;
      message = "Platform stratum must be initialized before framework.";
    }
    {
      assertion = cfg.application.initialized -> cfg.framework.initialized;
      message = "Framework stratum must be initialized before applications.";
    }
  ];
}
