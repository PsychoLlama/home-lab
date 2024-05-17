{ config, lib, ... }:

# The lab is divided into "Stratums", which are sets of services that can only
# depend on themselves or a lower stratum. This helps prevent circular
# dependencies. Circular dependencies cause substantial problems when
# rebuilding the lab from scratch.
#
# The lower stratums should contain as few services as possible.

with lib;

let
  inherit (cfg) bedrock frame;
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
    bedrock = {
      initialized = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether all critical services have been initialized. This stratum
          includes the lowest-level services, such as networking and storage.
        '';
      };
    };

    frame = {
      assertion = require "bedrock" bedrock.initialized;
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

    tenant = {
      assertion = require "frame" (frame.initialized && bedrock.initialized);
      initialized = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether all tenant-level services have been initialized. This level
          includes everything that is not crucial to bedrock or frame
          stratums, such as applications, servers, and databases.

          There are no higher stratums. Nothing should depend on this level.
        '';
      };
    };
  };

  config.assertions = [
    {
      assertion = cfg.frame.initialized -> cfg.bedrock.initialized;
      message = "Bedrock stratum must be initialized before frame.";
    }
    {
      assertion = cfg.tenant.initialized -> cfg.frame.initialized;
      message = "Frame stratum must be initialized before tenant.";
    }
  ];
}
