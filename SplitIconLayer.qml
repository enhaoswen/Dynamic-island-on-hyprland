import QtQuick

Item {
    property string iconText: ""
    property string iconFontFamily: "JetBrainsMono Nerd Font"
    property bool showCondition: false

    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 220 : 150
            easing.type: Easing.InOutQuad
        }
    }

    Text {
        anchors.centerIn: parent
        text: iconText
        color: "white"
        font.pixelSize: 18
        font.family: iconFontFamily
    }
}
