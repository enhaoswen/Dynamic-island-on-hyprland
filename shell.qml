import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import IslandBackend

PanelWindow {
    id: root
    color: "transparent"
    anchors { top: true; left: true; right: true }
    mask: Region { item: mainCapsule }
    implicitHeight: 300
    exclusiveZone: 45
    readonly property string iconFontFamily: "JetBrainsMono Nerd Font"
    readonly property string textFontFamily: "Inter"
    readonly property string heroFontFamily: "Inter Display"

    // --- 基础时钟引擎 ---
    QtObject {
        id: timeObj
        property string currentTime: "00:00"
    }
    Timer {
        id: clockTimer
        running: true; repeat: true; triggeredOnStart: true
        interval: 1000 
        onTriggered: {
            let now = new Date();
            timeObj.currentTime = Qt.formatTime(now, "hh:mm ap");
            interval = (60 - now.getSeconds()) * 1000 - now.getMilliseconds();
        }
    }

    // --- 灵动岛主容器与全局状态 ---
    Item {
        id: islandContainer
        anchors.fill: parent

        property string islandState: "normal"
        property string splitIcon: "🎧"
        property real osdProgressTarget: -1.0
        property real osdProgress: -1.0
        property string osdCustomText: ""
        property bool shakeCooling: false
        property real lockEndTime: 0
        property int currentWs: 1
        property int batteryCapacity: SysBackend.batteryCapacity
        property bool isCharging: SysBackend.batteryStatus === "Charging" || SysBackend.batteryStatus === "Full"
        property string _lastChargeStatus: SysBackend.batteryStatus
        property string _pendingVolType: ""
        property real   _pendingVolVal:  0.0
        property string _lastVolType: ""
        property real   _lastVolVal:  -1.0
        property bool btJustConnected: false
        property real   _pendingBlVal:  0.0
        readonly property bool splitShowsProgress: islandState === "split" && osdProgress >= 0
        readonly property bool splitShowsText: islandState === "split" && osdProgress < 0 && osdCustomText !== ""
        readonly property bool splitShowsIconOnly: islandState === "split" && osdProgress < 0 && osdCustomText === ""
        readonly property bool splitUsesExtendedLayout: splitShowsProgress || splitShowsText
        readonly property real splitCapsuleWidth: splitShowsProgress ? 248 : (splitShowsText ? 220 : 140)

        Behavior on osdProgress { SmoothedAnimation { velocity: 1.2; duration: 180; easing.type: Easing.InOutQuad } }

        function triggerSplitEvent(icon, shouldShake, progress, customText) {
            if (shouldShake === undefined) shouldShake = true;
            if (progress === undefined)    progress = -1.0;
            if (customText === undefined)  customText = "";

            splitIcon = icon; osdCustomText = customText; osdProgressTarget = progress;
            if (progress >= 0) osdProgress = progress;
            else osdProgress = -1.0;

            islandState = "split";
            if (shouldShake && !shakeCooling) { shakeAnim.restart(); shakeCooling = true; shakeCoolTimer.restart(); }
            autoHideTimer.restart();
        }

        Timer { id: shakeCoolTimer; interval: 250; onTriggered: islandContainer.shakeCooling = false }

        function smartRestoreState() {
            islandState = "normal";
            osdProgress = -1.0;
            osdCustomText = "";
        }

        Timer { id: autoHideTimer; interval: 2500; onTriggered: islandContainer.smartRestoreState() }

        function getWorkspaceIcon(wsId) {
            const icons = { 1: "", 2: "", 3: "", 4: "", 5: "", 6: "󰙯", 7: "󰈙", 8: "󰇮", 9: "󰊴", 10: "", "urgent": "" };
            return icons[wsId] || ""; 
        }

        Timer { id: btBlockVolTimer; interval: 2000; onTriggered: islandContainer.btJustConnected = false }
        Timer {
            id: volDebounce
            interval: 16
            onTriggered: {
                if (islandContainer.btJustConnected) return;
                if (islandContainer._pendingVolType !== islandContainer._lastVolType || Math.abs(islandContainer._pendingVolVal - islandContainer._lastVolVal) > 0.001) {
                    islandContainer._lastVolType = islandContainer._pendingVolType; islandContainer._lastVolVal  = islandContainer._pendingVolVal;
                    islandContainer.triggerSplitEvent(islandContainer._pendingVolType === "MUTE" ? "󰝟" : "󰕾", true, islandContainer._pendingVolVal, "");
                }
            }
        }
        Timer {
            id: blDebounce
            interval: 16
            onTriggered: {
                let icon = "󰃠";
                if (islandContainer._pendingBlVal < 0.3) icon = "󰃞";
                else if (islandContainer._pendingBlVal < 0.7) icon = "󰃟";
                islandContainer.triggerSplitEvent(icon, true, islandContainer._pendingBlVal, "");
            }
        }

        Connections {
            target: SysBackend

            function onWorkspaceChanged(wsId) {
                islandContainer.currentWs = wsId;
                islandContainer.islandState = "long_capsule";
                autoHideTimer.restart();
            }

            function onVolumeChanged(volPercentage, isMuted) {
                islandContainer._pendingVolType = isMuted ? "MUTE" : "VOL";
                islandContainer._pendingVolVal = volPercentage / 100.0;
                volDebounce.restart();
            }

            function onBatteryChanged(capacity, statusString) {
                islandContainer.batteryCapacity = capacity;
                islandContainer.isCharging = (statusString === "Charging" || statusString === "Full");
                if (islandContainer._lastChargeStatus !== "" && islandContainer._lastChargeStatus !== statusString) {
                    if (statusString === "Charging") islandContainer.triggerSplitEvent("", true, -1.0, ""); 
                    else if (statusString === "Discharging") islandContainer.triggerSplitEvent("", true, -1.0, ""); 
                }
                islandContainer._lastChargeStatus = statusString;
            }

            function onBrightnessChanged(val) {
                islandContainer._pendingBlVal = val;
                blDebounce.restart();
            }

            function onCapsLockChanged(isOn) {
                islandContainer.triggerSplitEvent(isOn ? "" : "", true, -1.0, isOn ? "Caps Lock ON" : "Caps Lock OFF", 1);
            }

            function onBluetoothChanged(isConnected) {
                islandContainer.btJustConnected = true; 
                btBlockVolTimer.restart();
                islandContainer.triggerSplitEvent("󰋋", true, -1.0, isConnected ? "Connected" : "Disconnected", 1);
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

        property var playersList: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
        property var activePlayer: {
            if (!playersList || playersList.length === 0) return null;
            for (let i = 0; i < playersList.length; i++) {
                if (playersList[i].playbackState === MprisPlaybackState.Playing) return playersList[i];
            }
            return playersList[0];
        }

        property string currentTrack:   activePlayer ? (activePlayer.trackTitle  || activePlayer.title  || "Unknown") : ""
        property string currentArtist: {
            if (!activePlayer) return "";
            let a = activePlayer.artist;
            if (!a && activePlayer.metadata) a = activePlayer.metadata["xesam:artist"];
            if (a) return Array.isArray(a) ? a.join(", ") : String(a);
            return "Unknown";
        }
        property string currentArtUrl:  activePlayer ? (activePlayer.trackArtUrl || activePlayer.artUrl || "") : ""
        property real   trackProgress: 0
        property string timePlayed:    "0:00"
        property string timeTotal:     "0:00"

        Timer {
            id: progressPoller
            interval: 500
            running: islandContainer.islandState === "expanded" && islandContainer.activePlayer !== null
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
            if (currentTrack !== "" && islandState !== "expanded") { islandState = "expanded"; autoHideTimer.restart(); }
        }

        // --- UI 渲染：保留旧分离气泡节点，但不再显示 ---
        Rectangle {
            id: splitBubble
            height: 32; width: 32; radius: 16; color: "black"; y: 8; z: -1
            property real targetX: islandContainer.islandState === "split" ? (islandContainer.width / 2) + 92 : (islandContainer.width / 2) - 16
            x: targetX
            Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

            readonly property bool isSplit: false
            opacity: isSplit ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: splitBubble.isSplit ? 300 : 250; easing.type: Easing.InOutQuad } }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: splitBubble; property: "rotation"; from: 0;   to: -25; duration: 60; easing.type: Easing.OutQuad }
                NumberAnimation { target: splitBubble; property: "rotation"; from: -25; to:  20; duration: 80; easing.type: Easing.InOutQuad }
                NumberAnimation { target: splitBubble; property: "rotation"; from:  20; to: -10; duration: 80; easing.type: Easing.InOutQuad }
                NumberAnimation { target: splitBubble; property: "rotation"; from: -10; to:   0; duration: 60; easing.type: Easing.OutQuad }
            }
            
            Text {
                id: splitIconText
                anchors.centerIn: parent; text: islandContainer.splitIcon; color: "white"
                font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"
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
              anchors.fill: parent; z: -1
              acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                  if (mouse.button === Qt.LeftButton){
                    if (islandContainer.islandState === "expanded") {
                      islandContainer.islandState = "normal"; 
                      islandContainer.osdProgress = -1.0;
                      islandContainer.osdCustomText = "";
                    } else {
                      islandContainer.islandState = "expanded"; 
                      autoHideTimer.restart();
                    }
                  }
                  else {
                      if (islandContainer.islandState === "control_center") {
                          islandContainer.islandState = "normal"; 
                          islandContainer.osdProgress = -1.0; 
                          islandContainer.osdCustomText = "";
                      } else {
                          islandContainer.islandState = "control_center"; 
                          autoHideTimer.stop(); 
                      }
                  } 
                }
            }

            ClockLayer {
                currentTime: timeObj.currentTime
                heroFontFamily: root.heroFontFamily
                showCondition: islandContainer.islandState === "normal"
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
                iconFontFamily: root.iconFontFamily
                textFontFamily: root.textFontFamily
                showCondition: islandContainer.islandState === "long_capsule"
            }

            ExpandedPlayerLayer {
                currentArtUrl: islandContainer.currentArtUrl
                currentTrack: islandContainer.currentTrack
                currentArtist: islandContainer.currentArtist
                isCharging: islandContainer.isCharging
                batteryCapacity: islandContainer.batteryCapacity
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
                showCondition: islandContainer.islandState === "control_center"
            }

        }

        states: [
            State { name: "normal";        when: islandContainer.islandState === "normal";         PropertyChanges { target: mainCapsule; width: 140; height: 38; radius: 19 } },
            State { name: "split";         when: islandContainer.islandState === "split";          PropertyChanges { target: mainCapsule; width: islandContainer.splitCapsuleWidth; height: 38; radius: 19 } },
            State { name: "long_capsule"; when: islandContainer.islandState === "long_capsule";   PropertyChanges { target: mainCapsule; width: 220; height: 38; radius: 19 } },
            State {name: "control_center";when: islandContainer.islandState === "control_center"; PropertyChanges { target: mainCapsule; width: 300; height: 38; radius: 19 } },
            State { name: "expanded";      when: islandContainer.islandState === "expanded";       PropertyChanges { target: mainCapsule; width: 400; height: 165; radius: 40 } }
        ]
    }
}
