pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../style"

// Open state of the quick settings panel. Same plate-morph contract as
// LauncherState: the per-monitor bars bind to this, the one whose screen
// name matches morphs into the panel. Driven by a click on the bar's empty
// space or by `qs ipc call quicksettings toggleOn <output>`.
//
// Also owns timer/stopwatch state so the panel UI can be lazy-loaded without
// losing a running timer/stopwatch.
Singleton {
    id: root

    property bool shown: false
    property string screen: ""

    // Tab the morphed panel shows; QuickSettingsPanel mirrors its currentTab
    // here so services/IPC can open the panel straight onto a tab.
    property int tab: 0

    // Width of the morphed plate; Bar.qml binds to this so the panel scrim
    // (PanelScrim.qml) can cut its click-through hole without duplicating
    // the constants.
    readonly property int plateWidth: Math.min(640,
        ((Quickshell.screens.find(s => s.name === root.screen)?.width ?? 1920)
         - Theme.barSideMargin * 2) - 160)

    // Height of the morphed plate, mirrored from Bar.qml so the panel scrim
    // (PanelScrim.qml) can cut the hole to the panel itself, not the column.
    property int plateHeight: Theme.barHeight

    // ---- timer / stopwatch state (survives panel unload) ----
    property bool timerRunning: false
    property int timerTotalMs: 0
    property int timerBaseMs: 0
    property int timerStartMs: 0
    property int timerRemainingMs: 0

    property bool swRunning: false
    property int swElapsedMs: 0
    property int swBaseMs: 0
    property int swStartMs: 0

    property bool _timeStateLoaded: false

    function saveTimeState(): void {
        if (!root._timeStateLoaded) return;
        timeStore.setText(JSON.stringify({
            timerRunning: root.timerRunning,
            timerTotalMs: root.timerTotalMs,
            timerBaseMs: root.timerBaseMs,
            timerStartMs: root.timerStartMs,
            timerRemainingMs: root.timerRemainingMs,
            swRunning: root.swRunning,
            swElapsedMs: root.swElapsedMs,
            swBaseMs: root.swBaseMs,
            swStartMs: root.swStartMs
        }));
    }

    function timerSet(ms: int): void {
        if (root.timerRunning)
            return;
        root.timerTotalMs = ms;
        root.timerBaseMs = ms;
        root.timerRemainingMs = ms;
        root.saveTimeState();
    }

    function timerAdjust(deltaMs: int): void {
        if (root.timerRunning)
            return;
        root.timerSet(Math.max(0, root.timerBaseMs + deltaMs));
    }

    function timerToggle(): void {
        if (root.timerRunning) {
            root.timerBaseMs = Math.max(0, root.timerBaseMs - (Date.now() - root.timerStartMs));
            root.timerRemainingMs = root.timerBaseMs;
            root.timerRunning = false;
        } else if (root.timerBaseMs > 0) {
            root.timerStartMs = Date.now();
            root.timerRunning = true;
        }
        root.saveTimeState();
    }

    function timerReset(): void {
        root.timerRunning = false;
        root.timerTotalMs = 0;
        root.timerBaseMs = 0;
        root.timerRemainingMs = 0;
        root.saveTimeState();
    }

    function swToggle(): void {
        if (root.swRunning) {
            root.swBaseMs = root.swBaseMs + (Date.now() - root.swStartMs);
            root.swElapsedMs = root.swBaseMs;
            root.swRunning = false;
        } else {
            root.swStartMs = Date.now();
            root.swRunning = true;
        }
        root.saveTimeState();
    }

    function swReset(): void {
        root.swRunning = false;
        root.swBaseMs = 0;
        root.swElapsedMs = 0;
        root.saveTimeState();
    }

    FileView {
        id: timeStore

        path: Qt.resolvedUrl("../quicksettings-state.json")

        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.timerRunning = !!d.timerRunning;
                root.timerTotalMs = d.timerTotalMs ?? 0;
                root.timerBaseMs = d.timerBaseMs ?? 0;
                root.timerStartMs = d.timerStartMs ?? 0;
                root.timerRemainingMs = d.timerRemainingMs ?? 0;
                root.swRunning = !!d.swRunning;
                root.swElapsedMs = d.swElapsedMs ?? 0;
                root.swBaseMs = d.swBaseMs ?? 0;
                root.swStartMs = d.swStartMs ?? 0;
                if (root.timerRunning) {
                    root.timerRemainingMs = Math.max(0, root.timerBaseMs - (Date.now() - root.timerStartMs));
                    if (root.timerRemainingMs === 0) {
                        root.timerRunning = false;
                        root.timerTotalMs = 0;
                        root.timerBaseMs = 0;
                    }
                }
                if (root.swRunning)
                    root.swElapsedMs = root.swBaseMs + (Date.now() - root.swStartMs);
            } catch (e) {
            }
            root._timeStateLoaded = true;
        }

        onLoadFailed: {
            root._timeStateLoaded = true;
        }
    }

    Timer {
        id: timerTick

        interval: 200
        repeat: true
        running: root.timerRunning

        onTriggered: {
            root.timerRemainingMs = Math.max(0, root.timerBaseMs - (Date.now() - root.timerStartMs));
            if (root.timerRemainingMs !== 0)
                return;
            root.timerRunning = false;
            root.timerTotalMs = 0;
            root.timerBaseMs = 0;
            root.saveTimeState();
            Quickshell.execDetached(["notify-send", "Timer", "Time is up"]);
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: root.swRunning

        onTriggered: root.swElapsedMs = root.swBaseMs + (Date.now() - root.swStartMs)
    }

    function toggle(screenName: string): void {
        if (root.shown) {
            root.shown = false;
            return;
        }
        // all bar plates share one morph
        LauncherState.shown = false;
        Wallpaper.shown = false;
        Clipboard.shown = false;
        // Empty target keeps the last used output; default to the first one.
        if (screenName !== "")
            root.screen = screenName;
        else if (root.screen === "")
            root.screen = Quickshell.screens[0]?.name ?? "";
        root.shown = true;
    }

    function close(): void {
        root.shown = false;
    }

    // Open onto a specific tab (7 = the chip's wifi networks view, 8 = app
    // colors, 9 = system monitor, 10 = tray); also the test hook for driving
    // views without a pointer.
    function openTab(screenName: string, i: int): void {
        if (root.shown)
            root.shown = false; // toggle() would only close it
        root.tab = i;
        root.toggle(screenName);
    }

    IpcHandler {
        target: "quicksettings"

        function toggle(): void { root.toggle("") }
        function toggleOn(screenName: string): void { root.toggle(screenName) }
        function close(): void { root.close() }
        function openTab(screenName: string, i: int): void { root.openTab(screenName, i) }
    }
}
