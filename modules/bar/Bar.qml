pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../../style"
import "."

// Peninsula bar: a compact plate pinned to the top edge (no top margin) with
// side margins, hugging its content and centered on the screen. The sides
// merge into the top edge through concave flare wings (a fillet tangent to
// both the edge and the plate side), so the island "flows out" of the screen
// top. The outline is a single continuous stroke that runs edge → fillet →
// side → bottom corners → side → fillet → edge, with no line along the top
// edge itself. Only the plate takes input (mask); the exclusive zone keeps
// windows below it with a small gap.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property int padH: 16

    // radius of the concave fillet connecting the plate sides to the top edge
    readonly property int flare: 20

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

    implicitHeight: Theme.barHeight
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: implicitHeight + Theme.barMargin
    color: "transparent"

    WlrLayershell.namespace: "quickshell:bar"

    mask: Region { item: plate }

    // Bottom corners only: the capsule is drawn one radius taller and shifted
    // up, and the plate clips its top rounding away — so the bar meets the
    // top edge with straight sides.
    Item {
        id: plate

        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height
        width: contentRow.implicitWidth + root.padH * 2
        clip: true

        Rectangle {
            y: -Theme.radiusLG
            width: parent.width
            height: parent.height + Theme.radiusLG
            radius: Theme.radiusLG
            color: Theme.plate
        }

        // Left and right sections pinned to the ends, the clock truly
        // centered between them via the two equally stretching fillers.
        RowLayout {
            id: contentRow

            anchors.fill: parent
            anchors.leftMargin: root.padH
            anchors.rightMargin: root.padH
            spacing: 14

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

    // Right flare wing fill, mirrored.
    Shape {
        anchors.left: plate.right
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
            PathArc {
                x: 0
                y: root.flare
                radiusX: root.flare
                radiusY: root.flare
                direction: PathArc.Counterclockwise
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
