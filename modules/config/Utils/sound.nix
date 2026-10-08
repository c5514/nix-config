{ pkgs, ... }:

let
  fixInternalMicBoost = pkgs.writeShellScript "fix-internal-mic-boost" ''
    set -euo pipefail
    card="$(${pkgs.gawk}/bin/awk '/HDA Intel PCH/ { print $1; exit }' /proc/asound/cards)"
    if [ -z "''${card:-}" ]; then
      echo "fix-internal-mic-boost: HDA Intel PCH card not found, skipping" >&2
      exit 0
    fi
    if ! ${pkgs.alsa-utils}/bin/amixer -c "$card" set 'Internal Mic Boost' 0dB >/dev/null; then
      echo "fix-internal-mic-boost: failed to set 'Internal Mic Boost' on card $card" >&2
      exit 1
    fi
  '';
  internalMicPathOverride = pkgs.runCommand "analog-input-internal-mic-zero-boost.conf" { } ''
    ${pkgs.gawk}/bin/awk '
      /^\[Element Internal Mic Boost\]/ { in_section = 1 }
      /^\[/ && !/^\[Element Internal Mic Boost\]/ { in_section = 0 }
      in_section && /^volume[[:space:]]*=[[:space:]]*merge/ { sub(/merge/, "zero") }
      { print }
    ' ${pkgs.pipewire}/share/alsa-card-profile/mixer/paths/analog-input-internal-mic.conf > $out
  '';

  username = "c5514";
  userHome = "/home/${username}";
in
{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;

    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 44100;
        "default.clock.quantum" = 512;
        "default.clock.min-quantum" = 512;
        "default.clock.max-quantum" = 512;
      };
    };
  };

  environment.systemPackages = with pkgs; [ alsa-utils ];

  systemd.services.fix-internal-mic-boost = {
    description = "Force ALC257 'Internal Mic Boost' to 0 dB";
    after = [ "sound.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${fixInternalMicBoost}";
    };
    wantedBy = [
      "multi-user.target"
      "post-resume.target"
    ];
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="sound", KERNEL=="controlC*", KERNELS!="card*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="fix-internal-mic-boost.service"
  '';

  system.activationScripts.fixInternalMicBoostAcp = {
    text = ''
      install -d -m 0755 -o ${username} -g users ${userHome}/.config/alsa-card-profile/paths
      ln -sf ${internalMicPathOverride} ${userHome}/.config/alsa-card-profile/paths/analog-input-internal-mic.conf
    '';
  };
}
