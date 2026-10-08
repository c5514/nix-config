{ config, ... }:
{
  services.restic = {
    enable = true;
    backups = {
      projects = {
        initialize = true;
        repository = "rclone:onedrive-research:restic-repo";
        passwordFile = "${config.home.homeDirectory}/.config/restic/projects-password.txt";
        paths = [ "${config.home.homeDirectory}/Research/Projects" ];
        pruneOpts = [
          "--keep-daily 30"
          "--keep-weekly 12"
          "--keep-monthly 12"
          "--keep-yearly 3"
        ];
        exclude = [
          "*.aux"
          "*.log"
          "*.toc"
          "*.lof"
          "*.lot"
          "*.out"
          "*.fls"
          "*.fdb_latexmk"
          "*.synctex.gz"
          "*.bbl"
          "*.blg"
          "*.nav"
          "*.snm"
          "*.vrb"
          "*~"
          ".DS_Store"
        ];
        timerConfig = {
          OnCalendar = "06:00";
          RandomizedDelaySec = "30min";
          Persistent = true;
        };
      };
      references = {
        initialize = true;
        repository = "rclone:mega-references:restic-repo";
        passwordFile = "${config.home.homeDirectory}/.config/restic/references-password.txt";
        paths = [ "${config.home.homeDirectory}/Research/References" ];
        exclude = [
          "*~"
          ".DS_Store"
        ];
        pruneOpts = [
          "--keep-daily 5"
          "--keep-weekly 3"
          "--keep-monthly 3"
          "--keep-yearly 3"
        ];
        timerConfig = {
          OnCalendar = "06:45";
          RandomizedDelaySec = "30min";
          Persistent = true;
        };
      };
    };
  };
}
