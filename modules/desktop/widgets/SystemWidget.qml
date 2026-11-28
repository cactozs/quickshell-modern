pragma ComponentBehavior: Bound

import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../style"

WidgetCard {
    id: root

    title: "Система"
    icon: "memory"
    cardWidth: 340
    badge: root.uptimeText !== "" ? "Работает " + root.uptimeText : ""

    property int cpuPct: 0
    property int memPct: 0
    property real lastIdle: 0
    property real lastTotal: 0
    property var cpuHistory: []
    property var memHistory: []
    property string uptimeText: ""

    function fmtUptime(seconds: real): string {
        const d = Math.floor(seconds / 86400);
        const h = Math.floor((seconds % 86400) / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        if (d > 0)
            return d + "д " + h + "ч";
        if (h > 0)
            return h + "ч " + m + "м";
        return m + "м";
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuStat.reload();
            memInfo.reload();
            uptimeFile.reload();
        }
    }

    FileView {
        id: cpuStat
        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            const line = text().split("\n").find(l => l.startsWith("cpu "));
            if (!line) return;
            const p = line.trim().split(/\s+/).slice(1).map(n => parseInt(n));
            const idle = (p[3] ?? 0) + (p[4] ?? 0);
            const total = p.reduce((a, b) => a + b, 0);
            const dt = total - root.lastTotal;
            const di = idle - root.lastIdle;
            root.lastTotal = total;
            root.lastIdle = idle;
            if (dt > 0) {
                root.cpuPct = Math.round(100 * (dt - di) / dt);
                root.cpuHistory = root.cpuHistory.concat([root.cpuPct]).slice(-40);
            }
        }
    }

    FileView {
        id: memInfo
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const total = parseInt(text().match(/MemTotal:\s*(\d+)/)?.[1] ?? "0");
            const avail = parseInt(text().match(/MemAvailable:\s*(\d+)/)?.[1] ?? "0");
            if (total > 0) {
                root.memPct = Math.round(100 * (total - avail) / total);
                root.memHistory = root.memHistory.concat([root.memPct]).slice(-40);
            }
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        printErrors: false
        onLoaded: {
            const seconds = parseFloat(text().trim());
            if (Number.isFinite(seconds))
                root.uptimeText = root.fmtUptime(seconds);
        }
    }

    component Metric: ColumnLayout {
        id: metric

        required property string label
        required property int value
        required property color accent
        required property var history

        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: metric.label
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            Item { Layout.fillWidth: true }

            Text {
                text: metric.value + "%"
                color: metric.accent
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
        }

        Sparkline {
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            values: metric.history
            lineColor: metric.accent
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 3
            radius: 2
            color: Theme.surfaceContainerHigh

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, metric.value / 100))
                height: parent.height
                radius: parent.radius
                color: metric.accent
            }
        }
    }

    Metric {
        Layout.fillWidth: true
        label: "CPU"
        value: root.cpuPct
        accent: Theme.primary
        history: root.cpuHistory
    }

    Metric {
        Layout.fillWidth: true
        label: "RAM"
        value: root.memPct
        accent: Theme.secondary
        history: root.memHistory
    }
}
