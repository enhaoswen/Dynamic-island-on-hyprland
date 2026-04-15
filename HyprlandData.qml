import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    visible: false

    property var windowList: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var activeWorkspace: null
    property var monitors: []
    property bool clientsReady: false
    property bool monitorsReady: false
    property bool workspacesReady: false
    property bool activeWorkspaceReady: false
    readonly property bool ready: clientsReady && monitorsReady && workspacesReady && activeWorkspaceReady

    function parseJson(text, fallback) {
        const source = (text || "").trim();
        if (!source)
            return fallback;

        try {
            return JSON.parse(source);
        } catch (error) {
            console.log("[HyprlandData] Failed to parse hyprctl output:", error);
            return fallback;
        }
    }

    function rebuildWindowIndex() {
        const byAddress = {};
        for (let index = 0; index < root.windowList.length; index++)
            byAddress[String(root.windowList[index].address || "").toLowerCase()] = root.windowList[index];
        root.windowByAddress = byAddress;
    }

    function queueRefresh() {
        refreshTimer.restart();
    }

    function updateAll() {
        if (!clientsProcess.running)
            clientsProcess.running = true;
        if (!monitorsProcess.running)
            monitorsProcess.running = true;
        if (!workspacesProcess.running)
            workspacesProcess.running = true;
        if (!activeWorkspaceProcess.running)
            activeWorkspaceProcess.running = true;
    }

    Component.onCompleted: updateAll()

    Timer {
        id: refreshTimer

        interval: 40
        repeat: false

        onTriggered: root.updateAll()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (!event || ["openlayer", "closelayer", "screencast"].indexOf(event.name) !== -1)
                return;

            root.queueRefresh();
        }
    }

    Process {
        id: clientsProcess

        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector

            onStreamFinished: {
                root.windowList = root.parseJson(clientsCollector.text, []);
                root.rebuildWindowIndex();
                root.clientsReady = true;
            }
        }
    }

    Process {
        id: monitorsProcess

        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector

            onStreamFinished: {
                root.monitors = root.parseJson(monitorsCollector.text, []);
                root.monitorsReady = true;
            }
        }
    }

    Process {
        id: workspacesProcess

        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector

            onStreamFinished: {
                const rawWorkspaces = root.parseJson(workspacesCollector.text, []);
                const filtered = rawWorkspaces.filter((workspace) => workspace.id >= 1 && workspace.id <= 100);
                root.workspaces = filtered;
                root.workspacesReady = true;
            }
        }
    }

    Process {
        id: activeWorkspaceProcess

        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector

            onStreamFinished: {
                root.activeWorkspace = root.parseJson(activeWorkspaceCollector.text, null);
                root.activeWorkspaceReady = true;
            }
        }
    }
}
