{ inputs, pkgs, ... }:
let
  minimalNvim = inputs.nixvim.legacyPackages.${pkgs.system}.makeNixvimWithModule {
    module = {
      imports = [
        ./minimal.nix
      ];
    };
  };
in
{
  home.file = {
    "snippets".source = ./plugins/snippets;
  };
  programs.nixvim = {
    enable = true;
    imports = [ ./complete.nix ];
  };
  home = {
    sessionVariables.EDITOR = "nvim";
    packages = [
      (pkgs.writeShellScriptBin "nvim-minimal" ''exec ${minimalNvim}/bin/nvim "$@" '')
    ];
  };
}
