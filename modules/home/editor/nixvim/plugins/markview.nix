{
  lib,
  config,
  ...
}:
{
  plugins = {
    markview = lib.mkIf config.plugins.treesitter.enable {
      enable = true;
    };
  };
}
