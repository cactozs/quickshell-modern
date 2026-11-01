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

    // ---- OLED plates ----
    readonly property color plate: "#e6000000"
    readonly property color plateStrong: "#f2000000"
    readonly property color plateBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.5)

    // ---- accents & text (Colors.json wins over the defaults) ----
    readonly property color primary: json.primary
    readonly property color onPrimary: json.on_primary
    readonly property color secondary: json.secondary
    readonly property color primaryContainer: json.primary_container
    readonly property color onSurface: json.on_surface
    readonly property color onSurfaceVariant: json.on_surface_variant
    readonly property color surfaceContainerHigh: json.surface_container_high
    readonly property color outlineVariant: json.outline_variant
    readonly property color error: json.error

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
            property string secondary: "#c2d7f5"
            property string primary_container: "#00497f"
            property string on_surface: "#e3e2e9"
            property string on_surface_variant: "#95909f"
            property string surface_container_high: "#2b2930"
            property string outline_variant: "#47464f"
            property string error: "#ffb4ab"
        }
    }
}
