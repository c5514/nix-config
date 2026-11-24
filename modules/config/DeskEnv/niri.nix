{ pkgs, ... }:
{
  programs = {
    uwsm = {
      enable = true;
    };
    niri = {
      enable = true;
      useNautilus = true;
    };
  };
  environment.systemPackages = with pkgs; [
    nautilus
    papers
  ];
}
