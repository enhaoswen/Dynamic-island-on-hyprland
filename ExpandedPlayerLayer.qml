import QtQuick
import Quickshell.Services.Mpris

Item {
    signal controlPressed()

    UserConfig {
        id: userConfig
    }

    property bool showCondition: false
    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property string timePlayed: "0:00"
    property string timeTotal: "0:00"
    property real trackProgress: 0
    property var activePlayer: null
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property real visualizerPhase: 0

    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

    function visualizerLevel(index) {
        const phase = visualizerPhase + index * 0.78;
        const primary = (Math.sin(phase) + 1) * 0.5;
        const secondary = (Math.sin(phase * 2 + index * 0.95) + 1) * 0.5;
        return 0.22 + primary * 0.42 + secondary * 0.24;
    }

    function pausedVisualizerLevel(index) {
        const levels = [0.34, 0.58, 0.82, 0.58, 0.34];
        return levels[index] || 0.4;
    }

    function togglePlayback() {
        if (!activePlayer || !activePlayer.canControl) return;

        if (activePlayer.canTogglePlaying) {
            activePlayer.togglePlaying();
            return;
        }

        if (activePlayer.playbackState === MprisPlaybackState.Playing) {
            if (activePlayer.canPause) activePlayer.pause();
            return;
        }

        if (activePlayer.canPlay) activePlayer.play();
    }

    anchors.fill: parent
    anchors.margins: 20
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 300 : 100
            easing.type: Easing.InOutQuad
        }
    }

    Timer {
        interval: 32
        repeat: true
        running: showCondition && isPlaying
        onTriggered: {
            visualizerPhase += 0.18;
            if (visualizerPhase > Math.PI * 2) visualizerPhase -= Math.PI * 2;
        }
    }

    Column {
        anchors.fill: parent
        spacing: 14

        Item {
            width: parent.width
            height: 60

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16

                Rectangle {
                    width: 60
                    height: 60
                    radius: 14
                    color: "#2c2c2e"
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: currentArtUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: source.toString() !== ""
                        sourceSize: Qt.size(120, 120)
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: currentTrack
                        color: "white"
                        font.pixelSize: 16
                        font.family: textFontFamily
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.15
                        width: 180
                        elide: Text.ElideRight
                    }

                    Text {
                        text: currentArtist
                        color: "#8e8e93"
                        font.pixelSize: 14
                        font.family: textFontFamily
                        font.weight: Font.Medium
                        width: 200
                        elide: Text.ElideRight
                    }
                }
            }

            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 22

                Row {
                    anchors.centerIn: parent
                    height: parent.height
                    spacing: 4

                    Repeater {
                        model: 5

                        delegate: Rectangle {
                            width: 4
                            height: isPlaying
                                ? 6 + (parent.height - 6) * visualizerLevel(index)
                                : 6 + (parent.height - 6) * pausedVisualizerLevel(index)
                            radius: 2
                            color: isPlaying ? "#b56cff" : "#5f4b72"
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on height {
                                NumberAnimation {
                                    duration: isPlaying ? 120 : 260
                                    easing.type: Easing.InOutQuad
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: isPlaying ? 140 : 280
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 16

            Text {
                id: timeL
                anchors.left: parent.left
                text: timePlayed
                color: "#8e8e93"
                font.pixelSize: 12
                font.family: textFontFamily
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: timeL.right
                anchors.right: timeR.left
                anchors.margins: 12
                height: 6
                radius: 3
                color: "#333333"

                Rectangle {
                    height: parent.height
                    radius: 3
                    color: "white"
                    width: parent.width * trackProgress

                    Behavior on width {
                        NumberAnimation {
                            duration: 500
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Text {
                id: timeR
                anchors.right: parent.right
                text: timeTotal
                color: "#8e8e93"
                font.pixelSize: 12
                font.family: textFontFamily
                font.weight: Font.Medium
            }
        }

        Item {
            width: parent.width
            height: 36

            Row {
                anchors.centerIn: parent
                spacing: 50

                Item {
                    width: 28
                    height: 28
                    scale: prevArea.pressed ? 0.8 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 100 }
                    }

                    Canvas {
                        anchors.fill: parent
                        property color fillColor: prevArea.pressed ? "#888" : "white"

                        onFillColorChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = fillColor;
                            ctx.strokeStyle = fillColor;
                            ctx.lineJoin = "round";
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            ctx.rect(3, 5, 3, 18);
                            ctx.moveTo(14, 5);
                            ctx.lineTo(6, 14);
                            ctx.lineTo(14, 23);
                            ctx.closePath();
                            ctx.moveTo(23, 5);
                            ctx.lineTo(15, 14);
                            ctx.lineTo(23, 23);
                            ctx.closePath();
                            ctx.fill();
                            ctx.stroke();
                        }
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        anchors.margins: -15
                        preventStealing: true
                        onPressed: (mouse) => {
                            controlPressed();
                            mouse.accepted = true;
                        }
                        onClicked: if (activePlayer) activePlayer.previous()
                    }
                }

                Item {
                    width: 28
                    height: 28
                    scale: playArea.pressed ? 0.8 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 100 }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        visible: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

                        Rectangle { width: 6; height: 20; radius: 2; color: playArea.pressed ? "#888" : "white" }
                        Rectangle { width: 6; height: 20; radius: 2; color: playArea.pressed ? "#888" : "white" }
                    }

                    Canvas {
                        anchors.fill: parent
                        visible: !activePlayer || activePlayer.playbackState !== MprisPlaybackState.Playing
                        property color fillColor: playArea.pressed ? "#888" : "white"

                        onFillColorChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = fillColor;
                            ctx.strokeStyle = fillColor;
                            ctx.lineJoin = "round";
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            ctx.moveTo(8, 4);
                            ctx.lineTo(24, 14);
                            ctx.lineTo(8, 24);
                            ctx.closePath();
                            ctx.fill();
                            ctx.stroke();
                        }
                    }

                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        anchors.margins: -15
                        preventStealing: true
                        onPressed: (mouse) => {
                            controlPressed();
                            mouse.accepted = true;
                        }
                        onClicked: togglePlayback()
                    }
                }

                Item {
                    width: 28
                    height: 28
                    scale: nextArea.pressed ? 0.8 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 100 }
                    }

                    Canvas {
                        anchors.fill: parent
                        property color fillColor: nextArea.pressed ? "#888" : "white"

                        onFillColorChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = fillColor;
                            ctx.strokeStyle = fillColor;
                            ctx.lineJoin = "round";
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            ctx.moveTo(5, 5);
                            ctx.lineTo(13, 14);
                            ctx.lineTo(5, 23);
                            ctx.closePath();
                            ctx.moveTo(14, 5);
                            ctx.lineTo(22, 14);
                            ctx.lineTo(14, 23);
                            ctx.closePath();
                            ctx.rect(22, 5, 3, 18);
                            ctx.fill();
                            ctx.stroke();
                        }
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        anchors.margins: -15
                        preventStealing: true
                        onPressed: (mouse) => {
                            controlPressed();
                            mouse.accepted = true;
                        }
                        onClicked: if (activePlayer) activePlayer.next()
                    }
                }
            }
        }
    }
}
