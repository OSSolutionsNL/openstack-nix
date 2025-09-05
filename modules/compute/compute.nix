{ neutron, nova }:
{ ... }:
{
  imports = [
    ../generic/controller-host-entry.nix
    (import ./neutron.nix { inherit neutron; })
    (import ./nova.nix { inherit nova; })
  ];
}
