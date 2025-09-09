{
  cinder,
}:
{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  # adminEnv = {
  #   OS_USERNAME = "admin";
  #   OS_PASSWORD = "admin";
  #   OS_PROJECT_NAME = "admin";
  #   OS_USER_DOMAIN_NAME = "Default";
  #   OS_PROJECT_DOMAIN_NAME = "Default";
  #   OS_AUTH_URL = "http://controller:5000/v3";
  #   OS_IDENTITY_API_VERSION = "3";
  # };
  cfg = config.cinder-storage-node;

  cinder_env = pkgs.python3.buildEnv.override {
    extraLibs = [
      cfg.cinderPackage
      pkgs.qemu
    ];
  };

  utils_env = pkgs.buildEnv {
    name = "utils";
    paths = [
      cinder_env
      pkgs.qemu
    ];
  };

  rootwrapConf = pkgs.callPackage ../../lib/rootwrap-conf.nix {
    package = cinder_env;
    filterPath = "/etc/cinder/rootwrap.d";
    inherit utils_env;
  };

  cinderConf = pkgs.writeText "cinder.conf" ''
    [DEFAULT]
    transport_url = rabbit://openstack:openstack@controller
    auth_strategy = keystone
    my_ip = controller
    enabled_backends = lvm
    volumes_dir = /var/lib/cinder/volumes
    state_path = /var/lib/cinder
    rootwrap_config = ${rootwrapConf}
    glance_api_servers = http://controller:9292

    [database]
    connection = mysql+pymysql://cinder:cinder@controller/cinder

    [keystone_authtoken]
    www_authenticate_uri = http://controller:5000
    auth_url = http://controller:5000
    memcached_servers = controller:11211
    auth_type = password
    project_domain_name = default
    user_domain_name = default
    project_name = service
    username = cinder
    password = cinder

    [oslo_concurrency]
    lock_path = /var/lib/cinder/tmp

    [lvm]
    volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
    volume_group = cinder-volumes
    volume_backend_name = lvm
    lvm_type = default
  '';
in
{
  imports = [
    ../generic/controller-host-entry.nix
  ];

  options.cinder-storage-node = {
    enable = mkEnableOption "Enable OpenStack Cinder storage node." // {
      default = true;
    };
    config = mkOption {
      default = cinderConf;
      description = ''
        The Cinder config.
      '';
    };
    cinderPackage = mkOption {
      default = cinder;
      type = types.package;
      description = ''
        The OpenStack Cinder package to use.
      '';
    };
  };

  config = mkIf cfg.enable {
    users.extraUsers.cinder = {
      group = "cinder";
      isSystemUser = true;
    };
    users.groups.cinder = {
      name = "cinder";
      members = [ "cinder" ];
    };

    security.sudo.enable = true;
    security.sudo.extraConfig = ''
      cinder ALL = (root) NOPASSWD: ${cinder_env}/bin/cinder-rootwrap ${rootwrapConf} *
    '';

    systemd.tmpfiles.settings = {
      "20-cinder" = {
        "/var/lib/cinder/" = {
          D = {
            user = "cinder";
            group = "cinder";
            mode = "0755";
          };
        };
        "/var/lib/cinder/volumes" = {
          D = {
            user = "cinder";
            group = "cinder";
            mode = "0755";
          };
        };
        "/var/log/cinder/" = {
          D = {
            user = "cinder";
            group = "cinder";
            mode = "0755";
          };
        };
      };
    };

    systemd.services.cinder-volume-group = {
      description = "OpenStack Cinder volume group setup";
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.lvm2
        pkgs.util-linux
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "cinder-volume-group.sh" ''
          set -euxo pipefail

          # Setup some lvm volume group required by cinder
          dd if=/dev/zero of=/tmp/cinder-volumes bs=1G count=2

          losetup /dev/loop0 /tmp/cinder-volumes

          # Create physical volume and volume group
          pvcreate /dev/loop0
          vgcreate cinder-volumes /dev/loop0
        '';
      };
    };

    # It seems regardless of what we do, the cinder-volume service does not
    # find the qemu-img command it requires for non-raw images. As a
    # workaround, add it as a systemPackage.
    # Update: still does not work -.-
    environment.systemPackages = [
      pkgs.qemu
    ];

    systemd.services.cinder-volume = {
      description = "OpenStack Cinder Volume";
      after = [
        "cinder-volume-group.service"
      ];
      path = with pkgs; [
        cinder_env
        lvm2
        # sudo must be in the path and only sudo in /run/wrappers has the
        # correct owner and rights
        "/run/wrappers"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "cinder";
        Group = "cinder";
        ExecStart = pkgs.writeShellScript "cinder-volume.sh" ''
          .cinder-volume-wrapped --config-file ${cfg.config}
        '';
        # The volume service requires some cinder setup to be done already and
        # manifested in the DB. As the storage node might run on a different
        # node and we cannot simply wait for some other service to complete, we
        # add a retry mechanism with some sensible delay.
        Restart = "on-failure";
        RestartSec = 20;
      };
    };
  };
}
