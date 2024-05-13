{
  pkgs,
  lib,
  colmena,
  clapfile,
  home-manager,
  revision,
  ...
}:

let
  # The default module name assigned when traversing options. Without
  # evaluating `config` the name would otherwise be unknown. This causes mild
  # problems on options using an associative structure.
  #
  # Source:
  # https://github.com/NixOS/nixpkgs/blob/af8b9db5c00f1a8e4b83578acc578ff7d823b786/lib/types.nix#L858-L873
  defaultDocsModuleName = "‹name›";

  # Evaluate modules in a minimal NixOS environment. This is lighter than
  # creating a new machine.
  toplevel = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    modules = [
      colmena.nixosModules.deploymentOptions
      colmena.nixosModules.assertionModule
      home-manager.nixosModules.home-manager
      clapfile.nixosModules.nixos
      ../modules

      {
        lab.networks.${defaultDocsModuleName}.ipv4.cidr = "127.0.0.1/32";
        networking.hostName = "machine";
        networking.domain = "example.com";
        lab.host = {
          system = pkgs.system;
          ethernet = "FF:FF:FF:FF:FF:FF";
          ip4 = "127.0.0.1";
        };
      }
    ];

    inherit (pkgs) system;
    inherit pkgs;
  };

  allOptions = lib.optionAttrSetToDocList toplevel.options;

  # Only generate documentation for things under the `lab.*` namespace.
  filteredOptions = lib.filter (
    opt: opt.visible && !opt.internal && (lib.hasPrefix "lab." opt.name)
  ) allOptions;

  # Convert to the format expected by `nixos-render-docs`.
  optionSet = lib.listToAttrs (
    lib.flip map filteredOptions (opt: {
      inherit (opt) name;
      value = lib.attrsets.removeAttrs opt [ "name" ];
    })
  );

  # Write the options file WITHOUT compiling mentioned dependencies. The
  # documentation generator will not traverse into listed store paths.
  optionsJSON = builtins.toFile "options.json" (
    builtins.unsafeDiscardStringContext (builtins.toJSON optionSet)
  );
in
{
  # To preview:
  # `man ./result/share/man/man5/lab.nix.5`
  manpage =
    pkgs.runCommand "generate-manpage-docs"
      {
        allowedReferences = [ "out" ];
        buildInputs = [
          pkgs.buildPackages.installShellFiles
          pkgs.buildPackages.nixos-render-docs
        ];
      }
      ''
        mkdir -p $out/share/man/man5
        nixos-render-docs -j $NIX_BUILD_CORES options manpage \
          --revision ${lib.escapeShellArg revision} \
          --footer /dev/null \
          ${optionsJSON} \
          $out/share/man/man5/lab.nix.5
      '';

  markdown =
    pkgs.runCommand "generate-markdown-docs"
      {
        allowedReferences = [ "out" ];
        nativeBuildInputs = [ pkgs.nixos-render-docs ];
      }
      ''
        mkdir $out
        nixos-render-docs -j $NIX_BUILD_CORES options commonmark \
          --revision ${lib.escapeShellArg revision} \
          --manpage-urls ${pkgs.path + "/doc/manpage-urls.json"} \
          ${optionsJSON} \
          $out/options.md
      '';
}
