{ pkgs, lib, ... }:
{
  imports = [
    ./hypridle.nix
    ./hyprlock.nix
  ];
  home.packages = with pkgs; [
    grimblast
    hyprsunset
    quickshell
    matugen
  ];
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    xwayland.enable = true;
    extraConfig = ''
      ---- MONITORS ----
      hl.monitor({
      	output = "eDP-1",
      	mode = "preferred",
      	position = "auto",
      	scale = "1",
      })
      hl.monitor({
      	output = "",
      	mode = "preferred",
      	position = "auto",
      	scale = "1",
      	mirror = "eDP-1",
      })

      ---- MY PROGRAMS ----

      local terminal = "wezterm"
      local fileManager = "~/Scripts/yazi.sh"
      local fileManager2 = "nautilus"
      local menu = "qs ipc call launcher toggle"
      local wallpaper = "qs ipc call wallpaper toggle"
      local powermenu = "qs ipc call powermenu toggle"
      local clipboard = "qs ipc call clipboard toggle"
      local browser = "firefox"
      local browser2 = "brave"

      ---- AUTOSTART ----
      hl.on("hyprland.start", function()
      	hl.exec_cmd("awww-daemon")
      	hl.exec_cmd("quickshell")
      	hl.exec_cmd("hypridle &")
      	hl.exec_cmd("hyprsunset -t 3500")
      	hl.exec_cmd("wl-paste --type text --watch cliphist store")
      	hl.exec_cmd("wl-paste --type image --watch cliphist store")
      	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
      	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
      	hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
      end)

      ---- ENVIRONMENT VARIABLES ----
      hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
      hl.env("HYPRCURSOR_SIZE", "24")
      hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
      hl.env("XCURSOR_SIZE", "24")
      hl.env("GDK_BACKEND", "wayland, x11,*")
      hl.env("QT_QPA_PLATFORM", "wayland;xcb")
      hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
      hl.env("XDG_SESSION_TYPE", "wayland")
      hl.env("XDG_SESSION_DESKTOP", "Hyprland")
      hl.env("WAYLAND_DISPLAY", "wayland-1")

      ----- PERMISSIONS -----
      hl.config({
      	ecosystem = {
      		enforce_permissions = true,
      	},
      })
      hl.permission(".*/bin/grimblast", "screencopy", "allow")
      hl.permission(".*/bin/grim", "screencopy", "allow")
      hl.permission(".*xdg-desktop-portal-hyprland", "screencopy", "allow")
      hl.permission(".*/bin/hyprlock", "screencopy", "allow")
      hl.permission(".*quickshell.*", "screencopy", "allow")
      -- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

      ---- LOOK AND FEEL ----
      hl.config({
      	general = {
      		gaps_in = 2,
      		gaps_out = 4,
      		border_size = 3,
      		col = {
      			active_border = "rgba(49A0E6FF)",
      			inactive_border = "rgba(595959aa)",
      		},
      		resize_on_border = true,
      		allow_tearing = false,
      		layout = "dwindle",
      	},

      	decoration = {
      		rounding = 15,
      		rounding_power = 2,
      		active_opacity = 1.0,
      		inactive_opacity = 1.0,
      		shadow = {
      			enabled = true,
      			range = 3,
      			render_power = 3,
      			color = "rgba(1a1a1aee)",
      		},
      		blur = {
      			enabled = true,
      			size = 6,
      			passes = 3,
      			vibrancy = 0.1696,
      		},
      	},
      	animations = {
      		enabled = true,
      	},
      })

      -- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
      hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
      hl.curve("md3_standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
      hl.curve("md3_decel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
      hl.curve("md3_accel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
      hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.1 } } })
      hl.curve("crazyshot", { type = "bezier", points = { { 0.1, 1.5 }, { 0.76, 0.92 } } })
      hl.curve("hyprnostretch", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
      hl.curve("menu_decel", { type = "bezier", points = { { 0.1, 1 }, { 0, 1 } } })
      hl.curve("menu_accel", { type = "bezier", points = { { 0.38, 0.04 }, { 1, 0.07 } } })
      hl.curve("easeInOutCirc", { type = "bezier", points = { { 0.85, 0 }, { 0.15, 1 } } })
      hl.curve("easeOutCirc", { type = "bezier", points = { { 0, 0.55 }, { 0.45, 1 } } })
      hl.curve("easeOutExpo", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
      hl.curve("softAcDecel", { type = "bezier", points = { { 0.26, 0.26 }, { 0.15, 1 } } })
      hl.curve("md2", { type = "bezier", points = { { 0.4, 0 }, { 0.2, 1 } } })

      hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "md3_decel" })
      hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "md3_decel", style = "popin 60%" })
      hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "md3_accel", style = "popin 60%" })
      hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
      hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "md3_decel" })
      hl.animation({ leaf = "layers", enabled = true, speed = 2, bezier = "md3_decel", style = "slide" })
      hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "menu_decel", style = "slide" })
      hl.animation({ leaf = "layersOut", enabled = true, speed = 1.6, bezier = "menu_accel" })
      hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "menu_decel" })
      hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 4.5, bezier = "menu_accel" })
      hl.animation({ leaf = "workspaces", enabled = true, speed = 7, bezier = "menu_decel", style = "slide" })
      hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "md3_decel", style = "slidevert" })

      hl.config({
      	dwindle = {
      		preserve_split = true,
      	},
      })
      hl.config({
      	master = {
      		new_status = "master",
      	},
      })

      hl.config({
      	scrolling = {
      		fullscreen_on_one_column = true,
      	},
      })

      ---- INPUT ----
      hl.config({
      	input = {
      		kb_layout = "us",
      		kb_variant = "altgr-intl",
      		kb_model = "",
      		kb_options = "",
      		kb_rules = "",
      		follow_mouse = 1,
      		sensitivity = 0,
      		touchpad = {
      			natural_scroll = false,
      		},
      		numlock_by_default = true,
      	},
      })
      hl.gesture({
      	fingers = 3,
      	direction = "horizontal",
      	action = "workspace",
      })
      hl.device({
      	name = "epic-mouse-v1",
      	sensitivity = -0.5,
      })
      hl.config({
      	misc = {
      		force_default_wallpaper = 0,
      		disable_hyprland_logo = true,
      	},
      })

      ---- KEYBINDINGS ----
      local mainMod = "SUPER"

      hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
      hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
      hl.bind(mainMod .. " + Q", hl.dsp.window.close())
      hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
      hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(fileManager2))
      hl.bind(mainMod .. " + BACKSPACE", hl.dsp.exec_cmd(powermenu))
      hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(clipboard))
      hl.bind(mainMod .. " + CTRL + V", hl.dsp.exec_cmd("cliphist wipe"))
      hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(wallpaper))
      hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
      hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(browser2))
      hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("qs ipc call picker toggle"))
      hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("qs ipc call theme toggle"))
      hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("qs ipc call calendar toggle"))
      hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("qs ipc call quickSettings toggle"))
      hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("qs ipc call audio-input toggle"))
      hl.bind("XF86Cut", hl.dsp.exec_cmd("grimblast copy area"))
      hl.bind(mainMod .. " + XF86Cut", hl.dsp.exec_cmd("grimblast copy active"))
      hl.bind(mainMod .. " + SHIFT + XF86Cut", hl.dsp.exec_cmd("grimblast copy screen"))

      -- Windows sizes
      hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
      hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
      hl.bind(mainMod .. " + CTRL + F", hl.dsp.window.float({ action = "toggle" }))
      hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

      hl.bind(mainMod .. " + T", function()
      	local workspace = hl.get_active_special_workspace() or hl.get_active_workspace()
      	if workspace.tiled_layout == "dwindle" then
      		hl.dispatch(hl.dsp.layout("togglesplit"))
      	elseif workspace.tiled_layout == "scrolling" then
      		hl.dispatch(hl.dsp.layout("colresize +conf"))
      	end
      end)

      -- Move focus of windows
      hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
      hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
      hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
      hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))
      hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
      hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
      hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
      hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
      hl.bind(mainMod .. " + TAB", hl.dsp.focus({ workspace = "previous" }))
      hl.bind("ALT + TAB", function()
      	local workspace = hl.get_active_special_workspace() or hl.get_active_workspace()
      	if workspace.tiled_layout == "dwindle" or workspace.tiled_layout == "scrolling" then
      		hl.dispatch(hl.dsp.window.cycle_next())
      		hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom" }))
      	else
      		hl.dispatch(hl.dsp.layout("cyclenext"))
      	end
      end)
      hl.bind("ALT + SHIFT + TAB", function()
      	local workspace = hl.get_active_special_workspace() or hl.get_active_workspace()
      	if not workspace then
      		return
      	end

      	if workspace.tiled_layout == "dwindle" or workspace.tiled_layout == "scrolling" then
      		hl.dispatch(hl.dsp.window.cycle_next("prev"))
      		hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
      	else
      		hl.dispatch(hl.dsp.layout("cycleprev"))
      	end
      end)
      -- Swap windows
      hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.swap({ direction = "left" }))
      hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.swap({ direction = "right" }))
      hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.swap({ direction = "up" }))
      hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.swap({ direction = "down" }))
      -- Resize windows (Non finished)
      hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.resize({ x = -40, y = 0, relative = true }))
      hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.resize({ x = 40, y = 0, relative = true }))
      hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.resize({ x = 0, y = -40, relative = true }))
      hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.resize({ x = 0, y = 40, relative = true }))

      -- Switch workspaces with mainMod + [0-9]
      -- Move active window to a workspace with mainMod + SHIFT + [0-9]
      for i = 1, 10 do
      	local key = i % 10 -- 10 maps to key 0
      	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
      	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
      end

      -- Example special workspace (scratchpad)
      hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
      hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

      -- Scroll through existing workspaces with mainMod + scroll
      hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
      hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

      -- Move/resize windows with mainMod + LMB/RMB and dragging
      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

      -- Laptop multimedia keys for volume and LCD brightness
      hl.bind(
      	"XF86AudioRaiseVolume",
      	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
      	{ locked = true, repeating = true }
      )
      hl.bind(
      	"XF86AudioLowerVolume",
      	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
      	{ locked = true, repeating = true }
      )
      hl.bind(
      	"XF86AudioMute",
      	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
      	{ locked = true, repeating = true }
      )
      hl.bind(
      	"XF86AudioMicMute",
      	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
      	{ locked = true, repeating = true }
      )
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

      -- Requires playerctl
      hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
      hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
      hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

      ---- WINDOWS AND WORKSPACES ----
      local suppressMaximizeRule = hl.window_rule({
      	-- Ignore maximize requests from all apps. You'll probably like this.
      	name = "suppress-maximize-events",
      	match = { class = ".*" },

      	suppress_event = "maximize",
      })
      -- suppressMaximizeRule:set_enabled(false)

      hl.window_rule({
      	-- Fix some dragging issues with XWayland
      	name = "fix-xwayland-drags",
      	match = {
      		class = "^$",
      		title = "^$",
      		xwayland = true,
      		float = true,
      		fullscreen = false,
      		pin = false,
      	},

      	no_focus = true,
      })

      -- Layer rules also return a handle.
      -- local overlayLayerRule = hl.layer_rule({
      --     name  = "no-anim-overlay",
      --     match = { namespace = "^my-overlay$" },
      --     no_anim = true,
      -- })
      -- overlayLayerRule:set_enabled(false)
      -- Blur behind the Quickshell dock (and its previews) and the desktop clock
      hl.layer_rule({
        match = { namespace = "^quickshell-dock$" },
      	blur = true,
      	ignore_alpha = 0.2,
      })
      hl.layer_rule({
      	match = { namespace = "^quickshell-desktop-clock$" },
      	blur = true,
      	ignore_alpha = 0.2,
      })
      hl.window_rule({ match = { class = "org.gnome.Calculator" }, float = true })
      hl.window_rule({ match = { class = "org.gnome.Weather" }, float = true })
      hl.window_rule({ match = { class = "org.gnome.Settings" }, float = true })
      hl.window_rule({ match = { class = "org.gnome.Nautilus" }, float = true })
      hl.window_rule({ match = { class = "xdg-desktop-portal-gtk" }, float = true })
      hl.window_rule({ match = { class = "com.github.wwmm.easyeffects" }, float = true })
      hl.window_rule({ match = { class = "thunar" }, float = true })
      hl.window_rule({ match = { class = "org.pulseaudio.pavucontrol" }, float = true })
      hl.window_rule({ match = { class = "feh" }, float = true })
      hl.window_rule({ match = { class = "Zotero" }, float = true })
      hl.window_rule({ match = { class = "org.pwmt.zathura" }, idle_inhibit = "focus" })
      hl.window_rule({ match = { class = "com.mitchellh.ghostty" }, idle_inhibit = "focus" })
      hl.window_rule({ match = { class = "foot" }, idle_inhibit = "focus" })
      hl.window_rule({ match = { class = "org.wezfurlong.wezterm" }, idle_inhibit = "focus" })
      hl.window_rule({ match = { class = "firefox" }, idle_inhibit = "focus" })
      hl.window_rule({ match = { class = "org.gnome.Evince" }, idle_inhibit = "focus", workspace = "3 silent" })
      hl.window_rule({ match = { class = "org.gnome.Papers" }, idle_inhibit = "focus", workspace = "3 silent" })
      hl.window_rule({ match = { class = "mpv" }, idle_inhibit = "focus", float = true, size = { 840, 460 } })
      hl.window_rule({ match = { class = "Tor Browser" }, workspace = "8" })
      hl.window_rule({ match = { class = "org.inkscape.Inkscape" }, workspace = "5" })
      hl.window_rule({ match = { class = "nz.co.mega" }, float = true, size = { 600, 600 } })
      hl.window_rule({
      	match = { class = "Spotify" },
      	idle_inhibit = "focus",
      	workspace = "7 silent",
      	float = true,
      	size = { 800, 600 },
      	move = { 20, 60 },
      })
      hl.window_rule({
      	match = { class = "thunderbird" },
      	idle_inhibit = "focus",
      	workspace = "6 silent",
      	float = true,
      	size = { 1075, 600 },
      	move = { 20, 60 },
      })
      hl.window_rule({
      	match = { class = "foot", title = "quick-latex" },
      	float = true,
      	size = { 540, 540 },
      	move = { 400, 200 },
      })
      hl.window_rule({
      	match = { class = "__main__.py", xwayland = true },
      	float = true,
      	size = { 540, 540 },
      	move = { 100, 200 },
      })
      hl.window_rule({
      	match = { class = "nm-connection-editor" },
      	float = true,
      	size = { 540, 540 },
      	move = { 100, 200 },
      })

      -- Hyprland-run windowrule
      hl.window_rule({
      	name = "move-hyprland-run",
      	match = { class = "hyprland-run" },
      	move = "20 monitor_h-120",
      	float = true,
      })

      hl.workspace_rule({ workspace = "1", layout = "monocle" })
      hl.workspace_rule({ workspace = "2", layout = "scrolling" })
      hl.workspace_rule({ workspace = "3", layout = "scrolling" })
      hl.workspace_rule({ workspace = "6", layout = "scrolling" })
      hl.workspace_rule({ workspace = "8", layout = "monocle" })
    '';
  };
}
