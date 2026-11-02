pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../style"

// Mirrors the QuickShell palette onto desktop app configs. Colors come from
// Theme (matugen), so every write follows the current wallpaper. Each target
// can be switched off in the quick settings "App colors" tab; off leaves the
// last generated file untouched.
//
// One-time wiring for the files that need it:
//   GTK       automatic (~/.config/gtk-3.0/gtk.css, gtk-4.0/gtk.css)
//   Qt        qt6ct color_scheme_path (already set here)
//   Niri      include "quickshell.kdl" (already set here)
//   Ghostty   theme = Quickshell
//   Foot      include=~/.config/foot/quickshell.ini (already set here)
//   Alacritty import = ["~/.config/alacritty/quickshell.toml"]
//   Kitty     include ~/.config/kitty/quickshell.conf
//   Neovim    :colorscheme quickshell
//   Helix     theme = "quickshell"
//   Zed       dark theme "Quickshell" (set in ~/.config/zed/settings.json here)
//   Bash      source ~/.config/bash/quickshell.sh
//   Fish      automatic (conf.d is sourced)
//   bat       --theme="quickshell" in ~/.config/bat/config (set here)
//
// Disabling a target never deletes its file: the app keeps the colors it last
// got. "Apply now" in the settings tab rewrites every enabled file.
Singleton {
    id: root

    readonly property string configHome: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        return xdg && xdg.length > 0 ? xdg : Quickshell.env("HOME") + "/.config";
    }

    // Groups shown in the quick settings "App colors" tab.
    readonly property var groups: [
        {
            label: "Desktop",
            apps: [
                { id: "gtk", label: "GTK", icon: "widgets" },
                { id: "qt", label: "Qt", icon: "apps" },
                { id: "niri", label: "Niri", icon: "window" }
            ]
        },
        {
            label: "Terminals",
            apps: [
                { id: "ghostty", label: "Ghostty", icon: "terminal" },
                { id: "foot", label: "Foot", icon: "terminal" },
                { id: "alacritty", label: "Alacritty", icon: "terminal" },
                { id: "kitty", label: "Kitty", icon: "terminal" }
            ]
        },
        {
            label: "Editors",
            apps: [
                { id: "nvim", label: "Neovim", icon: "code" },
                { id: "helix", label: "Helix", icon: "code" },
                { id: "zed", label: "Zed", icon: "code" }
            ]
        },
        {
            label: "Shells",
            apps: [
                { id: "bash", label: "Bash", icon: "terminal" },
                { id: "fish", label: "Fish", icon: "water" },
                { id: "bat", label: "bat", icon: "description" }
            ]
        }
    ]

    // The state file is read synchronously before the first write, so a target
    // switched off in a previous session is not regenerated on startup.
    property bool ready: false

    FileView {
        id: stateFile

        path: Qt.resolvedUrl("../theme-apps.json")
        preload: false
        blockAllReads: true
        blockWrites: true
        blockLoading: true
        printErrors: false

        Component.onCompleted: {
            text();
            root.ready = true;
            root.applyAll();
        }

        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: props

            property string themeAppsOff
        }
    }

    readonly property string themeAppsOff: props.themeAppsOff ? props.themeAppsOff : ""

    function enabled(id: string): bool {
        const ids = root.themeAppsOff.split(",");
        for (let i = 0; i < ids.length; i++) {
            if (ids[i] === id)
                return false;
        }
        return true;
    }

    function setEnabled(id: string, enabled: bool): void {
        const ids = root.themeAppsOff.split(",").filter(name => name !== "" && name !== id);
        if (!enabled)
            ids.push(id);
        props.themeAppsOff = ids.join(",");
        root.applyAll();
    }

    // ---- color formats --------------------------------------------------------

    function pad(value: real): string {
        const text = Math.round(value).toString(16);
        return text.length < 2 ? "0" + text : text;
    }

    function rgb(c: color): string {
        return "#" + pad(c.r * 255) + pad(c.g * 255) + pad(c.b * 255);
    }

    // niri colors are #rrggbbaa, alpha last.
    function rgba(c: color): string {
        return rgb(c) + pad(c.a * 255);
    }

    // Qt palette files are #aarrggbb.
    function argb(c: color): string {
        return "#" + pad(c.a * 255) + pad(c.r * 255) + pad(c.g * 255) + pad(c.b * 255);
    }

    function css(c: color): string {
        if (c.a >= 1)
            return rgb(c);
        return "rgba(" + Math.round(c.r * 255) + ", " + Math.round(c.g * 255) + ", "
            + Math.round(c.b * 255) + ", " + (Math.round(c.a * 100) / 100) + ")";
    }

    function alpha(c: color, factor: real): color {
        return Qt.rgba(c.r, c.g, c.b, factor);
    }

    // The 16 ANSI slots are built from M3 roles: roles stay contrast-safe
    // against `surface` even on muted wallpapers.
    readonly property var terminalNormal: [
        Theme.surfaceContainerLowest,
        Theme.error,
        Theme.secondary,
        Theme.tertiary,
        Theme.primary,
        Theme.tertiary,
        Theme.secondary,
        Theme.surfaceText
    ]

    readonly property var terminalBright: [
        Theme.outline,
        Theme.error,
        Theme.secondary,
        Theme.tertiary,
        Theme.primary,
        Theme.tertiary,
        Theme.secondary,
        Theme.surfaceText
    ]

    // Re-run after matugen rewrites Colors.json. The debounce collapses the
    // per-role adapter updates into one write per target.
    readonly property string paletteKey: [
        Theme.primary, Theme.primaryText, Theme.primaryContainer, Theme.primaryContainerText,
        Theme.secondary, Theme.secondaryText, Theme.tertiary, Theme.tertiaryText,
        Theme.error, Theme.errorText, Theme.errorContainer,
        Theme.surface, Theme.surfaceText, Theme.surfaceVariantText,
        Theme.surfaceContainerLowest, Theme.surfaceContainerLow, Theme.surfaceContainer,
        Theme.surfaceContainerHigh, Theme.surfaceContainerHighest,
        Theme.outline, Theme.outlineVariant, Theme.inverseSurface, Theme.inverseSurfaceText,
        Theme.shadow
    ].join("|")

    onPaletteKeyChanged: applyKick.restart()

    Timer {
        id: applyKick

        interval: 50
        onTriggered: root.applyAll()
    }

    // ---- GTK ------------------------------------------------------------------

    readonly property var gtkColors: [
        ["accent_color", Theme.primary],
        ["accent_bg_color", Theme.primary],
        ["accent_fg_color", Theme.primaryText],
        ["destructive_bg_color", Theme.error],
        ["destructive_fg_color", Theme.errorText],
        ["error_bg_color", Theme.error],
        ["error_fg_color", Theme.errorText],
        ["window_bg_color", Theme.surface],
        ["window_fg_color", Theme.surfaceText],
        ["view_bg_color", Theme.surfaceContainerLowest],
        ["view_fg_color", Theme.surfaceText],
        ["headerbar_bg_color", Theme.surfaceContainer],
        ["headerbar_fg_color", Theme.surfaceText],
        ["headerbar_backdrop_color", Theme.surface],
        ["popover_bg_color", Theme.surfaceContainerHigh],
        ["popover_fg_color", Theme.surfaceText],
        ["card_bg_color", Theme.surfaceContainerHigh],
        ["card_fg_color", Theme.surfaceText],
        ["dialog_bg_color", Theme.surfaceContainerHigh],
        ["dialog_fg_color", Theme.surfaceText],
        ["overview_bg_color", Theme.surfaceContainerHighest],
        ["overview_fg_color", Theme.surfaceText],
        ["sidebar_bg_color", Theme.surfaceContainerLow],
        ["sidebar_fg_color", Theme.surfaceText],
        ["sidebar_backdrop_color", Theme.surface],
        ["sidebar_border_color", Theme.surface],
        ["secondary_sidebar_bg_color", Theme.surfaceContainerLow],
        ["secondary_sidebar_fg_color", Theme.surfaceText]
    ]

    readonly property var gtkAliases: [
        ["theme_selected_bg_color", "accent_bg_color"],
        ["theme_selected_fg_color", "accent_fg_color"],
        ["theme_unfocused_fg_color", "window_fg_color"],
        ["theme_unfocused_text_color", "view_fg_color"],
        ["theme_unfocused_bg_color", "window_bg_color"],
        ["theme_unfocused_base_color", "window_bg_color"],
        ["theme_unfocused_selected_bg_color", "accent_bg_color"],
        ["theme_unfocused_selected_fg_color", "accent_fg_color"]
    ]

    readonly property var gtk4Extra: [
        ["error-color", Theme.error],
        ["warning-bg-color", Theme.tertiary],
        ["warning-fg-color", Theme.tertiaryText],
        ["warning-color", Theme.tertiary],
        ["success-color", Theme.secondary],
        ["success-bg-color", Theme.secondary],
        ["success-fg-color", Theme.secondaryText],
        ["shade-color", Qt.rgba(0, 0, 0, 0.36)]
    ]

    function gtkCss(gtk4: bool): string {
        const lines = [
            "/*",
            "* GTK colors — generated by quickshell (services/SystemTheme.qml) from",
            "* the active dark palette; edits are overwritten.",
            "*/",
            ""
        ];
        for (let i = 0; i < root.gtkColors.length; i++) {
            const entry = root.gtkColors[i];
            lines.push("@define-color " + entry[0] + " " + css(entry[1]) + ";");
        }
        lines.push("");
        lines.push("/* Focused selection and backdrop states */");
        for (let i = 0; i < root.gtkAliases.length; i++)
            lines.push("@define-color " + root.gtkAliases[i][0] + " @" + root.gtkAliases[i][1] + ";");
        if (!gtk4)
            return lines.join("\n") + "\n";

        lines.push("");
        lines.push(":root {");
        for (let i = 0; i < root.gtkColors.length; i++) {
            const entry = root.gtkColors[i];
            lines.push("    --" + entry[0].replace(/_/g, "-") + ": " + css(entry[1]) + ";");
        }
        lines.push("");
        for (let i = 0; i < root.gtk4Extra.length; i++) {
            const entry = root.gtk4Extra[i];
            lines.push("    --" + entry[0] + ": " + css(entry[1]) + ";");
        }
        lines.push("}");
        return lines.join("\n") + "\n";
    }

    // ---- ghostty --------------------------------------------------------------

    function ghosttyTheme(): string {
        const lines = [
            "# Ghostty theme — generated by quickshell (services/SystemTheme.qml)",
            "# from the active dark palette; edits are overwritten.",
            "background = " + rgb(Theme.surface),
            "foreground = " + rgb(Theme.surfaceText),
            "cursor-color = " + rgb(Theme.primary),
            "cursor-text = " + rgb(Theme.primaryText),
            "selection-background = " + rgb(Theme.primaryContainer),
            "selection-foreground = " + rgb(Theme.primaryContainerText)
        ];
        for (let i = 0; i < 8; i++)
            lines.push("palette = " + i + "=" + rgb(root.terminalNormal[i]));
        for (let i = 0; i < 8; i++)
            lines.push("palette = " + (i + 8) + "=" + rgb(root.terminalBright[i]));
        return lines.join("\n") + "\n";
    }

    // ---- Qt (qt6ct) -----------------------------------------------------------

    function qtPalette(): string {
        const row = [
            Theme.surfaceText, // windowText
            Theme.surfaceContainer, // button
            Theme.surfaceContainerHighest, // light
            Theme.surfaceContainerHigh, // midlight
            Theme.surfaceContainerLowest, // dark
            Theme.surfaceContainerLow, // mid
            Theme.surfaceText, // text
            Theme.primaryText, // brightText
            Theme.surfaceText, // buttonText
            Theme.surfaceContainerLow, // base
            Theme.surface, // window
            Theme.shadow, // shadow
            Theme.primary, // highlight
            Theme.primaryText, // highlightedText
            Theme.primary, // link
            Theme.tertiary, // linkVisited
            Theme.surfaceContainer, // alternateBase
            Theme.surfaceContainerLow, // NO_IDEA
            Theme.inverseSurface, // toolTipBase
            Theme.inverseSurfaceText, // toolTipText
            Theme.surfaceVariantText, // placeholderText
            Theme.primary // accent
        ];
        let colors = "";
        for (let i = 0; i < row.length; i++)
            colors += (i === 0 ? "" : ", ") + argb(row[i]);
        return [
            "[ColorScheme]",
            "#https://doc.qt.io/qt-6/qpalette.html",
            "# Generated by quickshell (services/SystemTheme.qml) from the active dark palette; edits are overwritten.",
            "# windowText,button,light,midlight,dark,mid,text,brightText,buttonText,base,window,"
                + "shadow,highlight,highlightedText,link,linkVisited,alternateBase,NO_IDEA,"
                + "toolTipBase,toolTipText,placeholderText,accent",
            "active_colors=" + colors,
            "disabled_colors=" + colors,
            "inactive_colors=" + colors,
            ""
        ].join("\n");
    }

    // ---- niri -----------------------------------------------------------------

    readonly property color niriActive: Theme.primary
    readonly property color niriInactive: root.alpha(Theme.primary, 0.35)
    readonly property color niriUrgent: Theme.error
    readonly property color niriActiveFrom: root.alpha(Theme.primary, 0.40)
    readonly property color niriActiveTo: root.alpha(Theme.secondary, 0.40)
    readonly property color niriInactiveFrom: root.alpha(Theme.surfaceVariantText, 0.70)
    readonly property color niriInactiveTo: root.alpha(Theme.surface, 0.70)

    // The color block is regenerated; the non-color blocks below it keep the
    // current blur/rounding/animation behavior.
    function niriText(): string {
        return [
            "// Generated by quickshell (services/SystemTheme.qml) — edits are overwritten.",
            "",
            "layout {",
            "    focus-ring {",
            "        active-gradient from=\"" + rgba(root.niriActiveFrom) + "\" to=\""
                + rgba(root.niriActiveTo) + "\" angle=180",
            "        inactive-gradient from=\"" + rgba(root.niriInactiveFrom) + "\" to=\""
                + rgba(root.niriInactiveTo) + "\" angle=45 relative-to=\"workspace-view\"",
            "    }",
            "",
            "    border {",
            "        active-color \"" + rgba(root.niriActive) + "\"",
            "        inactive-color \"" + rgba(root.niriInactive) + "\"",
            "        urgent-color \"" + rgba(root.niriUrgent) + "\"",
            "        active-gradient from=\"" + rgba(root.niriActiveFrom) + "\" to=\""
                + rgba(root.niriActiveTo) + "\" angle=150",
            "        inactive-gradient from=\"" + rgba(root.niriInactiveFrom) + "\" to=\""
                + rgba(root.niriInactiveTo) + "\" angle=150",
            "    }",
            "}",
            "",
            "layer-rule {",
            "    match namespace=\"^quickshell:\"",
            "",
            "    background-effect {",
            "        xray false",
            "    }",
            "}",
            "",
            "blur {",
            "    passes 1",
            "}",
            "",
            "window-rule {",
            "    geometry-corner-radius 8",
            "    clip-to-geometry true",
            "}",
            "",
            "animations {",
            "    slowdown 1.0",
            "}",
            ""
        ].join("\n");
    }

    // ---- other terminals ------------------------------------------------------

    function footTheme(): string {
        const hex = c => rgb(c).substring(1);
        const colors = [
            "background=" + hex(Theme.surface),
            "foreground=" + hex(Theme.surfaceText),
            "cursor=" + hex(Theme.surface) + " " + hex(Theme.primary),
            "selection-background=" + hex(Theme.primaryContainer),
            "selection-foreground=" + hex(Theme.primaryContainerText)
        ];
        for (let i = 0; i < 8; i++)
            colors.push("regular" + i + "=" + hex(root.terminalNormal[i]));
        for (let i = 0; i < 8; i++)
            colors.push("bright" + i + "=" + hex(root.terminalBright[i]));
        const lines = [
            "# Foot colors — generated by quickshell (services/SystemTheme.qml)",
            "# from the active dark palette; edits are overwritten.",
            ""
        ];
        for (const section of ["[colors-dark]", "[colors-light]"]) {
            lines.push(section);
            for (const line of colors)
                lines.push(line);
            lines.push("");
        }
        return lines.join("\n");
    }

    function alacrittyTheme(): string {
        const names = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];
        const lines = [
            "# Alacritty colors — generated by quickshell (services/SystemTheme.qml)",
            "# from the active dark palette; edits are overwritten.",
            "",
            "[colors.primary]",
            "background = \"" + rgb(Theme.surface) + "\"",
            "foreground = \"" + rgb(Theme.surfaceText) + "\"",
            "dim_foreground = \"" + rgb(Theme.surfaceVariantText) + "\"",
            "bright_foreground = \"" + rgb(Theme.surfaceText) + "\"",
            "",
            "[colors.cursor]",
            "text = \"" + rgb(Theme.surface) + "\"",
            "cursor = \"" + rgb(Theme.primary) + "\"",
            "",
            "[colors.selection]",
            "text = \"" + rgb(Theme.primaryContainerText) + "\"",
            "background = \"" + rgb(Theme.primaryContainer) + "\"",
            "",
            "[colors.normal]"
        ];
        for (let i = 0; i < 8; i++)
            lines.push(names[i] + " = \"" + rgb(root.terminalNormal[i]) + "\"");
        lines.push("");
        lines.push("[colors.bright]");
        for (let i = 0; i < 8; i++)
            lines.push(names[i] + " = \"" + rgb(root.terminalBright[i]) + "\"");
        return lines.join("\n") + "\n";
    }

    function kittyTheme(): string {
        const lines = [
            "# Kitty colors — generated by quickshell (services/SystemTheme.qml)",
            "# from the active dark palette; edits are overwritten.",
            "background " + rgb(Theme.surface),
            "foreground " + rgb(Theme.surfaceText),
            "cursor " + rgb(Theme.primary),
            "cursor_text_color " + rgb(Theme.primaryText),
            "selection_background " + rgb(Theme.primaryContainer),
            "selection_foreground " + rgb(Theme.primaryContainerText),
            "url_color " + rgb(Theme.secondary),
            "active_border_color " + rgb(Theme.primary),
            "inactive_border_color " + rgb(Theme.outlineVariant)
        ];
        for (let i = 0; i < 8; i++)
            lines.push("color" + i + " " + rgb(root.terminalNormal[i]));
        for (let i = 0; i < 8; i++)
            lines.push("color" + (i + 8) + " " + rgb(root.terminalBright[i]));
        return lines.join("\n") + "\n";
    }

    // ---- editors --------------------------------------------------------------

    function nvimTheme(): string {
        const hi = (group, fg, bg, opts) => "set(0, \"" + group + "\", { fg = \""
            + rgb(fg) + "\"" + (bg ? ", bg = \"" + rgb(bg) + "\"" : "")
            + (opts ? ", " + opts : "") + " })";
        return [
            "-- Generated by quickshell (services/SystemTheme.qml) — edits are overwritten.",
            "vim.o.background = \"dark\"",
            "vim.g.colors_name = \"quickshell\"",
            "local set = vim.api.nvim_set_hl",
            "",
            hi("Normal", Theme.surfaceText, Theme.surface),
            hi("NormalNC", Theme.surfaceVariantText, Theme.surface),
            hi("NormalFloat", Theme.surfaceText, Theme.surfaceContainerHigh),
            hi("FloatBorder", Theme.outline, Theme.surfaceContainerHigh),
            hi("Cursor", Theme.surface, Theme.primary),
            hi("CursorLine", Theme.surfaceText, Theme.surfaceContainerLow),
            hi("CursorLineNr", Theme.primary, null, "bold = true"),
            hi("LineNr", Theme.outline, null),
            hi("SignColumn", Theme.surfaceText, Theme.surface),
            hi("Visual", Theme.surfaceText, Theme.primaryContainer),
            hi("Search", Theme.primaryContainerText, Theme.primaryContainer),
            hi("IncSearch", Theme.primaryText, Theme.primary),
            hi("CurSearch", Theme.primaryText, Theme.primary),
            hi("Pmenu", Theme.surfaceText, Theme.surfaceContainerHigh),
            hi("PmenuSel", Theme.primaryContainerText, Theme.primaryContainer),
            hi("PmenuSbar", Theme.surfaceText, Theme.surfaceContainer),
            hi("PmenuThumb", Theme.surfaceText, Theme.outlineVariant),
            hi("StatusLine", Theme.surfaceText, Theme.surfaceContainer),
            hi("StatusLineNC", Theme.surfaceVariantText, Theme.surfaceContainerLow),
            hi("TabLine", Theme.surfaceVariantText, Theme.surfaceContainerLow),
            hi("TabLineSel", Theme.surfaceText, Theme.surfaceContainer),
            hi("TabLineFill", Theme.surfaceText, Theme.surfaceContainerLow),
            hi("WinSeparator", Theme.outlineVariant, null),
            hi("VertSplit", Theme.outlineVariant, null),
            hi("NonText", Theme.outlineVariant, null),
            hi("EndOfBuffer", Theme.surface, null),
            hi("Folded", Theme.surfaceVariantText, Theme.surfaceContainer),
            hi("Title", Theme.primary, null, "bold = true"),
            hi("Directory", Theme.primary, null),
            hi("MatchParen", Theme.primary, Theme.surfaceContainerHighest, "bold = true"),
            hi("Comment", Theme.surfaceVariantText, null, "italic = true"),
            hi("Constant", Theme.tertiary, null),
            hi("String", Theme.secondary, null),
            hi("Identifier", Theme.surfaceText, null),
            hi("Function", Theme.primary, null),
            hi("Statement", Theme.tertiary, null),
            hi("Keyword", Theme.tertiary, null),
            hi("Operator", Theme.surfaceVariantText, null),
            hi("Type", Theme.tertiary, null),
            hi("PreProc", Theme.tertiary, null),
            hi("Special", Theme.secondary, null),
            hi("Error", Theme.error, null),
            hi("ErrorMsg", Theme.error, null),
            hi("WarningMsg", Theme.tertiary, null),
            hi("Todo", Theme.error, null, "bold = true"),
            hi("DiagnosticError", Theme.error, null),
            hi("DiagnosticWarn", Theme.tertiary, null),
            hi("DiagnosticInfo", Theme.secondary, null),
            hi("DiagnosticHint", Theme.surfaceVariantText, null),
            hi("DiffAdd", Theme.secondary, null),
            hi("DiffChange", Theme.tertiary, null),
            hi("DiffDelete", Theme.error, null),
            hi("DiffText", Theme.primary, null),
            hi("SpellBad", Theme.error, null, "undercurl = true"),
            ""
        ].join("\n");
    }

    function helixTheme(): string {
        const palette = {
            surface: rgb(Theme.surface),
            surface_low: rgb(Theme.surfaceContainerLow),
            surface_high: rgb(Theme.surfaceContainerHigh),
            text: rgb(Theme.surfaceText),
            muted: rgb(Theme.surfaceVariantText),
            outline: rgb(Theme.outline),
            outline_variant: rgb(Theme.outlineVariant),
            primary: rgb(Theme.primary),
            primary_container: rgb(Theme.primaryContainer),
            secondary: rgb(Theme.secondary),
            tertiary: rgb(Theme.tertiary),
            error: rgb(Theme.error)
        };
        const lines = [
            "# Helix theme — generated by quickshell (services/SystemTheme.qml)",
            "# from the active dark palette; edits are overwritten.",
            "\"ui.background\" = { bg = \"surface\" }",
            "\"ui.text\" = { fg = \"text\" }",
            "\"ui.text.focus\" = { fg = \"text\" }",
            "\"ui.cursor\" = { fg = \"surface\", bg = \"primary\" }",
            "\"ui.cursor.primary\" = { fg = \"surface\", bg = \"primary\" }",
            "\"ui.cursorline.primary\" = { bg = \"surface_low\" }",
            "\"ui.selection\" = { bg = \"primary_container\" }",
            "\"ui.selection.primary\" = { bg = \"primary_container\" }",
            "\"ui.linenr\" = { fg = \"outline\" }",
            "\"ui.linenr.selected\" = { fg = \"text\" }",
            "\"ui.statusline\" = { fg = \"text\", bg = \"surface_low\" }",
            "\"ui.statusline.inactive\" = { fg = \"outline\", bg = \"surface\" }",
            "\"ui.statusline.normal\" = { fg = \"surface\", bg = \"primary\" }",
            "\"ui.popup\" = { fg = \"text\", bg = \"surface_high\" }",
            "\"ui.help\" = { fg = \"text\", bg = \"surface_high\" }",
            "\"ui.menu\" = { fg = \"text\", bg = \"surface_high\" }",
            "\"ui.menu.selected\" = { fg = \"surface\", bg = \"primary\" }",
            "\"ui.window\" = { fg = \"outline_variant\" }",
            "\"ui.virtual.whitespace\" = { fg = \"outline_variant\" }",
            "\"ui.virtual.indent-guide\" = { fg = \"outline_variant\" }",
            "\"ui.virtual.ruler\" = { bg = \"surface_low\" }",
            "\"comment\" = { fg = \"outline\", modifiers = [\"italic\"] }",
            "\"keyword\" = { fg = \"tertiary\" }",
            "\"operator\" = { fg = \"muted\" }",
            "\"punctuation\" = { fg = \"muted\" }",
            "\"string\" = { fg = \"secondary\" }",
            "\"constant\" = { fg = \"tertiary\" }",
            "\"constant.numeric\" = { fg = \"tertiary\" }",
            "\"function\" = { fg = \"primary\" }",
            "\"function.method\" = { fg = \"primary\" }",
            "\"variable\" = { fg = \"text\" }",
            "\"type\" = { fg = \"tertiary\" }",
            "\"attribute\" = { fg = \"primary\" }",
            "\"namespace\" = { fg = \"primary\" }",
            "\"label\" = { fg = \"primary\" }",
            "\"error\" = { fg = \"error\" }",
            "\"warning\" = { fg = \"tertiary\" }",
            "\"info\" = { fg = \"secondary\" }",
            "\"hint\" = { fg = \"muted\" }",
            "\"diff.plus\" = { fg = \"secondary\" }",
            "\"diff.minus\" = { fg = \"error\" }",
            "\"diff.delta\" = { fg = \"primary\" }",
            "\"markup.heading\" = { fg = \"primary\", modifiers = [\"bold\"] }",
            "\"markup.link.url\" = { fg = \"secondary\", modifiers = [\"underlined\"] }",
            "\"markup.raw\" = { fg = \"secondary\" }",
            "",
            "[palette]"
        ];
        for (const key in palette)
            lines.push(key + " = \"" + palette[key] + "\"");
        return lines.join("\n") + "\n";
    }

    function zedTheme(): string {
        const c = {
            bg: rgb(Theme.surface),
            low: rgb(Theme.surfaceContainerLow),
            mid: rgb(Theme.surfaceContainer),
            high: rgb(Theme.surfaceContainerHigh),
            highest: rgb(Theme.surfaceContainerHighest),
            text: rgb(Theme.surfaceText),
            muted: rgb(Theme.surfaceVariantText),
            outline: rgb(Theme.outline),
            variant: rgb(Theme.outlineVariant),
            primary: rgb(Theme.primary),
            container: rgb(Theme.primaryContainer),
            onContainer: rgb(Theme.primaryContainerText),
            secondary: rgb(Theme.secondary),
            tertiary: rgb(Theme.tertiary),
            error: rgb(Theme.error),
            errorContainer: rgb(Theme.errorContainer)
        };
        return JSON.stringify({
            "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
            name: "Quickshell",
            author: "quickshell",
            themes: [{
                name: "Quickshell",
                appearance: "dark",
                style: {
                    background: c.bg,
                    "surface.background": c.low,
                    "elevated_surface.background": c.high,
                    "panel.background": c.bg,
                    "panel.focused_border": c.primary,
                    "pane.focused_border": c.primary,
                    "editor.background": c.bg,
                    "editor.foreground": c.text,
                    "editor.gutter.background": c.bg,
                    "editor.active_line.background": c.low,
                    "editor.line_number": c.outline,
                    "editor.active_line_number": c.primary,
                    "status_bar.background": c.mid,
                    "title_bar.background": c.low,
                    "title_bar.inactive_background": c.bg,
                    "toolbar.background": c.low,
                    "tab_bar.background": c.low,
                    "tab.active_background": c.bg,
                    "tab.inactive_background": c.low,
                    border: c.variant,
                    "border.variant": c.variant,
                    "border.focused": c.primary,
                    "border.selected": c.primary,
                    "border.disabled": c.variant,
                    text: c.text,
                    "text.muted": c.muted,
                    "text.placeholder": c.outline,
                    "text.disabled": c.variant,
                    "text.accent": c.primary,
                    icon: c.muted,
                    "icon.muted": c.outline,
                    "icon.accent": c.primary,
                    "icon.disabled": c.variant,
                    "element.background": c.high,
                    "element.hover": c.highest,
                    "element.active": c.highest,
                    "element.selected": c.container,
                    "element.disabled": c.mid,
                    "ghost_element.hover": c.high,
                    "ghost_element.selected": c.highest,
                    "ghost_element.active": c.highest,
                    "search.match_background": c.container,
                    "scrollbar.thumb.background": c.variant,
                    "scrollbar.thumb.hover_background": c.outline,
                    "scrollbar.track.background": c.bg,
                    "drop_target.background": c.container,
                    error: c.error,
                    "error.background": c.errorContainer,
                    "error.border": c.error,
                    warning: c.tertiary,
                    "warning.background": c.high,
                    "warning.border": c.tertiary,
                    success: c.secondary,
                    info: c.primary,
                    hint: c.outline,
                    modified: c.tertiary,
                    created: c.secondary,
                    deleted: c.error,
                    conflict: c.error,
                    renamed: c.primary,
                    ignored: c.outline,
                    unreachable: c.outline,
                    "link_text.hover": c.secondary,
                    "terminal.background": c.bg,
                    "terminal.foreground": c.text,
                    "terminal.bright_foreground": c.text,
                    "terminal.dim_foreground": c.muted,
                    "terminal.ansi.background": c.bg,
                    "terminal.ansi.black": rgb(root.terminalNormal[0]),
                    "terminal.ansi.red": rgb(root.terminalNormal[1]),
                    "terminal.ansi.green": rgb(root.terminalNormal[2]),
                    "terminal.ansi.yellow": rgb(root.terminalNormal[3]),
                    "terminal.ansi.blue": rgb(root.terminalNormal[4]),
                    "terminal.ansi.magenta": rgb(root.terminalNormal[5]),
                    "terminal.ansi.cyan": rgb(root.terminalNormal[6]),
                    "terminal.ansi.white": rgb(root.terminalNormal[7]),
                    "terminal.ansi.bright_black": rgb(root.terminalBright[0]),
                    "terminal.ansi.bright_red": rgb(root.terminalBright[1]),
                    "terminal.ansi.bright_green": rgb(root.terminalBright[2]),
                    "terminal.ansi.bright_yellow": rgb(root.terminalBright[3]),
                    "terminal.ansi.bright_blue": rgb(root.terminalBright[4]),
                    "terminal.ansi.bright_magenta": rgb(root.terminalBright[5]),
                    "terminal.ansi.bright_cyan": rgb(root.terminalBright[6]),
                    "terminal.ansi.bright_white": rgb(root.terminalBright[7]),
                    players: [{ cursor: c.primary, selection: c.container, background: c.secondary }],
                    syntax: {
                        comment: { color: c.muted, font_style: "italic" },
                        "comment.doc": { color: c.muted, font_style: "italic" },
                        string: { color: c.secondary },
                        "string.escape": { color: c.tertiary },
                        "string.regex": { color: c.tertiary },
                        "string.special": { color: c.tertiary },
                        number: { color: c.tertiary },
                        boolean: { color: c.tertiary },
                        keyword: { color: c.tertiary },
                        type: { color: c.tertiary },
                        function: { color: c.primary },
                        "function.method": { color: c.primary },
                        variable: { color: c.text },
                        "variable.special": { color: c.primary },
                        property: { color: c.text },
                        attribute: { color: c.primary },
                        title: { color: c.primary, font_weight: 700 },
                        emphasis: { font_style: "italic" },
                        link_text: { color: c.primary },
                        link_uri: { color: c.secondary },
                        punctuation: { color: c.muted },
                        "punctuation.bracket": { color: c.muted },
                        "punctuation.delimiter": { color: c.muted },
                        operator: { color: c.muted },
                        preproc: { color: c.tertiary },
                        special: { color: c.secondary },
                        embedded: { color: c.text },
                        predicate: { color: c.primary },
                        primary: { color: c.text },
                        hint: { color: c.outline }
                    }
                }
            }]
        }, null, 2) + "\n";
    }

    // ---- pagers ---------------------------------------------------------------

    function batTheme(): string {
        const entry = (scope, fg, style) => "    <dict>\n"
            + "      <key>scope</key><string>" + scope + "</string>\n"
            + "      <key>settings</key>\n"
            + "      <dict><key>foreground</key><string>" + rgb(fg) + "</string>"
            + (style ? "<key>fontStyle</key><string>" + style + "</string>" : "")
            + "</dict>\n    </dict>";
        const scopes = [
            ["comment", Theme.surfaceVariantText, "italic"],
            ["string", Theme.secondary, ""],
            ["constant.numeric", Theme.tertiary, ""],
            ["constant.language", Theme.tertiary, ""],
            ["keyword", Theme.tertiary, ""],
            ["storage", Theme.tertiary, ""],
            ["entity.name.function", Theme.primary, ""],
            ["support.function", Theme.primary, ""],
            ["entity.name.type", Theme.tertiary, ""],
            ["support.type", Theme.tertiary, ""],
            ["variable", Theme.surfaceText, ""],
            ["attribute", Theme.primary, ""],
            ["entity.name.tag", Theme.primary, ""],
            ["operator", Theme.surfaceVariantText, ""],
            ["punctuation", Theme.surfaceVariantText, ""],
            ["invalid", Theme.error, ""],
            ["markup.heading", Theme.primary, "bold"],
            ["markup.bold", Theme.surfaceText, "bold"],
            ["markup.italic", Theme.surfaceText, "italic"],
            ["markup.underline", Theme.surfaceText, "underline"],
            ["markup.raw", Theme.secondary, ""],
            ["markup.inserted", Theme.secondary, ""],
            ["markup.deleted", Theme.error, ""],
            ["markup.changed", Theme.tertiary, ""],
            ["markup.link", Theme.secondary, "underline"]
        ];
        return [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
            "<plist version=\"1.0\">",
            "<dict>",
            "  <key>name</key><string>quickshell</string>",
            "  <key>settings</key>",
            "  <array>",
            "    <dict>",
            "      <key>settings</key>",
            "      <dict>",
            "        <key>background</key><string>" + rgb(Theme.surface) + "</string>",
            "        <key>foreground</key><string>" + rgb(Theme.surfaceText) + "</string>",
            "        <key>caret</key><string>" + rgb(Theme.primary) + "</string>",
            "        <key>selection</key><string>" + rgb(Theme.primaryContainer) + "</string>",
            "        <key>lineHighlight</key><string>" + rgb(Theme.surfaceContainerLow) + "</string>",
            "      </dict>",
            "    </dict>",
            scopes.map(s => entry(s[0], s[1], s[2])).join("\n"),
            "  </array>",
            "</dict>",
            "</plist>",
            ""
        ].join("\n");
    }

    // ---- shells ---------------------------------------------------------------

    function bashText(): string {
        // 24-bit SGR keeps the shell matching the palette even inside a
        // terminal whose 16 ANSI slots were not recolored by us.
        const fg = c => "38;2;" + Math.round(c.r * 255) + ";" + Math.round(c.g * 255)
            + ";" + Math.round(c.b * 255);
        const bold = c => "1;" + fg(c);
        const ls = [
            "rs=0",
            "di=" + fg(Theme.primary),
            "ln=" + fg(Theme.secondary),
            "mh=" + fg(Theme.secondary),
            "pi=" + fg(Theme.tertiary),
            "so=" + fg(Theme.tertiary),
            "do=" + fg(Theme.tertiary),
            "bd=" + fg(Theme.tertiary),
            "cd=" + fg(Theme.tertiary),
            "or=" + fg(Theme.error),
            "mi=" + fg(Theme.error),
            "su=" + fg(Theme.error),
            "sg=" + fg(Theme.error),
            "ca=" + fg(Theme.error),
            "tw=" + fg(Theme.error),
            "ow=" + fg(Theme.error),
            "st=" + fg(Theme.error),
            "ex=" + bold(Theme.secondary),
            "*.tar=" + fg(Theme.error),
            "*.tgz=" + fg(Theme.error),
            "*.zip=" + fg(Theme.error),
            "*.gz=" + fg(Theme.error),
            "*.xz=" + fg(Theme.error),
            "*.7z=" + fg(Theme.error),
            "*.mp3=" + fg(Theme.tertiary),
            "*.mp4=" + fg(Theme.tertiary),
            "*.jpg=" + fg(Theme.tertiary),
            "*.png=" + fg(Theme.tertiary),
            "*.pdf=" + fg(Theme.tertiary),
            "*.md=" + fg(Theme.tertiary)
        ];
        const grep = [
            "ms=" + bold(Theme.primary),
            "mc=" + bold(Theme.primary),
            "fn=" + fg(Theme.tertiary),
            "ln=" + fg(Theme.secondary),
            "bn=" + fg(Theme.secondary),
            "se=" + fg(Theme.surfaceVariantText)
        ];
        return [
            "# Bash colors — generated by quickshell (services/SystemTheme.qml)",
            "# One-time: add `source " + root.configHome + "/bash/quickshell.sh` to ~/.bashrc.",
            "LS_COLORS=\"" + ls.join(":") + "\"",
            "export LS_COLORS",
            "GREP_COLORS=\"" + grep.join(":") + "\"",
            "export GREP_COLORS",
            ""
        ].join("\n");
    }

    function fishText(): string {
        return [
            "# Fish colors — generated by quickshell (services/SystemTheme.qml)",
            "set -g fish_color_normal '" + rgb(Theme.surfaceText) + "'",
            "set -g fish_color_command '" + rgb(Theme.primary) + "'",
            "set -g fish_color_param '" + rgb(Theme.surfaceText) + "'",
            "set -g fish_color_keyword '" + rgb(Theme.tertiary) + "'",
            "set -g fish_color_function '" + rgb(Theme.primary) + "'",
            "set -g fish_color_operator '" + rgb(Theme.secondary) + "'",
            "set -g fish_color_escape '" + rgb(Theme.tertiary) + "'",
            "set -g fish_color_quote '" + rgb(Theme.secondary) + "'",
            "set -g fish_color_redirection '" + rgb(Theme.tertiary) + "'",
            "set -g fish_color_end '" + rgb(Theme.surfaceVariantText) + "'",
            "set -g fish_color_error '" + rgb(Theme.error) + "'",
            "set -g fish_color_comment '" + rgb(Theme.surfaceVariantText) + "'",
            "set -g fish_color_selection \"--background=" + rgb(Theme.primaryContainer) + "\"",
            "set -g fish_color_search_match \"--background=" + rgb(Theme.primaryContainer) + "\"",
            "set -g fish_color_autosuggestion '" + rgb(Theme.outline) + "'",
            "set -g fish_color_cwd '" + rgb(Theme.primary) + "'",
            "set -g fish_color_user '" + rgb(Theme.secondary) + "'",
            "set -g fish_color_host '" + rgb(Theme.primary) + "'",
            "set -g fish_color_cancel '" + rgb(Theme.error) + "'",
            "set -g fish_color_status '" + rgb(Theme.error) + "'",
            "set -g fish_pager_color_prefix '" + rgb(Theme.primary) + "'",
            "set -g fish_pager_color_completion '" + rgb(Theme.surfaceText) + "'",
            "set -g fish_pager_color_description '" + rgb(Theme.surfaceVariantText) + "'",
            "set -g fish_pager_color_selected_background \"--background="
                + rgb(Theme.primaryContainer) + "\"",
            ""
        ].join("\n");
    }

    // ---- writers --------------------------------------------------------------

    function writeTo(view: var, text: string): bool {
        view.reload();
        if (view.text() === text)
            return false;
        view.setText(text);
        return true;
    }

    function reloadGhostty(): void {
        if (root.writeTo(ghosttyFile, root.ghosttyTheme())) {
            ghosttyReload.running = false;
            ghosttyReload.running = true;
        }
    }

    function reloadFoot(): void {
        if (root.writeTo(footFile, root.footTheme())) {
            footReload.running = false;
            footReload.running = true;
        }
    }

    function reloadKitty(): void {
        if (root.writeTo(kittyFile, root.kittyTheme())) {
            kittyReload.running = false;
            kittyReload.running = true;
        }
    }

    function reloadBat(): void {
        if (root.writeTo(batFile, root.batTheme())) {
            batCacheBuild.running = false;
            batCacheBuild.running = true;
        }
    }

    function applyColorScheme(): void {
        colorScheme.running = false;
        colorScheme.running = true;
    }

    // Writes every enabled target. Called at startup, after a palette change
    // (debounced) and when a target is switched on.
    function applyAll(): void {
        if (!root.ready)
            return;

        if (root.enabled("gtk")) {
            const gtk3Changed = root.writeTo(gtk3File, root.gtkCss(false));
            const gtk4Changed = root.writeTo(gtk4File, root.gtkCss(true));
            if (gtk3Changed || gtk4Changed)
                root.applyColorScheme();
        }
        if (root.enabled("qt"))
            root.writeTo(qt6ctFile, root.qtPalette());
        if (root.enabled("niri"))
            root.writeTo(niriFile, root.niriText());
        if (root.enabled("ghostty"))
            root.reloadGhostty();
        if (root.enabled("foot"))
            root.reloadFoot();
        if (root.enabled("alacritty"))
            root.writeTo(alacrittyFile, root.alacrittyTheme());
        if (root.enabled("kitty"))
            root.reloadKitty();
        if (root.enabled("nvim"))
            root.writeTo(nvimFile, root.nvimTheme());
        if (root.enabled("helix"))
            root.writeTo(helixFile, root.helixTheme());
        if (root.enabled("zed"))
            root.writeTo(zedFile, root.zedTheme());
        if (root.enabled("bash"))
            root.writeTo(bashFile, root.bashText());
        if (root.enabled("fish"))
            root.writeTo(fishFile, root.fishText());
        if (root.enabled("bat"))
            root.reloadBat();
    }

    IpcHandler {
        target: "systemtheme"

        function setApp(id: string, enabled: bool): void { root.setEnabled(id, enabled) }
        function apply(): void { root.applyAll() }
    }

    FileView {
        id: gtk3File

        path: root.configHome + "/gtk-3.0/gtk.css"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: gtk4File

        path: root.configHome + "/gtk-4.0/gtk.css"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: qt6ctFile

        path: root.configHome + "/qt6ct/colors/matugen.conf"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: niriFile

        path: root.configHome + "/niri/quickshell.kdl"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: ghosttyFile

        path: root.configHome + "/ghostty/themes/Quickshell"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: footFile

        path: root.configHome + "/foot/quickshell.ini"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: alacrittyFile

        path: root.configHome + "/alacritty/quickshell.toml"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: kittyFile

        path: root.configHome + "/kitty/quickshell.conf"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: nvimFile

        path: root.configHome + "/nvim/colors/quickshell.lua"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: helixFile

        path: root.configHome + "/helix/themes/quickshell.toml"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: zedFile

        path: root.configHome + "/zed/themes/quickshell.json"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: bashFile

        path: root.configHome + "/bash/quickshell.sh"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: fishFile

        path: root.configHome + "/fish/conf.d/quickshell.fish"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: batFile

        path: root.configHome + "/bat/themes/quickshell.tmTheme"
        preload: false
        blockAllReads: true
        blockLoading: true
        printErrors: false
    }

    Process {
        id: ghosttyReload

        command: ["pkill", "-USR2", "-x", "ghostty"]
    }

    Process {
        id: footReload

        command: ["pkill", "-USR1", "-x", "foot"]
    }

    Process {
        id: kittyReload

        command: ["pkill", "-USR1", "-x", "kitty"]
    }

    Process {
        id: batCacheBuild

        command: ["bat", "cache", "--build"]
    }

    Process {
        id: colorScheme

        command: ["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"]
    }
}
