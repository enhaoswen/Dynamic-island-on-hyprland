import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import IslandBackend

PanelWindow {
    id: root
    color: "transparent"
    anchors { top: true; left: true; right: true }
    mask: Region { item: mainCapsule }
    implicitHeight: 300
    exclusiveZone: 45

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
        property int batteryCapacity: 100
        property bool isCharging: false
        property string _lastChargeStatus: ""
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

            // --- 内容层 1: 时钟 ---
            Text {
                id: clockText
                anchors.centerIn: parent; text: timeObj.currentTime; color: "white"
                font.pixelSize: 18; font.bold: true
                readonly property bool showCondition: islandContainer.islandState === "normal"
                opacity: showCondition ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: clockText.showCondition ? 300 : 200; easing.type: Easing.InOutQuad } }
            }

            Item {
                id: splitIconOnlyLayer
                anchors.fill: parent
                readonly property bool showCondition: islandContainer.splitShowsIconOnly
                opacity: showCondition ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: splitIconOnlyLayer.showCondition ? 220 : 150; easing.type: Easing.InOutQuad } }

                Text {
                    anchors.centerIn: parent
                    text: islandContainer.splitIcon
                    color: "white"
                    font.pixelSize: 18
                    font.family: "JetBrainsMono Nerd Font"
                }
            }

            // --- 内容层 1.5: OSD 进度条与文字 ---
            Item {
                id: osdLayer
                anchors.fill: parent
                readonly property bool showCondition: islandContainer.splitUsesExtendedLayout
                opacity: showCondition ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: osdLayer.showCondition ? 280 : 200; easing.type: Easing.InOutQuad } }

                Item {
                    anchors.fill: parent
                    visible: islandContainer.splitShowsProgress

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            text: islandContainer.splitIcon
                            color: "white"
                            font.pixelSize: 18
                            font.family: "JetBrainsMono Nerd Font"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: Math.round(islandContainer.osdProgress * 100) + "%"
                            color: "white"
                            font.pixelSize: 20
                            font.family: "SF Pro Display"
                            font.bold: true
                            font.letterSpacing: -0.3
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item {
                        width: 30
                        height: 30
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            radius: 8
                            color: "#111111"
                            border.color: "#1f1f1f"
                            border.width: 1
                        }

                        Canvas {
                            id: osdProgressRing
                            anchors.fill: parent
                            antialiasing: true
                            property real progressValue: Math.max(0, Math.min(1, islandContainer.osdProgress))

                            onProgressValueChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d");
                                var size = Math.min(width, height);
                                var lineWidth = 3.5;
                                var center = size / 2;
                                var radius = (size - lineWidth) / 2 - 0.5;
                                var startAngle = -Math.PI / 2;
                                var endAngle = startAngle + (Math.PI * 2 * progressValue);

                                ctx.clearRect(0, 0, width, height);
                                ctx.lineCap = "round";
                                ctx.lineWidth = lineWidth;

                                ctx.strokeStyle = "rgba(255, 255, 255, 0.16)";
                                ctx.beginPath();
                                ctx.arc(center, center, radius, 0, Math.PI * 2, false);
                                ctx.stroke();

                                ctx.strokeStyle = "#ffffff";
                                ctx.beginPath();
                                ctx.arc(center, center, radius, startAngle, endAngle, false);
                                ctx.stroke();
                            }
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent; spacing: 14; visible: islandContainer.splitShowsText
                    Text {
                        text: islandContainer.splitIcon; color: "white"; font.pixelSize: 18
                        font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: islandContainer.osdCustomText; color: "white"; font.pixelSize: 16; font.bold: true
                        font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // --- 内容层 2: 工作区 ---
            Item {
                id: wsLayer
                anchors.fill: parent
                readonly property bool showCondition: islandContainer.islandState === "long_capsule"
                opacity: showCondition ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: wsLayer.showCondition ? 300 : 100; easing.type: Easing.InOutQuad } }

                Row {
                    anchors.centerIn: parent; spacing: 14
                    Text { text: islandContainer.getWorkspaceIcon(islandContainer.currentWs); font.pixelSize: 19; font.family: "JetBrainsMono Nerd Font"; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Workspace " + islandContainer.currentWs; color: "white"; font.pixelSize: 16; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            // --- 内容层 3: 展开态音乐面板 ---
            Item {
                id: expandedLayer
                anchors.fill: parent; anchors.margins: 20
                readonly property bool showCondition: islandContainer.islandState === "expanded"
                opacity: showCondition ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: expandedLayer.showCondition ? 300 : 100; easing.type: Easing.InOutQuad } }

                Column {
                    anchors.fill: parent; spacing: 14
                    Item {
                        width: parent.width; height: 60
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 16
                            Rectangle {
                                width: 60; height: 60; radius: 14; color: "#2c2c2e"; clip: true
                                Image { anchors.fill: parent; source: islandContainer.currentArtUrl; fillMode: Image.PreserveAspectCrop; visible: source.toString() !== ""; sourceSize: Qt.size(120, 120) }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                Text { text: islandContainer.currentTrack; color: "white"; font.bold: true; font.pixelSize: 16; width: 200; elide: Text.ElideRight }
                                Text { text: islandContainer.currentArtist; color: "#8e8e93"; font.pixelSize: 14; width: 200; elide: Text.ElideRight }
                            }
                        }
                        Row {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                            Text { text: ""; color: "#ffffff"; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"; visible: islandContainer.isCharging; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: islandContainer.batteryCapacity + "%"; color: "white"; font.pixelSize: 14; font.bold: true; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                            Item {
                                width: 28; height: 14; anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    anchors.fill: parent; anchors.rightMargin: 2; radius: 4; color: "transparent"; border.color: "#8e8e93"; border.width: 1
                                    Rectangle {
                                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.margins: 2; radius: 2
                                        width: (parent.width - 4) * (islandContainer.batteryCapacity / 100.0)
                                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                        color: {
                                            if (islandContainer.batteryCapacity <= 10) return "#ff3b30";
                                            else if (islandContainer.batteryCapacity <= 20) return "#ffcc00";
                                            else return "#34c759";
                                        }
                                    }
                                }
                                Rectangle { width: 2; height: 6; radius: 1; color: "#8e8e93"; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }

                    Item {
                        width: parent.width; height: 16
                        Text { id: timeL; anchors.left: parent.left; text: islandContainer.timePlayed; color: "#8e8e93"; font.pixelSize: 12 }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter; anchors.left: timeL.right; anchors.right: timeR.left; anchors.margins: 12; height: 6; radius: 3; color: "#333333"
                            Rectangle {
                                height: parent.height; radius: 3; color: "white"; width: parent.width * islandContainer.trackProgress
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                            }
                        }
                        Text { id: timeR; anchors.right: parent.right; text: islandContainer.timeTotal; color: "#8e8e93"; font.pixelSize: 12 }
                    }

                    Item {
                        width: parent.width; height: 36
                        Row {
                            anchors.centerIn: parent; spacing: 50
                            Item {
                                width: 28; height: 28; scale: pA.pressed ? 0.8 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }
                                Canvas {
                                    anchors.fill: parent; property color fillColor: pA.pressed ? "#888" : "white"
                                    onFillColorChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height); ctx.fillStyle = fillColor; ctx.strokeStyle = fillColor; ctx.lineJoin = "round"; ctx.lineWidth = 2;
                                        ctx.beginPath(); ctx.rect(3, 5, 3, 18); ctx.moveTo(14, 5); ctx.lineTo(6, 14); ctx.lineTo(14, 23); ctx.closePath(); ctx.moveTo(23, 5); ctx.lineTo(15, 14); ctx.lineTo(23, 23); ctx.closePath(); ctx.fill(); ctx.stroke();
                                    }
                                }
                                MouseArea { id: pA; anchors.fill: parent; anchors.margins: -15; onClicked: if (islandContainer.activePlayer) islandContainer.activePlayer.previous() }
                            }

                            Item {
                                width: 28; height: 28; scale: playA.pressed ? 0.8 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }
                                Row {
                                    anchors.centerIn: parent; spacing: 6; visible: islandContainer.activePlayer && islandContainer.activePlayer.playbackState === MprisPlaybackState.Playing
                                    Rectangle { width: 6; height: 20; radius: 2; color: playA.pressed ? "#888" : "white" }
                                    Rectangle { width: 6; height: 20; radius: 2; color: playA.pressed ? "#888" : "white" }
                                }
                                Canvas {
                                    anchors.fill: parent; visible: !islandContainer.activePlayer || islandContainer.activePlayer.playbackState !== MprisPlaybackState.Playing
                                    property color fillColor: playA.pressed ? "#888" : "white"
                                    onFillColorChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height); ctx.fillStyle = fillColor; ctx.strokeStyle = fillColor; ctx.lineJoin = "round"; ctx.lineWidth = 2;
                                        ctx.beginPath(); ctx.moveTo(8, 4); ctx.lineTo(24, 14); ctx.lineTo(8, 24); ctx.closePath(); ctx.fill(); ctx.stroke();
                                    }
                                }
                                MouseArea {
                                    id: playA; anchors.fill: parent; anchors.margins: -15
                                    onClicked: {
                                        if (!islandContainer.activePlayer) return;
                                        if (islandContainer.activePlayer.playbackState === MprisPlaybackState.Playing) islandContainer.activePlayer.pause();
                                        else islandContainer.activePlayer.play();
                                    }
                                }
                            }

                            Item {
                                width: 28; height: 28; scale: nA.pressed ? 0.8 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }
                                Canvas {
                                    anchors.fill: parent; property color fillColor: nA.pressed ? "#888" : "white"
                                    onFillColorChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d"); ctx.clearRect(0, 0, width, height); ctx.fillStyle = fillColor; ctx.strokeStyle = fillColor; ctx.lineJoin = "round"; ctx.lineWidth = 2;
                                        ctx.beginPath(); ctx.moveTo(5, 5); ctx.lineTo(13, 14); ctx.lineTo(5, 23); ctx.closePath(); ctx.moveTo(14, 5); ctx.lineTo(22, 14); ctx.lineTo(14, 23); ctx.closePath(); ctx.rect(22, 5, 3, 18); ctx.fill(); ctx.stroke();
                                    }
                                }
                                MouseArea { id: nA; anchors.fill: parent; anchors.margins: -15; onClicked: if (islandContainer.activePlayer) islandContainer.activePlayer.next() }
                            }
                        }
                    }
                }
              }
          // --- 内容层 4: 横向控制中心 ---
              Item {
                  id: controlLayer
                  anchors.fill: parent

                  readonly property bool showCondition: islandContainer.islandState === "control_center"
                  opacity: showCondition ? 1 : 0
                  visible: opacity > 0
                  Behavior on opacity {
                      NumberAnimation {
                          duration: controlLayer.showCondition ? 300 : 100
                          easing.type: Easing.InOutQuad
                      }
                  }

                  Row {
                      anchors.centerIn: parent
                      spacing: 35
                      
                      Item {
                          width: 30; height: 30
                          scale: wifiArea.pressed ? 0.8 : 1.0
                          Behavior on scale { NumberAnimation { duration: 100 } }
                          Process {
                            id: wifiProc
                            command: ["sh", "-c", "~/.config/quickshell/wifi-menu.sh"]
                          }
                          Text {
                              anchors.centerIn: parent
                              text: ""
                              color: "white"
                              font.pixelSize: 20
                              font.family: "JetBrainsMono Nerd Font"
                          }
                          MouseArea {
                              id: wifiArea
                              anchors.fill: parent
                              onClicked: {
                                  wifiProc.running = true

                              }
                          }
                      }

                      Item {
                          width: 30; height: 30
                          scale: btArea.pressed ? 0.8 : 1.0
                          Behavior on scale { NumberAnimation { duration: 100 } }
                          Process {
                            id: btproc
                            command: ["sh", "-c", "~/.config/quickshell/bluetooth-menu.sh"]
                          }
                          Text {
                              anchors.centerIn: parent
                              text: ""
                              color: "white"
                              font.pixelSize: 20
                              font.family: "JetBrainsMono Nerd Font"
                          }
                          MouseArea {
                              id: btArea
                              anchors.fill: parent
                              onClicked: {
                                  btproc.running = true
                              }
                          }
                      }

                      Item {
                          width: 30; height: 30
                          scale: wpArea.pressed ? 0.8 : 1.0
                          Behavior on scale { NumberAnimation { duration: 100 } }
                          Process {
                            id: wpproc
                            command: ["sh", "-c", "~/.config/quickshell/wallpaper-switch.sh"]
                          }
                          Text {
                              anchors.centerIn: parent
                              text: "󰋩"
                              color: "white"
                              font.pixelSize: 20
                              font.family: "JetBrainsMono Nerd Font"
                          }
                          MouseArea {
                              id: wpArea
                              anchors.fill: parent
                              onClicked: {
                                wpproc.running = true
                              }
                          }
                      }

                      Item {
                          width: 30; height: 30
                          scale: extraArea.pressed ? 0.8 : 1.0
                          Behavior on scale { NumberAnimation { duration: 100 } }
                          Process {
                            id: powerproc
                            command: ["sh", "-c", "~/.config/quickshell/powermenu"]
                          }
                          Text {
                              anchors.centerIn: parent
                              text: "󰣇"
                              color: "white"
                              font.pixelSize: 20
                              font.family: "JetBrainsMono Nerd Font"
                          }
                          MouseArea {
                              id: extraArea
                              anchors.fill: parent
                              onClicked: {
                                powerproc.running = true
                              }
                          }
                      }
                  }
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
