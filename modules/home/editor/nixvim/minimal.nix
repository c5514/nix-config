{
  imports = [
    ./plugins/blink.nix
    ./plugins/conform.nix
    ./plugins/flash.nix
    ./plugins/luasnip.nix
    ./plugins/vimtex.nix
    ./autocmds.nix
    ./options.nix
  ];
  colorschemes.onedark = {
    enable = true;
    settings = {
      style = "warmer";
      colors.bg0 = "#0d1117";
      lualine.transparent = false;
    };
  };
  plugins = {
    lsp = {
      enable = true;
      inlayHints = true;
      servers.texlab.enable = true;
    };
  };
  keymaps = [
    {
      key = ";";
      action = ":";
      mode = "n";
    }
    {
      key = "jk";
      action = "<Esc>";
      mode = "i";
      options = {
        silent = true;
        noremap = true;
      };
    }
    {
      key = "<leader>/";
      action = "<Cmd>nohl<CR>";
      mode = "n";
      options = {
        desc = "Clear search";
      };
    }
  ];
}
