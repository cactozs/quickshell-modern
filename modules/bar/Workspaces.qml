pragma ComponentBehavior: Bound

import QtQuick
import "."
import "../../services"
import "../../style"

// Workspace dots for one niri output, like the reference bar: every open
// workspace is a little pill (taller than wide); the active one grows into
// a taller dot and shrinks back when focus leaves. Click focuses the
// workspace, hover gently scales a dot up, an urgent dot takes the error
// color.
//
// niri events rebuild the workspace array, and a Repeater (even over a
// ScriptModel) destroys and recreates every dot on each switch — too fast
// for any Behavior to play. The dots are therefore a keyed pool (by
// workspace idx) synced in place, so the height spring really runs.
Item {
    id: root

    // niri output whose workspaces to show (the bar's screen).
    property string screenName

    // inactive dots are little pills, the active one grows to pillHeight
    readonly property int dotWidth: 8
    readonly property int dotHeight: 10
    readonly property int pillHeight: 16
    readonly property int dotSpacing: 6

    readonly property var model: Niri.workspacesFor(root.screenName)

    implicitWidth: Math.max(0, model.length * (root.dotWidth + root.dotSpacing) - root.dotSpacing)
    implicitHeight: root.pillHeight

    // workspace idx -> Dot
    property var pool: ({})

    Component {
        id: dotComp
        Dot {}
    }

    onModelChanged: syncDots()
    Component.onCompleted: syncDots()

    function syncDots(): void {
        const alive = new Set();
        for (let i = 0; i < model.length; i++) {
            const ws = model[i];
            alive.add(ws.idx);
            let dot = pool[ws.idx];
            if (!dot) {
                dot = dotComp.createObject(root, {
                    wsIdx: ws.idx,
                    output: root.screenName,
                    dimWidth: root.dotWidth,
                    dimHeight: root.dotHeight,
                    growHeight: root.pillHeight,
                    active: ws.is_active ?? false,
                    urgent: ws.is_urgent ?? false
                });
                pool[ws.idx] = dot;
            }
            dot.active = ws.is_active ?? false;
            dot.urgent = ws.is_urgent ?? false;
            dot.x = i * (root.dotWidth + root.dotSpacing);
        }
        for (const key of Object.keys(pool)) {
            if (!alive.has(Number(key))) {
                pool[key].destroy();
                delete pool[key];
            }
        }
    }
}
