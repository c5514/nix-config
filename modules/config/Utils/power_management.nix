{
  config,
  lib,
  pkgs,
  ...
}:

{
  powerManagement = {
    enable = true;
    powertop.enable = true;
  };
  services = {
    upower.enable = true;
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "powersave";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 1;
        CPU_HWP_DYN_BOOST_ON_AC = 1;
        CPU_HWP_DYN_BOOST_ON_BAT = 0;
        PLATFORM_PROFILE_ON_AC = "balanced";
        PLATFORM_PROFILE_ON_BAT = "low-power";
        PCIE_ASPM_ON_AC = "default";
        PCIE_ASPM_ON_BAT = "powersupersave";
        SATA_LINKPWR_ON_AC = "med_power_with_dipm";
        SATA_LINKPWR_ON_BAT = "min_power";
        WIFI_PWR_ON_AC = "off";
        WIFI_PWR_ON_BAT = "on";
        USB_AUTOSUSPEND = 1;
        SOUND_POWER_SAVE_ON_AC = 0;
        SOUND_POWER_SAVE_ON_BAT = 1;
        SOUND_POWER_SAVE_CONTROLLER = "Y";
        RUNTIME_PM_ON_AC = "on";
        RUNTIME_PM_ON_BAT = "auto";
      };
    };
    power-profiles-daemon.enable = lib.mkForce false;
    thermald.enable = true;
  };
  systemd.services.battery-conservation-mode = {
    description = "Enable Lenovo battery conservation (Long_Life) charging";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.writeShellScript "set-long-life" ''
        for f in /sys/class/power_supply/BAT*/charge_types; do
          [ -w "$f" ] && echo Long_Life > "$f"
        done
      ''}";
    };
  };
}
