import QtQuick
import Quickshell.Services.Mpris

Item {
    property bool showCondition: false
    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property bool isCharging: false
    property int batteryCapacity: 0
    property string timePlayed: "0:00"
    property string timeTotal: "0:00"
    property real trackProgress: 0
    property var activePlayer: null
    property string iconFontFamily: "JetBrainsMono Nerd Font"
    property string textFontFamily: "Inter"

    anchors.fill: parent
    anchors.margins: 20
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 300 : 100
            easing.type: Easing.InOutQuad
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

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: ""
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.family: iconFontFamily
                    visible: isCharging
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: batteryCapacity + "%"
                    color: "white"
                    font.pixelSize: 14
                    font.family: textFontFamily
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.1
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: 28
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        anchors.rightMargin: 2
                        radius: 4
                        color: "transparent"
                        border.color: "#8e8e93"
                        border.width: 1

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            radius: 2
                            width: (parent.width - 4) * (batteryCapacity / 100.0)
                            color: {
                                if (batteryCapacity <= 10) return "#ff3b30";
                                if (batteryCapacity <= 20) return "#ffcc00";
                                return "#34c759";
                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 2
                        height: 6
                        radius: 1
                        color: "#8e8e93"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
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
                        onClicked: {
                            if (!activePlayer) return;
                            if (activePlayer.playbackState === MprisPlaybackState.Playing) activePlayer.pause();
                            else activePlayer.play();
                        }
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
                        onClicked: if (activePlayer) activePlayer.next()
                    }
                }
            }
        }
    }
}
