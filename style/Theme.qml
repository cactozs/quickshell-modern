pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Shell palette. Plates are pinned true black in Matugen mode and use warm
// Gruvbox darks in Gruvbox mode; accents and surface roles come from either
// the matugen-generated Colors.json (live, wallpaper-driven) or a fixed Gruvbox
// palette, selected via theme-apps.json. Colors.json is watched so matugen runs
// recolor the shell in Matugen mode; the adapter defaults below keep the shell
// usable before the first matugen run.
Singleton {
    id: root

    // ---- fonts ----
    readonly property string fontFamily: "Google Sans"
    readonly property string iconFont: "Material Symbols Rounded"

    // ---- geometry ----
    readonly property int barHeight: 40
    readonly property int barSideMargin: 12
    readonly property int barIslandMargin: 8
    // A pill: the largest radius the 40px bar can take without clipping.
    readonly property int barIslandRadius: barHeight / 2
    readonly property int radiusLG: 18
    readonly property int radiusXL: 24
    readonly property int radiusMD: 12

    readonly property string colorScheme: state.colorScheme === "gruvbox" ? "gruvbox" : "matugen"
    readonly property bool useGruvbox: colorScheme === "gruvbox"

    // ---- plates (fully opaque; Gruvbox uses warm dark levels) ----
    readonly property color plate: useGruvbox ? "#ff1d2021" : "#ff000000"
    readonly property color plateStrong: useGruvbox ? "#ff282828" : "#ff000000"
    readonly property color plateBorder: useGruvbox ? Qt.rgba(0.93, 0.86, 0.70, 0.10) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.5)

    // ---- accents & text (scheme-dependent) ----
    // Text roles avoid the `on<Capital>` form: QML parses those as signal
    // handlers, so they silently evaluate to black instead of the color.
    readonly property color primary: useGruvbox ? gruvbox.primary : json.primary
    readonly property color primaryText: useGruvbox ? gruvbox.on_primary : json.on_primary
    readonly property color primaryContainer: useGruvbox ? gruvbox.primary_container : json.primary_container
    readonly property color primaryContainerText: useGruvbox ? gruvbox.on_primary_container : json.on_primary_container
    readonly property color secondary: useGruvbox ? gruvbox.secondary : json.secondary
    readonly property color secondaryText: useGruvbox ? gruvbox.on_secondary : json.on_secondary
    readonly property color tertiary: useGruvbox ? gruvbox.tertiary : json.tertiary
    readonly property color tertiaryText: useGruvbox ? gruvbox.on_tertiary : json.on_tertiary
    // Editor keyword/statement accent: Gruvbox uses red, while Matugen keeps
    // the existing tertiary role so editor themes do not change in that mode.
    readonly property color syntaxKeyword: useGruvbox ? gruvbox.syntax_keyword : tertiary
    readonly property color error: useGruvbox ? gruvbox.error : json.error
    readonly property color errorText: useGruvbox ? gruvbox.on_error : json.on_error
    readonly property color errorContainer: useGruvbox ? gruvbox.error_container : json.error_container
    // pinned white (user request): content on active chips/buttons must read
    // on the dark container regardless of what the palette puts here
    readonly property color containerText: "#ffffffff"
    readonly property color surface: useGruvbox ? gruvbox.surface : json.surface
    readonly property color surfaceText: useGruvbox ? gruvbox.on_surface : json.on_surface
    readonly property color surfaceVariantText: useGruvbox ? gruvbox.on_surface_variant : json.on_surface_variant
    readonly property color surfaceContainerLowest: useGruvbox ? gruvbox.surface_container_lowest : json.surface_container_lowest
    readonly property color surfaceContainerLow: useGruvbox ? gruvbox.surface_container_low : json.surface_container_low
    readonly property color surfaceContainer: useGruvbox ? gruvbox.surface_container : json.surface_container
    readonly property color surfaceContainerHigh: useGruvbox ? gruvbox.surface_container_high : json.surface_container_high
    readonly property color surfaceContainerHighest: useGruvbox ? gruvbox.surface_container_highest : json.surface_container_highest
    readonly property color outline: useGruvbox ? gruvbox.outline : json.outline
    readonly property color outlineVariant: useGruvbox ? gruvbox.outline_variant : json.outline_variant
    readonly property color inverseSurface: useGruvbox ? gruvbox.inverse_surface : json.inverse_surface
    readonly property color inverseSurfaceText: useGruvbox ? gruvbox.inverse_on_surface : json.inverse_on_surface
    readonly property color shadow: useGruvbox ? gruvbox.shadow : json.shadow

    QtObject {
        id: gruvbox

        // Classic Gruvbox dark roles: orange dominant accent, green strings,
        // yellow types/constants, red errors, warm gray surfaces and text.
        readonly property color primary: "#fe8019"
        readonly property color on_primary: "#1d2021"
        readonly property color primary_container: "#af3a03"
        readonly property color on_primary_container: "#fbf1c7"
        readonly property color secondary: "#b8bb26"
        readonly property color on_secondary: "#1d2021"
        readonly property color tertiary: "#fabd2f"
        readonly property color on_tertiary: "#1d2021"
        readonly property color syntax_keyword: "#fb4934"
        readonly property color error: "#fb4934"
        readonly property color on_error: "#1d2021"
        readonly property color error_container: "#9d0006"
        readonly property color surface: "#282828"
        readonly property color on_surface: "#ebdbb2"
        readonly property color on_surface_variant: "#a89984"
        readonly property color surface_container_lowest: "#1d2021"
        readonly property color surface_container_low: "#32302f"
        readonly property color surface_container: "#3c3836"
        readonly property color surface_container_high: "#504945"
        readonly property color surface_container_highest: "#665c54"
        readonly property color outline: "#928374"
        readonly property color outline_variant: "#665c54"
        readonly property color inverse_surface: "#ebdbb2"
        readonly property color inverse_on_surface: "#282828"
        readonly property color shadow: "#000000"
    }

    FileView {
        id: stateFile

        path: Qt.resolvedUrl("../theme-apps.json")
        watchChanges: true
        printErrors: false

        onFileChanged: stateFile.reload()

        JsonAdapter {
            id: state

            property string colorScheme: "matugen"
        }
    }

    FileView {
        id: colorsFile

        path: Qt.resolvedUrl("Colors.json")
        watchChanges: true
        printErrors: false

        onFileChanged: colorsFile.reload()

        JsonAdapter {
            id: json

            property string primary: "#a8c8fb"
            property string on_primary: "#003062"
            property string primary_container: "#00497f"
            property string on_primary_container: "#eaddff"
            property string secondary: "#c2d7f5"
            property string on_secondary: "#332d41"
            property string tertiary: "#efb8c8"
            property string on_tertiary: "#492532"
            property string error: "#ffb4ab"
            property string on_error: "#601410"
            property string error_container: "#8c1d18"
            property string surface: "#141218"
            property string on_surface: "#e3e2e9"
            property string on_surface_variant: "#95909f"
            property string surface_container_lowest: "#0f0d13"
            property string surface_container_low: "#1d1b20"
            property string surface_container: "#211f26"
            property string surface_container_high: "#2b2930"
            property string surface_container_highest: "#36343b"
            property string outline: "#938f99"
            property string outline_variant: "#47464f"
            property string inverse_surface: "#e6e0e9"
            property string inverse_on_surface: "#322f35"
            property string shadow: "#000000"
        }
    }
}
