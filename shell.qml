import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import IslandBackend

PanelWindow {
    id: root
    UserConfig {
        id: userConfig
    }

    color: "transparent"
    anchors { top: true; left: true; right: true }
    mask: Region { item: mainCapsule }
    implicitHeight: 360
    exclusiveZone: 45
    readonly property string iconFontFamily: "JetBrainsMono Nerd Font"
    readonly property string textFontFamily: "Inter"
    readonly property string heroFontFamily: "Inter Display"

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
    Item {
        id: islandContainer
        anchors.fill: parent

        property string islandState: "normal"
        property string splitIcon: userConfig.statusIcons["default"]
        property real osdProgressTarget: -1.0
        property real osdProgress: -1.0
        property string osdCustomText: ""
        property real lockEndTime: 0
        property int currentWs: 1
        property int batteryCapacity: SysBackend.batteryCapacity
        property bool isCharging: SysBackend.batteryStatus === "Charging" || SysBackend.batteryStatus === "Full"
        property real currentVolume: -1
        property real currentBrightness: -1
        property string _lastChargeStatus: SysBackend.batteryStatus
        property string _pendingVolType: ""
        property real   _pendingVolVal:  0.0
        property string _lastVolType: ""
        property real   _lastVolVal:  -1.0
        property bool btJustConnected: false
        property real   _pendingBlVal:  0.0
        property real swipeTransitionProgress: 0
        property string restingState: "normal"
        property bool expandedByPlayerAutoOpen: false
        property string lyricsFetchState: "idle"
        property int lyricsRequestToken: 0
        property var syncedLyricLines: []
        property var plainLyricLines: []
        property int currentLyricIndex: -1
        property string currentLyricLine: ""
        property real lyricsCapsuleWidth: 220
        readonly property bool splitShowsProgress: islandState === "split" && osdProgress >= 0
        readonly property bool splitShowsText: islandState === "split" && osdProgress < 0 && osdCustomText !== ""
        readonly property bool splitShowsIconOnly: islandState === "split" && osdProgress < 0 && osdCustomText === ""
        readonly property bool splitUsesExtendedLayout: splitShowsProgress || splitShowsText
        readonly property real splitCapsuleWidth: splitShowsProgress ? 248 : (splitShowsText ? 220 : 140)
        readonly property bool canShowLyricsSwipe: islandState === "normal" || islandState === "long_capsule" || islandState === "lyrics"
        readonly property string lyricsDisplayText: {
            if (currentLyricLine !== "") return currentLyricLine;
            if (lyricsFetchState === "loading") return "Loading lyrics";
            if (lyricsFetchState === "error") return "Lyrics unavailable";
            if (lyricsFetchState === "empty") return currentTrack !== "" ? "" : "No music playing";
            return currentTrack !== "" ? "Lyrics standby" : "No music playing";
        }

        Behavior on osdProgress { SmoothedAnimation { velocity: 1.2; duration: 180; easing.type: Easing.InOutQuad } }
        Behavior on swipeTransitionProgress {
            NumberAnimation {
                duration: capsuleMouseArea.pressed ? 0 : 220
                easing.type: Easing.OutCubic
            }
        }

        function triggerSplitEvent(icon, shouldShake, progress, customText) {
            if (shouldShake === undefined) shouldShake = true;
            if (progress === undefined)    progress = -1.0;
            if (customText === undefined)  customText = "";

            if (islandState === "control_center") return;

            splitIcon = icon; osdCustomText = customText; osdProgressTarget = progress;
            if (progress >= 0) osdProgress = progress;
            else osdProgress = -1.0;

            islandState = "split";
            autoHideTimer.restart();
        }

        function smartRestoreState() {
            islandState = restingState;
            osdProgress = -1.0;
            osdCustomText = "";
            swipeTransitionProgress = restingState === "lyrics" ? 1 : 0;
            expandedByPlayerAutoOpen = false;
            if (restingState === "lyrics") syncLyricsCapsuleWidth();
        }

        function setRestingState(nextState) {
            restingState = nextState === "lyrics" ? "lyrics" : "normal";
        }

        function showExpandedPlayer(autoOpened) {
            islandState = "expanded";
            expandedByPlayerAutoOpen = autoOpened;
            if (autoOpened) autoHideTimer.restart();
            else autoHideTimer.stop();
        }

        function showLyricsCapsule() {
            setRestingState("lyrics");
            islandState = "lyrics";
            osdProgress = -1.0;
            osdCustomText = "";
            swipeTransitionProgress = 1;
            updateCurrentLyricLine();
            syncLyricsCapsuleWidth();
            autoHideTimer.stop();
        }

        function showTimeCapsule() {
            setRestingState("normal");
            islandState = "normal";
            osdProgress = -1.0;
            osdCustomText = "";
            swipeTransitionProgress = 0;
            autoHideTimer.stop();
        }

        Timer { id: autoHideTimer; interval: 2500; onTriggered: islandContainer.smartRestoreState() }

        function getWorkspaceIcon(wsId) {
            return userConfig.workspaceIcon(wsId);
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
                    islandContainer.triggerSplitEvent(
                        islandContainer._pendingVolType === "MUTE"
                            ? userConfig.statusIcons["mute"]
                            : userConfig.statusIcons["volume"],
                        true,
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
                let icon = userConfig.statusIcons["brightnessHigh"];
                if (islandContainer._pendingBlVal < 0.3) icon = userConfig.statusIcons["brightnessLow"];
                else if (islandContainer._pendingBlVal < 0.7) icon = userConfig.statusIcons["brightnessMedium"];
                islandContainer.triggerSplitEvent(icon, true, islandContainer._pendingBlVal, "");
            }
        }

        Connections {
            target: SysBackend

            function onWorkspaceChanged(wsId) {
                islandContainer.currentWs = wsId;
                if (islandContainer.islandState === "control_center") return;
                islandContainer.islandState = "long_capsule";
                islandContainer.swipeTransitionProgress = 0;
                autoHideTimer.restart();
            }

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
                    if (statusString === "Charging") islandContainer.triggerSplitEvent(userConfig.statusIcons["charging"], true, -1.0, "");
                    else if (statusString === "Discharging") islandContainer.triggerSplitEvent(userConfig.statusIcons["discharging"], true, -1.0, "");
                }
                islandContainer._lastChargeStatus = statusString;
            }

            function onBrightnessChanged(val) {
                islandContainer._pendingBlVal = val;
                islandContainer.currentBrightness = val;
                blDebounce.restart();
            }

            function onCapsLockChanged(isOn) {
                islandContainer.triggerSplitEvent(
                    isOn ? userConfig.statusIcons["capsLockOn"] : userConfig.statusIcons["capsLockOff"],
                    true,
                    -1.0,
                    isOn ? "Caps Lock ON" : "Caps Lock OFF",
                    1
                );
            }

            function onBluetoothChanged(isConnected) {
                islandContainer.btJustConnected = true; 
                btBlockVolTimer.restart();
                islandContainer.triggerSplitEvent(
                    userConfig.statusIcons["bluetooth"],
                    true,
                    -1.0,
                    isConnected ? "Connected" : "Disconnected",
                    1
                );
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

        function valueToMilliseconds(val) {
            let num = Number(val);
            if (isNaN(num) || num <= 0) return 0;
            if (num < 10000) return Math.floor(num * 1000);
            if (num < 100000000) return Math.floor(num);
            return Math.floor(num / 1000);
        }

        function valueToSeconds(val) {
            return Math.floor(valueToMilliseconds(val) / 1000);
        }

        function normalizeLyricsText(text) {
            return String(text === undefined || text === null ? "" : text)
                .toLowerCase()
                .replace(/[\s\-_()[\]{}"'`~!@#$%^&*+=|\\:;,.?<>/]+/g, " ")
                .trim();
        }

        function cleanLyricLineText(text) {
            return String(text === undefined || text === null ? "" : text)
                .replace(/\s+/g, " ")
                .trim();
        }

        function parseSyncedLyrics(rawLyrics) {
            const source = String(rawLyrics === undefined || rawLyrics === null ? "" : rawLyrics);
            const rows = source.split(/\r?\n/);
            const parsed = [];

            for (let i = 0; i < rows.length; i++) {
                const row = rows[i];
                const tagPattern = /\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]/g;
                const lineText = cleanLyricLineText(row.replace(tagPattern, ""));
                let match = null;

                while ((match = tagPattern.exec(row)) !== null) {
                    if (lineText === "") continue;
                    const minutes = Number(match[1]) || 0;
                    const seconds = Number(match[2]) || 0;
                    const fraction = ((match[3] || "") + "000").slice(0, 3);
                    parsed.push({
                        timeMs: minutes * 60000 + seconds * 1000 + (Number(fraction) || 0),
                        text: lineText
                    });
                }
            }

            parsed.sort((a, b) => a.timeMs - b.timeMs);
            return parsed;
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

        function clearLyricsState(nextState) {
            syncedLyricLines = [];
            plainLyricLines = [];
            currentLyricIndex = -1;
            currentLyricLine = "";
            lyricsFetchState = nextState === undefined ? "idle" : nextState;
        }

        function applyLyricsPayload(payload) {
            const synced = parseSyncedLyrics(payload && payload.syncedLyrics ? payload.syncedLyrics : "");
            let plainSource = "";

            if (payload && payload.plainLyrics) plainSource = payload.plainLyrics;
            else if (payload && payload.syncedLyrics) plainSource = payload.syncedLyrics;

            syncedLyricLines = synced;
            plainLyricLines = parsePlainLyrics(plainSource);
            lyricsFetchState = syncedLyricLines.length > 0 || plainLyricLines.length > 0 ? "ready" : "empty";
            updateCurrentLyricLine();
        }

        function pickBestLyricsCandidate(candidates) {
            if (!Array.isArray(candidates) || candidates.length === 0) return null;

            const wantedTitle = normalizeLyricsText(lyricsLookupTitle);
            const wantedArtist = normalizeLyricsText(lyricsLookupArtist);
            const wantedAlbum = normalizeLyricsText(currentAlbum);
            const wantedDuration = currentTrackDurationSeconds;
            let bestCandidate = null;
            let bestScore = -1;

            for (let i = 0; i < candidates.length; i++) {
                const item = candidates[i];
                const itemTitle = normalizeLyricsText(item && item.trackName ? item.trackName : "");
                const itemArtist = normalizeLyricsText(item && item.artistName ? item.artistName : "");
                const itemAlbum = normalizeLyricsText(item && item.albumName ? item.albumName : "");
                const itemDuration = Number(item && item.duration ? item.duration : 0) || 0;
                let score = 0;

                if (wantedTitle !== "") {
                    if (itemTitle === wantedTitle) score += 40;
                    else if (itemTitle !== "" && (itemTitle.indexOf(wantedTitle) >= 0 || wantedTitle.indexOf(itemTitle) >= 0)) score += 20;
                }

                if (wantedArtist !== "") {
                    if (itemArtist === wantedArtist) score += 35;
                    else if (itemArtist !== "" && (itemArtist.indexOf(wantedArtist) >= 0 || wantedArtist.indexOf(itemArtist) >= 0)) score += 18;
                }

                if (wantedAlbum !== "") {
                    if (itemAlbum === wantedAlbum) score += 12;
                    else if (itemAlbum !== "" && (itemAlbum.indexOf(wantedAlbum) >= 0 || wantedAlbum.indexOf(itemAlbum) >= 0)) score += 6;
                }

                if (wantedDuration > 0 && itemDuration > 0) {
                    const durationDiff = Math.abs(itemDuration - wantedDuration);
                    if (durationDiff <= 1) score += 18;
                    else if (durationDiff <= 3) score += 12;
                    else if (durationDiff <= 8) score += 6;
                }

                if (item && item.syncedLyrics) score += 25;
                else if (item && item.plainLyrics) score += 12;

                if (score > bestScore) {
                    bestScore = score;
                    bestCandidate = item;
                }
            }

            return bestCandidate;
        }

        function fetchLyricsForCurrentTrack() {
            lyricsRequestToken += 1;
            const requestToken = lyricsRequestToken;

            if (lyricsTrackKey === "") {
                clearLyricsState("idle");
                return;
            }

            const inlineLyrics = String(inlineLyricsRaw === undefined || inlineLyricsRaw === null ? "" : inlineLyricsRaw).trim();
            if (inlineLyrics !== "") {
                applyLyricsPayload({ syncedLyrics: inlineLyrics, plainLyrics: inlineLyrics });
                return;
            }

            clearLyricsState("loading");

            const queryParts = ["track_name=" + encodeURIComponent(lyricsLookupTitle)];
            if (lyricsLookupArtist !== "") queryParts.push("artist_name=" + encodeURIComponent(lyricsLookupArtist));
            if (currentAlbum !== "") queryParts.push("album_name=" + encodeURIComponent(currentAlbum));
            if (currentTrackDurationSeconds > 0) queryParts.push("duration=" + encodeURIComponent(currentTrackDurationSeconds));

            const xhr = new XMLHttpRequest();
            xhr.open("GET", "https://lrclib.net/api/search?" + queryParts.join("&"));
            xhr.timeout = 4500;
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                if (requestToken !== islandContainer.lyricsRequestToken) return;

                if (xhr.status >= 200 && xhr.status < 300) {
                    try {
                        const results = JSON.parse(xhr.responseText);
                        const bestCandidate = islandContainer.pickBestLyricsCandidate(results);
                        if (bestCandidate) islandContainer.applyLyricsPayload(bestCandidate);
                        else islandContainer.clearLyricsState("empty");
                    } catch (error) {
                        islandContainer.clearLyricsState("error");
                    }
                } else if (xhr.status === 404) {
                    islandContainer.clearLyricsState("empty");
                } else {
                    islandContainer.clearLyricsState("error");
                }
            };
            xhr.onerror = function() {
                if (requestToken !== islandContainer.lyricsRequestToken) return;
                islandContainer.clearLyricsState("error");
            };
            xhr.ontimeout = function() {
                if (requestToken !== islandContainer.lyricsRequestToken) return;
                islandContainer.clearLyricsState("error");
            };
            xhr.send();
        }

        function updateCurrentLyricLine(positionValue) {
            const positionMs = valueToMilliseconds(positionValue === undefined && activePlayer ? activePlayer.position : positionValue);

            if (syncedLyricLines.length > 0) {
                let lineIndex = 0;
                for (let i = 0; i < syncedLyricLines.length; i++) {
                    if (positionMs >= syncedLyricLines[i].timeMs) lineIndex = i;
                    else break;
                }
                currentLyricIndex = lineIndex;
                currentLyricLine = syncedLyricLines[lineIndex].text;
                return;
            }

            if (plainLyricLines.length > 0) {
                let lineIndex = 0;
                if (plainLyricLines.length > 1) {
                    if (currentTrackDurationSeconds > 0) {
                        const progress = Math.max(0, Math.min(0.999, positionMs / (currentTrackDurationSeconds * 1000)));
                        lineIndex = Math.min(plainLyricLines.length - 1, Math.floor(progress * plainLyricLines.length));
                    } else {
                        lineIndex = Math.min(plainLyricLines.length - 1, Math.floor(positionMs / 4000));
                    }
                }
                currentLyricIndex = lineIndex;
                currentLyricLine = plainLyricLines[lineIndex];
                return;
            }

            currentLyricIndex = -1;
            currentLyricLine = "";
        }

        property var playersList: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
        property var activePlayer: {
            if (!playersList || playersList.length === 0) return null;
            for (let i = 0; i < playersList.length; i++) {
                if (playersList[i].playbackState === MprisPlaybackState.Playing) return playersList[i];
            }
            return playersList[0];
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
        property string currentAlbum: {
            if (!activePlayer) return "";
            let album = activePlayer.album;
            if (!album && activePlayer.metadata) album = activePlayer.metadata["xesam:album"];
            return album ? String(album) : "";
        }
        property string currentArtUrl:  activePlayer ? (activePlayer.trackArtUrl || activePlayer.artUrl || "") : ""
        property string inlineLyricsRaw: {
            if (!activePlayer || !activePlayer.metadata) return "";
            let inlineLyrics = activePlayer.metadata["xesam:asText"];
            if (!inlineLyrics) inlineLyrics = activePlayer.metadata["xesam:comment"];
            if (Array.isArray(inlineLyrics)) return inlineLyrics.join("\n");
            return inlineLyrics ? String(inlineLyrics) : "";
        }
        property int currentTrackDurationSeconds: {
            if (!activePlayer) return 0;
            let totalLen = Number(activePlayer.length) || 0;
            if (totalLen <= 0 && activePlayer.metadata && activePlayer.metadata["mpris:length"]) totalLen = Number(activePlayer.metadata["mpris:length"]);
            return valueToSeconds(totalLen);
        }
        property string lyricsTrackKey: {
            if (lyricsLookupTitle === "") return "";
            return [
                lyricsLookupTitle.trim(),
                lyricsLookupArtist.trim(),
                currentAlbum.trim(),
                String(currentTrackDurationSeconds)
            ].join("||");
        }
        property real   trackProgress: 0
        property string timePlayed:    "0:00"
        property string timeTotal:     "0:00"

        Timer {
            id: progressPoller
            interval: 500
            running: islandContainer.activePlayer !== null && (
                islandContainer.islandState === "expanded"
                || (islandContainer.islandState === "lyrics"
                    && (islandContainer.syncedLyricLines.length > 0 || islandContainer.plainLyricLines.length > 1))
            )
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

                if (islandContainer.islandState === "lyrics") islandContainer.updateCurrentLyricLine(currentPos);
            }
        }

        onLyricsTrackKeyChanged: fetchLyricsForCurrentTrack()

        onCurrentTrackChanged: {
            if (currentTrack !== ""
                    && islandState !== "control_center") {
                if (islandState === "expanded" && !expandedByPlayerAutoOpen) return;
                showExpandedPlayer(true);
            }
        }

        // --- UI 渲染：灵动岛主干 ---
        Rectangle {
            id: mainCapsule
            color: "black"; y: 4; anchors.horizontalCenter: parent.horizontalCenter; clip: true

            Behavior on width  { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
            Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
            Behavior on radius { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

            MouseArea {
                id: capsuleMouseArea
                anchors.fill: parent
                z: -1
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

                  if (mouse.button === Qt.LeftButton){
                    if (islandContainer.islandState === "expanded") {
                      autoHideTimer.stop();
                      islandContainer.smartRestoreState();
                    } else {
                      islandContainer.showExpandedPlayer(false);
                    }
                  }
	                  else {
	                      if (islandContainer.islandState === "control_center") {
	                          islandContainer.smartRestoreState();
	                      } else {
	                          islandContainer.islandState = "control_center"; 
	                          autoHideTimer.stop(); 
	                      }
                  } 
                }
            }

            SwipeLyricsLayer {
                id: swipeLyricsLayer
                lyricText: islandContainer.lyricsDisplayText
                timeText: timeObj.currentTime
                textFontFamily: root.textFontFamily
                timeFontFamily: root.heroFontFamily
                textPixelSize: 16
                minimumWidth: 220
                maximumWidth: Math.max(220, root.width - 48)
                transitionProgress: islandContainer.swipeTransitionProgress
                showCondition: islandContainer.islandState === "normal"
                    || islandContainer.islandState === "lyrics"
                    || (islandContainer.islandState === "long_capsule" && islandContainer.swipeTransitionProgress > 0)
                onPreferredWidthChanged: {
                    if (islandContainer.islandState === "lyrics") islandContainer.syncLyricsCapsuleWidth();
                }
            }

            SplitIconLayer {
                iconText: islandContainer.splitIcon
                iconFontFamily: root.iconFontFamily
                showCondition: islandContainer.splitShowsIconOnly
            }

            OsdLayer {
                iconText: islandContainer.splitIcon
                progress: islandContainer.osdProgress
                customText: islandContainer.osdCustomText
                iconFontFamily: root.iconFontFamily
                textFontFamily: root.textFontFamily
                heroFontFamily: root.heroFontFamily
                showCondition: islandContainer.splitUsesExtendedLayout
            }

            WorkspaceLayer {
                workspaceId: islandContainer.currentWs
                workspaceIcon: islandContainer.getWorkspaceIcon(islandContainer.currentWs)
                displayText: "Workspace " + islandContainer.currentWs
                iconFontFamily: root.iconFontFamily
                textFontFamily: root.textFontFamily
                showCondition: islandContainer.islandState === "long_capsule" && islandContainer.swipeTransitionProgress < 0.001
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
                showCondition: islandContainer.islandState === "expanded"
            }

            ControlCenterLayer {
                iconFontFamily: root.iconFontFamily
                textFontFamily: root.textFontFamily
                heroFontFamily: root.heroFontFamily
                currentTime: timeObj.currentTime
                currentDateLabel: timeObj.currentDateLabel
                batteryCapacity: islandContainer.batteryCapacity
                isCharging: islandContainer.isCharging
                volumeLevel: islandContainer.currentVolume
                brightnessLevel: islandContainer.currentBrightness
                currentWorkspace: islandContainer.currentWs
                workspaceIcon: islandContainer.getWorkspaceIcon(islandContainer.currentWs)
                currentTrack: islandContainer.currentTrack
                currentArtist: islandContainer.currentArtist
                showCondition: islandContainer.islandState === "control_center"
            }

        }

        states: [
            State { name: "normal";        when: islandContainer.islandState === "normal";         PropertyChanges { target: mainCapsule; width: 140; height: 38; radius: 19 } },
            State { name: "split";         when: islandContainer.islandState === "split";          PropertyChanges { target: mainCapsule; width: islandContainer.splitCapsuleWidth; height: 38; radius: 19 } },
            State { name: "long_capsule"; when: islandContainer.islandState === "long_capsule";   PropertyChanges { target: mainCapsule; width: 220; height: 38; radius: 19 } },
            State { name: "lyrics";       when: islandContainer.islandState === "lyrics";         PropertyChanges { target: mainCapsule; width: islandContainer.lyricsCapsuleWidth; height: 38; radius: 19 } },
            State { name: "control_center"; when: islandContainer.islandState === "control_center"; PropertyChanges { target: mainCapsule; width: 420; height: 292; radius: 34 } },
            State { name: "expanded";      when: islandContainer.islandState === "expanded";       PropertyChanges { target: mainCapsule; width: 400; height: 165; radius: 40 } }
        ]
    }
}
