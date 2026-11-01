pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../../style"
import "../../services"

// Application launcher content: a search line and a result list, in the
// style of the reference pickers (search line on top, selected row outlined
// with the matugen accent, "N/M" counter and an "Enter to launch" hint at
// the bottom). Not a window of its own — the bar embeds this item and
// morphs into it. Open state lives in LauncherState, driven by the niri
// keybind through `qs ipc call launcher toggleOn <output>`; dismissed by
// Esc or launching an app.
Item {
    id: root

    // Set by the embedding bar: this monitor's plate is currently the
    // launcher.
    property bool active: false

    // The embedding bar sizes its plate height from this.
    implicitHeight: card.implicitHeight

    readonly property var allEntries: DesktopEntries.applications.values
    readonly property string query: input.text
    property int currentIndex: 0

    // Apps with Terminal=true in their desktop entry run through this.
    // $TERMINAL wins (e.g. ghostty), alacritty is the fallback. Split on
    // spaces so `TERMINAL="ghostty --class=foo"` also works.
    readonly property var terminalCommand: (Quickshell.env("TERMINAL") || "alacritty")
        .split(/\s+/).filter(s => s !== "").concat(["-e"])

    // ---- geometry ----
    readonly property int cardPadding: 16
    readonly property int rowHeight: 52
    readonly property int rowSpacing: 4

    // ---- results ------------------------------------------------------------
    // Empty query: most opened first, ties alphabetical. Otherwise:
    // exact > prefix > word start > substring > subsequence, with the name
    // weighted over comment/keywords.
    readonly property var results: {
        if (!root.visible)
            return [];

        const entries = root.allEntries;
        const q = root.query.toLowerCase().trim();
        if (q === "") {
            const counts = LauncherState.counts;
            return entries.slice().sort((a, b) =>
                (counts[b.id] ?? 0) - (counts[a.id] ?? 0)
                || a.name.localeCompare(b.name));
        }

        const scored = [];
        for (let i = 0; i < entries.length; i++) {
            const score = root.scoreEntry(entries[i], q);
            if (score > 0)
                scored.push({ entry: entries[i], score: score });
        }
        scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
        return scored.map(match => match.entry);
    }

    // ---- matching -----------------------------------------------------------

    // Match quality of query `q` (lowercase) inside lowercase `text`:
    // 0 = no match, higher is better. Exact > prefix > word start >
    // substring > subsequence.
    function matchQuality(text: string, q: string): int {
        if (q === "")
            return 1;
        if (text === q)
            return 100;
        if (text.startsWith(q))
            return 80;

        const at = text.indexOf(q);
        if (at > 0) {
            const prev = text.charAt(at - 1);
            if (" -_.,:;()[]/".indexOf(prev) !== -1)
                return 60;
            return 40;
        }

        // Subsequence: every query char must appear in order; tight runs win.
        let pos = 0;
        let gaps = 0;
        for (let i = 0; i < q.length; i++) {
            const found = text.indexOf(q.charAt(i), pos);
            if (found === -1)
                return 0;
            gaps += found - pos;
            pos = found + 1;
        }
        return Math.max(1, 20 - gaps);
    }

    // Weighted per-field score. Lower-weight fields require a stronger match
    // so a comment hit can't outrank a name hit.
    function fieldScore(text: string, q: string, weight: int, minQuality: int): int {
        const quality = root.matchQuality((text ?? "").toLowerCase(), q);
        return quality >= minQuality ? quality * weight : 0;
    }

    function scoreEntry(entry: DesktopEntry, q: string): int {
        let score = root.fieldScore(entry.name, q, 3, 1);
        score = Math.max(score, root.fieldScore(entry.genericName, q, 2, 20));
        score = Math.max(score, root.fieldScore(entry.id, q, 1, 40));
        score = Math.max(score, root.fieldScore(entry.comment, q, 1, 40));

        const keywords = entry.keywords;
        for (let i = 0; i < keywords.length; i++)
            score = Math.max(score, root.fieldScore(keywords[i], q, 2, 20));

        if (score > 0)
            score += Math.max(0, 20 - entry.name.length); // short names first
        return score;
    }

    // ---- actions ------------------------------------------------------------

    function moveFocus(delta: int): void {
        if (root.results.length === 0)
            return;
        root.currentIndex = Math.max(0, Math.min(root.results.length - 1, root.currentIndex + delta));
    }

    function activate(index: int): void {
        const entry = root.results[index];
        if (!entry)
            return;

        LauncherState.bump(entry.id);
        LauncherState.close();
        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: root.terminalCommand.concat(entry.command),
                workingDirectory: entry.workingDirectory
            });
        else
            entry.execute();
    }

    // Clear the query and selection whenever this monitor's plate becomes
    // the launcher.
    onActiveChanged: {
        if (!root.active)
            return;
        input.text = "";
        root.currentIndex = 0;
        focusKick.restart();
    }

    // Layer surfaces take a moment to gain keyboard focus; make sure the
    // search field ends up active either way.
    Timer {
        id: focusKick
        interval: 50
        onTriggered: input.forceActiveFocus()
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

            spacing: 12

            // ---- search line ------------------------------------------------

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
                    text: "Search apps…"
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

                    Keys.onEscapePressed: LauncherState.close()
                    Keys.onUpPressed: root.moveFocus(-1)
                    Keys.onDownPressed: root.moveFocus(1)
                }

                Text {
                    id: counter

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.results.length + "/" + root.allEntries.length
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            // ---- results --------------------------------------------------------

            ListView {
                id: list

                width: parent.width
                height: root.results.length > 0
                    ? Math.min(root.results.length * (root.rowHeight + root.rowSpacing) - root.rowSpacing,
                               root.rowHeight * 6 + root.rowSpacing * 5)
                    : 0
                visible: root.results.length > 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: root.rowSpacing
                model: root.results
                currentIndex: root.currentIndex
                delegate: ResultItem {}

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
                visible: root.results.length === 0
                text: "No results"
                color: Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            // ---- footer ---------------------------------------------------------

            Item {
                id: footer

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
                    text: "Enter to launch"
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }
    }

    // Application icon with the initial-letter fallback.
    component AppIcon: Item {
        id: iconBox

        required property DesktopEntry entry
        property int size: 32

        implicitWidth: size
        implicitHeight: size

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Theme.surfaceContainerHigh
            visible: iconImage.status !== Image.Ready

            Text {
                anchors.centerIn: parent
                text: (iconBox.entry?.name || "?").charAt(0).toUpperCase()
                color: Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(iconBox.size * 0.35)
            }
        }

        IconImage {
            id: iconImage

            anchors.fill: parent
            anchors.margins: 2
            // `true` makes a missing themed icon return "", so the
            // initial-letter fallback can appear instead of a placeholder.
            source: {
                const icon = iconBox.entry?.icon ?? "";
                return icon !== "" ? Quickshell.iconPath(icon, true) : "";
            }
        }
    }

    // One application row: icon (or initial fallback), name, description;
    // selected row gets a container tone and an accent outline.
    component ResultItem: Rectangle {
        id: item

        required property int index
        required property DesktopEntry modelData

        readonly property bool selected: root.currentIndex === item.index

        width: list.width
        height: root.rowHeight
        radius: Theme.radiusMD
        color: item.selected ? Theme.surfaceContainerHigh : "transparent"
        border.width: item.selected ? 1 : 0
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

        AppIcon {
            id: rowIcon

            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            entry: item.modelData
        }

        Column {
            anchors.left: rowIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: item.modelData.name || item.modelData.id
                color: Theme.onSurface
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: item.selected ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: item.modelData.comment || item.modelData.genericName || ""
                color: Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        HoverHandler {
            id: itemHover

            onHoveredChanged: {
                if (itemHover.hovered)
                    root.currentIndex = item.index;
            }
        }

        MouseArea {
            id: pressArea

            anchors.fill: parent

            onClicked: root.activate(item.index)
        }
    }
}
