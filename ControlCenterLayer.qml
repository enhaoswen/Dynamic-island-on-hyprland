import QtQuick
import Quickshell.Io

Item {
    property bool showCondition: false
    property string iconFontFamily: "JetBrainsMono Nerd Font"

    anchors.fill: parent
    opacity: showCondition ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 300 : 100
            easing.type: Easing.InOutQuad
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 35

        Repeater {
            model: [
                { icon: "", command: "~/.config/quickshell/wifi-menu.sh" },
                { icon: "", command: "~/.config/quickshell/bluetooth-menu.sh" },
                { icon: "󰋩", command: "~/.config/quickshell/wallpaper-switch.sh" },
                { icon: "󰣇", command: "~/.config/quickshell/powermenu" }
            ]

            delegate: Item {
                width: 30
                height: 30
                scale: launchArea.pressed ? 0.8 : 1.0

                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }

                Process {
                    id: launcher
                    command: ["sh", "-c", modelData.command]
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    color: "white"
                    font.pixelSize: 20
                    font.family: iconFontFamily
                }

                MouseArea {
                    id: launchArea
                    anchors.fill: parent
                    onClicked: launcher.running = true
                }
            }
        }
    }
}
