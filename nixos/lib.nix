inputs:

{
  defineHost = system: path: inputs.nixpkgs.lib.nixosSystem {
    inherit system;

    specialArgs = {
      inherit system inputs;
    };

    modules = [
      ({ lib, ... }: {
        # Match the directory name to the host's name.
        networking.hostName = lib.mkDefault (baseNameOf path);

        # Attach the git sha to `nixos-version` output.
        system.configurationRevision = inputs.self.rev or null;
      })

      path
    ];
  };
}
