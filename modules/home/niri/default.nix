{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    quickshell
    wl-mirror
    wlsunset
    matugen
  ];
  wayland.windowManager.niri = {
    enable = true;
    systemd.enable = false;
    xwaylandSatellitePackage = pkgs.xwayland-satellite;
    portalPackage = pkgs.xdg-desktop-portal-gnome;
  };
  xdg.configFile."quickshell".source = ./quickshell;
}
