{
  pkgs,
  lib,
  config,
  ...
}:
{
  plugins.undotree.enable = true;
  globals = lib.mkIf config.plugins.undotree.enable {
    undotree_DiffAutoOpen = 1;
    undotree_SetFocusWhenToggle = 1;
  };
  keymaps = lib.mkIf config.plugins.undotree.enable [
    {
      mode = "n";
      key = "<leader>ut";
      action = "<cmd>UndoTreeToggle<CR>";
      options = {
        silent = true;
        desc = "UndoTree";
      };
    }
  ];
}
