# TODO: Pass this as a flake input with `_module.args`.
#
# Note: the result still expects a config argument.
import (fetchTarball {
  url = "https://github.com/NixOS/nixpkgs/archive/2362848adf8.tar.gz";
  sha256 = "0wjr874z2y3hc69slaa7d9cw7rj47r1vmc1ml7dw512jld23pn3p";
})
