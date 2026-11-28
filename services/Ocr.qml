pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Region OCR: `grim` freezes the focused output while the overlay is still
// hidden, OcrOverlay lets the user drag a rectangle, ImageMagick crops it and
// Tesseract reads it. The text is copied with wl-copy and shown in a
// notification. `qs ipc call ocr startOn <screen>` opens it.
Singleton {
    id: root

    readonly property string languages: Quickshell.env("QS_OCR_LANGS") || "rus+est+eng"
    readonly property int minSelection: 8

    readonly property string runtimeDir: {
        const dir = Quickshell.env("XDG_RUNTIME_DIR") || "";
        return dir !== "" ? dir : "/tmp";
    }

    property bool active: false
    property string screen: ""
    property string phase: "idle" // idle | capture | select | ocr
    property string imagePath: ""

    function start(screenName: string): void {
        if (root.active) {
            root.cancel();
            return;
        }

        // The bar panels and the OCR overlay are mutually exclusive.
        LauncherState.shown = false;
        Wallpaper.shown = false;
        Clipboard.shown = false;
        QuickSettings.shown = false;

        if (screenName !== "")
            root.screen = screenName;
        else if (root.screen === "")
            root.screen = Quickshell.screens[0]?.name ?? "";

        if (root.screen === "") {
            root.notify("OCR", "No screen found");
            return;
        }

        root._removeImage();
        root.imagePath = root.runtimeDir + "/quickshell-ocr-" + Date.now() + ".png";
        root.phase = "capture";
        root.active = true;
        captureProc.command = ["grim", "-o", root.screen, root.imagePath];
        captureProc.running = true;
        captureTimeout.restart();
    }

    function cancel(): void {
        if (!root.active)
            return;
        // Set the phase first so late onExited handlers stay quiet.
        root.phase = "idle";
        if (captureProc.running)
            captureProc.running = false;
        if (ocrProc.running)
            ocrProc.running = false;
        if (copyProc.running)
            copyProc.running = false;
        captureTimeout.stop();
        ocrTimeout.stop();
        root._finish();
    }

    // Called by OcrOverlay with the logical selection and the screenshot scale.
    function select(x: real, y: real, w: real, h: real, scaleX: real, scaleY: real): void {
        if (root.phase !== "select" || root.imagePath === "")
            return;

        const px = Math.max(0, Math.round(x * scaleX));
        const py = Math.max(0, Math.round(y * scaleY));
        const pw = Math.max(0, Math.round(w * scaleX));
        const ph = Math.max(0, Math.round(h * scaleY));
        if (pw < root.minSelection || ph < root.minSelection)
            return;

        // Small selections benefit from a 2x upscale; full-screen crops do not.
        const upscale = ph < 240 ? "-resize 200%" : "";
        const script = 'set -o pipefail; magick "$1" -crop "$2" +repage '
            + "-colorspace Gray " + upscale + ' png:- | tesseract stdin stdout '
            + '-l "$3" --psm 6 --oem 1';

        root.phase = "ocr";
        ocrProc._text = "";
        ocrProc._err = "";
        ocrProc.command = ["bash", "-c", script, "sh", root.imagePath,
            pw + "x" + ph + "+" + px + "+" + py, root.languages];
        ocrProc.running = true;
        ocrTimeout.restart();
    }

    function fail(message: string): void {
        root.notify("OCR", message);
        root.cancel();
    }

    function copy(text: string): void {
        if (copyProc.running)
            copyProc.running = false;
        copyProc._text = text;
        copyProc.command = ["sh", "-c", 'printf %s "$1" | wl-copy', "sh", text];
        copyProc.running = true;
    }

    function notify(title: string, body: string): void {
        const message = body !== "" ? body : title;
        Quickshell.execDetached(["notify-send", "-a", "OCR", "-i", "edit-copy-symbolic", title, message]);
    }

    function preview(text: string): string {
        const clean = text.replace(/\s+/g, " ").trim();
        return clean.length > 120 ? clean.substring(0, 117) + "..." : clean;
    }

    function _finish(): void {
        root.active = false;
        root.phase = "idle";
        root._removeImage();
    }

    function _removeImage(): void {
        if (root.imagePath === "")
            return;
        Quickshell.execDetached(["rm", "-f", root.imagePath]);
        root.imagePath = "";
    }

    Process {
        id: captureProc

        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message !== "")
                    console.warn("OCR grim:", message);
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (root.phase !== "capture")
                return;
            captureTimeout.stop();
            if (exitCode === 0 && root.imagePath !== "") {
                root.phase = "select";
            } else {
                root.notify("OCR", "Could not capture the screen");
                root._finish();
            }
        }
    }

    Process {
        id: ocrProc

        property string _text: ""
        property string _err: ""

        stdout: StdioCollector {
            onStreamFinished: ocrProc._text = text
        }

        stderr: StdioCollector {
            onStreamFinished: ocrProc._err = text
        }

        onExited: (exitCode, exitStatus) => {
            if (root.phase !== "ocr")
                return;
            ocrTimeout.stop();

            const text = ocrProc._text.trim();
            if (exitCode !== 0) {
                const err = ocrProc._err.trim();
                if (err !== "")
                    console.warn("OCR tesseract:", err);
                root.notify("OCR", "Text recognition failed");
                root._finish();
                return;
            }
            if (text === "") {
                root.notify("OCR", "No text found");
                root._finish();
                return;
            }
            root.copy(text);
        }
    }

    Process {
        id: copyProc

        property string _text: ""

        onExited: (exitCode, exitStatus) => {
            if (root.phase !== "ocr")
                return;
            if (exitCode === 0)
                root.notify("OCR", root.preview(copyProc._text));
            else
                root.notify("OCR", "Could not copy the text");
            root._finish();
        }
    }

    Timer {
        id: captureTimeout

        interval: 5000
        onTriggered: {
            if (root.phase !== "capture")
                return;
            root.phase = "idle";
            captureProc.running = false;
            root.notify("OCR", "Could not capture the screen");
            root._finish();
        }
    }

    Timer {
        id: ocrTimeout

        interval: 20000
        onTriggered: {
            if (root.phase !== "ocr")
                return;
            root.phase = "idle";
            ocrProc.running = false;
            root.notify("OCR", "Text recognition timed out");
            root._finish();
        }
    }

    IpcHandler {
        target: "ocr"

        function start(): void { root.start("") }
        function startOn(screenName: string): void { root.start(screenName) }
        function cancel(): void { root.cancel() }
    }
}
