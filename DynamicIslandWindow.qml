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
        interval: 400
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
        property real currentBrightness: -1
        property string notificationAppName: ""
        property string notificationSummary: ""
        property string notificationBody: ""
        property string _lastChargeStatus: SysBackend.batteryStatus
        property string _pendingVolType: ""
        property real   _pendingVolVal:  0.0
        property string _lastVolType: ""
        property real   _lastVolVal:  -1.0
        property bool btJustConnected: false
        property real   _pendingBlVal:  0.0
        property real swipeTransitionProgress: 0
        property bool workspaceFromLyricsMode: false
        property bool splitFromLyricsMode: false
        property string restingState: "normal"
        property bool expandedByPlayerAutoOpen: false
        property real lyricsCapsuleWidth: 220
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
        readonly property bool canShowLyricsSwipe: islandState === "normal"
            || islandState === "lyrics"
            || (islandState === "long_capsule" && !workspaceFromLyricsMode)
        readonly property string lyricsDisplayText: lyricsBridge.displayText
        readonly property var overviewView: overviewLoader.item && overviewLoader.item.overviewView
            ? overviewLoader.item.overviewView
            : null

        Behavior on osdProgress {
            enabled: islandContainer.osdProgressAnimationEnabled

            SmoothedAnimation { velocity: 1.2; duration: 180; easing.type: Easing.InOutQuad }
        }
        Behavior on swipeTransitionProgress {
            NumberAnimation {
                duration: capsuleMouseArea.pressed ? 0 : islandContainer.swipeAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        Keys.onPressed: (event) => {
            if (!root.overviewVisible) return;

            if (event.key === Qt.Key_Escape) {
                root.closeOverviewEverywhere();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                Hyprland.dispatch("workspace r-1");
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                Hyprland.dispatch("workspace r+1");
                event.accepted = true;
            }
        }

        function setOsdProgress(nextProgress, animate) {
            osdProgressAnimationReset.stop();
            osdProgressAnimationEnabled = animate;
            osdProgress = nextProgress;
            if (!animate) osdProgressAnimationReset.restart();
        }

        function abortLyricsTransientMode() {
            lyricsTransientRestoreTimer.stop();
            workspaceFromLyricsMode = false;
            splitFromLyricsMode = false;
        }

        function clearTransientCapsule() {
            setOsdProgress(-1.0, false);
            osdCustomText = "";
            notificationAppName = "";
            notificationSummary = "";
            notificationBody = "";
        }

        function applyRestingVisuals() {
            swipeTransitionProgress = restingState === "lyrics" ? 1 : 0;
            if (restingState === "lyrics") syncLyricsCapsuleWidth();
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
            const animateFromLyrics = islandState === "lyrics"
                || (islandState === "long_capsule" && workspaceFromLyricsMode)
                || (islandState === "split" && splitFromLyricsMode);

            abortLyricsTransientMode();
            splitIcon = icon;
            osdCustomText = customText;
            setOsdProgress(nextProgress, animateProgress);
            splitFromLyricsMode = animateFromLyrics;
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

            abortLyricsTransientMode();
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

            if (!forceImmediate
                    && restingState === "lyrics"
                    && ((islandState === "long_capsule" && workspaceFromLyricsMode)
                        || (islandState === "split" && splitFromLyricsMode))) {
                expandedByPlayerAutoOpen = false;
                swipeTransitionProgress = 1;
                stopAutoHideTimer();
                lyricsTransientRestoreTimer.restart();
                return;
            }

            abortLyricsTransientMode();
            islandState = restingState;
            clearTransientCapsule();
            applyRestingVisuals();
            expandedByPlayerAutoOpen = false;
            stopAutoHideTimer();
        }

        function setRestingState(nextState) {
            restingState = nextState === "lyrics" ? "lyrics" : "normal";
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
            abortLyricsTransientMode();
            clearTransientCapsule();
            islandState = "expanded";
            expandedByPlayerAutoOpen = autoOpened;
            if (autoOpened) restartAutoHideTimer();
            else stopAutoHideTimer();
        }

        function showControlCenter() {
            abortLyricsTransientMode();
            clearTransientCapsule();
            islandState = "control_center";
            stopAutoHideTimer();
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
            const animateFromLyrics = islandState === "lyrics"
                || (islandState === "long_capsule" && workspaceFromLyricsMode)
                || (islandState === "split" && splitFromLyricsMode);
            clearTransientCapsule();
            lyricsTransientRestoreTimer.stop();
            workspaceFromLyricsMode = animateFromLyrics;
            splitFromLyricsMode = false;
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
            id: lyricsTransientRestoreTimer
            interval: islandContainer.swipeAnimationDuration
            onTriggered: {
                islandContainer.workspaceFromLyricsMode = false;
                islandContainer.splitFromLyricsMode = false;
                islandContainer.islandState = islandContainer.restingState;
                islandContainer.clearTransientCapsule();
                islandContainer.applyRestingVisuals();
                islandContainer.expandedByPlayerAutoOpen = false;
            }
        }

        function syncLyricsCapsuleWidth() {
            lyricsCapsuleWidth = Math.max(220, Math.min(root.width - 48, swipeLyricsLayer.preferredWidth));
        }

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
            readonly property real targetWidth: {
                if (root.overviewVisible) return root.overviewCapsuleWidth;

                switch (islandContainer.islandState) {
                case "split":
                    return islandContainer.splitCapsuleWidth;
                case "long_capsule":
                    return 220;
                case "lyrics":
                    return islandContainer.lyricsCapsuleWidth;
                case "control_center":
                    return 420;
                case "expanded":
                    return 400;
                case "notification":
                    return Math.max(notificationLayer.minimumWidth, Math.min(notificationLayer.maximumWidth, notificationLayer.preferredWidth));
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
                    return Math.max(56, Math.min(68, notificationLayer.preferredHeight));
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

            color: root.overviewVisible ? root.overviewCapsuleColor : "black"
            y: 4
            anchors.horizontalCenter: parent.horizontalCenter
            clip: true
            width: targetWidth
            height: targetHeight
            radius: targetRadius

            Behavior on width  { NumberAnimation { duration: mainCapsule.morphDuration; easing.type: Easing.OutQuint } }
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
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                preventStealing: true
                property real swipeStartX: 0
                property real swipeStartY: 0
                property real swipeStartProgress: 0
                property bool swipeArmed: false
                property bool swipePassedThreshold: false
                property bool swipeMoved: false
                property bool suppressNextClick: false

                Timer {
                    id: swipeSuppressReset
                    interval: 180
                    repeat: false
                    onTriggered: capsuleMouseArea.suppressNextClick = false
                }

                onPressed: (mouse) => {
                    swipeStartX = mouse.x;
                    swipeStartY = mouse.y;
                    swipeArmed = mouse.button === Qt.LeftButton && islandContainer.canShowLyricsSwipe;
                    swipeStartProgress = islandContainer.islandState === "lyrics" ? 1 : 0;
                    swipePassedThreshold = false;
                    swipeMoved = false;
                    islandContainer.swipeTransitionProgress = swipeStartProgress;
                }

                onPositionChanged: (mouse) => {
                    if (!pressed || !swipeArmed || suppressNextClick) return;

                    const deltaX = mouse.x - swipeStartX;
                    const deltaY = Math.abs(mouse.y - swipeStartY);
                    const adjustedDeltaX = deltaY < 24 ? deltaX : 0;
                    const nextProgress = Math.max(0, Math.min(1, swipeStartProgress + adjustedDeltaX / 108));

                    swipeMoved = swipeMoved || Math.abs(adjustedDeltaX) > 6 || deltaY > 6;
                    islandContainer.swipeTransitionProgress = nextProgress;
                    if (swipeStartProgress < 0.5) swipePassedThreshold = nextProgress >= 0.56;
                    else swipePassedThreshold = nextProgress <= 0.44;
                }

                onReleased: {
                    if (swipeMoved) {
                        suppressNextClick = true;
                        swipeSuppressReset.restart();
                    }
                    if (swipeArmed && swipePassedThreshold) {
                        if (swipeStartProgress < 0.5) islandContainer.showLyricsCapsule();
                        else islandContainer.showTimeCapsule();
                    } else {
                        islandContainer.swipeTransitionProgress = swipeStartProgress;
                    }
                    swipeArmed = false;
                    swipePassedThreshold = false;
                    swipeMoved = false;
                }

                onCanceled: {
                    swipeArmed = false;
                    swipePassedThreshold = false;
                    swipeMoved = false;
                    suppressNextClick = false;
                    swipeSuppressReset.stop();
                    islandContainer.swipeTransitionProgress = islandContainer.islandState === "lyrics" ? 1 : 0;
                }

                onClicked: (mouse) => {
                    if (suppressNextClick) {
                        swipeSuppressReset.stop();
                        suppressNextClick = false;
                        return;
                    }

                    if (mouse.button === Qt.LeftButton) {
                        if (islandContainer.islandState === "expanded") {
                            autoHideTimer.stop();
                            islandContainer.smartRestoreState();
                        } else {
                            islandContainer.showExpandedPlayer(false);
                        }
                        return;
                    }

                    if (islandContainer.islandState === "control_center") {
                        islandContainer.smartRestoreState();
                    } else {
                        islandContainer.showControlCenter();
                    }
                }
            }

            SwipeLyricsLayer {
                id: swipeLyricsLayer
                lyricText: islandContainer.lyricsDisplayText
                timeText: timeObj.currentTime
                textFontFamily: root.textFontFamily
                timeFontFamily: root.timeFontFamily
                textPixelSize: 16
                minimumWidth: 220
                maximumWidth: Math.max(220, root.width - 48)
                transitionProgress: islandContainer.swipeTransitionProgress
                showSecondaryText: !islandContainer.workspaceFromLyricsMode
                    && !islandContainer.splitFromLyricsMode
                showCondition: !root.overviewVisible && (
                    islandContainer.islandState === "normal"
                    || islandContainer.islandState === "lyrics"
                    || (islandContainer.islandState === "split"
                        && islandContainer.splitFromLyricsMode)
                    || (islandContainer.islandState === "long_capsule"
                        && (islandContainer.workspaceFromLyricsMode || islandContainer.swipeTransitionProgress > 0))
                )
                onPreferredWidthChanged: {
                    if (islandContainer.islandState === "lyrics") islandContainer.syncLyricsCapsuleWidth();
                }
            }

            SplitIconLayer {
                iconText: islandContainer.splitIcon
                iconFontFamily: root.iconFontFamily
                transitionProgress: islandContainer.swipeTransitionProgress
                slideFromLyrics: islandContainer.splitFromLyricsMode
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
                slideFromLyrics: islandContainer.splitFromLyricsMode
                showCondition: !root.overviewVisible && islandContainer.splitUsesExtendedLayout
            }

            WorkspaceLayer {
                workspaceId: islandContainer.currentWs
                displayText: "Workspace " + islandContainer.currentWs
                textFontFamily: root.textFontFamily
                textPixelSize: 16
                animateVisibility: islandContainer.restingState !== "lyrics"
                transitionProgress: islandContainer.swipeTransitionProgress
                showCondition: !root.overviewVisible
                    && islandContainer.islandState === "long_capsule"
                    && (islandContainer.workspaceFromLyricsMode || islandContainer.swipeTransitionProgress < 0.001)
                slideFromLyrics: islandContainer.workspaceFromLyricsMode
            }

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
                showCondition: !root.overviewVisible && islandContainer.islandState === "expanded"
                onControlPressed: islandContainer.suppressCapsuleClick()
            }

            NotificationLayer {
                id: notificationLayer
                appName: islandContainer.notificationAppName
                summary: islandContainer.notificationSummary
                body: islandContainer.notificationBody
                iconText: userConfig.statusIcons["notification"]
                iconFontFamily: root.iconFontFamily
                textFontFamily: root.textFontFamily
                heroFontFamily: root.heroFontFamily
                showCondition: !root.overviewVisible && islandContainer.islandState === "notification"
            }

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
                showCondition: !root.overviewVisible && islandContainer.islandState === "control_center"
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
