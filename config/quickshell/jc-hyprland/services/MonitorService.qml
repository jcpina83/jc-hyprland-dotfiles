import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property var monitors: []
    readonly property int count: monitors.length
    readonly property int activeCount:
        monitors.filter(monitor => !monitor.disabled).length

    readonly property string focusedOutputName:
        Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    property bool loading: false
    property string errorMessage: ""
    property string lastRefresh: ""

    signal refreshed()

    function logicalSize(width, height, scale, transform) {
        const safeScale = scale > 0 ? scale : 1;
        let logicalWidth = width / safeScale;
        let logicalHeight = height / safeScale;

        // 90° / 270° rotations (including flipped variants) swap axes.
        if (transform === 1 || transform === 3
                || transform === 5 || transform === 7) {
            const temporary = logicalWidth;
            logicalWidth = logicalHeight;
            logicalHeight = temporary;
        }

        return {
            width: logicalWidth,
            height: logicalHeight
        };
    }

    function normalizeMonitor(monitor) {
        const width = Number(monitor.width || 0);
        const height = Number(monitor.height || 0);
        const scale = Number(monitor.scale || 1);
        const transform = Number(monitor.transform || 0);
        const logical = logicalSize(width, height, scale, transform);

        return {
            output: String(monitor.name || ""),
            description: String(monitor.description || ""),
            make: String(monitor.make || ""),
            model: String(monitor.model || ""),
            serial: String(monitor.serial || ""),

            width: width,
            height: height,
            logicalWidth: logical.width,
            logicalHeight: logical.height,
            refreshRate: Number(monitor.refreshRate || 0),

            x: Number(monitor.x || 0),
            y: Number(monitor.y || 0),
            scale: scale,
            transform: transform,

            focused: Boolean(monitor.focused),
            disabled: Boolean(monitor.disabled),

            activeWorkspaceId:
                monitor.activeWorkspace && monitor.activeWorkspace.id !== undefined
                    ? Number(monitor.activeWorkspace.id)
                    : 0,
            activeWorkspaceName:
                monitor.activeWorkspace && monitor.activeWorkspace.name !== undefined
                    ? String(monitor.activeWorkspace.name)
                    : "",

            availableModes:
                Array.isArray(monitor.availableModes)
                    ? monitor.availableModes
                    : []
        };
    }

    function refresh(): void {
        root.loading = true;
        root.errorMessage = "";

        // Live Quickshell state + detailed Hyprland JSON snapshot.
        Hyprland.refreshMonitors();
        queryProcess.exec(["hyprctl", "-j", "monitors", "all"]);
    }

    function consumeSnapshot(rawText): void {
        let data;

        try {
            data = JSON.parse(rawText);
        } catch (error) {
            root.errorMessage = "Invalid JSON from hyprctl: " + error;
            return;
        }

        if (!Array.isArray(data)) {
            root.errorMessage = "Unexpected monitor payload from hyprctl";
            return;
        }

        const normalized = [];

        for (let i = 0; i < data.length; ++i)
            normalized.push(root.normalizeMonitor(data[i]));

        // Replace the complete snapshot atomically so UI consumers never see
        // a half-updated monitor topology.
        root.monitors = normalized;
        root.lastRefresh = new Date().toLocaleTimeString();
        root.refreshed();
    }

    Process {
        id: queryProcess

        stdout: StdioCollector {
            id: stdoutCollector
            onStreamFinished: root.consumeSnapshot(this.text)
        }

        stderr: StdioCollector {
            id: stderrCollector
        }

        onExited: (exitCode, exitStatus) => {
            root.loading = false;

            if (exitCode !== 0) {
                const details = stderrCollector.text.trim();

                root.errorMessage =
                    "hyprctl exited with code " + exitCode
                    + (details.length > 0 ? ": " + details : "");
            }
        }
    }

    Timer {
        id: refreshDebounce
        interval: 150
        repeat: false
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            switch (event.name) {
            case "monitoradded":
            case "monitoraddedv2":
            case "monitorremoved":
            case "monitorremovedv2":
            case "configreloaded":
                refreshDebounce.restart();
                break;
            }
        }
    }

    Component.onCompleted: root.refresh()
}
