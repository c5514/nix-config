{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/config/bootloader.nix
    ../../modules/config/Utils/default.nix
    ../../modules/config/Network/default.nix
    ../../modules/config/Utils/power_management.nix
    #../../modules/config/DeskEnv/gnome.nix
    # ../../modules/config/DeskEnv/hyprland.nix
    ../../modules/config/DeskEnv/niri.nix
  ];

  # Set your time zone.
  time.timeZone = "America/Lima";
  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        ignoreUserConfig = true;
        addons = with pkgs; [
          fcitx5-mozc
          qt6Packages.fcitx5-chinese-addons
          fcitx5-gtk
        ];
        settings = {
          inputMethod = {
            GroupOrder."0" = "Default";
            "Groups/0" = {
              Name = "Default";
              "Default Layout" = "us-altgr-intl";
              DefaultIM = "mozc";
            };
            "Groups/0/Items/0".Name = "keyboard-us-altgr-intl";
            "Groups/0/Items/1".Name = "mozc";
            "Groups/0/Items/2".Name = "pinyin";
          };
          globalOptions = {
            "Hotkey/TriggerKeys"."0" = "Control+space";
            Behavior = {
              ActiveByDefault = "False";
              ShareInputState = "All";
              ShowInputMethodInformation = "False";
            };
          };
          addons = {
            pinyin.globalSection.EmojiEnabled = "True";
          };
        };
      };
    };
  };
  console = {
    earlySetup = false;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v20n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };
  #Configure keymap in X11
  services.xserver = {
    xkb = {
      layout = "us";
      variant = "altgr-intl";
    };
    # videoDrivers = [ "amdgpu" ];
    videoDrivers = [ "modesetting" ];
  };
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
      ];
    };
    i2c.enable = true;
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.c5514 = {
    isNormalUser = true;
    description = "Cesar Levano";
    extraGroups = [
      "networkmanager"
      "wheel"
      "scanner"
      "lp"
    ];
    shell = pkgs.fish;
    # packages = with pkgs; [
    # ];
  };
  programs = {
    fish.enable = true;
    firefox.enable = true;
    dconf.enable = true;
  };
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    libva-utils
    intel-gpu-tools
    wget
    git
    brightnessctl
    playerctl
    wl-clipboard
    cliphist
    pavucontrol
    htop
    unzip
    material-design-icons
    fastfetch
    usbutils
  ];
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    fira-code
    fira-code-symbols
    fira-sans
    font-awesome
    material-icons
    jetbrains-mono
    freefont_ttf
    nerd-fonts.jetbrains-mono
    nerd-fonts.caskaydia-mono
    nerd-fonts.symbols-only
  ];
  security = {
    polkit.enable = true;
    pam.services.gdm.enableGnomeKeyring = true;
  };
  services = {
    gnome.gnome-keyring.enable = true;
    gvfs.enable = true;
    udisks2.enable = true;
    libinput.enable = true;
    flatpak.enable = true;
  };
  xdg.portal.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
