{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        source = "NixoOS";
        padding.right = 1;
        printRemaining = true;
        position = "left";
      };

      display = {
        stat = false;
        showErrors = false;
        disableLinewrap = true;
        hideCursor = true;
        separator = " ";
        brightColor = false;
        key = {
          width = 12;
          type = "string";
        };
        size = {
          binaryPrefix = "iec";
        };
        temp = {
          unit = "C";
          ndigits = 2;
        };
        bar = {
          char = {
            elapsed = "█";
            total = "░";
          };
          border = {
            left = "";
            right = "";
          };
          width = 20;
        };
        percent = {
          type = 3;
          ndigits = 2;
        };
      };
      modules = [
        {
          type = "title";
          format = "{#38;2;97;175;239}┏━━━━━━━━━━━━━━━━━━━━ {user-name-colored} {#38;2;97;175;239}━━━━━━━━━━━━━━━━━━━━━┓";
          color = {
            user = "38;2;97;175;239";
            at = "38;2;97;175;239";
            host = "38;2;97;175;239";
          };
        }
        {
          type = "custom";
          format = "{#38;2;97;175;239}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫";
        }
        # System Information
        {
          type = "os";
          key = "┃ {#keys}{#38;2;97;175;239} OS";
          keyColor = "38;2;97;175;239";
        }
        {
          type = "kernel";
          key = "┃ {#keys}{#38;2;97;175;239} Kernel";
          keyColor = "38;2;97;175;239";
        }
        {
          type = "uptime";
          key = "┃ {#keys}{#38;2;97;175;239} Uptime";
          keyColor = "38;2;97;175;239";
        }
        {
          type = "packages";
          key = "┃ {#keys}{#38;2;97;175;239}󰏖 Pkgs";
          keyColor = "38;2;97;175;239";
          format = "{all}";
        }
        {
          type = "custom";
          format = "{#38;2;97;175;239}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫";
        }
        # Desktop Environment
        {
          type = "de";
          key = "┃ {#keys}{#38;2;97;175;239} DE";
          keyColor = "38;2;97;175;239";
        }
        {
          type = "wm";
          key = "┃ {#keys}{#38;2;97;175;239} WM";
          keyColor = "38;2;97;175;239";
        }
        {
          type = "shell";
          key = "┃ {#keys}{#38;2;97;175;239} Shell";
          keyColor = "38;2;97;175;239";
        }
        {
          type = "display";
          key = "┃ {#keys}{#38;2;97;175;239}󰹑 Display";
          keyColor = "38;2;97;175;239";
        }
        {
          type = "custom";
          format = "{#38;2;97;175;239}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫";
        }
        #Hardware Information
        {
          type = "cpu";
          key = "┃ {#keys}{#38;2;97;175;239} CPU";
          format = "{name} @ {freq-max} │ {3}°C";
          keyColor = "38;2;97;175;239";
          temp = true;
        }
        {
          type = "cpuusage";
          key = "┃ {#keys}{#38;2;97;175;239}󰓅 Usage";
          keyColor = "38;2;97;175;239";
        }
        {
          type = "gpu";
          key = "┃ {#keys}{#38;2;97;175;239}󰾲 GPU";
          format = "{2} | {4}";
          temp = true;
          keyColor = "38;2;97;175;239";
        }
        {
          type = "memory";
          key = "┃ {#keys}{#38;2;97;175;239} Memory";
          format = "{used} / {total}";
          keyColor = "38;2;97;175;239";
        }
        {
          type = "physicaldisk";
          key = "┃ {#keys}{#38;2;97;175;239}󰋊 Drive";
          keyColor = "38;2;97;175;239";
          temp = true;
        }
        {
          type = "disk";
          key = "┃ {#keys}{#38;2;97;175;239}󱁼 Disk";
          keyColor = "38;2;97;175;239";
          format = "{1} / {2} ({3}) - {9}";
        }
        {
          type = "custom";
          format = "{#38;2;97;175;239}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫";
        }
        {
          type = "colors";
          key = "┃        ";
          symbol = "circle";
          keyColor = "38;2;97;175;239";
        }
        {
          type = "custom";
          format = "{#38;2;97;175;239}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛";
        }
      ];
    };
  };
}
