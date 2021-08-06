{
  imports = [../common/raspberry-pi.nix];

  services.nomad.enable = true;

  fileSystems."/var/db/consul" = {
    fsType = "nfs";
    device = "file-server.selfhosted.city:/mnt/zpool1/locker/applications/consul";
  };

  services.consul = {
    enable = true;
    interface.bind = "eth0";

    extraConfig = {
      data_dir = "/var/db/consul";
    };
  };
}
