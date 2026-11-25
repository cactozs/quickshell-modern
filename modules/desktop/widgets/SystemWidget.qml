pragma ComponentBehavior: Bound

import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../style"

WidgetCard {
    id: root

    title: "Система"
    icon: "memory"
    cardWidth: 250

    property int cpuPct: 0
    property int memPct: 0
    property real lastIdle: 0
    property real lastTotal: 0

    function pct(v: real): string { return Math.round(v) + "%"; }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuStat.reload();
            memInfo.reload();
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
            if (dt > 0)
                root.cpuPct = Math.round(100 * (dt - di) / dt);
        }
    }

    FileView {
        id: memInfo
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const total = parseInt(text().match(/MemTotal:\s*(\d+)/)?.[1] ?? "0");
            const avail = parseInt(text().match(/MemAvailable:\s*(\d+)/)?.[1] ?? "0");
            if (total > 0)
                root.memPct = Math.round(100 * (total - avail) / total);
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: "CPU"; color: Theme.surfaceVariantText; font.family: Theme.fontFamily; font.pixelSize: 11 }
            Text { text: root.pct(root.cpuPct); color: Qt.lighter(Theme.primary, 1.2); font.family: Theme.fontFamily; font.pixelSize: 26; font.weight: Font.DemiBold }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: "RAM"; color: Theme.surfaceVariantText; font.family: Theme.fontFamily; font.pixelSize: 11 }
            Text { text: root.pct(root.memPct); color: Theme.surfaceText; font.family: Theme.fontFamily; font.pixelSize: 26; font.weight: Font.DemiBold }
        }
    }

    Text {
        Layout.fillWidth: true
        text: "Обновление каждые 3 сек"
        color: Theme.surfaceVariantText
        font.family: Theme.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
    }
}
