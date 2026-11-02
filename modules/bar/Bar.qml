pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../../style"
import "../launcher"
import "../wallpaper"
import "../clipboard"
import "../quicksettings"
import "../osd"
import "../../services"
import "."

// Peninsula bar: a compact plate pinned to the top edge (no top margin) with
// side margins, hugging its content and centered on the screen. The sides
// merge into the top edge through concave flare wings (a fillet tangent to
// both the edge and the plate side), so the island "flows out" of the screen
// top. The outline is a single continuous stroke that runs edge → fillet →
// side → bottom corners → side → fillet → edge, with no line along the top
// edge itself. Only the plate takes input (mask); the exclusive zone keeps
// windows below it with a small gap.
//
// When the launcher opens on this monitor, the plate morphs into it: it
// widens and grows downward while the widgets fade into the launcher
// content. The exclusive zone stays at the resting height so windows
// below don't jump; the expanded plate just overlays them.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property int padH: 16

    // radius of the concave fillet connecting the plate sides to the top edge
    readonly property int flare: 14

    // The plate morphs into the launcher, the wallpaper ribbon, the
    // clipboard picker or the quick settings panel on the targeted monitor
    // only.
    readonly property bool launcherOpen: LauncherState.shown && LauncherState.screen === modelData.name
    readonly property bool wallpaperOpen: Wallpaper.shown && Wallpaper.screen === modelData.name
    readonly property bool clipboardOpen: Clipboard.shown && Clipboard.screen === modelData.name
    readonly property bool qsOpen: QuickSettings.shown && QuickSettings.screen === modelData.name
    readonly property bool panelOpen: root.launcherOpen || root.wallpaperOpen || root.clipboardOpen || root.qsOpen

    // OSD (volume/brightness/caps/layout) replaces the whole bar content for
    // a beat; suppressed while a real panel is morphed open.
    readonly property bool osdOpen: Osd.shown && !root.panelOpen

    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 0
        left: Theme.barSideMargin
        right: Theme.barSideMargin
    }

    implicitHeight: root.launcherOpen ? launcher.height
        : root.wallpaperOpen ? ribbon.height
        : root.clipboardOpen ? clipPicker.height
        : root.qsOpen ? qsPanel.height : Theme.barHeight

    Behavior on implicitHeight {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuint }
    }

    exclusionMode: ExclusionMode.Normal
    // Reserve the resting bar height even while expanded so windows below
    // don't jump.
    exclusiveZone: Theme.barHeight
    color: "transparent"

    WlrLayershell.namespace: "quickshell:bar"
    // Any open panel takes the keyboard so Esc can close it; at rest the bar
    // takes none, so niri's own binds keep working.
    WlrLayershell.keyboardFocus: (root.launcherOpen || root.clipboardOpen
        || root.wallpaperOpen || root.qsOpen)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: plate }

    // Publish the live plate height for PanelScrim's click-through hole. The
    // height is content-driven, so only the bar whose panel is open writes.
    Binding {
        target: root.launcherOpen ? LauncherState
            : root.wallpaperOpen ? Wallpaper
            : root.clipboardOpen ? Clipboard : QuickSettings
        property: "plateHeight"
        value: root.implicitHeight
        when: root.panelOpen
    }

    // Singletons are lazy: Audio, Brightness and CapsLock are referenced by
    // nothing else, so touch them once or their Process/Connections never
    // come alive (Osd and Niri wake through the bindings above).
    Component.onCompleted: {
        Audio.volume;
        Brightness.percent;
        CapsLock.capsOn;
    }

    // Bottom corners only: the capsule is drawn one radius taller and shifted
    // up, and the plate clips its top rounding away — so the bar meets the
    // top edge with straight sides.
    Item {
        id: plate

        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height
        width: root.launcherOpen ? LauncherState.plateWidth
            : root.wallpaperOpen ? Wallpaper.plateWidth
            : root.clipboardOpen ? Clipboard.plateWidth
            : root.qsOpen ? QuickSettings.plateWidth
            : root.osdOpen ? osd.implicitWidth + root.padH * 2
            : contentRow.implicitWidth + root.padH * 2
        clip: true

        Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuint }
        }

        Rectangle {
            y: -Theme.radiusLG
            width: parent.width
            height: parent.height + Theme.radiusLG
            radius: Theme.radiusLG
            color: Theme.plate
        }

        // Click anywhere on the bar's empty space to open the quick settings
        // panel. The widgets' own areas sit above this and consume their
        // clicks; while a panel or the OSD is morphed, this stays off so a
        // stray click can't fight the open content.
        MouseArea {
            anchors.fill: parent
            enabled: !root.panelOpen && !root.osdOpen

            onClicked: QuickSettings.toggle(root.modelData.name)
        }

        // Left and right sections pinned to the ends, the clock truly
        // centered between them via the two equally stretching fillers.
        RowLayout {
            id: contentRow

            anchors.fill: parent
            anchors.leftMargin: root.padH
            anchors.rightMargin: root.padH
            spacing: 14

            opacity: (root.panelOpen || root.osdOpen) ? 0 : 1
            enabled: !root.panelOpen && !root.osdOpen

            Behavior on opacity {
                // fade the bar widgets out fast so they don't linger through
                // the morph
                NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
            }

            Workspaces {
                Layout.alignment: Qt.AlignVCenter
                screenName: root.modelData.name
            }

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 10
            }

            Clock {
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 10
            }

            StatusRight {
                Layout.alignment: Qt.AlignVCenter
                screenName: root.modelData.name
            }
        }

        // The launcher content, shown while the plate is morphed open. Its
        // implicitHeight drives the plate height.
        Launcher {
            id: launcher

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            visible: root.launcherOpen
            active: root.launcherOpen

            // fade the launcher content in just after the plate starts
            // growing, so the morph reads as one motion
            opacity: root.launcherOpen ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: 50 }
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }

        // The wallpaper ribbon: same morph, horizontal filmstrip instead of
        // a list. No keyboard focus needed — wheel scrolls, clicks apply.
        WallpaperRibbon {
            id: ribbon

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            visible: root.wallpaperOpen
            active: root.wallpaperOpen

            opacity: root.wallpaperOpen ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: 50 }
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }

        // The clipboard picker: same morph, vertical history list.
        ClipboardPanel {
            id: clipPicker

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            visible: root.clipboardOpen
            active: root.clipboardOpen

            opacity: root.clipboardOpen ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: 50 }
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }

        // The quick settings panel: same morph, toggled by clicking the
        // bar's empty space.
        QuickSettingsPanel {
            id: qsPanel

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            visible: root.qsOpen
            active: root.qsOpen
            screenName: root.modelData.name

            opacity: root.qsOpen ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: 50 }
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }

        // Transient OSD content: the whole bar content swaps for it, then
        // swaps back. Height stays at the resting bar height.
        BarOsd {
            id: osd

            anchors.centerIn: parent
            visible: root.osdOpen

            opacity: root.osdOpen ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: 50 }
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // Left flare wing fill: square minus a quarter disc — the arc runs from
    // the top edge tangentially down into the plate's left side.
    Shape {
        anchors.right: plate.left
        y: 0
        width: root.flare
        height: root.flare
        antialiasing: true

        ShapePath {
            fillColor: Theme.plate
            strokeWidth: -1

            startX: 0
            startY: 0
            PathLine { x: root.flare; y: 0 }
            PathLine { x: root.flare; y: root.flare }
            PathArc {
                x: 0
                y: 0
                radiusX: root.flare
                radiusY: root.flare
                direction: PathArc.Counterclockwise
            }
        }
    }

    // Right wing, mirrored. The path is the exact x-mirror of the left one —
    // filling the disc side instead of the fillet side leaves a black wedge
    // past the plate edge with an AA seam slicing through it (visible on the
    // narrow OSD plate). Overlaps the plate by 1px: the plate centers on a
    // half pixel, and abutting AA edges at plate.right shine through as a
    // gray line otherwise.
    Shape {
        anchors.left: plate.right
        anchors.leftMargin: -1
        y: 0
        width: root.flare + 1
        height: root.flare
        antialiasing: true

        ShapePath {
            fillColor: Theme.plate
            strokeWidth: -1

            startX: root.flare
            startY: 0
            PathLine { x: 0; y: 0 }
            PathLine { x: 0; y: root.flare }
            PathArc {
                x: root.flare
                y: 0
                radiusX: root.flare
                radiusY: root.flare
                direction: PathArc.Clockwise
            }
        }
    }

    // One continuous outline over the composite silhouette: top edge → left
    // fillet → left side → bottom-left corner → bottom → bottom-right corner
    // → right side → right fillet → top edge. The top edge itself stays
    // unstroked so the plate merges into it.
    Shape {
        id: outline

        anchors.left: plate.left
        anchors.leftMargin: -root.flare
        y: 0
        width: plate.width + root.flare * 2
        height: plate.height
        antialiasing: true

        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.plateBorder
            strokeWidth: 1

            startX: 0
            startY: 0
            PathArc {
                x: root.flare
                y: root.flare
                radiusX: root.flare
                radiusY: root.flare
                direction: PathArc.Clockwise
            }
            PathLine { x: root.flare; y: outline.height - Theme.radiusLG }
            PathArc {
                x: root.flare + Theme.radiusLG
                y: outline.height
                radiusX: Theme.radiusLG
                radiusY: Theme.radiusLG
                direction: PathArc.Counterclockwise
            }
            PathLine { x: outline.width - root.flare - Theme.radiusLG; y: outline.height }
            PathArc {
                x: outline.width - root.flare
                y: outline.height - Theme.radiusLG
                radiusX: Theme.radiusLG
                radiusY: Theme.radiusLG
                direction: PathArc.Counterclockwise
            }
            PathLine { x: outline.width - root.flare; y: root.flare }
            PathArc {
                x: outline.width
                y: 0
                radiusX: root.flare
                radiusY: root.flare
                direction: PathArc.Clockwise
            }
        }
    }
}
