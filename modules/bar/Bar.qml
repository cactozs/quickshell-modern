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
// In the "island" style (BarState), the plate floats instead: a gap above the
// top edge, rounded corners on every side and no flare wings. Everything else
// — the centered content, the panel morph and the exclusive zone — is the
// same.
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

    // iOS sheet timing: opening runs longer than closing, as a sheet that is
    // pushed away dismisses faster than it is pulled up. Kept short so the
    // panels feel attached to the click that opens them.
    readonly property int morphDuration: root.panelOpen ? 55 : 40

    // Bar visibility, including the time it takes to fade. A panel opened
    // while the bar is hidden keeps it on screen until the panel closes.
    readonly property bool barShown: BarState.shown || root.panelOpen

    // Island only: at rest the plate shows just the clock. A workspace switch
    // flashes the dots in (the clock stays), hovering reveals the full row.
    property bool islandHovered: false
    readonly property var islandWorkspaces: Niri.workspacesFor(root.modelData.name)
    readonly property int islandActiveWs: {
        if (!BarState.island) return -1;
        const ws = root.islandWorkspaces.find(w => w.is_active);
        return ws ? ws.idx : -1;
    }
    property int lastActiveWs: -1
    readonly property bool islandExpanded: !BarState.island || root.islandHovered || wsFlash.running

    onIslandActiveWsChanged: {
        // No flash on the first niri sync or while the island is off.
        if (BarState.island && root.lastActiveWs !== -1 && root.islandActiveWs !== -1)
            wsFlash.restart();
        root.lastActiveWs = root.islandActiveWs;
    }

    Timer {
        id: wsFlash
        interval: 1500
    }

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
        top: BarState.topMargin
        left: Theme.barSideMargin
        right: Theme.barSideMargin
    }

    implicitHeight: root.launcherOpen ? launcherLoader.height
        : root.wallpaperOpen ? ribbonLoader.height
        : root.clipboardOpen ? clipPickerLoader.height
        : root.qsOpen ? qsPanel.height : Theme.barHeight

    Behavior on implicitHeight {
        NumberAnimation {
            duration: root.morphDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.32, 0.72, 0, 1]
        }
    }

    exclusionMode: ExclusionMode.Normal
    // Reserve the resting bar height even while expanded so windows below
    // don't jump.
    exclusiveZone: Theme.barHeight
    color: "transparent"

    // Mod+P (`qs ipc call bar toggle`) fades the bar out; the window stays
    // mapped until the fade ends, then unmaps so niri reclaims the space.
    visible: root.barShown || plate.opacity > 0.001

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

    // The plate clips its content to the bar bounds. In the notch style it is
    // drawn one radius taller and shifted up, so the top rounding is clipped
    // away and the bar meets the top edge with straight sides; in the island
    // style it is a pill-shaped plate (radius = half the bar height) with a gap
    // above.
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

        opacity: root.barShown ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
        }

        Behavior on width {
            NumberAnimation {
                // Panel morphs stay snappy; island hover expand/collapse is calmer.
                duration: root.panelOpen ? root.morphDuration : 140
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.32, 0.72, 0, 1]
            }
        }

        Rectangle {
            y: BarState.island ? 0 : -Theme.radiusLG
            width: parent.width
            height: parent.height + (BarState.island ? 0 : Theme.radiusLG)
            radius: BarState.island ? Theme.barIslandRadius : Theme.radiusLG
            color: Theme.plate
            border.width: BarState.island ? 1 : 0
            border.color: Theme.plateBorder
        }

        // Hover-to-expand lives on the plate itself so the dots' own
        // MouseAreas don't have to forward it; it covers the whole pill.
        HoverHandler {
            id: hoverHandler

            onHoveredChanged: root.islandHovered = hoverHandler.hovered
        }

        // Click anywhere on the bar's empty space to open the quick settings
        // panel. The widgets' own areas sit above this and consume their
        // clicks; while a panel or the OSD is morphed, this stays off so a
        // stray click can't fight the open content.
        MouseArea {
            anchors.fill: parent
            enabled: root.barShown && !root.panelOpen && !root.osdOpen

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
                // the morph; bringing them back waits for the panel content
                // to clear, otherwise the QS mirror row double-exposes
                SequentialAnimation {
                    PauseAnimation { duration: (root.panelOpen || root.osdOpen) ? 0 : 12 }
                    NumberAnimation {
                        duration: (root.panelOpen || root.osdOpen) ? 12 : 20
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Workspaces {
                Layout.alignment: Qt.AlignVCenter
                screenName: root.modelData.name
                visible: root.islandExpanded
            }

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 10
                visible: root.islandExpanded
            }

            Clock {
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.minimumWidth: 10
                visible: root.islandExpanded
            }

            StatusRight {
                Layout.alignment: Qt.AlignVCenter
                screenName: root.modelData.name
                visible: root.islandExpanded
            }
        }

        // The launcher content, shown while the plate is morphed open. Its
        // implicitHeight drives the plate height. Unloaded while closed —
        // every panel resets its own state when `active` flips on again.
        Loader {
            id: launcherLoader

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            y: root.launcherOpen ? 0 : -6
            // unload after the closing fade; `visible || opacity` holds the
            // item alive through it, enabled cuts input at once
            active: root.launcherOpen || opacity > 0.001
            visible: root.launcherOpen || opacity > 0.001
            enabled: root.launcherOpen

            // fade the launcher content in just after the plate starts
            // growing, so the morph reads as one motion; closing fades out
            // immediately so the shrinking plate never clips a live panel
            opacity: root.launcherOpen ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.launcherOpen ? 4 : 0 }
                    NumberAnimation {
                        duration: root.launcherOpen ? 22 : 12
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: root.morphDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.32, 0.72, 0, 1]
                }
            }

            sourceComponent: Component {
                Launcher { active: root.launcherOpen }
            }
        }

        // The wallpaper ribbon: same morph, horizontal filmstrip instead of
        // a list. No keyboard focus needed — wheel scrolls, clicks apply.
        // Unloaded while closed, same contract as the launcher.
        Loader {
            id: ribbonLoader

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            y: root.wallpaperOpen ? 0 : -6
            active: root.wallpaperOpen || opacity > 0.001
            visible: root.wallpaperOpen || opacity > 0.001
            enabled: root.wallpaperOpen

            opacity: root.wallpaperOpen ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.wallpaperOpen ? 4 : 0 }
                    NumberAnimation {
                        duration: root.wallpaperOpen ? 22 : 12
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: root.morphDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.32, 0.72, 0, 1]
                }
            }

            sourceComponent: Component {
                WallpaperRibbon { active: root.wallpaperOpen }
            }
        }

        // The clipboard picker: same morph, vertical history list.
        // Unloaded while closed, same contract as the launcher.
        Loader {
            id: clipPickerLoader

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            y: root.clipboardOpen ? 0 : -6
            active: root.clipboardOpen || opacity > 0.001
            visible: root.clipboardOpen || opacity > 0.001
            enabled: root.clipboardOpen

            opacity: root.clipboardOpen ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.clipboardOpen ? 4 : 0 }
                    NumberAnimation {
                        duration: root.clipboardOpen ? 22 : 12
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: root.morphDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.32, 0.72, 0, 1]
                }
            }

            sourceComponent: Component {
                ClipboardPanel { active: root.clipboardOpen }
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
            y: root.qsOpen ? 0 : -6
            visible: root.qsOpen || opacity > 0.001
            enabled: root.qsOpen
            active: root.qsOpen
            screenName: root.modelData.name

            opacity: root.qsOpen ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.qsOpen ? 4 : 0 }
                    NumberAnimation {
                        duration: root.qsOpen ? 22 : 12
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: root.morphDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.32, 0.72, 0, 1]
                }
            }
        }

        // Transient OSD content: the whole bar content swaps for it, then
        // swaps back. Height stays at the resting bar height.
        BarOsd {
            id: osd

            anchors.centerIn: parent
            visible: root.osdOpen || opacity > 0.001

            opacity: root.osdOpen ? 1 : 0
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.osdOpen ? 5 : 0 }
                    NumberAnimation {
                        duration: root.osdOpen ? 30 : 20
                        easing.type: Easing.OutCubic
                    }
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
        opacity: plate.opacity
        visible: !BarState.island

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
        opacity: plate.opacity
        visible: !BarState.island

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

    // Notch only: one continuous outline over the composite silhouette: top
    // edge → left fillet → left side → bottom-left corner → bottom →
    // bottom-right corner → right side → right fillet → top edge. The top edge
    // itself stays unstroked so the plate merges into it. The island style
    // gets its border from the plate rectangle instead.
    Shape {
        id: outline

        anchors.left: plate.left
        anchors.leftMargin: -root.flare
        y: 0
        width: plate.width + root.flare * 2
        height: plate.height
        antialiasing: true
        opacity: plate.opacity
        visible: !BarState.island

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
