import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import IslandBackend

PanelWindow {
    id: root
    property var shellRootController: null
    property string overviewPhase: "closed"
    readonly property bool overviewPreparing: overviewPhase === "preparing"
    readonly property bool overviewVisible: overviewPhase === "opening" || overviewPhase === "open"
    readonly property bool overviewContentVisible: overviewPhase === "open"
    readonly property bool overviewLoaderActive: overviewPhase !== "closed"
    readonly property var hyprMonitor: screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
    readonly property string hyprMonitorName: hyprMonitor && hyprMonitor.name ? String(hyprMonitor.name) : ""
    readonly property bool monitorFocused: hyprMonitor ? hyprMonitor.focused : false
    readonly property int currentMonitorWorkspaceId: hyprMonitor && hyprMonitor.activeWorkspace
        ? hyprMonitor.activeWorkspace.id
        : 1

    UserConfig {
        id: userConfig
    }

    color: "transparent"
    anchors { top: true; left: true; right: true }
    mask: Region { item: mainCapsule }
    implicitHeight: (root.overviewVisible || root.overviewPreparing)
        ? Math.max(360, Math.ceil(4 + root.overviewCapsuleHeight + 8))
        : 360
    exclusiveZone: 45
    aboveWindows: true
    focusable: root.overviewVisible && root.monitorFocused
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.overviewVisible && root.monitorFocused
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None
    readonly property string iconFontFamily: userConfig.iconFontFamily
    readonly property string textFontFamily: userConfig.textFontFamily
    readonly property string heroFontFamily: userConfig.heroFontFamily
    readonly property string timeFontFamily: userConfig.timeFontFamily
    readonly property int dynamicIslandAcceptedButtons: userConfig.mouseButtonsMask([
        userConfig.dynamicIslandSwipeButton,
        userConfig.dynamicIslandPrimaryButton,
        userConfig.dynamicIslandSecondaryButton
    ])
    readonly property real overviewWallpaperScale: 0.18
    readonly property real overviewWallpaperCacheScaleMultiplier: 1.75
    readonly property int overviewWallpaperTargetWidth: {
        const screenWidth = hyprMonitor ? hyprMonitor.width : (screen ? screen.width : 1920);
        const monitorScale = hyprMonitor && hyprMonitor.scale ? hyprMonitor.scale : 1;
        const workspaceWidth = Math.max(180, screenWidth * overviewWallpaperScale / monitorScale);
        return Math.max(1, Math.round(workspaceWidth * overviewWallpaperCacheScaleMultiplier));
    }
    readonly property int overviewWallpaperTargetHeight: {
        const screenHeight = hyprMonitor ? hyprMonitor.height : (screen ? screen.height : 1080);
        const monitorScale = hyprMonitor && hyprMonitor.scale ? hyprMonitor.scale : 1;
        const workspaceHeight = Math.max(120, screenHeight * overviewWallpaperScale / monitorScale);
        return Math.max(1, Math.round(workspaceHeight * overviewWallpaperCacheScaleMultiplier));
    }
    readonly property real overviewCapsuleWidth: islandContainer.overviewView ? islandContainer.overviewView.width : 760
    readonly property real overviewCapsuleHeight: islandContainer.overviewView ? islandContainer.overviewView.height : 308
    readonly property real overviewCapsuleRadius: islandContainer.overviewView
        ? islandContainer.overviewView.largeWorkspaceRadius + islandContainer.overviewView.outerPadding
        : 44
    readonly property color overviewCapsuleColor: islandContainer.overviewView
        ? islandContainer.overviewView.cardColor
        : "#ee17181b"
    readonly property color overviewCapsuleBorderColor: islandContainer.overviewView
        ? islandContainer.overviewView.cardBorderColor
        : "#33ffffff"

    function beginOverviewOpening() {
        if (!overviewPreparing) return;
        overviewPhase = "opening";
        overviewRevealTimer.restart();
    }

    function openOverview() {
        if (overviewLoaderActive) return;
        overviewPhase = "preparing";
        if (overviewLoader.status === Loader.Ready) {
            beginOverviewOpening();
        }
    }

    function closeOverview() {
        if (!overviewLoaderActive) return;
        overviewRevealTimer.stop();
        islandContainer.restoreRestingCapsule(true);
        overviewPhase = "closed";
    }

    function closeOverviewEverywhere() {
        if (shellRootController && shellRootController.closeOverviewAll) {
            shellRootController.closeOverviewAll();
            return;
        }

        closeOverview();
    }

    function openOverviewEverywhere() {
        if (shellRootController && shellRootController.openOverviewAll) {
            shellRootController.openOverviewAll();
            return;
        }

        openOverview();
    }

    function toggleOverviewEverywhere() {
        if (shellRootController && shellRootController.toggleOverviewAll) {
            shellRootController.toggleOverviewAll();
            return;
        }

        if (overviewLoaderActive)
            closeOverviewEverywhere();
        else
            openOverviewEverywhere();
    }

    function normalizeWorkspaceId(rawValue) {
        const parsed = parseInt(String(rawValue === undefined || rawValue === null ? "" : rawValue), 10);
        return isNaN(parsed) ? -1 : parsed;
    }

    function syncWorkspaceState() {
        if (currentMonitorWorkspaceId >= 1)
            islandContainer.currentWs = currentMonitorWorkspaceId;
    }

    function showWorkspaceForThisMonitor(workspaceId) {
        const targetWorkspaceId = normalizeWorkspaceId(workspaceId);
        if (targetWorkspaceId >= 1)
            islandContainer.showWorkspaceCapsule(targetWorkspaceId);
    }

    function prewarmWallpaperCache() {
        overviewWallpaperCache.refreshNow();
    }

    function handleWorkspaceEvent(event) {
        if (!event)
            return;
        if (hyprMonitorName === "")
            return;

        if (event.name === "workspacev2" || event.name === "workspace") {
            const args = event.parse(event.name === "workspacev2" ? 2 : 1);
            const targetWorkspaceId = normalizeWorkspaceId(args.length > 0 ? args[0] : "");
            if (targetWorkspaceId < 1)
                return;

            Qt.callLater(() => {
                const focusedWorkspace = Hyprland.focusedWorkspace;
                if (!root.monitorFocused || !focusedWorkspace)
                    return;
                if (focusedWorkspace.id !== targetWorkspaceId)
                    return;

                root.showWorkspaceForThisMonitor(targetWorkspaceId);
            });
            return;
        }

        if (event.name === "focusedmonv2" || event.name === "focusedmon") {
            const args = event.parse(2);
            const targetMonitorName = args.length > 0 ? String(args[0]) : "";
            const targetWorkspaceId = normalizeWorkspaceId(args.length > 1 ? args[1] : "");
            if (targetWorkspaceId < 1)
                return;
            if (hyprMonitorName !== "" && targetMonitorName !== hyprMonitorName)
                return;

            // `focusedmonv2` covers jumping to a workspace that already lives on another monitor.
            showWorkspaceForThisMonitor(targetWorkspaceId);
        }
    }

    onOverviewVisibleChanged: {
        if (overviewVisible && monitorFocused) overviewFocusTimer.restart();
    }
    onMonitorFocusedChanged: {
        if (overviewVisible && monitorFocused) overviewFocusTimer.restart();
    }
    onHyprMonitorChanged: syncWorkspaceState()

    Timer {
        id: overviewFocusTimer
        interval: 0
        repeat: false
        onTriggered: islandContainer.forceActiveFocus()
    }

    Timer {
        id: overviewRevealTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (root.overviewPhase === "opening") root.overviewPhase = "open";
        }
    }

    WallpaperThumbnailCache {
        id: overviewWallpaperCache

        sourcePath: userConfig.wallpaperPath
        targetWidth: root.overviewWallpaperTargetWidth
        targetHeight: root.overviewWallpaperTargetHeight
    }

    // --- 基础时钟引擎 ---
    QtObject {
        id: timeObj
        property string currentTime: "00:00"
        property string currentDateLabel: "Mon, Jan 01"
        readonly property var monthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        readonly property var dayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        function padTwoDigits(value) {
            return value < 10 ? "0" + value : String(value);
        }

        function formatDateLabel(now) {
            return dayNames[now.getDay()]
                + ", "
                + monthNames[now.getMonth()]
                + " "
                + padTwoDigits(now.getDate());
        }
    }
    Timer {
        id: clockTimer
        running: true; repeat: true; triggeredOnStart: true
        interval: 1000 
        onTriggered: {
            let now = new Date();
            timeObj.currentTime = Qt.formatTime(now, "hh:mm ap");
            timeObj.currentDateLabel = timeObj.formatDateLabel(now);
            interval = (60 - now.getSeconds()) * 1000 - now.getMilliseconds();
        }
    }

    // --- 灵动岛主容器与全局状态 ---
    FocusScope {
        id: islandContainer
        anchors.fill: parent
        focus: root.overviewVisible && root.monitorFocused

        property string islandState: "normal"
        property string splitIcon: userConfig.statusIcons["default"]
        property real osdProgress: -1.0
        property bool osdProgressAnimationEnabled: true
        property string osdCustomText: ""
        property int currentWs: root.currentMonitorWorkspaceId > 0 ? root.currentMonitorWorkspaceId : 1
        property int batteryCapacity: SysBackend.batteryCapacity
        property bool isCharging: SysBackend.batteryStatus === "Charging" || SysBackend.batteryStatus === "Full"
        property real currentVolume: -1
        property bool isMuted: false
        property real currentBrightness: -1
        property real currentCpuUsage: -1
        property real currentRamUsage: -1
        property string notificationAppName: ""
        property string notificationSummary: ""
        property string notificationBody: ""
        property real _lastCpuTotal: -1
        property real _lastCpuIdle: -1
        property var cavaLevels: [0, 0, 0, 0, 0, 0, 0, 0]
        property string _lastChargeStatus: SysBackend.batteryStatus
        property string _pendingVolType: ""
        property real   _pendingVolVal:  0.0
        property string _lastVolType: ""
        property real   _lastVolVal:  -1.0
        property bool btJustConnected: false
        property real   _pendingBlVal:  0.0
        property real swipeTransitionProgress: 0
        property string workspaceOriginSide: "none"
        property string splitOriginSide: "none"
        property string restingState: "normal"
        property bool expandedByPlayerAutoOpen: false
        property real customCapsuleWidth: 220
        property real lyricsCapsuleWidth: 220
        property bool sideSwipeSettling: false
        readonly property int defaultAutoHideInterval: 1250
        readonly property int notificationAutoHideInterval: 4200
        readonly property int swipeAnimationDuration: 220
        readonly property bool blocksTransientSplit: islandState === "expanded"
            || islandState === "control_center"
            || islandState === "notification"
        readonly property bool splitShowsProgress: islandState === "split" && osdProgress >= 0
        readonly property bool splitShowsText: islandState === "split" && osdProgress < 0 && osdCustomText !== ""
        readonly property bool splitShowsIconOnly: islandState === "split" && osdProgress < 0 && osdCustomText === ""
        readonly property bool splitUsesExtendedLayout: splitShowsProgress || splitShowsText
        readonly property real splitCapsuleWidth: splitShowsProgress ? 248 : (splitShowsText ? 220 : 140)
        readonly property bool canShowSideSwipe: islandState === "normal"
            || islandState === "custom"
            || islandState === "lyrics"
            || (islandState === "long_capsule" && workspaceOriginSide === "none")
        readonly property real rightSwipeProgress: Math.max(0, swipeTransitionProgress)
        readonly property var configuredLeftSwipeIds: buildNormalizedSwipeItemIds(userConfig.dynamicIslandLeftSwipeItems)
        readonly property bool usesSystemStatsModule: configuredLeftSwipeIds.indexOf("cpu") !== -1
            || configuredLeftSwipeIds.indexOf("ram") !== -1
        readonly property bool usesCavaModule: configuredLeftSwipeIds.indexOf("cava") !== -1
        readonly property var customLeftItems: buildCustomSwipeItems(userConfig.dynamicIslandLeftSwipeItems)
        readonly property bool hasCustomLeftItems: customLeftItems.length > 0
        readonly property bool customSwipeVisible: !root.overviewVisible
            && hasCustomLeftItems
            && (
                capsuleMouseArea.sideSwipeInteractive
                ? swipeTransitionProgress < 0
                : (
                    islandState === "custom"
                    || (islandState === "normal" && swipeTransitionProgress < 0)
                    || (islandState === "split" && splitOriginSide === "left")
                    || (islandState === "long_capsule"
                        && (workspaceOriginSide === "left" || swipeTransitionProgress < 0))
                )
            )
        readonly property bool lyricsSwipeVisible: !root.overviewVisible && (
            capsuleMouseArea.sideSwipeInteractive
            ? swipeTransitionProgress >= 0
            : (
                islandState === "lyrics"
                || (islandState === "normal" && swipeTransitionProgress >= 0)
                || (islandState === "split" && splitOriginSide === "right")
                || (islandState === "long_capsule"
                    && (workspaceOriginSide === "right" || swipeTransitionProgress > 0))
            )
        )
        readonly property bool expandedLayerVisible: !root.overviewVisible && islandState === "expanded"
        readonly property bool notificationLayerVisible: !root.overviewVisible && islandState === "notification"
        readonly property bool controlCenterLayerVisible: !root.overviewVisible && islandState === "control_center"
        readonly property string lyricsDisplayText: lyricsBridge.displayText
        readonly property var overviewView: overviewLoader.item && overviewLoader.item.overviewView
            ? overviewLoader.item.overviewView
            : null

        onCustomLeftItemsChanged: {
            if (restingState === "custom" && !hasCustomLeftItems) {
                restingState = "normal";

                if (islandState === "custom"
                        || (islandState === "split" && splitOriginSide === "left")
                        || (islandState === "long_capsule" && workspaceOriginSide === "left")) {
                    restoreRestingCapsule(true);
                } else {
                    applyRestingVisuals();
                }
            } else if (restingState === "custom") {
                syncCustomCapsuleWidth();
            }
        }

        Behavior on osdProgress {
            enabled: islandContainer.osdProgressAnimationEnabled

            SmoothedAnimation { velocity: 1.2; duration: 180; easing.type: Easing.InOutQuad }
        }
        Behavior on swipeTransitionProgress {
            NumberAnimation {
                duration: capsuleMouseArea.sideSwipeInteractive ? 0 : islandContainer.swipeAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        Keys.onPressed: (event) => {
            if (!root.overviewVisible) return;

            if (userConfig.overviewCloseKey && event.key === userConfig.overviewCloseKey) {
                root.closeOverviewEverywhere();
                event.accepted = true;
            } else if (userConfig.overviewPreviousWorkspaceKey && event.key === userConfig.overviewPreviousWorkspaceKey) {
                Hyprland.dispatch("workspace r-1");
                event.accepted = true;
            } else if (userConfig.overviewNextWorkspaceKey && event.key === userConfig.overviewNextWorkspaceKey) {
                Hyprland.dispatch("workspace r+1");
                event.accepted = true;
            }
        }

        function handleConfiguredClickAction(actionName) {
            switch (actionName) {
            case "":
            case "none":
                return;
            case "toggleExpandedPlayer":
                if (islandState === "expanded") {
                    autoHideTimer.stop();
                    smartRestoreState();
                } else {
                    showExpandedPlayer(false);
                }
                return;
            case "openExpandedPlayer":
                showExpandedPlayer(false);
                return;
            case "closeExpandedPlayer":
                if (islandState === "expanded")
                    smartRestoreState();
                return;
            case "toggleControlCenter":
                if (islandState === "control_center")
                    smartRestoreState();
                else
                    showControlCenter();
                return;
            case "openControlCenter":
                showControlCenter();
                return;
            case "closeControlCenter":
                if (islandState === "control_center")
                    smartRestoreState();
                return;
            case "toggleOverview":
                root.toggleOverviewEverywhere();
                return;
            case "openOverview":
                root.openOverviewEverywhere();
                return;
            case "closeOverview":
                root.closeOverviewEverywhere();
                return;
            case "toggleLyrics":
                if (restingState === "lyrics")
                    showTimeCapsule();
                else
                    showLyricsCapsule();
                return;
            case "showLyrics":
                showLyricsCapsule();
                return;
            case "showTime":
                showTimeCapsule();
                return;
            case "restoreRestingCapsule":
                smartRestoreState();
                return;
            default:
                console.warn("Unknown Dynamic Island click action:", actionName);
            }
        }

        function normalizeSwipeItemId(rawId) {
            return String(rawId === undefined || rawId === null ? "" : rawId).trim().toLowerCase();
        }

        function formatPercentText(value) {
            return Math.round(Math.max(0, value) * 100) + "%";
        }

        function clamp01(value) {
            return Math.max(0, Math.min(1, value));
        }

        function applyBrightnessOutput(text) {
            const match = String(text === undefined || text === null ? "" : text).match(/,(\d+)%/);
            if (!match) return;
            currentBrightness = clamp01(parseInt(match[1], 10) / 100);
        }

        function applyVolumeOutput(text) {
            const source = String(text === undefined || text === null ? "" : text);
            const match = source.match(/([0-9]*\.?[0-9]+)/);
            if (match) currentVolume = clamp01(parseFloat(match[1]));
            isMuted = /\bMUTED\b/i.test(source);
        }

        function refreshMissingLeftSwipeValues() {
            if (currentBrightness < 0 && !brightnessSnapshot.running)
                brightnessSnapshot.exec(["brightnessctl", "-m"]);
            if (currentVolume < 0 && !volumeSnapshot.running)
                volumeSnapshot.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]);
            if (usesSystemStatsModule && !systemStatsSnapshot.running)
                systemStatsSnapshot.exec(systemStatsSnapshot.command);
        }

        function buildNormalizedSwipeItemIds(rawItems) {
            const source = Array.isArray(rawItems) ? rawItems : [];
            const resolved = [];
            const seen = {};

            for (let index = 0; index < source.length; index++) {
                const itemId = normalizeSwipeItemId(source[index]);
                if (itemId === "" || seen[itemId]) continue;
                seen[itemId] = true;
                resolved.push(itemId);
            }

            return resolved;
        }

        function applySystemStatsOutput(text) {
            const lines = String(text === undefined || text === null ? "" : text).trim().split(/\r?\n/);

            for (let index = 0; index < lines.length; index++) {
                const line = lines[index].trim();
                if (line === "") continue;

                const parts = line.split(/\s+/);
                if (parts[0] === "cpu" && parts.length >= 6) {
                    let total = 0;
                    for (let valueIndex = 1; valueIndex < parts.length; valueIndex++)
                        total += Number(parts[valueIndex]) || 0;

                    const idle = (Number(parts[4]) || 0) + (Number(parts[5]) || 0);
                    if (_lastCpuTotal >= 0 && _lastCpuIdle >= 0 && total > _lastCpuTotal) {
                        const totalDiff = total - _lastCpuTotal;
                        const idleDiff = idle - _lastCpuIdle;
                        currentCpuUsage = totalDiff > 0 ? clamp01((totalDiff - idleDiff) / totalDiff) : 0;
                    } else {
                        currentCpuUsage = currentCpuUsage >= 0 ? currentCpuUsage : 0;
                    }

                    _lastCpuTotal = total;
                    _lastCpuIdle = idle;
                    continue;
                }

                if (parts[0] === "mem" && parts.length >= 3) {
                    const totalMem = Number(parts[1]) || 0;
                    const availableMem = Number(parts[2]) || 0;
                    if (totalMem > 0) currentRamUsage = clamp01((totalMem - availableMem) / totalMem);
                }
            }
        }

        function applyCavaOutput(line) {
            const values = String(line === undefined || line === null ? "" : line)
                .split(";")
                .filter(value => value !== "");

            if (values.length === 0) return;

            const nextLevels = [];
            for (let index = 0; index < values.length; index++) {
                const parsed = Number(values[index]);
                nextLevels.push(clamp01((isNaN(parsed) ? 0 : parsed) / 7.0));
            }

            cavaLevels = nextLevels;
        }

        function buildCustomSwipeItem(itemId) {
            switch (itemId) {
            case "time":
                return { id: itemId, icon: "", text: timeObj.currentTime };
            case "date":
                return { id: itemId, icon: "", text: timeObj.currentDateLabel };
            case "battery":
                if (batteryCapacity < 0) return null;
                return {
                    id: itemId,
                    icon: isCharging ? userConfig.statusIcons["charging"] : "",
                    text: Math.max(0, batteryCapacity) + "%"
                };
            case "volume":
                if (currentVolume < 0) return null;
                return {
                    id: itemId,
                    icon: isMuted ? userConfig.statusIcons["mute"] : userConfig.statusIcons["volume"],
                    text: formatPercentText(currentVolume)
                };
            case "brightness":
                if (currentBrightness < 0) return null;
                return {
                    id: itemId,
                    icon: brightnessStatusIcon(currentBrightness),
                    text: formatPercentText(currentBrightness)
                };
            case "workspace":
                return { id: itemId, icon: "", text: "WS " + currentWs };
            case "cpu":
                if (currentCpuUsage < 0) return null;
                return {
                    id: itemId,
                    icon: userConfig.statusIcons["cpu"],
                    text: formatPercentText(currentCpuUsage)
                };
            case "ram":
                if (currentRamUsage < 0) return null;
                return {
                    id: itemId,
                    icon: userConfig.statusIcons["ram"],
                    text: formatPercentText(currentRamUsage)
                };
            case "cava":
                return { id: itemId, kind: "cava" };
            default:
                return null;
            }
        }

        function buildCustomSwipeItems(rawItems) {
            const source = Array.isArray(rawItems) ? rawItems : [];
            const resolved = [];
            const seen = {};

            for (let index = 0; index < source.length; index++) {
                const itemId = normalizeSwipeItemId(source[index]);
                if (itemId === "" || seen[itemId]) continue;
                seen[itemId] = true;

                const nextItem = buildCustomSwipeItem(itemId);
                if (nextItem) resolved.push(nextItem);
            }

            return resolved;
        }

        function normalizeRestingState(nextState) {
            if (nextState === "lyrics") return "lyrics";
            if (nextState === "custom" && hasCustomLeftItems) return "custom";
            return "normal";
        }

        function restingStateProgress(nextState) {
            switch (normalizeRestingState(nextState)) {
            case "custom":
                return -1;
            case "lyrics":
                return 1;
            default:
                return 0;
            }
        }

        function restingStateSide(nextState) {
            switch (normalizeRestingState(nextState)) {
            case "custom":
                return "left";
            case "lyrics":
                return "right";
            default:
                return "none";
            }
        }

        function swipeRestProgressForState() {
            switch (islandState) {
            case "custom":
                return -1;
            case "lyrics":
                return 1;
            default:
                return 0;
            }
        }

        function currentTransientOriginSide() {
            switch (islandState) {
            case "custom":
                return "left";
            case "lyrics":
                return "right";
            case "long_capsule":
                return workspaceOriginSide;
            case "split":
                return splitOriginSide;
            default:
                return "none";
            }
        }

        function setOsdProgress(nextProgress, animate) {
            osdProgressAnimationReset.stop();
            osdProgressAnimationEnabled = animate;
            osdProgress = nextProgress;
            if (!animate) osdProgressAnimationReset.restart();
        }

        function abortSideTransientMode() {
            sideTransientRestoreTimer.stop();
            workspaceOriginSide = "none";
            splitOriginSide = "none";
        }

        function clearTransientCapsule() {
            setOsdProgress(-1.0, false);
            osdCustomText = "";
            notificationAppName = "";
            notificationSummary = "";
            notificationBody = "";
        }

        function prepareRestingCapsuleGeometry() {
            if (restingState === "custom")
                syncCustomCapsuleWidth();
            if (restingState === "lyrics")
                syncLyricsCapsuleWidth();
        }

        function applyRestingVisuals() {
            prepareRestingCapsuleGeometry();
            swipeTransitionProgress = restingStateProgress(restingState);
        }

        function sideSwipeRestProgressForProgress(progressValue) {
            if (progressValue <= -0.5) return -1;
            if (progressValue >= 0.5) return 1;
            return 0;
        }

        function sideSwipeRestWidthForProgress(progressValue) {
            if (progressValue <= -0.5) return customCapsuleWidth;
            if (progressValue >= 0.5) return lyricsCapsuleWidth;
            return 140;
        }

        function customSideSwipeDragDistance() {
            const view = customSwipeLoader.item;
            if (view && view.dragDistance > 0) return view.dragDistance;
            return Math.max(140, customCapsuleWidth + 4);
        }

        function lyricsSideSwipeDragDistance() {
            const view = lyricsSwipeLoader.item;
            if (view && view.dragDistance > 0) return view.dragDistance;
            return Math.max(140, lyricsCapsuleWidth + 2);
        }

        function sideSwipeDragDistanceForDirection(direction) {
            if (direction === "left") return customSideSwipeDragDistance();
            if (direction === "right") return lyricsSideSwipeDragDistance();
            return 140;
        }

        function advanceSideSwipeProgress(currentProgress, deltaX) {
            const minProgress = hasCustomLeftItems ? -1 : 0;
            let nextProgress = Math.max(minProgress, Math.min(1, currentProgress));
            let remainingDelta = deltaX;

            if (remainingDelta > 0) {
                if (nextProgress < 0) {
                    const leftDistance = Math.max(1, sideSwipeDragDistanceForDirection("left"));
                    const progressToCenter = Math.min(-nextProgress, remainingDelta / leftDistance);
                    nextProgress += progressToCenter;
                    remainingDelta -= progressToCenter * leftDistance;
                }

                if (remainingDelta > 0 && nextProgress < 1) {
                    const rightDistance = Math.max(1, sideSwipeDragDistanceForDirection("right"));
                    nextProgress = Math.min(1, nextProgress + remainingDelta / rightDistance);
                }
            } else if (remainingDelta < 0) {
                if (nextProgress > 0) {
                    const rightDistance = Math.max(1, sideSwipeDragDistanceForDirection("right"));
                    const progressToCenter = Math.min(nextProgress, -remainingDelta / rightDistance);
                    nextProgress -= progressToCenter;
                    remainingDelta += progressToCenter * rightDistance;
                }

                if (remainingDelta < 0 && nextProgress > minProgress) {
                    const leftDistance = Math.max(1, sideSwipeDragDistanceForDirection("left"));
                    nextProgress = Math.max(minProgress, nextProgress + remainingDelta / leftDistance);
                }
            }

            return Math.max(minProgress, Math.min(1, nextProgress));
        }

        function resolveSideSwipeSettle(startProgress, finalProgress) {
            let settleAction = "";
            let settleProgress = sideSwipeRestProgressForProgress(startProgress);
            let settleWidth = sideSwipeRestWidthForProgress(startProgress);

            if (finalProgress >= 0.56) {
                settleAction = "lyrics";
                settleProgress = 1;
                settleWidth = lyricsCapsuleWidth;
            } else if (hasCustomLeftItems && finalProgress <= -0.56) {
                settleAction = "custom";
                settleProgress = -1;
                settleWidth = customCapsuleWidth;
            } else if (startProgress <= -0.5) {
                if (finalProgress >= -0.44) {
                    settleAction = "time";
                    settleProgress = 0;
                    settleWidth = 140;
                }
            } else if (startProgress >= 0.5) {
                if (finalProgress <= 0.44) {
                    settleAction = "time";
                    settleProgress = 0;
                    settleWidth = 140;
                }
            } else {
                settleAction = "time";
                settleProgress = 0;
                settleWidth = 140;
            }

            return {
                action: settleAction,
                progress: settleProgress,
                width: settleWidth
            };
        }

        function beginSideSwipeSettle(targetWidth) {
            sideSwipeSettling = true;
            mainCapsule.displayedWidth = targetWidth;
            sideSwipeSettleReset.restart();
        }

        function cancelSideSwipeSettle() {
            sideSwipeSettleReset.stop();
            sideSwipeSettling = false;
        }

        function finishSideSwipeSettle() {
            sideSwipeSettling = false;
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
        }

        function restartAutoHideTimer(duration) {
            autoHideTimer.interval = duration === undefined ? defaultAutoHideInterval : duration;
            autoHideTimer.restart();
        }

        function stopAutoHideTimer() {
            autoHideTimer.stop();
            autoHideTimer.interval = defaultAutoHideInterval;
        }

        function showTransientCapsule(icon, progress, customText) {
            if (progress === undefined)    progress = -1.0;
            if (customText === undefined)  customText = "";

            if (blocksTransientSplit) return;

            const nextProgress = progress >= 0 ? progress : -1.0;
            const animateProgress = islandState === "split" && osdProgress >= 0 && nextProgress >= 0;
            const animateFromSide = currentTransientOriginSide();

            abortSideTransientMode();
            splitIcon = icon;
            osdCustomText = customText;
            setOsdProgress(nextProgress, animateProgress);
            splitOriginSide = animateFromSide;
            islandState = "split";
            swipeTransitionProgress = 0;
            restartAutoHideTimer();
        }

        function showNotificationCapsule(appName, summary, body) {
            if (root.overviewVisible || islandState === "control_center" || islandState === "expanded") return;

            const cleanedAppName = cleanNotificationText(appName);
            const cleanedSummary = cleanNotificationText(summary);
            const cleanedBody = cleanNotificationText(body);
            const resolvedSummary = cleanedSummary !== ""
                ? cleanedSummary
                : (cleanedBody !== "" ? cleanedBody : "New notification");

            abortSideTransientMode();
            clearTransientCapsule();
            notificationAppName = cleanedAppName !== "" ? cleanedAppName : "Notification";
            notificationSummary = resolvedSummary;
            notificationBody = cleanedSummary !== "" ? cleanedBody : "";
            islandState = "notification";
            restartAutoHideTimer(notificationAutoHideInterval);
        }

        function suppressCapsuleClick() {
            capsuleMouseArea.suppressNextClick = true;
            swipeSuppressReset.restart();
        }

        function restoreRestingCapsule(forceImmediate) {
            if (forceImmediate === undefined) forceImmediate = false;
            const normalizedRestingState = normalizeRestingState(restingState);
            const targetSide = restingStateSide(normalizedRestingState);
            const shouldAnimateToSide = targetSide !== "none"
                && ((islandState === "long_capsule" && workspaceOriginSide === targetSide)
                    || (islandState === "split" && splitOriginSide === targetSide));

            if (!forceImmediate && shouldAnimateToSide) {
                expandedByPlayerAutoOpen = false;
                prepareRestingCapsuleGeometry();
                swipeTransitionProgress = restingStateProgress(normalizedRestingState);
                stopAutoHideTimer();
                sideTransientRestoreTimer.restart();
                return;
            }

            abortSideTransientMode();
            prepareRestingCapsuleGeometry();
            islandState = normalizedRestingState;
            clearTransientCapsule();
            applyRestingVisuals();
            expandedByPlayerAutoOpen = false;
            stopAutoHideTimer();
        }

        function setRestingState(nextState) {
            restingState = normalizeRestingState(nextState);
        }

        function smartRestoreState() {
            restoreRestingCapsule();
        }

        function showRestingCapsule(nextState) {
            setRestingState(nextState);
            restoreRestingCapsule();
            stopAutoHideTimer();
        }

        function showExpandedPlayer(autoOpened) {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "expanded";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            expandedByPlayerAutoOpen = autoOpened;
            if (autoOpened) restartAutoHideTimer();
            else stopAutoHideTimer();
        }

        function showControlCenter() {
            cancelSideSwipeSettle();
            abortSideTransientMode();
            clearTransientCapsule();
            islandState = "control_center";
            mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
            stopAutoHideTimer();
        }

        function showCustomCapsule() {
            if (!hasCustomLeftItems) {
                showTimeCapsule();
                return;
            }

            refreshMissingLeftSwipeValues();
            showRestingCapsule("custom");
        }

        function showLyricsCapsule() {
            showRestingCapsule("lyrics");
        }

        function showTimeCapsule() {
            showRestingCapsule("normal");
        }

        function showWorkspaceCapsule(wsId) {
            currentWs = wsId;
            if (islandState === "control_center" || islandState === "notification") return;
            const animateFromSide = currentTransientOriginSide();
            clearTransientCapsule();
            sideTransientRestoreTimer.stop();
            workspaceOriginSide = animateFromSide;
            splitOriginSide = "none";
            islandState = "long_capsule";
            swipeTransitionProgress = 0;
            restartAutoHideTimer();
        }

        function brightnessStatusIcon(value) {
            if (value < 0.3) return userConfig.statusIcons["brightnessLow"];
            if (value < 0.7) return userConfig.statusIcons["brightnessMedium"];
            return userConfig.statusIcons["brightnessHigh"];
        }

        Timer { id: autoHideTimer; interval: islandContainer.defaultAutoHideInterval; onTriggered: islandContainer.smartRestoreState() }
        Timer {
            id: osdProgressAnimationReset
            interval: 0
            onTriggered: islandContainer.osdProgressAnimationEnabled = true
        }
        Timer {
            id: sideTransientRestoreTimer
            interval: islandContainer.swipeAnimationDuration
            onTriggered: {
                islandContainer.workspaceOriginSide = "none";
                islandContainer.splitOriginSide = "none";
                islandContainer.prepareRestingCapsuleGeometry();
                islandContainer.islandState = islandContainer.normalizeRestingState(islandContainer.restingState);
                islandContainer.clearTransientCapsule();
                islandContainer.applyRestingVisuals();
                islandContainer.expandedByPlayerAutoOpen = false;
            }
        }
        Timer {
            id: sideSwipeSettleReset
            interval: mainCapsule.morphDuration
            onTriggered: islandContainer.finishSideSwipeSettle()
        }

        function syncCustomCapsuleWidth() {
            const view = customSwipeLoader.item;
            if (!view) return;
            customCapsuleWidth = Math.max(220, Math.min(root.width - 48, view.preferredWidth));
        }

        function syncLyricsCapsuleWidth() {
            const view = lyricsSwipeLoader.item;
            if (!view) return;
            lyricsCapsuleWidth = Math.max(220, Math.min(root.width - 48, view.preferredWidth));
        }

        Process {
            id: brightnessSnapshot
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: islandContainer.applyBrightnessOutput(text)
            }
        }

        Process {
            id: volumeSnapshot
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: islandContainer.applyVolumeOutput(text)
            }
        }

        Process {
            id: systemStatsSnapshot
            command: [
                "sh",
                "-lc",
                "awk 'NR == 1 { print \"cpu\", $2, $3, $4, $5, $6, $7, $8, $9, $10 } $1 == \"MemTotal:\" { total = $2 } $1 == \"MemAvailable:\" { available = $2 } END { print \"mem\", total, available }' /proc/stat /proc/meminfo"
            ]
            stdout: StdioCollector {
                waitForEnd: true
                onStreamFinished: islandContainer.applySystemStatsOutput(text)
            }
        }

        Timer {
            id: systemStatsPollTimer
            interval: 3000
            repeat: true
            running: islandContainer.usesSystemStatsModule && customSwipeLoader.active
            triggeredOnStart: true
            onTriggered: {
                if (!systemStatsSnapshot.running)
                    systemStatsSnapshot.exec(systemStatsSnapshot.command);
            }
        }

        Timer {
            id: cavaRestartTimer
            interval: 1200
            repeat: false
            onTriggered: {
                if (islandContainer.usesCavaModule && customSwipeLoader.active)
                    cavaMonitor.running = true;
            }
        }

        Process {
            id: cavaMonitor
            running: islandContainer.usesCavaModule && customSwipeLoader.active
            command: [
                "sh",
                "-lc",
                "exec cava -p /dev/stdin <<'EOF'\n[general]\nframerate = 60\nbars = 8\nautosens = 1\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 7\nchannels = mono\nEOF"
            ]
            stdout: SplitParser {
                splitMarker: "\n"

                onRead: function(data) {
                    islandContainer.applyCavaOutput(data);
                }
            }
            onExited: {
                if (islandContainer.usesCavaModule && customSwipeLoader.active)
                    cavaRestartTimer.restart();
            }
        }

        Component.onCompleted: refreshMissingLeftSwipeValues()

        Timer { id: btBlockVolTimer; interval: 2000; onTriggered: islandContainer.btJustConnected = false }
        Timer {
            id: volDebounce
            interval: 16
            onTriggered: {
                if (islandContainer.btJustConnected) return;
                if (islandContainer._pendingVolType !== islandContainer._lastVolType || Math.abs(islandContainer._pendingVolVal - islandContainer._lastVolVal) > 0.001) {
                    islandContainer._lastVolType = islandContainer._pendingVolType; islandContainer._lastVolVal  = islandContainer._pendingVolVal;
                    islandContainer.showTransientCapsule(
                        islandContainer._pendingVolType === "MUTE"
                            ? userConfig.statusIcons["mute"]
                            : userConfig.statusIcons["volume"],
                        islandContainer._pendingVolVal,
                        ""
                    );
                }
            }
        }
        Timer {
            id: blDebounce
            interval: 16
            onTriggered: {
                islandContainer.showTransientCapsule(
                    islandContainer.brightnessStatusIcon(islandContainer._pendingBlVal),
                    islandContainer._pendingBlVal,
                    ""
                );
            }
        }

        Connections {
            target: SysBackend

            function onVolumeChanged(volPercentage, isMuted) {
                islandContainer._pendingVolType = isMuted ? "MUTE" : "VOL";
                islandContainer._pendingVolVal = volPercentage / 100.0;
                islandContainer.currentVolume = volPercentage / 100.0;
                islandContainer.isMuted = isMuted;
                volDebounce.restart();
            }

            function onBatteryChanged(capacity, statusString) {
                islandContainer.batteryCapacity = capacity;
                islandContainer.isCharging = (statusString === "Charging" || statusString === "Full");
                if (islandContainer._lastChargeStatus !== "" && islandContainer._lastChargeStatus !== statusString) {
                    if (statusString === "Charging") islandContainer.showTransientCapsule(userConfig.statusIcons["charging"]);
                    else if (statusString === "Discharging") islandContainer.showTransientCapsule(userConfig.statusIcons["discharging"]);
                }
                islandContainer._lastChargeStatus = statusString;
            }

            function onBrightnessChanged(val) {
                islandContainer._pendingBlVal = val;
                islandContainer.currentBrightness = val;
                blDebounce.restart();
            }

            function onCapsLockChanged(isOn) {
                islandContainer.showTransientCapsule(
                    isOn ? userConfig.statusIcons["capsLockOn"] : userConfig.statusIcons["capsLockOff"],
                    -1.0,
                    isOn ? "Caps Lock ON" : "Caps Lock OFF"
                );
            }

            function onBluetoothChanged(isConnected) {
                islandContainer.btJustConnected = true; 
                btBlockVolTimer.restart();
                islandContainer.showTransientCapsule(
                    userConfig.statusIcons["bluetooth"],
                    -1.0,
                    isConnected ? "Connected" : "Disconnected"
                );
            }
        }

        Connections {
            target: Hyprland

            function onRawEvent(event) {
                root.handleWorkspaceEvent(event);
            }
        }

        Connections {
            target: root.hyprMonitor

            function onActiveWorkspaceChanged() {
                root.syncWorkspaceState();
            }
        }

        // --- MPRIS 音乐控制逻辑 ---
        function formatTime(val) {
            let num = Number(val);
            if (isNaN(num) || num <= 0) return "0:00";
            let totalSeconds = 0;
            if (num < 10000) totalSeconds = Math.floor(num);
            else if (num < 100000000) totalSeconds = Math.floor(num / 1000);
            else totalSeconds = Math.floor(num / 1000000);
            let m = Math.floor(totalSeconds / 60);
            let s = Math.floor(totalSeconds % 60);
            return m + ":" + (s < 10 ? "0" : "") + s;
        }

        function cleanLyricLineText(text) {
            return String(text === undefined || text === null ? "" : text)
                .replace(/\s+/g, " ")
                .trim();
        }

        function parsePlainLyrics(rawLyrics) {
            const source = String(rawLyrics === undefined || rawLyrics === null ? "" : rawLyrics);
            const rows = source.split(/\r?\n/);
            const parsed = [];

            for (let i = 0; i < rows.length; i++) {
                const row = rows[i].trim();
                if (row === "") continue;
                if (/^\[[a-zA-Z]+:.*\]$/.test(row)) continue;
                const lineText = cleanLyricLineText(row.replace(/\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]/g, ""));
                if (lineText !== "") parsed.push(lineText);
            }

            return parsed;
        }

        function cleanNotificationText(text) {
            return String(text === undefined || text === null ? "" : text)
                .replace(/<[^>]*>/g, " ")
                .replace(/&nbsp;/g, " ")
                .replace(/&amp;/g, "&")
                .replace(/&quot;/g, "\"")
                .replace(/&lt;/g, "<")
                .replace(/&gt;/g, ">")
                .replace(/\s+/g, " ")
                .trim();
        }

        function playerHasTrackInfo(player) {
            if (!player) return false;
            if ((player.trackTitle || player.title || "") !== "") return true;
            if (!player.metadata) return false;
            return Boolean(
                player.metadata["xesam:title"]
                || player.metadata["mpris:trackid"]
                || player.metadata["xesam:url"]
            );
        }

        function findPlayerByDbusName(dbusName) {
            if (!playersList || !dbusName) return null;
            for (let i = 0; i < playersList.length; i++) {
                if (playersList[i].dbusName === dbusName) return playersList[i];
            }
            return null;
        }

        function resolveActivePlayer() {
            if (!playersList || playersList.length === 0) return null;

            for (let i = 0; i < playersList.length; i++) {
                if (playersList[i].playbackState === MprisPlaybackState.Playing) return playersList[i];
            }

            const rememberedPlayer = findPlayerByDbusName(lastActivePlayerDbusName);
            if (rememberedPlayer && (playerHasTrackInfo(rememberedPlayer) || rememberedPlayer.canControl)) return rememberedPlayer;

            for (let i = 0; i < playersList.length; i++) {
                if (playersList[i].playbackState === MprisPlaybackState.Paused && playerHasTrackInfo(playersList[i])) return playersList[i];
            }

            for (let i = 0; i < playersList.length; i++) {
                if (playersList[i].canControl) return playersList[i];
            }

            return playersList[0];
        }

        property string lastActivePlayerDbusName: ""
        property var playersList: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
        property var activePlayer: resolveActivePlayer()

        onActivePlayerChanged: {
            if (activePlayer && activePlayer.dbusName) lastActivePlayerDbusName = activePlayer.dbusName;
            else if (!activePlayer) lastActivePlayerDbusName = "";
        }

        property string lyricsLookupTitle: activePlayer ? (activePlayer.trackTitle || activePlayer.title || "") : ""
        property string lyricsLookupArtist: {
            if (!activePlayer) return "";
            let a = activePlayer.artist;
            if (!a && activePlayer.metadata) a = activePlayer.metadata["xesam:artist"];
            if (a) return Array.isArray(a) ? a.join(", ") : String(a);
            return "";
        }
        property string currentTrack: activePlayer ? (lyricsLookupTitle !== "" ? lyricsLookupTitle : "Unknown") : ""
        property string currentArtist: {
            if (!activePlayer) return "";
            if (lyricsLookupArtist !== "") return lyricsLookupArtist;
            return "Unknown";
        }
        property string currentArtUrl:  activePlayer ? (activePlayer.trackArtUrl || activePlayer.artUrl || "") : ""
        property string inlineLyricsRaw: {
            if (!activePlayer || !activePlayer.metadata) return "";
            let inlineLyrics = activePlayer.metadata["xesam:asText"];
            if (!inlineLyrics) inlineLyrics = activePlayer.metadata["xesam:comment"];
            if (Array.isArray(inlineLyrics)) return inlineLyrics.join("\n");
            return inlineLyrics ? String(inlineLyrics) : "";
        }

        QtObject {
            id: notificationBridge

            property bool captureActive: false
            property int captureStage: -1
            property string pendingAppName: ""
            property string pendingSummary: ""
            property string pendingBody: ""

            function resetCapture() {
                captureActive = false;
                captureStage = -1;
                pendingAppName = "";
                pendingSummary = "";
                pendingBody = "";
            }

            function beginCapture() {
                resetCapture();
                captureActive = true;
                captureStage = 0;
            }

            function decodeMonitorString(line) {
                const match = line.match(/^\s*string "(.*)"\s*$/);
                if (!match) return "";

                try {
                    return JSON.parse("\"" + match[1] + "\"");
                } catch (error) {
                    return match[1]
                        .replace(/\\"/g, "\"")
                        .replace(/\\\\/g, "\\");
                }
            }

            function commitCapture() {
                islandContainer.showNotificationCapsule(pendingAppName, pendingSummary, pendingBody);
                resetCapture();
            }

            function handleLine(rawLine) {
                const line = String(rawLine === undefined || rawLine === null ? "" : rawLine).trim();
                if (line === "") return;

                if (line.indexOf("member=Notify") !== -1) {
                    beginCapture();
                    return;
                }

                if (!captureActive) return;

                switch (captureStage) {
                case 0:
                    if (!line.startsWith("string ")) return;
                    pendingAppName = decodeMonitorString(line);
                    captureStage = 1;
                    return;
                case 1:
                    if (!line.startsWith("uint32 ")) return;
                    captureStage = 2;
                    return;
                case 2:
                    if (!line.startsWith("string ")) return;
                    captureStage = 3;
                    return;
                case 3:
                    if (!line.startsWith("string ")) return;
                    pendingSummary = decodeMonitorString(line);
                    captureStage = 4;
                    return;
                case 4:
                    if (!line.startsWith("string ")) return;
                    pendingBody = decodeMonitorString(line);
                    commitCapture();
                    return;
                default:
                    resetCapture();
                }
            }
        }

        Timer {
            id: notificationMonitorRestartTimer
            interval: 1200
            repeat: false
            onTriggered: notificationMonitor.running = true
        }

        Process {
            id: notificationMonitor
            running: true
            command: [
                "dbus-monitor",
                "--session",
                "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"
            ]
            stdout: SplitParser {
                splitMarker: "\n"

                onRead: function(data) {
                    notificationBridge.handleLine(data);
                }
            }
            onExited: notificationMonitorRestartTimer.restart()
        }

        QtObject {
            id: lyricsBridge

            readonly property string title: islandContainer.currentTrack
            readonly property string artist: islandContainer.currentArtist
            readonly property string currentLyric: SysBackend && SysBackend.lyricsCurrentLyric !== undefined
                ? SysBackend.lyricsCurrentLyric
                : ""
            readonly property bool isSynced: SysBackend && SysBackend.lyricsIsSynced !== undefined
                ? SysBackend.lyricsIsSynced
                : false
            readonly property string backendStatus: SysBackend && SysBackend.lyricsBackendStatus !== undefined
                ? SysBackend.lyricsBackendStatus
                : "idle"
            readonly property var plainLines: islandContainer.parsePlainLyrics(islandContainer.inlineLyricsRaw)
            readonly property string plainLyric: plainLines.length > 0 ? plainLines[0] : ""
            readonly property string displayText: {
                if (title === "") return "No music playing";
                if (backendStatus === "missing" || backendStatus === "error") return "no lyrics";
                if (isSynced && currentLyric !== "") return currentLyric;
                if (plainLyric !== "") return plainLyric;
                return artist !== "" && artist !== "Unknown"
                    ? title + " - " + artist
                    : title;
            }
        }

        property real   trackProgress: 0
        property string timePlayed:    "0:00"
        property string timeTotal:     "0:00"

        Timer {
            id: progressPoller
            interval: 500
            running: islandContainer.activePlayer !== null && islandContainer.islandState === "expanded"
            repeat: true
            onTriggered: {
                let player = islandContainer.activePlayer;
                if (!player) return;
                let currentPos = Number(player.position) || 0;
                let totalLen   = Number(player.length) || 0;
                if (totalLen <= 0 && player.metadata && player.metadata["mpris:length"]) totalLen = Number(player.metadata["mpris:length"]);

                if (totalLen > 0) {
                    islandContainer.trackProgress = currentPos / totalLen; islandContainer.timePlayed = islandContainer.formatTime(currentPos); islandContainer.timeTotal = islandContainer.formatTime(totalLen);
                } else {
                    islandContainer.trackProgress = 0; islandContainer.timePlayed = islandContainer.formatTime(currentPos); islandContainer.timeTotal = "0:00";
                }
            }
        }

        onCurrentTrackChanged: {
            if (currentTrack !== ""
                    && islandState !== "control_center"
                    && islandState !== "notification") {
                if (islandState === "expanded" && !expandedByPlayerAutoOpen) return;
                showExpandedPlayer(true);
            }
        }

        // --- UI 渲染：灵动岛主干 ---
        Rectangle {
            id: mainCapsule
            property int morphDuration: 400
            property real outlineWidth: root.overviewVisible ? 1 : 0
            property color outlineColor: root.overviewVisible ? root.overviewCapsuleBorderColor : "#00000000"
            property real displayedWidth: baseTargetWidth
            readonly property real baseTargetWidth: {
                if (root.overviewVisible) return root.overviewCapsuleWidth;
                if (sideTransientRestoreTimer.running) {
                    if (islandContainer.restingState === "lyrics"
                            && ((islandContainer.islandState === "split" && islandContainer.splitOriginSide === "right")
                                || (islandContainer.islandState === "long_capsule" && islandContainer.workspaceOriginSide === "right"))) {
                        return islandContainer.lyricsCapsuleWidth;
                    }

                    if (islandContainer.restingState === "custom"
                            && ((islandContainer.islandState === "split" && islandContainer.splitOriginSide === "left")
                                || (islandContainer.islandState === "long_capsule" && islandContainer.workspaceOriginSide === "left"))) {
                        return islandContainer.customCapsuleWidth;
                    }
                }

                switch (islandContainer.islandState) {
                case "split":
                    return islandContainer.splitCapsuleWidth;
                case "long_capsule":
                    return 220;
                case "custom":
                    return islandContainer.customCapsuleWidth;
                case "lyrics":
                    return islandContainer.lyricsCapsuleWidth;
                case "control_center":
                    return 420;
                case "expanded":
                    return 400;
                case "notification":
                    if (!notificationLoader.item) return 272;
                    return Math.max(
                        notificationLoader.item.minimumWidth,
                        Math.min(notificationLoader.item.maximumWidth, notificationLoader.item.preferredWidth)
                    );
                default:
                    return 140;
                }
            }
            readonly property real targetHeight: {
                if (root.overviewVisible) return root.overviewCapsuleHeight;

                switch (islandContainer.islandState) {
                case "control_center":
                    return 292;
                case "expanded":
                    return 165;
                case "notification":
                    return notificationLoader.item
                        ? Math.max(56, Math.min(68, notificationLoader.item.preferredHeight))
                        : 56;
                default:
                    return 38;
                }
            }
            readonly property real targetRadius: {
                if (root.overviewVisible) return root.overviewCapsuleRadius;

                switch (islandContainer.islandState) {
                case "control_center":
                    return 34;
                case "expanded":
                    return 40;
                case "notification":
                    return mainCapsule.targetHeight / 2;
                default:
                    return 19;
                }
            }
            function sideSwipeWidthForProgress(progressValue) {
                if (progressValue < 0)
                    return 140 + (islandContainer.customCapsuleWidth - 140)
                        * islandContainer.clamp01(-progressValue);
                if (progressValue > 0)
                    return 140 + (islandContainer.lyricsCapsuleWidth - 140)
                        * islandContainer.clamp01(progressValue);
                return 140;
            }
            readonly property real sideSwipePreviewWidth: mainCapsule.sideSwipeWidthForProgress(
                islandContainer.swipeTransitionProgress
            )
            color: root.overviewVisible ? root.overviewCapsuleColor : "black"
            y: 4
            anchors.horizontalCenter: parent.horizontalCenter
            clip: true
            width: displayedWidth
            height: targetHeight
            radius: targetRadius

            onBaseTargetWidthChanged: {
                if (!capsuleMouseArea.sideSwipeInteractive && !islandContainer.sideSwipeSettling)
                    displayedWidth = baseTargetWidth;
            }

            Behavior on displayedWidth  {
                NumberAnimation {
                    duration: capsuleMouseArea.sideSwipeInteractive ? 0 : mainCapsule.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on height { NumberAnimation { duration: mainCapsule.morphDuration; easing.type: Easing.OutQuint } }
            Behavior on radius { NumberAnimation { duration: mainCapsule.morphDuration; easing.type: Easing.OutQuint } }
            Behavior on color { ColorAnimation { duration: 280; easing.type: Easing.InOutQuad } }
            Behavior on outlineWidth { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }
            Behavior on outlineColor { ColorAnimation { duration: 260; easing.type: Easing.InOutQuad } }
            border.width: outlineWidth
            border.color: outlineColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(parent.radius - 1, 0)
                color: "transparent"
                border.width: 1
                border.color: "#12ffffff"
                opacity: root.overviewVisible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.overviewVisible ? 260 : 140
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            MouseArea {
                id: capsuleMouseArea
                anchors.fill: parent
                z: -1
                enabled: !root.overviewVisible
                acceptedButtons: root.dynamicIslandAcceptedButtons
                preventStealing: true
                property real swipeStartX: 0
                property real swipeStartY: 0
                property real swipeStartProgress: 0
                property real swipeLastX: 0
                property bool swipeArmed: false
                property bool swipeMoved: false
                property bool sideSwipeInteractive: false
                property bool suppressNextClick: false

                Timer {
                    id: swipeSuppressReset
                    interval: 180
                    repeat: false
                    onTriggered: capsuleMouseArea.suppressNextClick = false
                }

                onPressed: (mouse) => {
                    const mappedPoint = capsuleMouseArea.mapToItem(islandContainer, mouse.x, mouse.y);
                    swipeStartX = mappedPoint.x;
                    swipeStartY = mappedPoint.y;
                    islandContainer.cancelSideSwipeSettle();
                    swipeArmed = mouse.button === userConfig.mouseButton(userConfig.dynamicIslandSwipeButton)
                        && islandContainer.canShowSideSwipe;
                    swipeStartProgress = islandContainer.swipeTransitionProgress;
                    swipeLastX = mappedPoint.x;
                    swipeMoved = false;
                    sideSwipeInteractive = swipeArmed;
                    islandContainer.swipeTransitionProgress = swipeStartProgress;
                }

                onPositionChanged: (mouse) => {
                    if (!pressed || !swipeArmed || suppressNextClick) return;

                    const mappedPoint = capsuleMouseArea.mapToItem(islandContainer, mouse.x, mouse.y);
                    const deltaX = mappedPoint.x - swipeLastX;
                    const deltaY = Math.abs(mappedPoint.y - swipeStartY);
                    const adjustedDeltaX = deltaY < 24 ? deltaX : 0;
                    const nextProgress = islandContainer.advanceSideSwipeProgress(
                        islandContainer.swipeTransitionProgress,
                        adjustedDeltaX
                    );

                    swipeMoved = swipeMoved || Math.abs(nextProgress - swipeStartProgress) > 0.03 || deltaY > 6;
                    swipeLastX = mappedPoint.x;
                    islandContainer.swipeTransitionProgress = nextProgress;
                    mainCapsule.displayedWidth = mainCapsule.sideSwipePreviewWidth;
                }

                onReleased: {
                    if (swipeMoved) {
                        suppressNextClick = true;
                        swipeSuppressReset.restart();
                    }
                    let settleResult = {
                        action: "",
                        progress: islandContainer.sideSwipeRestProgressForProgress(swipeStartProgress),
                        width: islandContainer.sideSwipeRestWidthForProgress(swipeStartProgress)
                    };

                    if (swipeArmed)
                        settleResult = islandContainer.resolveSideSwipeSettle(
                            swipeStartProgress,
                            islandContainer.swipeTransitionProgress
                        );

                    sideSwipeInteractive = false;

                    if (swipeArmed)
                        islandContainer.beginSideSwipeSettle(settleResult.width);
                    else
                        mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;

                    if (swipeArmed) {
                        switch (settleResult.action) {
                        case "time":
                            islandContainer.showTimeCapsule();
                            break;
                        case "custom":
                            islandContainer.showCustomCapsule();
                            break;
                        case "lyrics":
                            islandContainer.showLyricsCapsule();
                            break;
                        default:
                            islandContainer.swipeTransitionProgress = settleResult.progress;
                        }
                    } else {
                        islandContainer.swipeTransitionProgress = settleResult.progress;
                    }
                    swipeArmed = false;
                    swipeMoved = false;
                }

                onCanceled: {
                    swipeArmed = false;
                    swipeMoved = false;
                    sideSwipeInteractive = false;
                    suppressNextClick = false;
                    swipeSuppressReset.stop();
                    mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
                    islandContainer.swipeTransitionProgress = islandContainer.swipeRestProgressForState();
                }

                onClicked: (mouse) => {
                    if (suppressNextClick) {
                        swipeSuppressReset.stop();
                        suppressNextClick = false;
                        return;
                    }

                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandPrimaryButton)) {
                        islandContainer.handleConfiguredClickAction(userConfig.dynamicIslandPrimaryAction);
                        return;
                    }

                    if (mouse.button === userConfig.mouseButton(userConfig.dynamicIslandSecondaryButton)) {
                        islandContainer.handleConfiguredClickAction(userConfig.dynamicIslandSecondaryAction);
                    }
                }
            }

            Loader {
                id: customSwipeLoader
                anchors.fill: parent
                active: islandContainer.customSwipeVisible
                asynchronous: false
                visible: active

                onLoaded: islandContainer.syncCustomCapsuleWidth()

                sourceComponent: Component {
                    SwipeCustomInfoLayer {
                        items: islandContainer.customLeftItems
                        cavaLevels: islandContainer.cavaLevels
                        timeText: timeObj.currentTime
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.heroFontFamily
                        timeFontFamily: root.heroFontFamily
                        minimumWidth: 220
                        maximumWidth: Math.max(220, root.width - 48)
                        transitionProgress: islandContainer.swipeTransitionProgress
                        showSecondaryText: islandContainer.workspaceOriginSide !== "left"
                            && islandContainer.splitOriginSide !== "left"
                        showCondition: true
                        onPreferredWidthChanged: islandContainer.syncCustomCapsuleWidth()
                    }
                }
            }

            Loader {
                id: lyricsSwipeLoader
                anchors.fill: parent
                active: islandContainer.lyricsSwipeVisible
                asynchronous: false
                visible: active

                onLoaded: islandContainer.syncLyricsCapsuleWidth()

                sourceComponent: Component {
                    SwipeLyricsLayer {
                        lyricText: islandContainer.lyricsDisplayText
                        timeText: timeObj.currentTime
                        textFontFamily: root.textFontFamily
                        timeFontFamily: root.timeFontFamily
                        textPixelSize: 16
                        minimumWidth: 220
                        maximumWidth: Math.max(220, root.width - 48)
                        transitionProgress: islandContainer.rightSwipeProgress
                        showSecondaryText: islandContainer.workspaceOriginSide !== "right"
                            && islandContainer.splitOriginSide !== "right"
                        showCondition: true
                        onPreferredWidthChanged: islandContainer.syncLyricsCapsuleWidth()
                    }
                }
            }

            SplitIconLayer {
                iconText: islandContainer.splitIcon
                iconFontFamily: root.iconFontFamily
                transitionProgress: islandContainer.swipeTransitionProgress
                slideDirection: islandContainer.splitOriginSide
                showCondition: !root.overviewVisible && islandContainer.splitShowsIconOnly
            }

            OsdLayer {
                iconText: islandContainer.splitIcon
                progress: islandContainer.osdProgress
                customText: islandContainer.osdCustomText
                iconFontFamily: root.iconFontFamily
                textFontFamily: root.textFontFamily
                heroFontFamily: root.heroFontFamily
                transitionProgress: islandContainer.swipeTransitionProgress
                slideDirection: islandContainer.splitOriginSide
                showCondition: !root.overviewVisible && islandContainer.splitUsesExtendedLayout
            }

            WorkspaceLayer {
                workspaceId: islandContainer.currentWs
                displayText: "Workspace " + islandContainer.currentWs
                textFontFamily: root.textFontFamily
                textPixelSize: 16
                animateVisibility: islandContainer.restingState === "normal"
                transitionProgress: islandContainer.swipeTransitionProgress
                showCondition: !root.overviewVisible
                    && islandContainer.islandState === "long_capsule"
                    && (islandContainer.workspaceOriginSide !== "none"
                        || Math.abs(islandContainer.swipeTransitionProgress) < 0.001)
                slideDirection: islandContainer.workspaceOriginSide
            }

            Loader {
                id: expandedPlayerLoader
                anchors.fill: parent
                active: islandContainer.expandedLayerVisible
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    ExpandedPlayerLayer {
                        currentArtUrl: islandContainer.currentArtUrl
                        currentTrack: islandContainer.currentTrack
                        currentArtist: islandContainer.currentArtist
                        timePlayed: islandContainer.timePlayed
                        timeTotal: islandContainer.timeTotal
                        trackProgress: islandContainer.trackProgress
                        activePlayer: islandContainer.activePlayer
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        showCondition: islandContainer.expandedLayerVisible
                        onControlPressed: islandContainer.suppressCapsuleClick()
                    }
                }
            }

            Loader {
                id: notificationLoader
                anchors.fill: parent
                active: islandContainer.notificationLayerVisible
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    NotificationLayer {
                        appName: islandContainer.notificationAppName
                        summary: islandContainer.notificationSummary
                        body: islandContainer.notificationBody
                        iconText: userConfig.statusIcons["notification"]
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        showCondition: true
                    }
                }
            }

            Loader {
                id: controlCenterLoader
                anchors.fill: parent
                active: islandContainer.controlCenterLayerVisible
                asynchronous: false
                visible: active

                sourceComponent: Component {
                    ControlCenterLayer {
                        iconFontFamily: root.iconFontFamily
                        textFontFamily: root.textFontFamily
                        heroFontFamily: root.heroFontFamily
                        sliderIntroDelay: mainCapsule.morphDuration
                        currentTime: timeObj.currentTime
                        currentDateLabel: timeObj.currentDateLabel
                        batteryCapacity: islandContainer.batteryCapacity
                        isCharging: islandContainer.isCharging
                        volumeLevel: islandContainer.currentVolume
                        brightnessLevel: islandContainer.currentBrightness
                        currentWorkspace: islandContainer.currentWs
                        currentTrack: islandContainer.currentTrack
                        currentArtist: islandContainer.currentArtist
                        showCondition: true
                    }
                }
            }

            Loader {
                id: overviewLoader

                anchors.fill: parent
                active: root.overviewLoaderActive
                asynchronous: false
                visible: root.overviewContentVisible

                onStatusChanged: {
                    if (status === Loader.Ready && root.overviewPreparing) {
                        root.beginOverviewOpening();
                    }
                }

                sourceComponent: Component {
                    Item {
                        id: overviewScene

                        property alias overviewView: overviewView

                        anchors.fill: parent

                        HyprlandData {
                            id: hyprlandData
                        }

                        WorkspaceOverviewLayer {
                            id: overviewView

                            anchors.centerIn: parent
                            screen: root.screen
                            hyprlandData: hyprlandData
                            showCondition: root.overviewVisible
                            textFontFamily: root.textFontFamily
                            heroFontFamily: root.heroFontFamily
                            wallpaperPath: overviewWallpaperCache.effectiveSource
                            windowCornerRadius: userConfig.workspaceOverviewWindowRadius
                            onCloseRequested: root.closeOverviewEverywhere()
                        }
                    }
                }
            }

        }
    }
}
