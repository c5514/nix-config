{ inputs, pkgs, ... }:
{
  imports = [
    ./firefox.nix
    ./zathura.nix
    ./spicetify.nix
    ./rmpc.nix
  ];
  home.packages =
    (with pkgs; [
      tikzit
      brave
      freetube
      # obsidian
      proton-vpn-cli
      # zotero
      inkscape
      # gimp
      texliveFull
      typst
      # telegram-desktop
      mpv
      mpd
      feh
      pinta
      obs-studio
      libreoffice-qt-stable
      btop
    ])
    ++ (with inputs.nix-wolfram.packages.${pkgs.stdenv.hostPlatform.system}; [
      wljs
      wolfram-engine
    ]);
}
