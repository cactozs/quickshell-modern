pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Shell palette. The OLED neutrals are pinned here (true black plates); every
// accent comes from the matugen-generated Colors.json sitting next to this
// file — `matugen image` / `awww img` rewrites it and the shell recolors live
// through watchChanges. The JsonAdapter defaults below are the fallback
// palette, so the shell looks right before the first matugen run.
Singleton {
    id: root

    // ---- fonts ----
    readonly property string fontFamily: "Google Sans"
    readonly property string iconFont: "Material Symbols Rounded"

    // ---- geometry ----
    readonly property int barHeight: 40
    readonly property int barSideMargin: 12
    readonly property int radiusLG: 18
    readonly property int radiusXL: 24
    readonly property int radiusMD: 12

    // ---- OLED plates (fully opaque) ----
    readonly property color plate: "#ff000000"
    readonly property color plateStrong: "#ff000000"
    readonly property color plateBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.5)

    // ---- accents & text (Colors.json wins over the defaults) ----
    // Text roles avoid the `on<Capital>` form: QML parses those as signal
    // handlers, so they silently evaluate to black instead of the color.
    readonly property color primary: json.primary
    readonly property color primaryText: json.on_primary
    readonly property color primaryContainer: json.primary_container
    readonly property color primaryContainerText: json.on_primary_container
    readonly property color secondary: json.secondary
    readonly property color secondaryText: json.on_secondary
    readonly property color tertiary: json.tertiary
    readonly property color tertiaryText: json.on_tertiary
    readonly property color error: json.error
    readonly property color errorText: json.on_error
    readonly property color errorContainer: json.error_container
    // pinned white (user request): content on active chips/buttons must read
    // on the dark container regardless of what matugen puts here
    readonly property color containerText: "#ffffffff"
    readonly property color surface: json.surface
    readonly property color surfaceText: json.on_surface
    readonly property color surfaceVariantText: json.on_surface_variant
    readonly property color surfaceContainerLowest: json.surface_container_lowest
    readonly property color surfaceContainerLow: json.surface_container_low
    readonly property color surfaceContainer: json.surface_container
    readonly property color surfaceContainerHigh: json.surface_container_high
    readonly property color surfaceContainerHighest: json.surface_container_highest
    readonly property color outline: json.outline
    readonly property color outlineVariant: json.outline_variant
    readonly property color inverseSurface: json.inverse_surface
    readonly property color inverseSurfaceText: json.inverse_on_surface
    readonly property color shadow: json.shadow

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
