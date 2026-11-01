pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import "../../style"
import "../../services"

// Clipboard history content: a search line and a list of cliphist rows, same
// embedded-in-the-bar pattern as Launcher.qml (the bar morphs into it).
// Click or Enter re-copies the entry via `cliphist decode | wl-copy` and
// folds the panel away; the X or Ctrl+Z deletes it from the history. Image
// entries decode to a thumbnail file under XDG_RUNTIME_DIR the first time
// their row is created.
Item {
    id: root

    // Set by the embedding bar: this monitor's plate is currently the picker.
    property bool active: false

    // The embedding bar sizes its plate height from this.
    implicitHeight: card.implicitHeight

    readonly property var entries: Clipboard.list
    readonly property string query: input.text

    // Substring match on the preview text (the line without the id prefix).
    readonly property var results: {
        if (root.query === "")
            return root.entries;
        const q = root.query.toLowerCase();
        return root.entries.filter(line =>
            line.slice(line.indexOf("\t") + 1).toLowerCase().includes(q));
    }

    property int currentIndex: 0

    // ---- geometry ----
    readonly property int cardPadding: 14
    readonly property int rowHeight: 52
    readonly property int rowSpacing: 4
    readonly property int maxRows: 7

    // Binary rows decode into one file per cliphist id here.
    readonly property string thumbDir: Clipboard.thumbDir

    function moveFocus(delta: int): void {
        if (root.results.length === 0)
            return;
        root.currentIndex = Math.max(0, Math.min(root.results.length - 1, root.currentIndex + delta));
    }

    function activate(index: int): void {
        const line = root.results[index];
        if (line !== undefined)
            Clipboard.activate(line);
    }

    function deleteCurrent(): void {
        const line = root.results[root.currentIndex];
        if (line !== undefined)
            Clipboard.remove(line);
    }

    onActiveChanged: {
        if (!root.active)
            return;
        input.text = "";
        root.currentIndex = 0;
        focusKick.restart();
        scrollKick.restart();
    }

    // Layer surfaces take a moment to gain keyboard focus; make sure the
    // search line ends up active either way.
    Timer {
        id: focusKick

        interval: 50
        onTriggered: input.forceActiveFocus()
    }

    // The list fills async after refresh(); snap back to the newest entry
    // once it has laid out.
    Timer {
        id: scrollKick

        interval: 150
        onTriggered: list.contentY = 0
    }

    // Content container: fills the bar plate that morphs around it — the
    // plate itself is the background now.
    Item {
        id: card

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        implicitHeight: column.implicitHeight + root.cardPadding * 2

        Column {
            id: column

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: root.cardPadding
            }

            spacing: 10

            // ---- search line ----

            Item {
                id: searchBar

                width: parent.width
                height: 40

                Text {
                    id: searchIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    color: input.activeFocus ? Theme.primary : Theme.onSurfaceVariant
                    font.family: Theme.iconFont
                    font.pixelSize: 20

                    Behavior on color {
                        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                }

                Text {
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search history…"
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    visible: input.text.length === 0
                }

                TextInput {
                    id: input

                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.right: counter.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true

                    color: Theme.onSurface
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    selectByMouse: true
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.onPrimary

                    focus: root.active

                    onAccepted: root.activate(root.currentIndex)
                    onTextChanged: root.currentIndex = 0

                    Keys.onEscapePressed: Clipboard.close()
                    Keys.onUpPressed: root.moveFocus(-1)
                    Keys.onDownPressed: root.moveFocus(1)

                    // Ctrl+Z deletes the selected row. Handled here, not
                    // via a Shortcut: layer-shell windows are never
                    // Qt-"active", so window-context shortcuts don't fire —
                    // but Keys on the focused input always do.
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
                            root.deleteCurrent();
                            event.accepted = true;
                        }
                    }
                }

                Text {
                    id: counter

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.results.length + "/" + root.entries.length
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            // ---- history ----

            ListView {
                id: list

                width: parent.width
                height: root.results.length > 0
                    ? Math.min(root.results.length * (root.rowHeight + root.rowSpacing) - root.rowSpacing,
                               root.maxRows * (root.rowHeight + root.rowSpacing) - root.rowSpacing)
                    : 0
                visible: root.results.length > 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: root.rowSpacing
                model: root.results
                currentIndex: root.currentIndex
                delegate: ClipRow {}

                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, ListView.Contain);
                }

                // Wheel moves the selection rather than scrolling, so Enter can
                // never fire on an off-screen row.
                WheelHandler {
                    onWheel: event => {
                        if (event.angleDelta.y === 0)
                            return;
                        root.moveFocus(event.angleDelta.y > 0 ? -1 : 1);
                        event.accepted = true;
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.entries.length === 0
                text: "Clipboard is empty"
                color: Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.entries.length > 0 && root.results.length === 0
                text: "No results"
                color: Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            // ---- footer ----

            Item {
                width: parent.width
                implicitHeight: hintLeft.implicitHeight

                Text {
                    id: hintLeft

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↑↓ — navigate · Esc — close"
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Enter to copy · Ctrl+Z — delete"
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }
    }

    // One history row: text preview (2 lines) or, for binary entries, a
    // decoded thumbnail + the cliphist caption ("45 KiB png"). The selected
    // row gets the container tone + accent outline; the X deletes it.
    component ClipRow: Rectangle {
        id: row

        required property int index
        required property string modelData

        readonly property bool binary: modelData.includes("[[ binary data")
        // Preview without the leading "id\t" cliphist prefix.
        readonly property string preview: modelData.slice(modelData.indexOf("\t") + 1)
            .replace(/\t/g, " ").trim()
        // "[[ binary data · 45 KiB png ]]" → "45 KiB png"
        readonly property string caption: binary
            ? preview.replace(/^\[\[ binary data[^a-z0-9]*/i, "").replace(/\]\]$/, "").trim()
            : ""
        readonly property int entryId: parseInt(modelData)
        readonly property string thumbPath: root.thumbDir + "/" + entryId

        // Decoded thumbnail path, empty until the decode landed on disk.
        property string decoded: ""

        readonly property bool selected: root.currentIndex === row.index

        width: list.width
        height: root.rowHeight
        radius: Theme.radiusMD
        color: row.selected ? Theme.surfaceContainerHigh : "transparent"
        border.width: row.selected ? 1 : 0
        border.color: Theme.primary
        // respond on press, not release
        scale: pressArea.pressed ? 0.98 : 1

        Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Behavior on border.width {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        Behavior on scale {
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        // Thumbnail box for binary rows; the glyph shows until the decode
        // finishes, then the image takes over.
        ClippingRectangle {
            id: thumb

            visible: row.binary
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 8
            color: "transparent"

            Text {
                anchors.centerIn: parent
                visible: row.decoded === ""
                text: "image"
                color: Theme.onSurfaceVariant
                font.family: Theme.iconFont
                font.pixelSize: 18
            }

            Image {
                anchors.fill: parent
                visible: row.decoded !== ""
                source: row.decoded
                sourceSize: Qt.size(72, 72)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Text {
            anchors.left: row.binary ? thumb.right : parent.left
            anchors.leftMargin: row.binary ? 10 : 12
            anchors.right: delButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: row.binary ? row.caption : row.preview
            color: row.binary ? Theme.onSurfaceVariant : Theme.onSurface
            font.family: Theme.fontFamily
            font.pixelSize: 12
            maximumLineCount: 2
            wrapMode: Text.Wrap
            elide: Text.ElideRight
        }

        Text {
            id: delButton

            // Above the row-wide pressArea: later siblings stack on top in
            // QML, so without this the row MouseArea eats the X clicks.
            z: 1

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "close"
            color: row.selected ? Theme.error : Theme.onSurfaceVariant
            font.family: Theme.iconFont
            font.pixelSize: 16
            opacity: row.selected ? 1 : 0.5

            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor

                onClicked: Clipboard.remove(row.modelData)
            }
        }

        HoverHandler {
            id: rowHover

            onHoveredChanged: {
                if (rowHover.hovered)
                    root.currentIndex = row.index;
            }
        }

        MouseArea {
            id: pressArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onClicked: root.activate(row.index)
        }

        Component.onCompleted: {
            if (row.binary) {
                decodeProc.command = ["sh", "-c",
                    'mkdir -p "$3" && printf %s\\n "$1" | cliphist decode > "$2"',
                    "sh", row.modelData, row.thumbPath, root.thumbDir];
                decodeProc.running = true;
            }
        }

        Process {
            id: decodeProc

            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0)
                    row.decoded = row.thumbPath;
            }
        }
    }
}
