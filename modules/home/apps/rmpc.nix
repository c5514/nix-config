{
  programs.rmpc = {
    enable = true;
    config = ''
      (
          address: "/tmp/mpd_socket",
          password: None,
          theme: Some("dark"),
          cache_dir: None,
          on_song_change: None,
          volume_step: 5,
          max_fps: 30,
          scrolloff: 3,
          wrap_navigation: true,
          enable_mouse: false,
          enable_config_hot_reload: true,
          status_update_interval_ms: Some(1000),
          select_current_song_on_change: true,
          browser_song_sort: [Disc, Track, Artist, Title],
      )
    '';
  };
  xdg.configFile."rmpc/themes/dark.ron".text = ''
    #![enable(implicit_some)]
    #![enable(unwrap_newtypes)]
    #![enable(unwrap_variant_newtypes)]
    (
        default_album_art_path: None,
        draw_borders: false,
        show_song_table_header: false,

        symbols: (
            song: "🎵",
            dir: "📁",
            playlist: "🎼",
            marker: "\u{e0b0}"
        ),

        layout: Split(
            direction: Vertical,
            panes: [
                (
                    size: "1",
                    pane: Pane(Tabs),
                ),
                (
                    size: "4",
                    pane: Split(
                        direction: Horizontal,
                        panes: [
                            (
                                size: "100%",
                                pane: Split(
                                    direction: Vertical,
                                    panes: [
                                        (
                                            size: "4",
                                            borders: "ALL",
                                            pane: Pane(Header),
                                        ),
                                    ]
                                )
                            ),
                        ]
                    ),
                ),
                (
                    size: "100%",
                    pane: Split(
                        direction: Horizontal,
                        panes: [
                            (
                                size: "100%",
                                borders: "NONE",
                                pane: Pane(TabContent),
                            ),
                        ]
                    ),
                ),
                (
                    size: "3",
                    borders: "TOP | BOTTOM",
                    pane: Pane(ProgressBar),
                ),
            ],
        ),

        progress_bar: (
            symbols: ["█", "█", "█", "█", "█"],
            track_style: (fg: "#333333"),
            elapsed_style: (fg: "#7AA2F7"),
            thumb_style: (fg: "#E5C07B"),
        ),

        scrollbar: (
            symbols: ["│", "█", "▲", "▼"],
            track_style: (fg: "#222222"),
            ends_style: (fg: "#4C6A9E"),
            thumb_style: (fg: "#7AA2F7"),
        ),

        browser_column_widths: [20, 38, 42],

        text_color: "#F5F5F5",
        background_color: "#121212",
        header_background_color: "#121212",
        modal_background_color: None,
        modal_backdrop: false,

        tab_bar: (
            active_style: (
                fg: "#121212",
                bg: "#7AA2F7",
                modifiers: "Bold"
            ),
            inactive_style: (
                fg: "#B8B8B8"
            )
        ),

        borders_style: (
            fg: "#4C6A9E"
        ),

        highlighted_item_style: (
            fg: "#7AA2F7",
            modifiers: "Bold"
        ),

        current_item_style: (
            fg: "#121212",
            bg: "#E5C07B",
            modifiers: "Bold"
        ),

        highlight_border_style: (
            fg: "#7AA2F7"
        ),

        song_table_format: [
            (
                prop: (
                    kind: Property(Artist),
                    style: (fg: "#B8B8B8"),
                    default: (kind: Text("Unknown"))
                ),
                width: "50%",
                alignment: Right,
            ),
            (
                prop: (
                    kind: Text("-"),
                    style: (fg: "#4C6A9E"),
                    default: (kind: Text("Unknown"))
                ),
                width: "1",
                alignment: Center,
            ),
            (
                prop: (
                    kind: Property(Title),
                    style: (fg: "#F5F5F5"),
                    default: (kind: Text("Unknown"))
                ),
                width: "50%",
            ),
        ],

        header: (
            rows: [
                (
                    left: [
                        (
                            kind: Text("["),
                            style: (fg: "#7AA2F7", modifiers: "Bold")
                        ),
                        (
                            kind: Property(Status(State)),
                            style: (fg: "#E5C07B", modifiers: "Bold")
                        ),
                        (
                            kind: Text("]"),
                            style: (fg: "#7AA2F7", modifiers: "Bold")
                        )
                    ],

                    center: [
                        (
                            kind: Property(Song(Artist)),
                            style: (fg: "#E5C07B", modifiers: "Bold"),
                            default: (
                                kind: Text("Unknown"),
                                style: (fg: "#E5C07B", modifiers: "Bold")
                            )
                        ),
                        (
                            kind: Text(" - "),
                            style: (fg: "#4C6A9E")
                        ),
                        (
                            kind: Property(Song(Title)),
                            style: (fg: "#F5F5F5", modifiers: "Bold"),
                            default: (
                                kind: Text("No Song"),
                                style: (fg: "#F5F5F5", modifiers: "Bold")
                            )
                        )
                    ],

                    right: [
                        (
                            kind: Text("[ "),
                            style: (fg: "#7AA2F7")
                        ),

                        (
                            kind: Property(Status(RepeatV2(
                                on_label: "",
                                off_label: "",
                                on_style: (
                                    fg: "#E5C07B",
                                    modifiers: "Bold"
                                ),
                                off_style: (
                                    fg: "#F5F5F5",
                                    modifiers: "Bold"
                                )
                            )))
                        ),

                        (
                            kind: Text(" | "),
                            style: (fg: "#4C6A9E")
                        ),

                        (
                            kind: Property(Status(RandomV2(
                                on_label: "",
                                off_label: "",
                                on_style: (
                                    fg: "#E5C07B",
                                    modifiers: "Bold"
                                ),
                                off_style: (
                                    fg: "#F5F5F5",
                                    modifiers: "Bold"
                                )
                            )))
                        ),

                        (
                            kind: Text(" | "),
                            style: (fg: "#4C6A9E")
                        ),

                        (
                            kind: Property(Status(ConsumeV2(
                                on_label: "󰮯",
                                off_label: "󰮯",
                                oneshot_label: "󰮯󰇊",
                                on_style: (
                                    fg: "#E5C07B",
                                    modifiers: "Bold"
                                ),
                                off_style: (
                                    fg: "#F5F5F5",
                                    modifiers: "Bold"
                                )
                            )))
                        ),

                        (
                            kind: Text(" | "),
                            style: (fg: "#4C6A9E")
                        ),

                        (
                            kind: Property(Status(SingleV2(
                                on_label: "󰎤",
                                off_label: "󰎦",
                                oneshot_label: "󰇊",
                                off_oneshot_label: "󱅊",
                                on_style: (
                                    fg: "#E5C07B",
                                    modifiers: "Bold"
                                ),
                                off_style: (
                                    fg: "#F5F5F5",
                                    modifiers: "Bold"
                                )
                            )))
                        ),

                        (
                            kind: Text(" ]"),
                            style: (fg: "#7AA2F7")
                        ),
                    ]
                )
            ],
        ),
    )
  '';
}
