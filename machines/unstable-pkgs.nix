# NixOps doesn't allow custom arguments in NixOS configurations. Unstable
# packages cannot reasonably be passed through the Flake.
#
# Update: That's false. I can use `_module.args`. But I'm not in a position to
# fix that right now.
#
# Note: the result still expects a config argument.
import (fetchTarball {
  url = "https://github.com/NixOS/nixpkgs/archive/2362848adf8.tar.gz";
  sha256 = "0wjr874z2y3hc69slaa7d9cw7rj47r1vmc1ml7dw512jld23pn3p";
})
