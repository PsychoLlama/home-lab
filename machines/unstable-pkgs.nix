# NixOps doesn't allow custom arguments in NixOS configurations. Unstable
# packages cannot reasonably be passed through the Flake.
#
# Note: the result still expects a config argument.
import (fetchTarball {
  url = "https://github.com/NixOS/nixpkgs/archive/f225322e3b.tar.gz";
  sha256 = "1cbl7w81h2m4as15z094jkcrgg2mdi2wnkzg2dhd6080vgic11vy";
})
