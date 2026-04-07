pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: root

    UserConfig {
        id: userConfig
    }

    required property var screen
    required property var hyprlandData

    property bool showCondition: false
    property string textFontFamily: userConfig.textFontFamily
    property string heroFontFamily: userConfig.heroFontFamily
    property string wallpaperPath: "/home/dan/.config/hypr/wallpaper.png"
    property real windowCornerRadius: 15
    property real scale: 0.18
    property int rows: 2
    property int columns: 5
    property bool orderRightLeft: false
    property bool orderBottomUp: false
    property bool centerIcons: true

    readonly property real wallpaperCacheScaleMultiplier: 1.75
    readonly property int cachedWallpaperWidth: Math.max(1, Math.round(workspaceImplicitWidth * wallpaperCacheScaleMultiplier))
    readonly property int cachedWallpaperHeight: Math.max(1, Math.round(workspaceImplicitHeight * wallpaperCacheScaleMultiplier))

    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
    readonly property var monitorData: findMonitorData(monitor ? monitor.id : -1)
    readonly property int workspacesShown: rows * columns
    readonly property int effectiveActiveWorkspaceId: {
        const workspaceId = monitor && monitor.activeWorkspace
            ? monitor.activeWorkspace.id
            : (hyprlandData && hyprlandData.activeWorkspace ? hyprlandData.activeWorkspace.id : 1);
        return Math.max(1, Math.min(100, workspaceId || 1));
    }
    readonly property int workspaceGroup: Math.floor((effectiveActiveWorkspaceId - 1) / workspacesShown)
    readonly property real workspaceSpacing: 6
    readonly property real outerPadding: 14
    readonly property real largeWorkspaceRadius: 30
    readonly property real smallWorkspaceRadius: 16
    readonly property int workspaceOverviewCellAcceptedButtons: userConfig.mouseButtonsMask(userConfig.workspaceOverviewWorkspaceActivateButton)
    readonly property int workspaceOverviewWindowAcceptedButtons: userConfig.mouseButtonsMask([
        userConfig.workspaceOverviewWindowDragButton,
        userConfig.workspaceOverviewWindowFocusButton,
        userConfig.workspaceOverviewWindowCloseButton
    ])
    readonly property color activeBorderColor: "#73d4ff"
    readonly property color cardColor: "#ee17181b"
    readonly property color cardBorderColor: "#33ffffff"
    readonly property color workspaceColor: "#ff202226"
    readonly property color workspaceHoverColor: "#ff2b2d34"
    readonly property color workspaceBorderHoverColor: "#66d9f6ff"
    readonly property real workspaceImplicitWidth: {
        const reserved = monitorData && monitorData.reserved ? monitorData.reserved : [0, 0, 0, 0];
        const screenWidth = monitor ? monitor.width : (screen ? screen.width : 1920);
        const screenHeight = monitor ? monitor.height : (screen ? screen.height : 1080);
        const transform = monitorData && monitorData.transform !== undefined ? monitorData.transform : 0;
        const monitorScale = monitor && monitor.scale ? monitor.scale : 1;
        const baseWidth = transform % 2 === 1 ? screenHeight : screenWidth;
        return Math.max(180, (baseWidth - reserved[0] - reserved[2]) * scale / monitorScale);
    }
    readonly property real workspaceImplicitHeight: {
        const reserved = monitorData && monitorData.reserved ? monitorData.reserved : [0, 0, 0, 0];
        const screenWidth = monitor ? monitor.width : (screen ? screen.width : 1920);
        const screenHeight = monitor ? monitor.height : (screen ? screen.height : 1080);
        const transform = monitorData && monitorData.transform !== undefined ? monitorData.transform : 0;
        const monitorScale = monitor && monitor.scale ? monitor.scale : 1;
        const baseHeight = transform % 2 === 1 ? screenWidth : screenHeight;
        return Math.max(120, (baseHeight - reserved[1] - reserved[3]) * scale / monitorScale);
    }

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    signal closeRequested()

    visible: opacity > 0
    opacity: showCondition ? 1 : 0
    width: implicitWidth
    height: implicitHeight
    implicitWidth: overviewCard.implicitWidth
    implicitHeight: overviewCard.implicitHeight

    function findMonitorData(monitorId) {
        const monitors = hyprlandData && hyprlandData.monitors ? hyprlandData.monitors : [];
        for (let index = 0; index < monitors.length; index++) {
            if (monitors[index].id === monitorId)
                return monitors[index];
        }
        return null;
    }

    function getWsRow(workspaceId) {
        const normalRow = Math.floor((workspaceId - 1) / columns) % rows;
        return orderBottomUp ? rows - normalRow - 1 : normalRow;
    }

    function getWsColumn(workspaceId) {
        const normalColumn = (workspaceId - 1) % columns;
        return orderRightLeft ? columns - normalColumn - 1 : normalColumn;
    }

    function getWsInCell(rowIndex, columnIndex) {
        const workspaceRow = orderBottomUp ? rows - rowIndex - 1 : rowIndex;
        const workspaceColumn = orderRightLeft ? columns - columnIndex - 1 : columnIndex;
        return workspaceRow * columns + workspaceColumn + 1;
    }

    function workspaceAtPoint(pointX, pointY) {
        const cellSpanX = workspaceImplicitWidth + workspaceSpacing;
        const cellSpanY = workspaceImplicitHeight + workspaceSpacing;
        const columnIndex = Math.floor(pointX / cellSpanX);
        const rowIndex = Math.floor(pointY / cellSpanY);
        const localX = pointX - columnIndex * cellSpanX;
        const localY = pointY - rowIndex * cellSpanY;

        if (columnIndex < 0 || columnIndex >= columns || rowIndex < 0 || rowIndex >= rows)
            return -1;
        if (localX < 0 || localY < 0 || localX > workspaceImplicitWidth || localY > workspaceImplicitHeight)
            return -1;

        return workspaceGroup * workspacesShown + getWsInCell(rowIndex, columnIndex);
    }

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 180 : 120
            easing.type: Easing.InOutQuad
        }
    }

    Rectangle {
        id: overviewCard

        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        implicitWidth: workspaceStage.implicitWidth + root.outerPadding * 2
        implicitHeight: workspaceStage.implicitHeight + root.outerPadding * 2
        radius: root.largeWorkspaceRadius + root.outerPadding
        color: root.cardColor
        border.width: 1
        border.color: root.cardBorderColor

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.width: 1
            border.color: "#12ffffff"
        }

        Item {
            id: workspaceStage

            anchors.centerIn: parent
            width: implicitWidth
            height: implicitHeight
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Column {
                id: workspaceColumnLayout

                width: implicitWidth
                height: implicitHeight
                spacing: root.workspaceSpacing

                Repeater {
                    model: root.rows

                    delegate: Row {
                        id: workspaceRow

                        required property int index

                        width: implicitWidth
                        height: implicitHeight
                        spacing: root.workspaceSpacing

                        Repeater {
                            model: root.columns

                            delegate: Rectangle {
                                id: workspaceCell

                                required property int index

                                property int columnIndex: index
                                property int workspaceValue: root.workspaceGroup * root.workspacesShown + root.getWsInCell(workspaceRow.index, columnIndex)
                                property bool hoveredWhileDragging: root.draggingTargetWorkspace === workspaceValue
                                    && root.draggingFromWorkspace !== workspaceValue
                                property bool workspaceAtLeft: columnIndex === 0
                                property bool workspaceAtRight: columnIndex === root.columns - 1
                                property bool workspaceAtTop: workspaceRow.index === 0
                                property bool workspaceAtBottom: workspaceRow.index === root.rows - 1

                                implicitWidth: root.workspaceImplicitWidth
                                implicitHeight: root.workspaceImplicitHeight
                                width: implicitWidth
                                height: implicitHeight
                                clip: true
                                color: hoveredWhileDragging ? root.workspaceHoverColor : root.workspaceColor
                                topLeftRadius: workspaceAtLeft && workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                                topRightRadius: workspaceAtRight && workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                                bottomLeftRadius: workspaceAtLeft && workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                                bottomRightRadius: workspaceAtRight && workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                                border.width: hoveredWhileDragging ? 2 : 1
                                border.color: hoveredWhileDragging ? root.workspaceBorderHoverColor : "#1effffff"

                                ClippingRectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    color: "transparent"
                                    contentUnderBorder: true
                                    antialiasing: true
                                    topLeftRadius: Math.max(workspaceCell.topLeftRadius - 1, 0)
                                    topRightRadius: Math.max(workspaceCell.topRightRadius - 1, 0)
                                    bottomLeftRadius: Math.max(workspaceCell.bottomLeftRadius - 1, 0)
                                    bottomRightRadius: Math.max(workspaceCell.bottomRightRadius - 1, 0)

                                    Image {
                                        anchors.fill: parent
                                        source: root.wallpaperPath
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: root.cachedWallpaperWidth
                                        sourceSize.height: root.cachedWallpaperHeight
                                        asynchronous: true
                                        cache: false
                                        opacity: 0.92
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: hoveredWhileDragging ? "#280d131a" : "#42070b10"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: root.workspaceOverviewCellAcceptedButtons

                                    onPressed: (mouse) => {
                                        if (mouse.button !== userConfig.mouseButton(userConfig.workspaceOverviewWorkspaceActivateButton))
                                            return;
                                        if (root.draggingFromWorkspace !== -1)
                                            return;

                                        root.closeRequested();
                                        Hyprland.dispatch("workspace " + workspaceCell.workspaceValue);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: windowSpace

                anchors.fill: workspaceColumnLayout

                Repeater {
                    model: ScriptModel {
                        values: {
                            const values = ToplevelManager.toplevels && ToplevelManager.toplevels.values
                                ? ToplevelManager.toplevels.values
                                : [];

                            return values.filter((toplevel) => {
                                const rawAddress = toplevel && toplevel.HyprlandToplevel
                                    ? String(toplevel.HyprlandToplevel.address || "")
                                    : "";
                                const address = rawAddress.startsWith("0x")
                                    ? rawAddress.toLowerCase()
                                    : ("0x" + rawAddress).toLowerCase();
                                const windowData = root.hyprlandData && root.hyprlandData.windowByAddress
                                    ? root.hyprlandData.windowByAddress[address]
                                    : null;
                                const workspaceId = windowData && windowData.workspace ? windowData.workspace.id : -1;
                                return workspaceId > root.workspaceGroup * root.workspacesShown
                                    && workspaceId <= (root.workspaceGroup + 1) * root.workspacesShown;
                            });
                        }
                    }

                    delegate: WorkspaceOverviewWindow {
                        id: windowTile

                        required property var modelData

                        readonly property string address: {
                            const rawAddress = modelData && modelData.HyprlandToplevel
                                ? String(modelData.HyprlandToplevel.address || "")
                                : "";
                            return rawAddress.startsWith("0x")
                                ? rawAddress.toLowerCase()
                                : ("0x" + rawAddress).toLowerCase();
                        }
                        readonly property int workspaceId: windowData && windowData.workspace ? windowData.workspace.id : -1
                        property int monitorId: windowData && windowData.monitor !== undefined ? windowData.monitor : -1
                        property var sourceMonitorData: root.findMonitorData(monitorId)
                        property int workspaceRowIndex: root.getWsRow(workspaceId > 0 ? workspaceId : 1)
                        property int workspaceColumnIndex: root.getWsColumn(workspaceId > 0 ? workspaceId : 1)
                        property real workspaceOffsetX: (root.workspaceImplicitWidth + root.workspaceSpacing) * workspaceColumnIndex
                        property real workspaceOffsetY: (root.workspaceImplicitHeight + root.workspaceSpacing) * workspaceRowIndex
                        property real distanceFromLeftEdge: Math.max(initX - workspaceOffsetX, 0)
                        property real distanceFromRightEdge: Math.max(root.workspaceImplicitWidth - ((initX - workspaceOffsetX) + targetWindowWidth), 0)
                        property real distanceFromTopEdge: Math.max(initY - workspaceOffsetY, 0)
                        property real distanceFromBottomEdge: Math.max(root.workspaceImplicitHeight - ((initY - workspaceOffsetY) + targetWindowHeight), 0)
                        property bool workspaceAtLeft: workspaceColumnIndex === 0
                        property bool workspaceAtRight: workspaceColumnIndex === root.columns - 1
                        property bool workspaceAtTop: workspaceRowIndex === 0
                        property bool workspaceAtBottom: workspaceRowIndex === root.rows - 1

                        windowData: root.hyprlandData && root.hyprlandData.windowByAddress
                            ? root.hyprlandData.windowByAddress[address]
                            : null
                        toplevel: modelData
                        visible: workspaceId > root.workspaceGroup * root.workspacesShown
                            && workspaceId <= (root.workspaceGroup + 1) * root.workspacesShown
                        scale: root.scale
                        monitorData: sourceMonitorData ? sourceMonitorData : root.monitorData
                        widgetMonitor: root.monitorData
                        xOffset: workspaceOffsetX
                        yOffset: workspaceOffsetY
                        centerIcons: root.centerIcons
                        draggingActive: Drag.active
                        pressed: dragArea.pressed
                        hovered: dragArea.containsMouse
                        topLeftRadius: Math.max((workspaceAtLeft && workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - Math.max(distanceFromLeftEdge, distanceFromTopEdge), root.windowCornerRadius)
                        topRightRadius: Math.max((workspaceAtRight && workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - Math.max(distanceFromRightEdge, distanceFromTopEdge), root.windowCornerRadius)
                        bottomLeftRadius: Math.max((workspaceAtLeft && workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - Math.max(distanceFromLeftEdge, distanceFromBottomEdge), root.windowCornerRadius)
                        bottomRightRadius: Math.max((workspaceAtRight && workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - Math.max(distanceFromRightEdge, distanceFromBottomEdge), root.windowCornerRadius)
                        z: Drag.active ? 99999 : (windowData && windowData.fullscreen ? 30 : 20) + (windowData && windowData.floating ? 5 : 0)

                        Timer {
                            id: restoreTilePosition

                            interval: 80
                            repeat: false

                            onTriggered: {
                                windowTile.x = Math.round(windowTile.initX);
                                windowTile.y = Math.round(windowTile.initY);
                            }
                        }

                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2

                        MouseArea {
                            id: dragArea

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: root.workspaceOverviewWindowAcceptedButtons
                            drag.target: draggingWindow ? parent : null

                            property bool movedWindow: false
                            property bool draggingWindow: false

                            onPressed: (mouse) => {
                                if (mouse.button !== userConfig.mouseButton(userConfig.workspaceOverviewWindowDragButton))
                                    return;

                                movedWindow = false;
                                draggingWindow = true;
                                root.draggingFromWorkspace = windowTile.windowData && windowTile.windowData.workspace
                                    ? windowTile.windowData.workspace.id
                                    : -1;
                                windowTile.Drag.active = true;
                                windowTile.Drag.source = windowTile;
                                windowTile.Drag.hotSpot.x = mouse.x;
                                windowTile.Drag.hotSpot.y = mouse.y;
                            }

                            onPositionChanged: {
                                if (!draggingWindow || !(pressedButtons & userConfig.mouseButton(userConfig.workspaceOverviewWindowDragButton)))
                                    return;

                                root.draggingTargetWorkspace = root.workspaceAtPoint(
                                    windowTile.x + windowTile.width / 2,
                                    windowTile.y + windowTile.height / 2
                                );

                                if (!movedWindow) {
                                    movedWindow = Math.abs(windowTile.x - windowTile.initX) > 4
                                        || Math.abs(windowTile.y - windowTile.initY) > 4;
                                }
                            }

                            onReleased: {
                                if (!draggingWindow)
                                    return;

                                draggingWindow = false;
                                const targetWorkspace = root.workspaceAtPoint(
                                    windowTile.x + windowTile.width / 2,
                                    windowTile.y + windowTile.height / 2
                                );

                                windowTile.Drag.active = false;
                                root.draggingFromWorkspace = -1;
                                root.draggingTargetWorkspace = -1;

                                if (targetWorkspace !== -1
                                        && windowTile.windowData
                                        && windowTile.windowData.workspace
                                        && targetWorkspace !== windowTile.windowData.workspace.id) {
                                    Hyprland.dispatch("movetoworkspacesilent " + targetWorkspace + ", address:" + windowTile.windowData.address);
                                    restoreTilePosition.restart();
                                } else if (windowTile.windowData && windowTile.windowData.floating) {
                                    const percentageX = Math.round((windowTile.x - windowTile.workspaceOffsetX) / root.workspaceImplicitWidth * 100);
                                    const percentageY = Math.round((windowTile.y - windowTile.workspaceOffsetY) / root.workspaceImplicitHeight * 100);
                                    Hyprland.dispatch("movewindowpixel exact " + percentageX + "% " + percentageY + "%, address:" + windowTile.windowData.address);
                                } else {
                                    restoreTilePosition.restart();
                                }
                            }

                            onCanceled: {
                                draggingWindow = false;
                                windowTile.Drag.active = false;
                                root.draggingFromWorkspace = -1;
                                root.draggingTargetWorkspace = -1;
                            }

                            onClicked: (mouse) => {
                                if (!windowTile.windowData)
                                    return;
                                if (movedWindow) {
                                    movedWindow = false;
                                    return;
                                }

                                if (mouse.button === userConfig.mouseButton(userConfig.workspaceOverviewWindowFocusButton)) {
                                    root.closeRequested();
                                    Hyprland.dispatch("focuswindow address:" + windowTile.windowData.address);
                                    mouse.accepted = true;
                                } else if (mouse.button === userConfig.mouseButton(userConfig.workspaceOverviewWindowCloseButton)) {
                                    Hyprland.dispatch("closewindow address:" + windowTile.windowData.address);
                                    mouse.accepted = true;
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: focusedWorkspaceIndicator

                    property int rowIndex: root.getWsRow(root.effectiveActiveWorkspaceId)
                    property int columnIndex: root.getWsColumn(root.effectiveActiveWorkspaceId)
                    property bool workspaceAtLeft: columnIndex === 0
                    property bool workspaceAtRight: columnIndex === root.columns - 1
                    property bool workspaceAtTop: rowIndex === 0
                    property bool workspaceAtBottom: rowIndex === root.rows - 1

                    x: (root.workspaceImplicitWidth + root.workspaceSpacing) * columnIndex
                    y: (root.workspaceImplicitHeight + root.workspaceSpacing) * rowIndex
                    width: root.workspaceImplicitWidth
                    height: root.workspaceImplicitHeight
                    color: "transparent"
                    border.width: 2
                    border.color: root.activeBorderColor
                    topLeftRadius: workspaceAtLeft && workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    topRightRadius: workspaceAtRight && workspaceAtTop ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    bottomLeftRadius: workspaceAtLeft && workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                    bottomRightRadius: workspaceAtRight && workspaceAtBottom ? root.largeWorkspaceRadius : root.smallWorkspaceRadius

                    Behavior on x {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
