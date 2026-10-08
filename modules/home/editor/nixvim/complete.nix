{ pkgs, ... }:
{
  imports = [
    ./plugins/alpha.nix
    ./plugins/autopairs.nix
    ./plugins/blink.nix
    ./plugins/bufferline.nix
    ./plugins/conform.nix
    ./plugins/flash.nix
    ./plugins/git.nix
    ./plugins/illustrate.nix
    ./plugins/indent.nix
    ./plugins/lsp.nix
    ./plugins/lualine.nix
    ./plugins/luasnip.nix
    ./plugins/markview.nix
    ./plugins/mini.nix
    ./plugins/neotree.nix
    ./plugins/smart-splits.nix
    ./plugins/telescope.nix
    ./plugins/todo-comments.nix
    ./plugins/treesitter.nix
    ./plugins/undotree.nix
    ./plugins/vimtex.nix
    ./plugins/yazi.nix
    ./autocmds.nix
    ./keymaps.nix
    ./options.nix
    ./latex-templates.nix
  ];
  viAlias = true;
  vimAlias = true;
  plugins.vimtex.texlivePackage = pkgs.texliveFull;
  colorschemes.onedark = {
    enable = true;
    settings = {
      style = "warmer";
      colors.bg0 = "#0d1117";
      lualine.transparent = false;
    };
  };
}
