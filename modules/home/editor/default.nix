{ pkgs, ... }:
{
  imports = [
    ./nixvim/default.nix
    # ./vscodium.nix
  ];
  home.packages = with pkgs; [
    emacs
  ];
}
